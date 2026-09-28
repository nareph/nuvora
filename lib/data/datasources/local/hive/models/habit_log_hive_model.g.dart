// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_log_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitLogHiveModelAdapter extends TypeAdapter<HabitLogHiveModel> {
  @override
  final int typeId = 23;

  @override
  HabitLogHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HabitLogHiveModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      habitId: fields[2] as String,
      date: fields[3] as DateTime,
      completed: fields[4] as bool,
      loggedAt: fields[5] as DateTime,
      value: fields[6] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, HabitLogHiveModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.habitId)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.completed)
      ..writeByte(5)
      ..write(obj.loggedAt)
      ..writeByte(6)
      ..write(obj.value);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitLogHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
