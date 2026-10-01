import 'package:gymgenius/domain/enums/budget_level.dart';
import 'package:gymgenius/domain/enums/meal_objective.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';

import '../../../models/meal_template.dart';

const List<MealTemplate> cameroonRiceAndGrainDishes = [
  MealTemplate(
    id: 'cm_meal_rice_chicken',
    name: 'Rice and grilled chicken with vegetables',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_rice',
      'cm_chicken',
      'cm_carrot',
      'cm_cabbage',
      'cm_tomato',
    ],
    ingredientNames: [
      'White rice',
      'Grilled chicken',
      'Carrot',
      'Cabbage',
      'Tomato',
    ],
    baseMacros: MacroTargets(
      calories: 620,
      proteinG: 42,
      carbsG: 72,
      fatG: 14,
    ),
    minBudget: BudgetLevel.medium,
    tags: [
      'lunch',
      'dinner',
      'high_protein',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_jollof_rice',
    name: 'Jollof Rice',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_rice',
      'cm_tomato',
      'cm_onion',
      'cm_palm_oil',
      'cm_chicken',
    ],
    ingredientNames: [
      'White rice',
      'Tomato',
      'Onion',
      'Palm oil',
      'Chicken',
    ],
    baseMacros: MacroTargets(
      calories: 650,
      proteinG: 30,
      carbsG: 78,
      fatG: 22,
    ),
    minBudget: BudgetLevel.medium,
    tags: [
      'lunch',
      'dinner',
      'staple',
      'special',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_bifaga',
    name: 'Stir-Fried Rice with Bounga (Smoked Fish)',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_rice',
      'cm_smoked_fish',
      'cm_morue',
      'cm_onion',
      'cm_tomato',
      'cm_palm_oil',
    ],
    ingredientNames: [
      'Stir-fried rice',
      'Smoked fish (Bounga)',
      'Morue',
      'Onion',
      'Tomato',
      'Palm oil',
    ],
    baseMacros: MacroTargets(
      calories: 520,
      proteinG: 34,
      carbsG: 55,
      fatG: 17,
    ),
    minBudget: BudgetLevel.medium,
    allergens: ['fish'],
    tags: [
      'lunch',
      'dinner',
      'traditional',
      'fish',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_rice_tomato_fish',
    name: 'Rice with tomato sauce and fish',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_rice',
      'cm_fish',
      'cm_tomato',
      'cm_onion',
      'cm_palm_oil',
    ],
    ingredientNames: [
      'White rice',
      'Fresh fish',
      'Tomato',
      'Onion',
      'Palm oil',
    ],
    baseMacros: MacroTargets(
      calories: 560,
      proteinG: 32,
      carbsG: 68,
      fatG: 16,
    ),
    minBudget: BudgetLevel.medium,
    allergens: ['fish'],
    tags: [
      'lunch',
      'dinner',
      'staple',
      'fish',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_rice_peanut_sauce',
    name: 'White rice with peanut sauce',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_rice',
      'cm_peanut_paste',
      'cm_onion',
      'cm_tomato',
      'cm_hot_pepper',
    ],
    ingredientNames: [
      'White rice',
      'Peanut paste',
      'Onion',
      'Tomato',
      'Hot pepper',
    ],
    baseMacros: MacroTargets(
      calories: 610,
      proteinG: 18,
      carbsG: 75,
      fatG: 25,
    ),
    minBudget: BudgetLevel.medium,
    allergens: ['peanut'],
    tags: [
      'lunch',
      'dinner',
      'traditional',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_corn_chaff',
    name: 'Corn Chaff (maize and beans)',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_maize_boiled',
      'cm_beans',
      'cm_palm_oil',
      'cm_onion',
      'cm_tomato',
    ],
    ingredientNames: [
      'Maize',
      'Beans',
      'Palm oil',
      'Onion',
      'Tomato',
    ],
    baseMacros: MacroTargets(
      calories: 560,
      proteinG: 19,
      carbsG: 82,
      fatG: 17,
    ),
    minBudget: BudgetLevel.low,
    tags: [
      'street_food',
      'lunch',
      'dinner',
      'staple',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_pasta_tomato_sauce',
    name: 'Pasta with tomato sauce',
    objective: MealObjective.light,
    ingredientIds: [
      'cm_macaroni',
      'cm_tomato',
      'cm_onion',
      'cm_carrot',
    ],
    ingredientNames: [
      'Macaroni',
      'Tomato',
      'Onion',
      'Carrot',
    ],
    baseMacros: MacroTargets(
      calories: 390,
      proteinG: 13,
      carbsG: 65,
      fatG: 8,
    ),
    minBudget: BudgetLevel.low,
    tags: [
      'lunch',
      'dinner',
      'vegetarian',
      'light',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_sardines_rice',
    name: 'Rice with sardines',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_rice',
      'cm_sardines',
      'cm_onion',
      'cm_tomato',
    ],
    ingredientNames: [
      'White rice',
      'Sardines',
      'Onion',
      'Tomato',
    ],
    baseMacros: MacroTargets(
      calories: 540,
      proteinG: 31,
      carbsG: 61,
      fatG: 18,
    ),
    minBudget: BudgetLevel.low,
    allergens: ['fish'],
    tags: [
      'lunch',
      'dinner',
      'post_workout',
      'fish',
      'budget',
    ],
  ),

  MealTemplate(
    id: 'cm_meal_beef_rice',
    name: 'Rice with beef',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_rice',
      'cm_beef',
      'cm_onion',
      'cm_tomato',
    ],
    ingredientNames: [
      'White rice',
      'Beef',
      'Onion',
      'Tomato',
    ],
    baseMacros: MacroTargets(
      calories: 610,
      proteinG: 34,
      carbsG: 62,
      fatG: 21,
    ),
    minBudget: BudgetLevel.medium,
    tags: [
      'lunch',
      'dinner',
      'staple',
    ],
  ),

  // ---------------------------------------------------------------------------
  // Additional Cameroon grain meal
  // ---------------------------------------------------------------------------

  MealTemplate(
    id: 'cm_meal_folere_rice',
    name: 'Foléré sauce with rice',
    objective: MealObjective.light,
    ingredientIds: [
      'cm_folere',
      'cm_rice',
      'cm_onion',
      'cm_tomato',
      'cm_hot_pepper',
    ],
    ingredientNames: [
      'Foléré / roselle leaves',
      'White rice',
      'Onion',
      'Tomato',
      'Hot pepper',
    ],
    baseMacros: MacroTargets(
      calories: 420,
      proteinG: 10,
      carbsG: 67,
      fatG: 12,
    ),
    minBudget: BudgetLevel.low,
    tags: [
      'lunch',
      'dinner',
      'traditional',
      'vegetable',
    ],
  ),
];
