import 'dart:typed_data';
import 'uni_packet.dart';
import 'const.dart';

class TarsUniPacket extends UniPacket {
  TarsUniPacket() {
    package.iVersion = Const.PACKET_TYPE_TUP3;
    package.cPacketType = Const.PACKET_TYPE_TARSNORMAL;
    package.iMessageType = 0;
    package.iTimeout = 0;
    package.sBuffer = Uint8List.fromList([0x0]);
    package.context = <String, String>{};
    package.status = <String, String>{};
  }

  /// 设置协议版本
  void setTarsVersion(int version) {
    setVersion(version);
  }

  /// 设置调用类型
  void setTarsPacketType(int packetType) {
    package.cPacketType = packetType;
  }

  /// 设置消息类型
  void setTarsMessageType(int messageType) {
    package.iMessageType = messageType;
  }

  /// 设置超时时间
  void setTarsTimeout(int timeout) {
    package.iTimeout = timeout;
  }

  /// 设置参数编码内容
  void setTarsBuffer(Uint8List buffer) {
    package.sBuffer = buffer;
  }

  /// 设置上下文
  void setTarsContext(Map<String, String> context) {
    package.context = context;
  }

  /// 设置特殊消息的状态值
  void setTarsStatus(Map<String, String> status) {
    package.status = status;
  }

  /// 获取协议版本
  int getTarsVersion() {
    return package.iVersion;
  }

  /// 获取调用类型
  int getTarsPacketType() {
    return package.cPacketType;
  }

  /// 获取消息类型
  int getTarsMessageType() {
    return package.iMessageType;
  }

  /// 获取超时时间
  int getTarsTimeout() {
    return package.iTimeout;
  }

  /// 获取参数编码后内容
  Uint8List? getTarsBuffer() {
    return package.sBuffer;
  }

  /// 获取上下文信息
  Map<String, String>? getTarsContext() {
    return package.context;
  }

  /// 获取特殊消息的状态值
  Map<String, String>? getTarsStatus() {
    return package.status;
  }

  /// 获取调用tars的返回值
  int getTarsResultCode() {
    int result = 0;
    try {
      String? rcode = package.status?[Const.STATUS_RESULT_CODE];
      result = (rcode != null ? int.tryParse(rcode) : 0)!;
    } catch (e) {
      print('getTarsResultCode exception: $e');
      return 0;
    }
    return result;
  }

  /// 获取调用tars的返回描述
  String getTarsResultDesc() {
    String? rdesc = package.status?[Const.STATUS_RESULT_DESC];
    String result = rdesc ?? "";
    return result;
  }
}
