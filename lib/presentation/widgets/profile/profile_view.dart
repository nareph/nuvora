// lib/presentation/widgets/profile/profile_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gymgenius/domain/enums/budget_level.dart';
import 'package:gymgenius/domain/enums/equipment_type.dart';
import 'package:gymgenius/domain/enums/experience_level.dart';
import 'package:gymgenius/domain/enums/fitness_goal.dart';
import 'package:gymgenius/domain/enums/gender.dart';
import 'package:gymgenius/domain/enums/muscle_group.dart';
import 'package:gymgenius/domain/enums/session_duration.dart';
import 'package:gymgenius/domain/enums/workout_day.dart';
import 'package:gymgenius/domain/enums/workout_frequency.dart';
import 'package:gymgenius/domain/enums/activity_level.dart';
import 'package:gymgenius/presentation/question/profile_questions.dart';
import 'package:gymgenius/presentation/widgets/profile/preference_display_item.dart';
import 'package:gymgenius/presentation/widgets/profile/preference_edit_item.dart';
import 'package:gymgenius/presentation/widgets/profile/profile_header.dart';

class ProfileField {
  final String id;
  final String label;
  final FieldType type;
  final List<String>? options;
  final Map<String, String>? optionLabels;

  const ProfileField({
    required this.id,
    required this.label,
    required this.type,
    this.options,
    this.optionLabels,
  });
}

enum FieldType { singleChoice, multipleChoice, numeric }

final List<ProfileField> profileFields = [
  ProfileField(
    id: 'goal',
    label: 'Fitness Goal',
    type: FieldType.singleChoice,
    options: FitnessGoal.values.map((e) => e.value).toList(),
    optionLabels: {for (var e in FitnessGoal.values) e.value: e.displayName},
  ),
  ProfileField(
    id: 'gender',
    label: 'Gender',
    type: FieldType.singleChoice,
    options: Gender.values.map((e) => e.value).toList(),
    optionLabels: {for (var e in Gender.values) e.value: e.displayName},
  ),
  ProfileField(
    id: 'experience',
    label: 'Experience Level',
    type: FieldType.singleChoice,
    options: ExperienceLevel.values.map((e) => e.value).toList(),
    optionLabels: {
      for (var e in ExperienceLevel.values) e.value: e.displayName
    },
  ),
  ProfileField(
    id: 'activity_level',
    label: 'Activity Level',
    type: FieldType.singleChoice,
    options: ActivityLevel.values.map((e) => e.value).toList(),
    optionLabels: {for (var e in ActivityLevel.values) e.value: e.displayName},
  ),
  ProfileField(
    id: 'frequency',
    label: 'Workout Frequency',
    type: FieldType.singleChoice,
    options: WorkoutFrequency.values.map((e) => e.value).toList(),
    optionLabels: {
      for (var e in WorkoutFrequency.values) e.value: e.displayName
    },
  ),
  ProfileField(
    id: 'session_duration_minutes',
    label: 'Session Duration',
    type: FieldType.singleChoice,
    options: SessionDuration.values.map((e) => e.value).toList(),
    optionLabels: {
      for (var e in SessionDuration.values) e.value: e.displayName
    },
  ),
  ProfileField(
    id: 'workout_days',
    label: 'Preferred Workout Days',
    type: FieldType.multipleChoice,
    options: WorkoutDay.values.map((e) => e.value).toList(),
    optionLabels: {for (var e in WorkoutDay.values) e.value: e.displayName},
  ),
  ProfileField(
    id: 'equipment',
    label: 'Available Equipment',
    type: FieldType.multipleChoice,
    options: EquipmentType.values.map((e) => e.value).toList(),
    optionLabels: {for (var e in EquipmentType.values) e.value: e.displayName},
  ),
  ProfileField(
    id: 'focus_areas',
    label: 'Focus Areas',
    type: FieldType.multipleChoice,
    options: MuscleGroup.values.map((e) => e.value).toList(),
    optionLabels: {for (var e in MuscleGroup.values) e.value: e.displayName},
  ),
  ProfileField(
    id: 'avoided_muscles',
    label: 'Muscles to Avoid',
    type: FieldType.multipleChoice,
    options: MuscleGroup.values.map((e) => e.value).toList(),
    optionLabels: {for (var e in MuscleGroup.values) e.value: e.displayName},
  ),
  ProfileField(
    id: 'food_budget',
    label: 'Food Budget',
    type: FieldType.singleChoice,
    options: BudgetLevel.values.map((e) => e.value).toList(),
    optionLabels: {for (var e in BudgetLevel.values) e.value: e.displayName},
  ),
  const ProfileField(
    id: 'food_restrictions',
    label: 'Food Allergies / Restrictions',
    type: FieldType.multipleChoice,
    options: [
      'vegetarian',
      'vegan',
      'peanut',
      'fish',
      'egg',
      'dairy',
      'gluten'
    ],
    optionLabels: {
      'vegetarian': 'Vegetarian',
      'vegan': 'Vegan',
      'peanut': 'Peanut / Groundnut Allergy',
      'fish': 'Fish / Seafood Allergy',
      'egg': 'Egg Allergy',
      'dairy': 'Dairy / Lactose Intolerance',
      'gluten': 'Gluten Intolerance',
    },
  ),
  const ProfileField(
    id: 'food_preferences',
    label: 'Favorite Foods',
    type: FieldType.multipleChoice,
    options: [
      'rice',
      'plantain',
      'cassava',
      'beans',
      'fish',
      'chicken',
      'beef',
      'vegetables',
      'fruits',
      'eggs',
    ],
    optionLabels: {
      'rice': 'Rice',
      'plantain': 'Plantain',
      'cassava': 'Cassava',
      'beans': 'Beans',
      'fish': 'Fish',
      'chicken': 'Chicken',
      'beef': 'Beef',
      'vegetables': 'Vegetables',
      'fruits': 'Fruits',
      'eggs': 'Eggs',
    },
  ),
  ProfileField(
    id: 'country',
    label: 'Country',
    type: FieldType.singleChoice,
    options: [
      'Cameroon',
      'Nigeria',
      'Ghana',
      'Kenya',
      'South Africa',
      'USA',
      'UK',
      'France',
      'Germany',
      'Other'
    ],
    optionLabels: {
      'Cameroon': 'Cameroon',
      'Nigeria': 'Nigeria',
      'Ghana': 'Ghana',
      'Kenya': 'Kenya',
      'South Africa': 'South Africa',
      'USA': 'USA',
      'UK': 'United Kingdom',
      'France': 'France',
      'Germany': 'Germany',
      'Other': 'Other',
    },
  ),
];

