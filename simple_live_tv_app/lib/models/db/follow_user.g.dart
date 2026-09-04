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
      isSpecialFollow: fields[6] as bool? ?? false,
      roomTitle: fields[7] as String? ?? "",
      roomCover: fields[8] as String? ?? "",
      previewUpdatedAt: fields[9] as DateTime?,
      tag: fields[10] as String? ?? "全部",
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
      ..write(obj.isSpecialFollow)
      ..writeByte(7)
      ..write(obj.roomTitle)
      ..writeByte(8)
      ..write(obj.roomCover)
      ..writeByte(9)
      ..write(obj.previewUpdatedAt)
      ..writeByte(10)
      ..write(obj.tag);
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
