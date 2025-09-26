// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_metrics.dart';

// **************************************************************************
// TypeAdapterGenerator
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
      sessions: (fields[1] as List?)?.cast<SessionMetrics>(),
    );
  }

  @override
  void write(BinaryWriter writer, DailyMetrics obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.sessions);
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
