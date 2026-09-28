// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_log_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NutritionLogHiveModelAdapter extends TypeAdapter<NutritionLogHiveModel> {
  @override
  final int typeId = 25;

  @override
  NutritionLogHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NutritionLogHiveModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      name: fields[2] as String,
      source: fields[3] as String,
      mealType: fields[4] as String,
      calories: fields[5] as int,
      proteinG: fields[6] as int,
      carbsG: fields[7] as int,
      fatG: fields[8] as int,
      loggedAt: fields[9] as DateTime,
      templateId: fields[10] as String?,
      planMealId: fields[11] as String?,
      portions: (fields[12] as List).cast<LoggedFoodPortionHiveModel>(),
      note: fields[13] as String?,
      dataQuality: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NutritionLogHiveModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.source)
      ..writeByte(4)
      ..write(obj.mealType)
      ..writeByte(5)
      ..write(obj.calories)
      ..writeByte(6)
      ..write(obj.proteinG)
      ..writeByte(7)
      ..write(obj.carbsG)
      ..writeByte(8)
      ..write(obj.fatG)
      ..writeByte(9)
      ..write(obj.loggedAt)
      ..writeByte(10)
      ..write(obj.templateId)
      ..writeByte(11)
      ..write(obj.planMealId)
      ..writeByte(12)
      ..write(obj.portions)
      ..writeByte(13)
      ..write(obj.note)
      ..writeByte(14)
      ..write(obj.dataQuality);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionLogHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
