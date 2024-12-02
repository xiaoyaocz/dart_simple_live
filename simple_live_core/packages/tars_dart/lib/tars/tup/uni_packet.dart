// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/tup/write_buffer.dart';

import 'const.dart';
import 'request_packet.dart';
import 'uni_attribute.dart';

class UniPacket extends UniAttribute {
  static const int kUniPacketHeadSize = 4;

  RequestPacket package = RequestPacket();

  /// 获取请求的service名字
  ///
  /// @return
  String get servantName {
    return package.sServantName;
  }

  set servantName(String value) {
    package.sServantName = value;
  }

  /// 获取请求的函数名字
  ///
  /// @return
  String get funcName {
    return package.sFuncName;
  }

  set funcName(String value) {
    package.sFuncName = value;
  }

  /// 获取消息序列号
  ///
  /// @return
  int get requestId {
    return package.iRequestId;
  }

  set requestId(int value) {
    package.iRequestId = value;
  }

  UniPacket() {
    package.iVersion = Const.PACKET_TYPE_TUP3;
  }

  void setVersion(int iVer) {
    version = iVer;
    package.iVersion = iVer;
  }

  int getVersion() {
    return package.iVersion;
  }

  /// 将put的对象进行编码
  @override
  Uint8List encode() {
    if (package.sServantName.compareTo("") == 0) {
      throw ArgumentError("servantName can not is null");
    }
    if (package.sFuncName.compareTo("") == 0) {
      throw ArgumentError("funcName can not is null");
    }

    TarsOutputStream _os = TarsOutputStream();
    _os.setServerEncoding(encodeName);
    if (package.iVersion == Const.PACKET_TYPE_TUP) {
      throw UnimplementedError();
    } else {
      _os.write(newData, 0);
    }

    package.sBuffer = _os.toUint8List();

    _os = TarsOutputStream();
    _os.setServerEncoding(encodeName);
    writeTo(_os);
    Uint8List body = _os.toUint8List();
    int size = body.lengthInBytes;

    final WriteBuffer buffer = WriteBuffer();
    buffer.putInt32(size + kUniPacketHeadSize, endian: Endian.big);
    buffer.putUint8List(body);
    return buffer.done().buffer.asUint8List();
  }

  /// 对传入的数据进行解码 填充可get的对象
  @override
  void decode(Uint8List buffer, {int index = 0}) {
    if (buffer.lengthInBytes < kUniPacketHeadSize) {
      throw ArgumentError("Decode namespace must include size head");
    }
    try {
      TarsInputStream _is =
          TarsInputStream(buffer, pos: kUniPacketHeadSize + index);
      _is.setServerEncoding(encodeName);
      //解码出RequestPacket包
      readFrom(_is);

      //设置tup版本
      version = package.iVersion;

      _is = TarsInputStream(package.sBuffer);
      _is.setServerEncoding(encodeName);

      if (package.iVersion == Const.PACKET_TYPE_TUP) {
        oldData = _is.readMapMap<String, String, Uint8List>(
            <String, Map<String, Uint8List>>{
              "": {
                "": Uint8List.fromList([0x0])
              }
            },
            0,
            false);
      } else {
        newData = _is.readMap<String, Uint8List>({
          "": Uint8List.fromList([0x0])
        }, 0, false);
      }
    } catch (e) {
      print('decode exception: $e');
      rethrow;
    }
  }

  @override
  void writeTo(TarsOutputStream _os) {
    package.writeTo(_os);
  }

  @override
  void readFrom(TarsInputStream _is) {
    package.readFrom(_is);
  }
}
