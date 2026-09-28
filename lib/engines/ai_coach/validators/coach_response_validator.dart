import 'dart:convert';

import 'package:gymgenius/domain/enums/workout_adjustment.dart';
import 'package:gymgenius/engines/ai_coach/models/coach_context.dart';
import 'package:gymgenius/engines/ai_coach/models/coach_response.dart';
import 'package:gymgenius/engines/ai_coach/repair/json_repair_service.dart';

/// Validates and guardrails AI Coach JSON responses.
class CoachResponseValidator {
  final JsonRepairService _jsonRepair;

  CoachResponseValidator({
    JsonRepairService? jsonRepair,
  }) : _jsonRepair = jsonRepair ?? JsonRepairService();

  /// Forbidden action tags when the Decision Engine reduced load,
  /// prescribed rest, recovery, or a protective session.
  static const forbiddenWhenProtective = {
    'increase_volume',
    'increase_intensity',
    'increase_load',
    'increase_weight',
    'add_sets',
    'add_volume',
    'add_weight',
    'push_harder',
    'train_harder',
    'skip_rest',
  };

  /// Text markers representing advice that would conflict with
  /// a protective workout decision.
  static const forbiddenTextMarkers = [
    // English.
    'increase volume',
    'increase intensity',
    'increase load',
    'increase weight',
    'add more sets',
    'add sets',
    'add more volume',
    'add weight',
    'more weight',
    'train harder',
    'push harder',
    'skip rest',
    'reduce rest',

    // French.
    'augmenter le volume',
    'augmente le volume',
    'augmenter l’intensité',
    "augmenter l'intensité",
    'augmente l’intensité',
    "augmente l'intensité",
    'augmenter la charge',
    'augmente la charge',
    'augmenter le poids',
    'augmente le poids',
    'ajouter des séries',
    'ajoute des séries',
    'plus de séries',
    'ajouter du volume',
    'ajoute du volume',
    'ajouter du poids',
    'ajoute du poids',
    'pousser plus fort',
    'pousse plus fort',
    's’entraîner plus fort',
    "s'entraîner plus fort",
    'entrainer plus fort',
    'ignorer le repos',
    'sauter le repos',
    'réduire le repos',
    'réduis le repos',
  ];

  /// Tries to parse a structured CoachResponse from raw text.
  /// Returns null if parsing fails.
  CoachResponse? tryParse({
    required String raw,
    required CoachContext context,
    required String providerId,
    required String promptVersion,
    DateTime? generatedAt,
  }) {
    // -----------------------------------------------------------------------
    // Step 1: Use the JSON repair service.
    // -----------------------------------------------------------------------
    try {
      final decoded = _jsonRepair.parseJsonWithRepair(
        raw,
        'coach_response',
      );

      final response = _responseFromDecoded(
        decoded,
        providerId: providerId,
        promptVersion: promptVersion,
        generatedAt: generatedAt,
      );

      return _finalizeResponse(
        response,
        context,
      );
    } catch (_) {
      // Continue to next strategy.
    }

    // -----------------------------------------------------------------------
    // Step 2: Extract a bare JSON object using brace boundaries.
    // -----------------------------------------------------------------------
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');

      if (start >= 0 && end > start) {
        final substring = raw.substring(start, end + 1);
        final decoded = jsonDecode(substring);

        final response = _responseFromDecoded(
          decoded,
          providerId: providerId,
          promptVersion: promptVersion,
          generatedAt: generatedAt,
        );

        return _finalizeResponse(
          response,
          context,
        );
      }
    } catch (_) {
      // Continue.
    }

