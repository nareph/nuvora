import 'package:flutter/material.dart';
import 'package:gymgenius/domain/entities/food_item.dart';
import 'package:gymgenius/domain/entities/logged_food_portion.dart';
import 'package:gymgenius/domain/entities/meal_portion_option.dart';
import 'package:gymgenius/domain/enums/meal_type.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';
import 'package:gymgenius/engines/nutrition_engine/builders/meal_log_builder.dart';
import 'package:gymgenius/engines/nutrition_engine/food_knowledge_base/models/meal_template.dart';
import 'package:gymgenius/presentation/viewmodels/nutrition_viewmodel.dart';

/// Bottom sheet for nutrition logging.
///
/// The sheet exposes four user-friendly logging paths:
/// 1. Meal Library — choose a known meal and a human-friendly portion.
/// 2. Food — log one individual food at any meal timing.
/// 3. Compose — build a meal from multiple foods using human portions.
/// 4. Manual — enter approximate macros when nothing else fits.
///
/// Today's suggested meals are logged directly from NutritionScreen.
Future<void> showLogMealSheet({
  required BuildContext context,
  required NutritionViewModel vm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _LogMealSheet(vm: vm),
  );
}

class _LogMealSheet extends StatefulWidget {
  final NutritionViewModel vm;

  const _LogMealSheet({required this.vm});

