import 'dart:convert';

import 'package:gymgenius/core/logger/logger_service.dart';
import 'package:gymgenius/domain/entities/weekly_progress_report.dart';
import 'package:gymgenius/engines/ai_coach/ai_config.dart';
import 'package:gymgenius/engines/ai_coach/builders/coach_context_builder.dart';
import 'package:gymgenius/engines/ai_coach/models/coach_context.dart';
import 'package:gymgenius/engines/ai_coach/models/coach_response.dart';
import 'package:gymgenius/engines/ai_coach/models/conversation.dart';
import 'package:gymgenius/engines/ai_coach/prompts/coach_prompts.dart';
import 'package:gymgenius/engines/ai_coach/providers/ai_provider.dart';
import 'package:gymgenius/engines/ai_coach/providers/coach_request_options.dart';
import 'package:gymgenius/engines/ai_coach/providers/local_coach_provider.dart';
import 'package:gymgenius/engines/ai_coach/validators/coach_response_validator.dart';
import 'package:gymgenius/engines/decision_engine/models/daily_plan.dart';

/// Orchestrates AI Coach flows.
///
/// Responsibilities:
/// - builds the deterministic CoachContext;
/// - calls the configured cloud provider when available;
/// - parses and validates cloud responses;
/// - falls back to deterministic local coaching;
/// - never mutates domain engines or persistence.
class AICoachEngine {
  final AIProvider _primary;
  final LocalCoachProvider _local;
  final CoachContextBuilder _contextBuilder;
  final CoachResponseValidator _validator;

  static const _tag = 'AICoachEngine';
  static const _localProviderId = 'local';

  AICoachEngine({
    required AIProvider primary,
    LocalCoachProvider local = const LocalCoachProvider(),
    CoachContextBuilder contextBuilder = const CoachContextBuilder(),
    CoachResponseValidator? validator,
  })  : _primary = primary,
        _local = local,
        _contextBuilder = contextBuilder,
        _validator = validator ?? CoachResponseValidator();

  /// Builds the compact context consumed by the AI Coach.
  CoachContext buildContext(DailyPlan plan) {
    return _contextBuilder.build(plan);
  }

  /// Generates today's coaching from the deterministic DailyPlan.
  Future<CoachResponse> generateDailyCoaching(
    DailyPlan plan,
  ) async {
    final context = _contextBuilder.build(plan);
    final contextJson = jsonEncode(
      context.toPromptMap(),
    );

    return _completeStructured(
      context: context,
      systemPrompt: CoachPrompts.system,
      userPrompt: CoachPrompts.dailyUser(contextJson),
      localBuilder: () => _local.buildDaily(context),
    );
  }

  /// Generates the weekly coaching summary.
  Future<CoachResponse> generateWeeklySummary({
    required DailyPlan plan,
    required WeeklyProgressReport report,
  }) async {
    final context = _contextBuilder.build(plan);

    final weeklyMap = {
      'weekStart': report.weekStart.toIso8601String(),
      'weekEnd': report.weekEnd.toIso8601String(),
      'weightStartKg': report.weightStartKg,
      'weightEndKg': report.weightEndKg,
      'weightChangeKg': report.weightChangeKg,
      'workoutsCompleted': report.workoutsCompleted,
      'workoutsPlanned': report.workoutsPlanned,
      'consistencyScore': report.consistencyScore,
      'strengthChangePercent': report.strengthChangePercent,
      'averageReadiness': report.averageReadiness,
      'positives': report.positives,
      'improvements': report.improvements,
    };

    return _completeStructured(
      context: context,
      systemPrompt: CoachPrompts.system,
      userPrompt: CoachPrompts.weeklyUser(
        jsonEncode(context.toPromptMap()),
        jsonEncode(weeklyMap),
      ),
      localBuilder: () => _local.buildWeekly(
        context: context,
        weeklyReport: weeklyMap,
      ),
    );
  }

