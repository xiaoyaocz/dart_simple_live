// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FollowUserAdapter extends TypeAdapter<FollowUser> {
  @override
  final int typeId = 1;

  @override
  FollowUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FollowUser(
      id: fields[0] as String,
      roomId: fields[1] as String,
      siteId: fields[2] as String,
      userName: fields[3] as String,
      face: fields[4] as String,
      addTime: fields[5] as DateTime,
      tag: fields[6] ?? "全部",
      isSpecialFollow: fields[7] as bool? ?? false,
      roomTitle: fields[8] as String? ?? "",
      roomCover: fields[9] as String? ?? "",
      previewUpdatedAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, FollowUser obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.roomId)
      ..writeByte(2)
      ..write(obj.siteId)
      ..writeByte(3)
      ..write(obj.userName)
      ..writeByte(4)
      ..write(obj.face)
      ..writeByte(5)
      ..write(obj.addTime)
      ..writeByte(6)
      ..write(obj.tag)
      ..writeByte(7)
      ..write(obj.isSpecialFollow)
      ..writeByte(8)
      ..write(obj.roomTitle)
      ..writeByte(9)
      ..write(obj.roomCover)
      ..writeByte(10)
      ..write(obj.previewUpdatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
