// ignore_for_file: non_constant_identifier_names, avoid_renaming_method_parameters, no_leading_underscores_for_local_identifiers

import 'dart:core';
import 'dart:typed_data';
import '/tars/codec/tars_input_stream.dart';
import '/tars/codec/tars_output_stream.dart';
import '/tars/codec/tars_struct.dart';
import '/tars/codec/tars_displayer.dart';
import '/tars/codec/tars_deep_copyable.dart';

class RequestPacket extends TarsStruct {
  String className() {
    return "RequestPacket";
  }

  int iVersion = 0;

  int cPacketType = 0;

  int iMessageType = 0;

  int iRequestId = 0;

  String sServantName = "";

  String sFuncName = "";

  Uint8List? sBuffer;

  int iTimeout = 0;

  Map<String, String>? context;

  Map<String, String>? status;

  RequestPacket(
      {this.iVersion = 0,
      this.cPacketType = 0,
      this.iMessageType = 0,
      this.iRequestId = 0,
      this.sServantName = "",
      this.sFuncName = "",
      this.sBuffer,
      this.iTimeout = 0,
      this.context,
      this.status});

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(iVersion, 1);
    _os.write(cPacketType, 2);
    _os.write(iMessageType, 3);
    _os.write(iRequestId, 4);
    _os.write(sServantName, 5);
    _os.write(sFuncName, 6);
    _os.write(sBuffer, 7);
    _os.write(iTimeout, 8);
    _os.write(context, 9);
    _os.write(status, 10);
  }

  static Uint8List cache_sBuffer = Uint8List.fromList([0x0]);
  static Map<String, String> cache_context = {"": ""};
  static Map<String, String> cache_status = {"": ""};

  @override
  void readFrom(TarsInputStream _is) {
    iVersion = _is.read<int>(iVersion, 1, false);
    cPacketType = _is.read<int>(cPacketType, 2, false);
    iMessageType = _is.read<int>(iMessageType, 3, false);
    iRequestId = _is.read<int>(iRequestId, 4, false);
    sServantName = _is.read<String>(sServantName, 5, false);
    sFuncName = _is.read<String>(sFuncName, 6, false);
    sBuffer = _is.read<int>(cache_sBuffer, 7, false);
    iTimeout = _is.read<int>(iTimeout, 8, false);
    context = _is.readMap<String, String>(cache_context, 9, false);
    status = _is.readMap<String, String>(cache_status, 10, false);
  }

  @override
  void displayAsString(StringBuffer _os, int _level) {
    TarsDisplayer _ds = TarsDisplayer(_os, level: _level);
    _ds.display(iVersion, "iVersion");
    _ds.display(cPacketType, "cPacketType");
    _ds.display(iMessageType, "iMessageType");
    _ds.display(iRequestId, "iRequestId");
    _ds.display(sServantName, "sServantName");
    _ds.display(sFuncName, "sFuncName");
    _ds.display(sBuffer, "sBuffer");
    _ds.display(iTimeout, "iTimeout");
    _ds.display(context, "context");
    _ds.display(status, "status");
  }

  @override
  Object deepCopy() {
    var o = RequestPacket();
    o.iVersion = iVersion;
    o.cPacketType = cPacketType;
    o.iMessageType = iMessageType;
    o.iRequestId = iRequestId;
    o.sServantName = sServantName;
    o.sFuncName = sFuncName;
    o.sBuffer = sBuffer;
    o.iTimeout = iTimeout;
    if (null != context) {
      o.context = mapDeepCopy<String, String>(context!);
    }
    if (null != status) {
      o.status = mapDeepCopy<String, String>(status!);
    }
    return o;
  }
}
