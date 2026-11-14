// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_favorite.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IptvFavoriteAdapter extends TypeAdapter<IptvFavorite> {
  @override
  final int typeId = 5;

  @override
  IptvFavorite read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IptvFavorite(
      id: fields[0] as String,
      playlistId: fields[1] as String,
      channelId: fields[2] as String,
      name: fields[3] as String,
      logo: fields[4] as String,
      group: fields[5] as String,
      url: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, IptvFavorite obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.playlistId)
      ..writeByte(2)
      ..write(obj.channelId)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.logo)
      ..writeByte(5)
      ..write(obj.group)
      ..writeByte(6)
      ..write(obj.url);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IptvFavoriteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