// ============================================================
// Validation rules per physical stat key.
// Keep in sync with StatsInputView validators.
// ============================================================
typedef _StatRule = ({
  num min,
  num max,
  bool isInteger,
  bool isOptional,
  String label,
});

const Map<String, _StatRule> _statRules = {
  'age': (
    min: 10,
    max: 100,
    isInteger: true,
    isOptional: false,
    label: 'age',
  ),
  'height_m': (
    min: 0.5,
    max: 2.5,
    isInteger: false,
    isOptional: false,
    label: 'height',
  ),
  'weight_kg': (
    min: 20,
    max: 300,
    isInteger: false,
    isOptional: false,
    label: 'weight',
  ),
  'target_weight_kg': (
    min: 20,
    max: 300,
    isInteger: false,
    isOptional: true,
    label: 'target weight',
  ),
};

class ProfileView extends StatefulWidget {
  final String displayName;
  final String email;
  final bool isEditing;
  final bool isSaving;
  final Map<String, dynamic> sourceDataForUI;
  final VoidCallback onToggleEdit;
  final VoidCallback onSaveChanges;
  final VoidCallback onCancelChanges;
  final Function(String key, dynamic value) onUpdatePreference;
  final bool isOffline;
  final Map<String, TextEditingController> controllers;

  const ProfileView({
    super.key,
    required this.displayName,
    required this.email,
    required this.isEditing,
    required this.isSaving,
    required this.sourceDataForUI,
    required this.onToggleEdit,
    required this.onSaveChanges,
    required this.onCancelChanges,
    required this.onUpdatePreference,
    required this.controllers,
    this.isOffline = false,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    bool noPreferencesSet = profileFields.every((field) {
      final value = widget.sourceDataForUI[field.id];
      return value == null ||
          (value is List && value.isEmpty) ||
          (value is Map &&
              value.values.every((v) => v == null || v.toString().isEmpty)) ||
          (value is String && value.isEmpty);
    });

    if (noPreferencesSet && !widget.isEditing && !widget.isSaving) {
      return _buildNoPreferencesState(context, colorScheme, textTheme);
    }

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            if (widget.isOffline) _buildOfflineBanner(context, colorScheme),
            ProfileHeader(
              displayName: widget.displayName,
              email: widget.email,
              memberSince: 'N/A',
            ),
            const SizedBox(height: 24),
            _buildPreferencesHeader(context, colorScheme, textTheme),
            const SizedBox(height: 12),
            if (widget.isSaving) _buildSavingIndicator(),
            if (!widget.isSaving) _buildPreferencesList(context, colorScheme),
            if (widget.isEditing && !widget.isSaving)
              _buildActionButtons(context, colorScheme),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Validators
  // ============================================================
  String? _validateStat(String? value, String statKey) {
    final rule = _statRules[statKey];
    if (rule == null) return null;

    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return rule.isOptional ? null : 'Please enter your ${rule.label}.';
    }

    final parsed = rule.isInteger ? int.tryParse(text) : double.tryParse(text);

    if (parsed == null) {
      return 'Please enter a valid number for ${rule.label}.';
    }

    if (parsed < rule.min) {
      return '${rule.label[0].toUpperCase()}${rule.label.substring(1)} '
          'must be at least ${rule.min}.';
    }
    if (parsed > rule.max) {
      return '${rule.label[0].toUpperCase()}${rule.label.substring(1)} '
          'cannot exceed ${rule.max}.';
    }

    return null;
  }

  // ============================================================
  // Physical stats section
  // ============================================================
  Widget _buildPhysicalStatsSection(
      BuildContext context, ColorScheme colorScheme) {
    final stats =
        widget.sourceDataForUI['physical_stats'] as Map<String, dynamic>? ?? {};
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_weight_outlined,
                    size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text('Body Measurements',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ...statSubKeyEntries.map((entry) {
              final controllerKey = 'physical_stats_${entry.key}';
              final controller = widget.controllers[controllerKey];
              final rule = _statRules[entry.key];
              final isDecimal = rule?.isInteger == false;

              if (widget.isEditing) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: isDecimal,
                      signed: false,
                    ),
                    inputFormatters: isDecimal
                        ? [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
                          ]
                        : [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: rule?.isOptional == true
                          ? '${entry.label} (${entry.unit}, optional)'
                          : '${entry.label} (${entry.unit})',
                      hintText: entry.hint,
                      prefixIcon: Icon(
                        entry.key == 'age'
                            ? Icons.cake_outlined
                            : entry.key == 'height_m'
                                ? Icons.height_outlined
                                : entry.key == 'target_weight_kg'
                                    ? Icons.flag_outlined
                                    : Icons.monitor_weight_outlined,
                        size: 20,
                      ),
                    ),
                    validator: (v) => _validateStat(v, entry.key),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                );
              } else {
                final raw = stats[entry.key];
                final hasValue = raw != null &&
                    raw.toString().isNotEmpty &&
                    raw != 0 &&
                    raw != 0.0;
                final display = hasValue ? '$raw ${entry.unit}' : '—';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.label, style: textTheme.bodyMedium),
                      Text(
                        display,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: hasValue
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPreferencesState(
      BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (widget.isOffline) _buildOfflineBanner(context, colorScheme),
          ProfileHeader(
            displayName: widget.displayName,
            email: widget.email,
            memberSince: 'N/A',
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(Icons.fact_check_outlined,
                      size: 56, color: colorScheme.primary),
                  const SizedBox(height: 16),
                  Text("Set Your Preferences",
                      style: textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    widget.isOffline
                        ? "You're currently offline. Connect to the internet to set or update your preferences."
                        : "Complete your fitness profile to get personalized AI workout plans tailored just for you.",
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text("Set Preferences Now"),
                    onPressed: widget.isOffline ? null : widget.onToggleEdit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: colorScheme.errorContainer.withAlpha(128),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined,
              color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
                  "You're currently offline. Changes will not be saved.",
                  style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildPreferencesHeader(
      BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text("Your Preferences",
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        if (!widget.isEditing && !widget.isSaving)
          TextButton.icon(
            icon: Icon(Icons.edit_outlined,
                size: 20,
                color: widget.isOffline
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary),
            label: Text("Edit All",
                style: textTheme.labelLarge?.copyWith(
                    color: widget.isOffline
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary)),
            onPressed: widget.isOffline ? null : widget.onToggleEdit,
          ),
      ],
    );
  }

  Widget _buildSavingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Saving your preferences..."),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesList(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        _buildPhysicalStatsSection(context, colorScheme),
        ...profileFields.map((field) {
          if (widget.isEditing) {
            return PreferenceEditItem(
              key: ValueKey('edit_${field.id}'),
              field: field,
              currentValue: widget.sourceDataForUI[field.id],
              controllers: widget.controllers,
              onUpdate: widget.onUpdatePreference,
              isOffline: widget.isOffline,
            );
          } else {
            return PreferenceDisplayItem(
              key: ValueKey('display_${field.id}'),
              field: field,
              currentValue: widget.sourceDataForUI[field.id],
            );
          }
        }).toList(),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
              onPressed: widget.onCancelChanges, child: const Text("Cancel")),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_alt_outlined, size: 20),
            label: const Text("Save Changes"),
            onPressed: _handleSave,
          ),
        ],
      ),
    );
  }

  void _handleSave() {
    final form = _formKey.currentState;
    if (form == null) return;

    if (!form.validate()) {
      // Errors are already shown inline by the validators.
      return;
    }
    widget.onSaveChanges();
  }
}
