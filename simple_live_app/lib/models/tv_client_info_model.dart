import 'dart:convert';

T? asT<T>(dynamic value) {
  if (value is T) {
    return value;
  }
  return null;
}

class TVClientInfoModel {
  TVClientInfoModel({
    required this.name,
    required this.version,
    required this.ip,
    required this.port,
  });

  factory TVClientInfoModel.fromJson(Map<String, dynamic> json) =>
      TVClientInfoModel(
        name: asT<String>(json['name'])!,
        version: asT<String>(json['version'])!,
        ip: asT<String>(json['ip'])!,
        port: asT<int>(json['port'])!,
      );

  String name;
  String version;
  String ip;
  int port;

  @override
  String toString() {
    return jsonEncode(this);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'version': version,
        'ip': ip,
        'port': port,
      };
}
