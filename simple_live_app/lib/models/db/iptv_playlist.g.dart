// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_playlist.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IptvPlaylistAdapter extends TypeAdapter<IptvPlaylist> {
  @override
  final int typeId = 4;

  @override
  IptvPlaylist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IptvPlaylist(
      id: fields[0] as String,
      name: fields[1] as String,
      url: fields[2] as String,
      type: fields[3] as int,
      updateTime: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, IptvPlaylist obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.updateTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IptvPlaylistAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
