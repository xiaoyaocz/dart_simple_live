// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_tag.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IptvTagAdapter extends TypeAdapter<IptvTag> {
  @override
  final int typeId = 6;

  @override
  IptvTag read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IptvTag(
      id: fields[1] as String,
      tag: fields[2] as String,
      favoriteIds: (fields[3] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, IptvTag obj) {
    writer
      ..writeByte(3)
      ..writeByte(1)
      ..write(obj.id)
      ..writeByte(2)
      ..write(obj.tag)
      ..writeByte(3)
      ..write(obj.favoriteIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IptvTagAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
