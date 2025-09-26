// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_metrics.dart';

// **************************************************************************
// HiveTypeGenerator
// **************************************************************************

class DailyMetricsAdapter extends TypeAdapter<DailyMetrics> {
  @override
  final int typeId = 1;

  @override
  DailyMetrics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyMetrics(
      date: fields[0] as DateTime,
    )
      ..durationWatchedSec = fields[1] as int
      ..promptsShown = fields[2] as int
      ..autoCleared = fields[3] as int
      ..manualOverrides = fields[4] as int;
  }

  @override
  void write(BinaryWriter writer, DailyMetrics obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.durationWatchedSec)
      ..writeByte(2)
      ..write(obj.promptsShown)
      ..writeByte(3)
      ..write(obj.autoCleared)
      ..writeByte(4)
      ..write(obj.manualOverrides);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyMetricsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