    // -----------------------------------------------------------------------
    // Step 3: Handle providers that return:
    // { "message": "{\"message\":\"...\" ...}" }
    // -----------------------------------------------------------------------
    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];

        if (message is String) {
          final trimmedMessage = message.trim();

          if (trimmedMessage.startsWith('{')) {
            final nested = jsonDecode(trimmedMessage);

            final response = _responseFromDecoded(
              nested,
              providerId: providerId,
              promptVersion: promptVersion,
              generatedAt: generatedAt,
            );

            final finalized = _finalizeResponse(
              response,
              context,
            );

            if (finalized != null) {
              return finalized;
            }
          }
        }
      }
    } catch (_) {
      // Continue.
    }

    return null;
  }

  /// Converts decoded JSON into a CoachResponse.
  CoachResponse _responseFromDecoded(
    dynamic decoded, {
    required String providerId,
    required String promptVersion,
    DateTime? generatedAt,
  }) {
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Coach response must be a JSON object.',
      );
    }

    return CoachResponse.fromJson(
      decoded,
      providerId: providerId,
      promptVersion: promptVersion,
      generatedAt: generatedAt,
    );
  }

  /// Normalizes a parsed response and applies all guardrails.
  ///
  /// Returns null when the response contains neither a usable message
  /// nor insights/recommendations from which a message can be built.
  CoachResponse? _finalizeResponse(
    CoachResponse response,
    CoachContext context, {
    bool markAsFallback = false,
  }) {
    CoachResponse? normalized = response;

    if (normalized.message.trim().isEmpty) {
      normalized = _buildMessageFromStructuredContent(normalized);

      if (normalized == null) {
        return null;
      }
    }

    if (markAsFallback) {
      normalized = normalized.copyWith(
        usedFallback: true,
      );
    }

    return _applyGuardrails(
      normalized,
      context,
    );
  }

  /// Builds a message from insights or recommendations when the AI
  /// omitted the top-level message.
  CoachResponse? _buildMessageFromStructuredContent(
    CoachResponse response,
  ) {
    if (response.insights.isNotEmpty) {
      final message = response.insights
          .map((insight) => insight.body.trim())
          .where((body) => body.isNotEmpty)
          .join(' ');

      if (message.isNotEmpty) {
        return response.copyWith(
          message: message,
        );
      }
    }

    if (response.recommendations.isNotEmpty) {
      final message = response.recommendations
          .map((recommendation) => recommendation.text.trim())
          .where((text) => text.isNotEmpty)
          .join(' ');

      if (message.isNotEmpty) {
        return response.copyWith(
          message: message,
        );
      }
    }

    return null;
  }

  /// Applies guardrails to filter out unsafe or conflicting recommendations.
  CoachResponse _applyGuardrails(
    CoachResponse response,
    CoachContext context,
  ) {
    final filtered = response.recommendations.where((recommendation) {
      // The prompt contract requires recommendations to explicitly
      // align with the Decision Engine.
      if (!recommendation.alignsWithDecision) {
        return false;
      }

      // On normal days, alignment is the only guardrail required here.
      if (!context.isProtectiveDay) {
        return true;
      }

      final tag = _normalizeText(
        recommendation.actionTag ?? '',
      );

      final text = _normalizeText(
        recommendation.text,
      );

      // Explicit unsafe action tag.
      if (forbiddenWhenProtective.contains(tag)) {
        return false;
      }

      // Unsafe advice hidden inside natural-language text.
      if (_containsForbiddenText(text)) {
        return false;
      }

      return true;
    }).toList();

    return response.copyWith(
      recommendations: filtered,
    );
  }

  bool _containsForbiddenText(String text) {
    for (final marker in forbiddenTextMarkers) {
      if (text.contains(_normalizeText(marker))) {
        return true;
      }
    }

    return false;
  }

  /// Lightweight normalization for tag/text comparisons.
  static String _normalizeText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Textual fallback when structured parse fails.
  ///
  /// Attempts to extract a JSON object from the message before falling
  /// back to a safe plain-text CoachResponse.
  CoachResponse textFallback({
    required String message,
    required CoachContext context,
    required String providerId,
    required String promptVersion,
    DateTime? generatedAt,
  }) {
    final trimmed = message.trim();

    // -----------------------------------------------------------------------
    // First fallback strategy: valid JSON response.
    // -----------------------------------------------------------------------
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);

        final parsed = _responseFromDecoded(
          decoded,
          providerId: providerId,
          promptVersion: promptVersion,
          generatedAt: generatedAt,
        );

        final structuredFallback = _finalizeResponse(
          parsed,
          context,
          markAsFallback: true,
        );

        if (structuredFallback != null) {
          return structuredFallback;
        }
      } catch (_) {
        // Not valid structured JSON.
      }
    }

    // -----------------------------------------------------------------------
    // Plain-text fallback.
    // -----------------------------------------------------------------------
    final cleanMessage = trimmed.isEmpty
        ? 'Follow today\'s plan from the Decision Engine.'
        : trimmed;

    final recommendations = <CoachRecommendation>[
      CoachRecommendation(
        category: CoachRecommendationCategory.general,
        text: context.isAdapted
            ? 'Follow the adapted workout (${context.workoutAdjustment}).'
            : 'Complete your planned session.',
        reason: 'Aligned with Decision Engine',
        alignsWithDecision: true,
        actionTag: fallbackActionTag(context),
      ),
    ];

    // -----------------------------------------------------------------------
    // Best-effort extraction of simple insights from raw text.
    // -----------------------------------------------------------------------
    final insights = <CoachInsight>[];

    if (_containsInsightKeyword(cleanMessage)) {
      final sentences = cleanMessage.split(
        RegExp(r'[.!?]\s+'),
      );

      for (final sentence in sentences) {
        final trimmedSentence = sentence.trim();

        if (trimmedSentence.length > 20 &&
            !_containsWord(trimmedSentence, 'insight') &&
            !_containsWord(trimmedSentence, 'recommendation')) {
          insights.add(
            CoachInsight(
              type: 'insight',
              title: 'AI Coach Insight',
              body: trimmedSentence,
              priority: CoachPriority.medium,
            ),
          );
        }
      }
    }

    final fallbackRecommendations = insights.isEmpty
        ? recommendations
        : [
            ...recommendations,
            ...insights.map(
              (insight) => CoachRecommendation(
                category: CoachRecommendationCategory.general,
                text: insight.body,
                reason: 'Extracted from AI response',
                alignsWithDecision: true,
                actionTag: fallbackActionTag(context),
              ),
            ),
          ];

    final response = CoachResponse(
      message: cleanMessage,
      insights: insights,
      recommendations: fallbackRecommendations,
      providerId: providerId,
      promptVersion: promptVersion,
      generatedAt: generatedAt ?? DateTime.now(),
      usedFallback: true,
    );

    return _applyGuardrails(
      response,
      context,
    );
  }

  static bool _containsInsightKeyword(String value) {
    final normalized = _normalizeText(value);

    return normalized.contains('insight') ||
        normalized.contains('recommendation');
  }

  static bool _containsWord(
    String value,
    String word,
  ) {
    final normalizedValue = _normalizeText(value);
    final normalizedWord = _normalizeText(word);

    return normalizedValue.contains(normalizedWord);
  }

  /// Determines a safe fallback action tag based on the context.
  static String fallbackActionTag(
    CoachContext context,
  ) {
    if (context.isRestDay ||
        context.workoutAdjustment == WorkoutAdjustment.restDay.value ||
        context.workoutAdjustment == WorkoutAdjustment.skipWorkout.value) {
      return 'rest';
    }

    if (context.workoutAdjustment == WorkoutAdjustment.recoverySession.value) {
      return 'follow_recovery';
    }

    if (context.volumeWasReduced) {
      return 'follow_reduced_volume';
    }

    return 'follow_plan';
  }

  /// Applies the same response guardrails to an already structured response.
  ///
  /// Used by deterministic/local providers so every CoachResponse follows
  /// the same safety and Decision Engine alignment rules.
  CoachResponse guardResponse({
    required CoachResponse response,
    required CoachContext context,
  }) {
    return _applyGuardrails(response, context);
  }
}
