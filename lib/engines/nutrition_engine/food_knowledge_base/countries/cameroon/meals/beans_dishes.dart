import 'package:gymgenius/domain/enums/budget_level.dart';
import 'package:gymgenius/domain/enums/meal_objective.dart';
import 'package:gymgenius/domain/value_objects/macro_targets.dart';

import '../../../models/meal_template.dart';

const List<MealTemplate> cameroonBeansDishes = [
  MealTemplate(
    id: 'cm_meal_beans_plantain',
    name: 'Beans and plantain',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_beans',
      'cm_plantain_boiled',
      'cm_palm_oil',
    ],
    ingredientNames: [
      'Beans',
      'Boiled plantain',
      'Palm oil',
    ],
    baseMacros: MacroTargets(
      calories: 550,
      proteinG: 20,
      carbsG: 95,
      fatG: 4,
    ),
    tags: [
      'lunch',
      'dinner',
      'staple',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_beans_avocado',
    name: 'Beans with avocado',
    objective: MealObjective.recovery,
    ingredientIds: [
      'cm_beans',
      'cm_avocado',
      'cm_tomato',
    ],
    ingredientNames: [
      'Beans',
      'Avocado',
      'Tomato',
    ],
    baseMacros: MacroTargets(
      calories: 420,
      proteinG: 18,
      carbsG: 40,
      fatG: 18,
    ),
    tags: [
      'lunch',
      'recovery',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_koki',
    name: 'Koki with boiled plantain',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_koki_beans',
      'cm_palm_oil',
      'cm_plantain_boiled',
    ],
    ingredientNames: [
      'Koki beans',
      'Palm oil',
      'Boiled plantain',
    ],
    baseMacros: MacroTargets(
      calories: 580,
      proteinG: 18,
      carbsG: 70,
      fatG: 22,
    ),
    tags: [
      'traditional',
      'lunch',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_rice_beans',
    name: 'Rice and Beans',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_rice',
      'cm_beans',
      'cm_palm_oil',
    ],
    ingredientNames: [
      'White rice',
      'Beans',
      'Palm oil',
    ],
    baseMacros: MacroTargets(
      calories: 520,
      proteinG: 18,
      carbsG: 78,
      fatG: 12,
    ),
    tags: [
      'lunch',
      'dinner',
      'staple',
      'vegetarian',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_beans_yam',
    name: 'Beans and Yam',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_beans',
      'cm_yam',
    ],
    ingredientNames: [
      'Beans',
      'Yam',
    ],
    baseMacros: MacroTargets(
      calories: 540,
      proteinG: 19,
      carbsG: 85,
      fatG: 10,
    ),
    tags: [
      'lunch',
      'dinner',
      'staple',
      'vegetarian',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_beans_macaroni',
    name: 'Beans and Pasta',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_beans',
      'cm_macaroni',
    ],
    ingredientNames: [
      'Beans',
      'Macaroni',
    ],
    baseMacros: MacroTargets(
      calories: 500,
      proteinG: 17,
      carbsG: 80,
      fatG: 10,
    ),
    tags: [
      'lunch',
      'dinner',
      'staple',
      'vegetarian',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_beans_tomato_beef',
    name: 'Beans stew with beef',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_beans',
      'cm_beef',
      'cm_tomato',
      'cm_onion',
    ],
    ingredientNames: [
      'Beans',
      'Beef',
      'Tomato',
      'Onion',
    ],
    baseMacros: MacroTargets(
      calories: 580,
      proteinG: 32,
      carbsG: 45,
      fatG: 26,
    ),
    minBudget: BudgetLevel.medium,
    tags: [
      'lunch',
      'dinner',
      'traditional',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_beans_tomato_fish',
    name: 'Beans stew with fish',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_beans',
      'cm_fish',
      'cm_tomato',
      'cm_onion',
    ],
    ingredientNames: [
      'Beans',
      'Fresh fish',
      'Tomato',
      'Onion',
    ],
    baseMacros: MacroTargets(
      calories: 520,
      proteinG: 33,
      carbsG: 40,
      fatG: 18,
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
    id: 'cm_meal_beans_corn_meal',
    name: 'Beans with corn meal',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_beans',
      'cm_corn_flour',
    ],
    ingredientNames: [
      'Beans',
      'Corn meal',
    ],
    baseMacros: MacroTargets(
      calories: 500,
      proteinG: 18,
      carbsG: 75,
      fatG: 12,
    ),
    tags: [
      'lunch',
      'dinner',
      'staple',
      'vegetarian',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_beans_fufu',
    name: 'Beans with fufu',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_beans',
      'cm_fufu',
    ],
    ingredientNames: [
      'Beans',
      'Water fufu',
    ],
    baseMacros: MacroTargets(
      calories: 540,
      proteinG: 17,
      carbsG: 80,
      fatG: 10,
    ),
    tags: [
      'lunch',
      'dinner',
      'staple',
      'vegetarian',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_beans_fried_plantain',
    name: 'Beans with fried plantain',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_beans',
      'cm_plantain_fried',
    ],
    ingredientNames: [
      'Beans',
      'Fried plantain',
    ],
    baseMacros: MacroTargets(
      calories: 650,
      proteinG: 19,
      carbsG: 88,
      fatG: 24,
    ),
    minBudget: BudgetLevel.low,
    tags: [
      'lunch',
      'dinner',
      'staple',
      'budget',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_beans_cassava',
    name: 'Beans with cassava',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_beans',
      'cm_cassava',
    ],
    ingredientNames: [
      'Beans',
      'Cassava',
    ],
    baseMacros: MacroTargets(
      calories: 560,
      proteinG: 18,
      carbsG: 92,
      fatG: 12,
    ),
    minBudget: BudgetLevel.low,
    tags: [
      'lunch',
      'dinner',
      'staple',
      'vegetarian',
      'budget',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_beans_sweet_potato',
    name: 'Beans with sweet potato',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_beans',
      'cm_sweet_potato',
    ],
    ingredientNames: [
      'Beans',
      'Sweet potato',
    ],
    baseMacros: MacroTargets(
      calories: 500,
      proteinG: 18,
      carbsG: 82,
      fatG: 7,
    ),
    minBudget: BudgetLevel.low,
    tags: [
      'lunch',
      'dinner',
      'staple',
      'vegetarian',
      'budget',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_beans_potato',
    name: 'Beans with Irish potatoes',
    objective: MealObjective.highEnergy,
    ingredientIds: [
      'cm_beans',
      'cm_irish_potato',
    ],
    ingredientNames: [
      'Beans',
      'Irish potato',
    ],
    baseMacros: MacroTargets(
      calories: 490,
      proteinG: 18,
      carbsG: 78,
      fatG: 7,
    ),
    minBudget: BudgetLevel.low,
    tags: [
      'lunch',
      'dinner',
      'staple',
      'vegetarian',
      'budget',
    ],
  ),
  MealTemplate(
    id: 'cm_meal_beans_smoked_fish',
    name: 'Beans with smoked fish',
    objective: MealObjective.highProtein,
    ingredientIds: [
      'cm_beans',
      'cm_smoked_fish',
      'cm_onion',
    ],
    ingredientNames: [
      'Beans',
      'Smoked fish',
      'Onion',
    ],
    baseMacros: MacroTargets(
      calories: 540,
      proteinG: 34,
      carbsG: 42,
      fatG: 20,
    ),
    minBudget: BudgetLevel.medium,
    allergens: ['fish'],
    tags: [
      'lunch',
      'dinner',
      'traditional',
      'high_protein',
      'fish',
    ],
  ),
];