  /// Answers a user question using the deterministic context and
  /// the clipped recent conversation history.
  Future<CoachResponse> chat({
    required DailyPlan plan,
    required String question,
    List<ConversationMessage> history = const [],
  }) async {
    final context = _contextBuilder.build(plan);

    final clipped = history.length > AIConfig.coachMaxHistoryMessages
        ? history.sublist(
            history.length - AIConfig.coachMaxHistoryMessages,
          )
        : history;

    final historyJson = jsonEncode(
      clipped
          .map(
            (message) => {
              'role': message.role.value,
              'content': message.content,
            },
          )
          .toList(),
    );

    return _completeStructured(
      context: context,
      systemPrompt: CoachPrompts.system,
      userPrompt: CoachPrompts.chatUser(
        contextJson: jsonEncode(context.toPromptMap()),
        historyJson: historyJson,
        question: question,
      ),
      localBuilder: () => _local.buildChat(
        context: context,
        question: question,
      ),
    );
  }

  // ============================================================
  // Core completion
  // ============================================================

  Future<CoachResponse> _completeStructured({
    required CoachContext context,
    required String systemPrompt,
    required String userPrompt,
    required CoachResponse Function() localBuilder,
  }) async {
    final generatedAt = DateTime.now();

    // -----------------------------------------------------------------------
    // Cloud provider
    // -----------------------------------------------------------------------
    if (_primary.isAvailable && AIConfig.canUseCoachCloud) {
      try {
        final raw = await _primary
            .complete(
              systemPrompt: systemPrompt,
              userPrompt: userPrompt,
              options: const CoachRequestOptions(
                temperature: 0.4,
                maxTokens: AIConfig.coachMaxOutputTokens,
                timeout: AIConfig.coachTimeout,
              ),
            )
            .timeout(AIConfig.coachTimeout);

        // Do not log the generated health/coaching text itself.
        Log.debug(
          'Cloud provider returned ${raw.length} characters.',
          tag: _tag,
        );

        final parsed = _validator.tryParse(
          raw: raw,
          context: context,
          providerId: _primary.id,
          promptVersion: CoachPrompts.promptVersion,
          generatedAt: generatedAt,
        );

        if (parsed != null) {
          Log.debug(
            'Parsed structured cloud response.',
            tag: _tag,
          );

          return parsed;
        }

        Log.warning(
          'Structured cloud parsing failed; using validated text fallback.',
          tag: _tag,
        );

        return _validator.textFallback(
          message: raw,
          context: context,
          providerId: _primary.id,
          promptVersion: CoachPrompts.promptVersion,
          generatedAt: generatedAt,
        );
      } catch (e, s) {
        Log.warning(
          'Cloud provider failed: $e. Falling back to local Coach.',
          tag: _tag,
        );

        Log.debug(
          '$s',
          tag: _tag,
        );
      }
    }

    // -----------------------------------------------------------------------
    // Local deterministic fallback
    // -----------------------------------------------------------------------
    try {
      final localResponse = localBuilder();

      final normalizedLocalResponse = localResponse.copyWith(
        providerId: _localProviderId,
        promptVersion: CoachPrompts.promptVersion,
        generatedAt: generatedAt,
        usedFallback: true,
      );

      // The local provider is deterministic, but it still goes through
      // the exact same response guardrails as the cloud response.
      final guardedLocalResponse = _validator.guardResponse(
        response: normalizedLocalResponse,
        context: context,
      );

      Log.debug(
        'Using validated local Coach response.',
        tag: _tag,
      );

      return guardedLocalResponse;
    } catch (e, s) {
      // The local provider itself should normally never fail, but keep a
      // final safe path so the Coach layer does not crash the user flow.
      Log.error(
        'Local Coach provider failed: $e',
        tag: _tag,
        stackTrace: s,
      );

      return _validator.textFallback(
        message: '',
        context: context,
        providerId: _localProviderId,
        promptVersion: CoachPrompts.promptVersion,
        generatedAt: generatedAt,
      );
    }
  }
}
