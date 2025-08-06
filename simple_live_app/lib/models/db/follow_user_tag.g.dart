// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follow_user_tag.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FollowUserTagAdapter extends TypeAdapter<FollowUserTag> {
  @override
  final int typeId = 3;

  @override
  FollowUserTag read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FollowUserTag(
      id: fields[1] as String,
      tag: fields[2] as String,
      userId: (fields[3] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, FollowUserTag obj) {
    writer
      ..writeByte(3)
      ..writeByte(1)
      ..write(obj.id)
      ..writeByte(2)
      ..write(obj.tag)
      ..writeByte(3)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is FollowUserTagAdapter &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
}