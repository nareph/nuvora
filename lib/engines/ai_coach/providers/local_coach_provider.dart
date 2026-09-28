// lib/engines/ai_coach/providers/local_coach_provider.dart

import 'dart:convert';

import 'package:gymgenius/engines/ai_coach/models/coach_context.dart';
import 'package:gymgenius/engines/ai_coach/models/coach_response.dart';
import 'package:gymgenius/engines/ai_coach/prompts/coach_prompts.dart';
import 'package:gymgenius/engines/ai_coach/providers/ai_provider.dart';
import 'package:gymgenius/engines/ai_coach/providers/coach_request_options.dart';
import 'package:gymgenius/engines/ai_coach/validators/coach_response_validator.dart';

/// Deterministic offline coach — templates from [CoachContext], no network.
///
/// The local provider follows the same safety rules as the cloud AI Coach:
/// - never invents metrics or nutrition data;
/// - never changes Decision Engine decisions;
/// - distinguishes nutrition targets from logged intake;
/// - never treats a missing meal log as proof that the meal was skipped;
/// - never recommends compensatory exercise or restrictive nutrition.
class LocalCoachProvider implements AIProvider {
  const LocalCoachProvider();

  @override
  String get id => 'local';

  @override
  bool get isAvailable => true;

  @override
  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    CoachRequestOptions options = const CoachRequestOptions(),
  }) async {
    // Local provider ignores free-form prompts and expects context embedded
    // via engine helpers; engine prefers [buildDaily], [buildWeekly],
    // and [buildChat].
    return jsonEncode({
      'message':
          'Follow today\'s Decision Engine plan. Cloud AI is unavailable — local coaching active.',
      'insights': <Map<String, dynamic>>[],
      'recommendations': [
        {
          'category': 'general',
          'text': 'Stick to the recommended session and recovery cues.',
          'reason': 'Local fallback',
          'alignsWithDecision': true,
          'actionTag': 'follow_plan',
        }
      ],
      'tone': 'supportive',
      'promptVersion': CoachPrompts.promptVersion,
    });
  }

  // ===========================================================================
  // Daily coaching
  // ===========================================================================

  /// Builds a daily coaching response locally (without network).
  CoachResponse buildDaily(CoachContext context) {
    final buffer = StringBuffer();

    // -------------------------------------------------------------------------
    // Workout / recovery state
    // -------------------------------------------------------------------------

    if (context.isRestDay) {
      buffer.write('Today is a rest day. Recover well');

      if (context.readinessScore != null) {
        buffer.write(' (readiness ${context.readinessScore})');
      }

      buffer.write('.');
    } else if (context.volumeWasReduced) {
      buffer.write(
        'Your plan was adapted with '
        '${context.workoutAdjustment.replaceAll('_', ' ')}. ',
      );
      buffer.write(
        'Follow the reduced session — do not add extra volume.',
      );
    } else {
      buffer.write('You are cleared for today\'s planned workout');

      if (context.readinessScore != null) {
        buffer.write(' (readiness ${context.readinessScore})');
      }

      buffer.write('.');
    }

    // -------------------------------------------------------------------------
    // Progress signals
    // -------------------------------------------------------------------------

    if (context.weightPlateau || context.strengthPlateau) {
      buffer.write(' A plateau signal is present — stay consistent.');
    }

    // -------------------------------------------------------------------------
    // Nutrition adherence summary
    //
    // Important:
    // - "target" values describe the plan;
    // - "logged" values describe recorded intake;
    // - missing meal logs are never interpreted as skipped meals.
    // -------------------------------------------------------------------------

    final nutritionMessage = _buildNutritionMessage(context);

    if (nutritionMessage != null) {
      buffer.write(' $nutritionMessage');
    }

    // -------------------------------------------------------------------------
    // Insights
    // -------------------------------------------------------------------------

    final insights = <CoachInsight>[];

    if (context.readinessScore != null) {
      insights.add(
        CoachInsight(
          type: 'recovery',
          title: 'Readiness',
          body: 'Readiness score: ${context.readinessScore}.',
          priority: context.readinessScore! < 60
              ? CoachPriority.high
              : CoachPriority.medium,
        ),
      );
    }

    if (context.consistencyScore != null) {
      insights.add(
        CoachInsight(
          type: 'progress',
          title: 'Consistency',
          body: 'Consistency score: ${context.consistencyScore}%.',
        ),
      );
    }

    final nutritionInsight = _buildNutritionInsight(context);

    if (nutritionInsight != null) {
      insights.add(nutritionInsight);
    }

    // -------------------------------------------------------------------------
    // Recommendations
    // -------------------------------------------------------------------------

    final recommendations = <CoachRecommendation>[
      CoachRecommendation(
        category: CoachRecommendationCategory.workout,
        text: context.volumeWasReduced
            ? 'Complete the adapted workout without adding sets.'
            : context.isRestDay
                ? 'Prioritize sleep and light movement.'
                : 'Complete the planned session as written.',
        reason: context.healthReason ?? 'Decision Engine plan',
        alignsWithDecision: true,
        actionTag: CoachResponseValidator.fallbackActionTag(context),
      ),
    ];

    final nutritionRecommendation = _buildNutritionRecommendation(context);

    if (nutritionRecommendation != null) {
      recommendations.add(nutritionRecommendation);
    }

    return CoachResponse(
      message: buffer.toString().trim(),
      insights: insights,
      recommendations: recommendations,
      providerId: id,
      promptVersion: CoachPrompts.promptVersion,
      generatedAt: DateTime.now(),
      usedFallback: true,
    );
  }

  /// Builds a concise nutrition message from deterministic adherence data.
  String? _buildNutritionMessage(CoachContext context) {
    if (!context.hasNutritionAdherence) {
      return null;
    }

    final expected = context.nutritionExpectedMeals;
    final logged = context.nutritionLoggedMeals;
    final coverage = context.nutritionMealSlotCoverage;

    final parts = <String>[];

    // -------------------------------------------------------------------------
    // Meal-slot coverage
    // -------------------------------------------------------------------------

    if (expected != null && logged != null) {
      parts.add(
        '$logged of $expected planned meal slots are logged',
      );
    }

    // -------------------------------------------------------------------------
    // Adherence score
    // -------------------------------------------------------------------------

    if (context.nutritionAdherenceScore != null) {
      final percent = (context.nutritionAdherenceScore! * 100).round();

      parts.add('nutrition adherence: $percent%');
    }

    // -------------------------------------------------------------------------
    // Recorded intake
    // -------------------------------------------------------------------------

    if (context.nutritionLoggedCalories != null) {
      parts.add(
        'recorded intake: ${context.nutritionLoggedCalories} kcal',
      );
    }

    // -------------------------------------------------------------------------
    // Missing meal slots
    //
    // These are only "not yet logged". They are NOT skipped meals.
    // -------------------------------------------------------------------------

    if (context.nutritionMissingMealSlots.isNotEmpty) {
      final slots = context.nutritionMissingMealSlots.join(', ');

      parts.add('not yet logged: $slots');
    }

    if (parts.isEmpty) {
      return null;
    }

    final coverageText =
        coverage == null ? '' : ' (${(coverage * 100).round()}% slot coverage)';

    return 'Nutrition: ${parts.join('; ')}$coverageText.';
  }

  /// Builds a structured nutrition insight when adherence data exists.
  CoachInsight? _buildNutritionInsight(CoachContext context) {
    if (!context.hasNutritionAdherence) {
      return null;
    }

    final expected = context.nutritionExpectedMeals;
    final logged = context.nutritionLoggedMeals;

    String body;

    if (expected != null && logged != null) {
      body = '$logged of $expected planned meal slots are logged';

      if (context.nutritionMealSlotCoverage != null) {
        body +=
            ' (${(context.nutritionMealSlotCoverage! * 100).round()}% coverage)';
      }

      body += '.';
    } else if (context.nutritionLoggedCalories != null) {
      body = 'Recorded nutrition intake: '
          '${context.nutritionLoggedCalories} kcal.';
    } else {
      body = 'Nutrition adherence data is available.';
    }

    CoachPriority priority = CoachPriority.medium;

    if (context.nutritionAdherenceScore != null) {
      if (context.nutritionAdherenceScore! < 0.5) {
        priority = CoachPriority.high;
      } else if (context.nutritionAdherenceScore! >= 0.8) {
        priority = CoachPriority.low;
      }
    }

    return CoachInsight(
      type: 'nutrition',
      title: 'Nutrition adherence',
      body: body,
      priority: priority,
    );
  }

  /// Builds a safe nutrition recommendation.
  ///
  /// The recommendation never changes nutrition targets and never assumes
  /// that an unlogged meal was skipped.
  CoachRecommendation? _buildNutritionRecommendation(
    CoachContext context,
  ) {
    if (!context.hasNutritionAdherence) {
      return null;
    }

    final missing = context.nutritionMissingMealSlots.isNotEmpty;

    if (missing) {
      return CoachRecommendation(
        category: CoachRecommendationCategory.nutrition,
        text: 'Log the meal you ate when convenient.',
        reason: 'Nutrition logging is incomplete.',
        alignsWithDecision: true,
        actionTag: 'log_meal',
      );
    }

    if (context.allNutritionMealsLogged) {
      return CoachRecommendation(
        category: CoachRecommendationCategory.nutrition,
        text: 'Keep logging meals consistently.',
        reason: 'All planned meal slots are currently covered by logs.',
        alignsWithDecision: true,
        actionTag: 'log_meal',
      );
    }

    if (context.hasLoggedNutrition) {
      return CoachRecommendation(
        category: CoachRecommendationCategory.nutrition,
        text:
            'Continue following today\'s nutrition plan and logging what you eat.',
        reason: 'Observed nutrition data is available.',
        alignsWithDecision: true,
        actionTag: 'follow_plan',
      );
    }

    return null;
  }

  // ===========================================================================
  // Weekly summary
  // ===========================================================================

  /// Builds a weekly summary coaching response locally.
  CoachResponse buildWeekly({
    required CoachContext context,
    required Map<String, dynamic> weeklyReport,
  }) {
    final completed = weeklyReport['workoutsCompleted'];
    final planned = weeklyReport['workoutsPlanned'];
    final consistency = weeklyReport['consistencyScore'];
    final weightChange = weeklyReport['weightChangeKg'];

    final positives =
        (weeklyReport['positives'] as List?)?.cast<String>() ?? [];

    final improvements =
        (weeklyReport['improvements'] as List?)?.cast<String>() ?? [];

    final message = StringBuffer('Weekly summary: ');

    if (completed != null && planned != null) {
      message.write('$completed/$planned workouts completed');

      if (consistency != null) {
        message.write(' (consistency $consistency%)');
      }

      message.write('. ');
    }

    if (weightChange != null) {
      message.write('Weight change: $weightChange kg. ');
    }

    if (positives.isNotEmpty) {
      message.write('Positives: ${positives.join('; ')}. ');
    }

    if (improvements.isNotEmpty) {
      message.write('Focus next week: ${improvements.join('; ')}.');
    }

    return CoachResponse(
      message: message.toString().trim(),
      insights: [
        if (consistency != null)
          CoachInsight(
            type: 'progress',
            title: 'Consistency',
            body: '$consistency%',
          ),
      ],
      recommendations: [
        CoachRecommendation(
          category: CoachRecommendationCategory.progress,
          text: improvements.isNotEmpty
              ? improvements.first
              : 'Keep logging workouts and weight.',
          reason: 'Weekly report',
          alignsWithDecision: true,
          actionTag: 'follow_plan',
        ),
      ],
      providerId: id,
      promptVersion: CoachPrompts.promptVersion,
      generatedAt: DateTime.now(),
      usedFallback: true,
    );
  }

  // ===========================================================================
  // Chat
  // ===========================================================================

  /// Builds a chat response locally.
  CoachResponse buildChat({
    required CoachContext context,
    required String question,
  }) {
    final q = question.toLowerCase();

    String message;

    // -------------------------------------------------------------------------
    // Decision explanation
    // -------------------------------------------------------------------------

    if (q.contains('why') || q.contains('pourquoi')) {
      message = context.decisionReasons.isNotEmpty
          ? 'Today\'s decision reasons: '
              '${context.decisionReasons.join(', ')}.'
          : 'Today follows the scheduled plan from the Decision Engine.';
    }

    // -------------------------------------------------------------------------
    // Nutrition
    // -------------------------------------------------------------------------

    else if (q.contains('nutrition') ||
        q.contains('meal') ||
        q.contains('repas') ||
        q.contains('aliment') ||
        q.contains('calorie') ||
        q.contains('protein') ||
        q.contains('protéine')) {
      message = _buildNutritionChatMessage(context);
    }

    // -------------------------------------------------------------------------
    // Recovery
    // -------------------------------------------------------------------------

    else if (q.contains('recovery') ||
        q.contains('sleep') ||
        q.contains('récupération') ||
        q.contains('sommeil')) {
      message = context.readinessScore != null
          ? 'Readiness is ${context.readinessScore}'
              '${context.volumeWasReduced ? ' — volume was reduced accordingly' : ''}.'
          : 'No recovery check-in is available for today.';
    }

    // -------------------------------------------------------------------------
    // Progress
    // -------------------------------------------------------------------------

    else if (q.contains('progress') ||
        q.contains('plateau') ||
        q.contains('progrès')) {
      if (context.healthPrimaryAction == 'refresh_program') {
        message = 'A plateau or low adherence was detected. '
            'Your program is due for a refresh — follow the new plan.';
      } else if (context.weightPlateau || context.strengthPlateau) {
        message = 'A plateau was detected. Stay consistent; a program refresh '
            'is considered after two weeks of data.';
      } else if (context.consistencyScore != null) {
        message = 'Consistency is at ${context.consistencyScore}%.';
      } else {
        message = 'Not enough progress data yet.';
      }
    }

    // -------------------------------------------------------------------------
    // Default
    // -------------------------------------------------------------------------

    else {
      message = 'I can explain today\'s workout, recovery, nutrition, '
          'or progress using your real data.';
    }

    return CoachResponse(
      message: message,
      providerId: id,
      promptVersion: CoachPrompts.promptVersion,
      generatedAt: DateTime.now(),
      usedFallback: true,
    );
  }

  /// Builds a nutrition-aware offline chat answer.
  String _buildNutritionChatMessage(CoachContext context) {
    // No adherence snapshot — only the deterministic plan target is known.
    if (!context.hasNutritionAdherence) {
      if (context.nutritionCalories != null) {
        return 'Today\'s nutrition target is '
            '${context.nutritionCalories} kcal'
            '${context.nutritionProteinG != null ? ' with ${context.nutritionProteinG}g protein' : ''}. '
            'No nutrition intake data is available yet.';
      }

      return 'Nutrition data is not available yet.';
    }

    final parts = <String>[];

    // -------------------------------------------------------------------------
    // Planned target
    // -------------------------------------------------------------------------

    if (context.nutritionCalories != null) {
      parts.add(
        'Today\'s target is ${context.nutritionCalories} kcal',
      );

      if (context.nutritionProteinG != null) {
        parts.add(
          'with ${context.nutritionProteinG}g protein',
        );
      }
    }

    // -------------------------------------------------------------------------
    // Recorded intake
    // -------------------------------------------------------------------------

    if (context.nutritionLoggedCalories != null) {
      parts.add(
        'recorded intake is ${context.nutritionLoggedCalories} kcal',
      );
    }

    if (context.nutritionLoggedProteinG != null) {
      parts.add(
        '${context.nutritionLoggedProteinG}g protein logged',
      );
    }

    // -------------------------------------------------------------------------
    // Meal-slot coverage
    // -------------------------------------------------------------------------

    if (context.nutritionExpectedMeals != null &&
        context.nutritionLoggedMeals != null) {
      parts.add(
        '${context.nutritionLoggedMeals} of '
        '${context.nutritionExpectedMeals} planned meal slots are logged',
      );
    }

    // -------------------------------------------------------------------------
    // Missing logs
    // -------------------------------------------------------------------------

    if (context.nutritionMissingMealSlots.isNotEmpty) {
      final missing = context.nutritionMissingMealSlots.join(', ');

      parts.add(
        'not yet logged: $missing',
      );
    }

    // -------------------------------------------------------------------------
    // Adherence
    // -------------------------------------------------------------------------

    if (context.nutritionAdherenceScore != null) {
      final percent = (context.nutritionAdherenceScore! * 100).round();

      parts.add('adherence score: $percent%');
    }

    if (parts.isEmpty) {
      return 'Nutrition adherence data is available, but there is not enough '
          'information to summarize it yet.';
    }

    return '${parts.join('; ')}.';
  }
}
