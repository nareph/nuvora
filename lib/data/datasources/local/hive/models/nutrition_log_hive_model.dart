import 'package:hive/hive.dart';

import 'logged_food_portion_hive_model.dart';

part 'nutrition_log_hive_model.g.dart';

@HiveType(typeId: 25)
class NutritionLogHiveModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  String name;

  @HiveField(3)
  String source;

  @HiveField(4)
  String mealType;

  @HiveField(5)
  int calories;

  @HiveField(6)
  int proteinG;

  @HiveField(7)
  int carbsG;

  @HiveField(8)
  int fatG;

  @HiveField(9)
  DateTime loggedAt;

  @HiveField(10)
  String? templateId;

  @HiveField(11)
  String? planMealId;

  @HiveField(12)
  List<LoggedFoodPortionHiveModel> portions;

  @HiveField(13)
  String? note;

  /// Nullable on purpose for backward compatibility.
  ///
  /// Old Hive records do not contain field 14. The domain mapper will derive
  /// the appropriate quality from [source] when this value is null.
  @HiveField(14)
  String? dataQuality;

  NutritionLogHiveModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.source,
    required this.mealType,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.loggedAt,
    this.templateId,
    this.planMealId,
    this.portions = const [],
    this.note,
    this.dataQuality,
  });
}