  @override
  State<_LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends State<_LogMealSheet> {
  int _tab = 0; // 0 = Meal library, 1 = Food, 2 = Compose, 3 = Manual
  final _nameController = TextEditingController(text: 'Custom meal');
  MealType _mealType = MealType.lunch;
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final List<_PortionDraft> _portions = [];
  FoodItem? _selectedFood;
  int _foodQuantity = 1;
  final _builder = const MealLogBuilder();

  // --- Database tab state ---
  final _searchController = TextEditingController();
  MealType? _typeFilter;
  MealTemplate? _selectedTemplate;
  MealPortionOption? _selectedTemplatePortion;
  MealType _selectedTemplateMealType = MealType.lunch;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Log a meal',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Meals')),
              ButtonSegment(value: 1, label: Text('Food')),
              ButtonSegment(value: 2, label: Text('Compose')),
              ButtonSegment(value: 3, label: Text('Manual')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 16),
          if (_tab == 0)
            ..._databaseFields(theme)
          else if (_tab == 1)
            ..._foodFields(theme)
          else if (_tab == 2)
            ..._composeFields(theme)
          else
            ..._manualFields(theme),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('Save log'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Meal Library
  // ------------------------------------------------------------------

  List<Widget> _databaseFields(ThemeData theme) {
    if (_selectedTemplate != null) {
      return [_selectedTemplateCard(theme)];
    }

    final query = _searchController.text.trim().toLowerCase();
    final templates = widget.vm.availableMealTemplates.where((t) {
      final matchesQuery =
          query.isEmpty || t.name.toLowerCase().contains(query);
      final matchesType =
          _typeFilter == null || t.tags.contains(_typeFilter!.value);
      return matchesQuery && matchesType;
    }).toList();

    return [
      TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Search meals...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _typeChip(null, 'All'),
            ...MealType.values.map((t) => _typeChip(t, t.displayName)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 280,
        child: templates.isEmpty
            ? const Center(child: Text('No meals found'))
            : ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, i) => _templateTile(templates[i]),
              ),
      ),
    ];
  }

  Widget _typeChip(MealType? type, String label) {
    final selected = _typeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _typeFilter = type),
      ),
    );
  }

  MealPortionOption _standardPortionFor(MealTemplate template) {
    return template.effectivePortionOptions.firstWhere(
      (option) => option.multiplier == 1.0,
      orElse: () => template.effectivePortionOptions.first,
    );
  }

  Widget _templateTile(MealTemplate template) {
    final macros = template.baseMacros;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(template.name),
        subtitle: Text(
          '${macros.calories} kcal · '
          'P${macros.proteinG} C${macros.carbsG} F${macros.fatG}',
        ),
        onTap: () => setState(() {
          _selectedTemplate = template;
          _selectedTemplatePortion = _standardPortionFor(template);
        }),
      ),
    );
  }

  Widget _selectedTemplateCard(ThemeData theme) {
    final template = _selectedTemplate!;
    final portion = _selectedTemplatePortion ?? _standardPortionFor(template);
    final macros = template.macrosForPortion(portion);
    final portionOptions = template.effectivePortionOptions;

    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _selectedTemplate = null;
                    _selectedTemplatePortion = null;
                  }),
                ),
              ],
            ),
            Text(
              '${macros.calories} kcal · '
              'P${macros.proteinG} C${macros.carbsG} F${macros.fatG}',
            ),
            const SizedBox(height: 4),
            Text(
              template.ingredientNames.join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MealPortionOption>(
              initialValue: portion,
              decoration: const InputDecoration(
                labelText: 'Portion',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: portionOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedTemplatePortion = value;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MealType>(
              initialValue: _selectedTemplateMealType,
              decoration: const InputDecoration(
                labelText: 'Log as',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: MealType.values
                  .map(
                    (t) =>
                        DropdownMenuItem(value: t, child: Text(t.displayName)),
                  )
                  .toList(),
              onChanged: (v) => setState(
                () => _selectedTemplateMealType = v ?? MealType.lunch,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Individual food
  // ------------------------------------------------------------------

  List<Widget> _foodFields(ThemeData theme) {
    final food = _selectedFood;
    final portions = food == null
        ? const <LoggedFoodPortion>[]
        : [
            LoggedFoodPortion(
              foodId: food.id,
              foodName: food.name,
              grams: food.defaultPortionGrams * _foodQuantity,
            ),
          ];

    final preview = food == null
        ? null
        : _builder.computeMacrosFromPortions(
            portions,
            widget.vm.availableFoods,
          );

    return [
      Text(
        'Log a food directly',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'A food can be logged at any meal time — including post-workout.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<FoodItem>(
        initialValue: _selectedFood,
        decoration: const InputDecoration(
          labelText: 'Food',
          border: OutlineInputBorder(),
        ),
        items: widget.vm.availableFoods
            .map(
              (f) => DropdownMenuItem(
                value: f,
                child: Text(f.name, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (food) => setState(() {
          _selectedFood = food;
          _foodQuantity = 1;
        }),
      ),
      const SizedBox(height: 12),
      if (food != null) ...[
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Portion',
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  food.defaultPortionLabel,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              DropdownButton<int>(
                value: _foodQuantity,
                underline: const SizedBox.shrink(),
                items: List.generate(3, (index) => index + 1)
                    .map(
                      (quantity) => DropdownMenuItem(
                        value: quantity,
                        child: Text('×$quantity'),
                      ),
                    )
                    .toList(),
                onChanged: (quantity) => setState(() {
                  _foodQuantity = quantity ?? 1;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<MealType>(
          initialValue: _mealType,
          decoration: const InputDecoration(
            labelText: 'Log as',
            border: OutlineInputBorder(),
          ),
          items: MealType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                ),
              )
              .toList(),
          onChanged: (type) => setState(() {
            _mealType = type ?? MealType.lunch;
          }),
        ),
        const SizedBox(height: 12),
        if (preview != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Estimated: ~${preview.calories} kcal · '
                'P${preview.proteinG} C${preview.carbsG} F${preview.fatG}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
      ],
    ];
  }

  // ------------------------------------------------------------------
  // Compose from foods
  // ------------------------------------------------------------------

  List<Widget> _composeFields(ThemeData theme) {
    final validDrafts =
        _portions.where((p) => p.food != null && p.grams > 0).toList();

    final preview = validDrafts.isEmpty
        ? null
        : _builder.computeMacrosFromPortions(
            validDrafts
                .map(
                  (p) => LoggedFoodPortion(
                    foodId: p.food!.id,
                    foodName: p.food!.name,
                    grams: p.grams,
                  ),
                )
                .toList(),
            widget.vm.availableFoods,
          );

    return [
      TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Meal name',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<MealType>(
        initialValue: _mealType,
        decoration: const InputDecoration(
          labelText: 'Meal type',
          border: OutlineInputBorder(),
        ),
        items: MealType.values
            .map(
              (t) => DropdownMenuItem(
                value: t,
                child: Text(t.displayName),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _mealType = v ?? MealType.lunch),
      ),
      const SizedBox(height: 12),
      ..._portions.map((draft) => _portionRow(draft)),
      TextButton.icon(
        onPressed: _addPortion,
        icon: const Icon(Icons.add),
        label: const Text('Add food'),
      ),
      if (preview != null)
        Text(
          'Preview: ${preview.calories} kcal · '
          'P${preview.proteinG} C${preview.carbsG} F${preview.fatG}',
          style: theme.textTheme.bodyMedium,
        ),
    ];
  }

  // ------------------------------------------------------------------
  // Manual entry
  // ------------------------------------------------------------------

  List<Widget> _manualFields(ThemeData theme) {
    return [
      TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Meal name',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<MealType>(
        initialValue: _mealType,
        decoration: const InputDecoration(
          labelText: 'Meal type',
          border: OutlineInputBorder(),
        ),
        items: MealType.values
            .map(
              (t) => DropdownMenuItem(
                value: t,
                child: Text(t.displayName),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _mealType = v ?? MealType.lunch),
      ),
      const SizedBox(height: 12),
      _macroField(_caloriesController, 'Calories (kcal)'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _macroField(_proteinController, 'Protein (g)')),
          const SizedBox(width: 8),
          Expanded(child: _macroField(_carbsController, 'Carbs (g)')),
          const SizedBox(width: 8),
          Expanded(child: _macroField(_fatController, 'Fat (g)')),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Approximate values are fine — logging beats skipping.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }

  Widget _macroField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _portionRow(_PortionDraft draft) {
    final food = draft.food;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<FoodItem>(
                    initialValue: draft.food,
                    decoration: const InputDecoration(
                      labelText: 'Food',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: widget.vm.availableFoods
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            child: Text(
                              f.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (f) => setState(() {
                      draft.food = f;
                      draft.multiplier = 1.0;
                    }),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove food',
                  onPressed: () => setState(() => _portions.remove(draft)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (food != null) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<double>(
                initialValue: draft.multiplier,
                decoration: InputDecoration(
                  labelText: 'Portion',
                  helperText: 'Reference: ${food.defaultPortionLabel}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: _foodPortionOptions(food)
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.$1,
                        child: Text(option.$2),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  draft.multiplier = value ?? 1.0;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<(double, String)> _foodPortionOptions(FoodItem food) {
    final label = food.defaultPortionLabel;
    return [
      (0.5, '½ × $label'),
      (1.0, '1 × $label'),
      (1.5, '1½ × $label'),
      (2.0, '2 × $label'),
      (3.0, '3 × $label'),
    ];
  }

  void _addPortion() {
    setState(() {
      _portions.add(_PortionDraft());
    });
  }

  Future<void> _save() async {
    if (_tab == 0) {
      final template = _selectedTemplate;
      if (template == null) return;
      await widget.vm.logDatabaseMeal(
        template: template,
        mealType: _selectedTemplateMealType,
        portion: _selectedTemplatePortion ?? _standardPortionFor(template),
      );
    } else if (_tab == 1) {
      final food = _selectedFood;
      if (food == null || _foodQuantity <= 0) return;

      final portions = [
        LoggedFoodPortion(
          foodId: food.id,
          foodName: food.name,
          grams: food.defaultPortionGrams * _foodQuantity,
        ),
      ];

      await widget.vm.logComposedMeal(
        name: food.name,
        mealType: _mealType,
        portions: portions,
      );
    } else if (_tab == 2) {
      final portions = _portions
          .where((p) => p.food != null && p.grams > 0)
          .map(
            (p) => LoggedFoodPortion(
              foodId: p.food!.id,
              foodName: p.food!.name,
              grams: p.grams,
            ),
          )
          .toList();
      if (portions.isEmpty) return;
      await widget.vm.logComposedMeal(
        name: _nameController.text,
        mealType: _mealType,
        portions: portions,
      );
    } else {
      final calories = int.tryParse(_caloriesController.text.trim()) ?? 0;
      if (calories <= 0) return;
      await widget.vm.logManualMeal(
        name: _nameController.text,
        mealType: _mealType,
        macros: MacroTargets(
          calories: calories,
          proteinG: int.tryParse(_proteinController.text.trim()) ?? 0,
          carbsG: int.tryParse(_carbsController.text.trim()) ?? 0,
          fatG: int.tryParse(_fatController.text.trim()) ?? 0,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }
}

class _PortionDraft {
  FoodItem? food;
  double multiplier = 1.0;

  double get grams => (food?.defaultPortionGrams ?? 0).toDouble() * multiplier;
}
