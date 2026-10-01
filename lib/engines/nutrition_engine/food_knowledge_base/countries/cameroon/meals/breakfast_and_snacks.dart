import 'package:gymgenius/domain/enums/budget_level.dart';
import 'package:gymgenius/domain/enums/meal_objective.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';

import '../../../models/meal_template.dart';

const List<MealTemplate> cameroonBreakfastAndSnacks = [
  MealTemplate(
    id: 'cm_meal_eggs_bread',
    name: 'Eggs with bread and avocado',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_eggs',
      'cm_bread',
      'cm_avocado',
    ],
    ingredientNames: [
      'Eggs',
      'Local bread',
      'Avocado',
    ],
    baseMacros: MacroTargets(
      calories: 520,
      proteinG: 22,
      carbsG: 42,
      fatG: 28,
    ),
    minBudget: BudgetLevel.low,
    allergens: ['egg'],
    tags: ['breakfast', 'high_protein'],
  ),

  MealTemplate(
    id: 'cm_meal_fruit_eggs',
    name: 'Fruit plate with boiled eggs',
    objective: MealObjective.light,
    ingredientIds: [
      'cm_banana',
      'cm_papaya',
      'cm_eggs',
    ],
    ingredientNames: [
      'Banana',
      'Papaya',
      'Boiled eggs',
    ],
    baseMacros: MacroTargets(
      calories: 320,
      proteinG: 16,
      carbsG: 38,
      fatG: 12,
    ),
    minBudget: BudgetLevel.low,
    allergens: ['egg'],
    tags: ['snack', 'breakfast', 'light'],
  ),

  MealTemplate(
    id: 'cm_meal_power_porridge',
    name: 'Maize Power Porridge',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_corn_flour',
      'cm_nido_powder',
      'cm_eggs',
      'cm_groundnuts',
    ],
    ingredientNames: [
      'Corn flour',
      'Nido milk powder',
      'Eggs',
      'Groundnuts',
    ],
    baseMacros: MacroTargets(
      calories: 560,
      proteinG: 25,
      carbsG: 65,
      fatG: 21,
    ),
    minBudget: BudgetLevel.low,
    allergens: ['egg', 'peanut', 'dairy'],
    tags: [
      'breakfast',
      'mass_gain',
      'porridge',
      'post_workout',
      'high_protein',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_beignets_lait',
    name: 'Beignets with fermented milk (Pendidam)',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_beignets',
      'cm_fermented_milk',
    ],
    ingredientNames: [
      'Beignets',
      'Fermented milk / Pendidam',
    ],
    baseMacros: MacroTargets(
      calories: 520,
      proteinG: 12,
      carbsG: 70,
      fatG: 21,
    ),
    minBudget: BudgetLevel.low,
    allergens: ['dairy'],
    tags: [
      'breakfast',
      'street_food',
      'snack',
      'high_energy',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_soya_brochettes',
    name: 'Soya (beef or chicken skewers)',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_beef',
      'cm_chicken',
      'cm_onion',
      'cm_hot_pepper',
    ],
    ingredientNames: [
      'Beef or chicken',
      'Onion',
      'Hot pepper',
    ],
    baseMacros: MacroTargets(
      calories: 420,
      proteinG: 42,
      carbsG: 10,
      fatG: 24,
    ),
    minBudget: BudgetLevel.medium,
    tags: [
      'street_food',
      'snack',
      'high_protein',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_omelette_bread',
    name: 'Omelette with bread',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_eggs',
      'cm_bread',
      'cm_onion',
      'cm_tomato',
    ],
    ingredientNames: [
      'Eggs',
      'Local bread',
      'Onion',
      'Tomato',
    ],
    baseMacros: MacroTargets(
      calories: 450,
      proteinG: 21,
      carbsG: 43,
      fatG: 20,
    ),
    minBudget: BudgetLevel.low,
    allergens: ['egg'],
    tags: [
      'breakfast',
      'high_protein',
      'budget',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_eggs_plantain',
    name: 'Eggs with boiled plantain',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_eggs',
      'cm_plantain_boiled',
    ],
    ingredientNames: [
      'Eggs',
      'Boiled plantain',
    ],
    baseMacros: MacroTargets(
      calories: 470,
      proteinG: 18,
      carbsG: 55,
      fatG: 17,
    ),
    minBudget: BudgetLevel.low,
    allergens: ['egg'],
    tags: [
      'breakfast',
      'high_protein',
      'budget',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_sweet_potato_eggs',
    name: 'Sweet potato with eggs',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_sweet_potato',
      'cm_eggs',
    ],
    ingredientNames: [
      'Sweet potato',
      'Eggs',
    ],
    baseMacros: MacroTargets(
      calories: 430,
      proteinG: 17,
      carbsG: 48,
      fatG: 17,
    ),
    minBudget: BudgetLevel.low,
    allergens: ['egg'],
    tags: [
      'breakfast',
      'post_workout',
      'budget',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_maize_eggs',
    name: 'Boiled maize with eggs',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_maize_boiled',
      'cm_eggs',
    ],
    ingredientNames: [
      'Boiled maize',
      'Eggs',
    ],
    baseMacros: MacroTargets(
      calories: 420,
      proteinG: 19,
      carbsG: 48,
      fatG: 16,
    ),
    minBudget: BudgetLevel.low,
    allergens: ['egg'],
    tags: [
      'breakfast',
      'staple',
      'budget',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_banana_bread',
    name: 'Banana with bread',
    objective: MealObjective.light,
    ingredientIds: [
      'cm_banana',
      'cm_bread',
    ],
    ingredientNames: [
      'Banana',
      'Local bread',
    ],
    baseMacros: MacroTargets(
      calories: 360,
      proteinG: 8,
      carbsG: 68,
      fatG: 6,
    ),
    minBudget: BudgetLevel.low,
    tags: [
      'breakfast',
      'snack',
      'pre_workout',
      'budget',
    ],
  ),

  // ---------------------------------------------------------------------------
  // Additional Cameroon breakfast / street-food meals
  // ---------------------------------------------------------------------------

  MealTemplate(
    id: 'cm_meal_puff_puff_beans',
    name: 'Puff Puff and Beans',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_beignets',
      'cm_beans',
      'cm_palm_oil',
    ],
    ingredientNames: [
      'Puff Puff / Beignets',
      'Cooked beans',
      'Palm oil',
    ],
    baseMacros: MacroTargets(
      calories: 620,
      proteinG: 18,
      carbsG: 82,
      fatG: 23,
    ),
    minBudget: BudgetLevel.low,
    tags: [
      'breakfast',
      'street_food',
      'high_energy',
      'budget',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_egusi_pudding',
    name: 'Egusi Pudding',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_egusi',
      'cm_crayfish',
      'cm_smoked_fish',
      'cm_eggs',
      'cm_hot_pepper',
    ],
    ingredientNames: [
      'Egusi / melon seeds',
      'Dried crayfish',
      'Smoked fish',
      'Eggs',
      'Hot pepper',
    ],
    baseMacros: MacroTargets(
      calories: 520,
      proteinG: 31,
      carbsG: 12,
      fatG: 38,
    ),
    minBudget: BudgetLevel.medium,
    allergens: [
      'fish',
      'shellfish',
      'egg',
    ],
    tags: [
      'traditional',
      'breakfast',
      'high_protein',
    ],
  ),
];
