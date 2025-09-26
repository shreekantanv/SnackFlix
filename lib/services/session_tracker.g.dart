// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_tracker.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionMetricsAdapter extends TypeAdapter<SessionMetrics> {
  @override
  final int typeId = 0;

  @override
  SessionMetrics read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionMetrics(
      url: fields[6] as String?,
    )
      ..endedAt = fields[1] as DateTime?
      ..promptsShown = fields[2] as int
      ..autoCleared = fields[3] as int
      ..manualOverrides = fields[4] as int
      ..durationWatchedSec = fields[5] as int;
  }

  @override
  void write(BinaryWriter writer, SessionMetrics obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.startedAt)
      ..writeByte(1)
      ..write(obj.endedAt)
      ..writeByte(2)
      ..write(obj.promptsShown)
      ..writeByte(3)
      ..write(obj.autoCleared)
      ..writeByte(4)
      ..write(obj.manualOverrides)
      ..writeByte(5)
      ..write(obj.durationWatchedSec)
      ..writeByte(6)
      ..write(obj.url);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionMetricsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
