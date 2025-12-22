import 'package:tars_dart/tars/codec/tars_displayer.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

class HuyaUserId extends TarsStruct {
  int lUid = 0;
  String sGuid = "";
  String sToken = "";
  String sHuYaUA = "";
  String sCookie = "";
  int iTokenType = 0;
  String sDeviceInfo = "";
  String sQIMEI = "";

  @override
  void readFrom(TarsInputStream _is) {
    lUid = _is.read(lUid, 0, false);
    sGuid = _is.read(sGuid, 1, false);
    sToken = _is.read(sToken, 2, false);
    sHuYaUA = _is.read(sHuYaUA, 3, false);
    sCookie = _is.read(sCookie, 4, false);
    iTokenType = _is.read(iTokenType, 5, false);
    sDeviceInfo = _is.read(sDeviceInfo, 6, false);
    sQIMEI = _is.read(sQIMEI, 7, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(lUid, 0);
    _os.write(sGuid, 1);
    _os.write(sToken, 2);
    _os.write(sHuYaUA, 3);
    _os.write(sCookie, 4);
    _os.write(iTokenType, 5);
    _os.write(sDeviceInfo, 6);
    _os.write(sQIMEI, 7);
  }

  @override
  Object deepCopy() {
    return HuyaUserId()
      ..lUid = lUid
      ..sGuid = sGuid
      ..sToken = sToken
      ..sHuYaUA = sHuYaUA
      ..sCookie = sCookie
      ..iTokenType = iTokenType
      ..sDeviceInfo = sDeviceInfo
      ..sQIMEI = sQIMEI;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayInt(lUid, "lUid");
    _ds.DisplayString(sGuid, "sGuid");
    _ds.DisplayString(sToken, "sToken");
    _ds.DisplayString(sHuYaUA, "sHuYaUA");
    _ds.DisplayString(sCookie, "sCookie");
    _ds.DisplayInt(iTokenType, "iTokenType");
    _ds.DisplayString(sDeviceInfo, "sDeviceInfo");
    _ds.DisplayString(sQIMEI, "sQIMEI");
  }
}

class GetLivingInfoReq extends TarsStruct {
  HuyaUserId tId = HuyaUserId();
  int lTopSid = 0;
  int lSubSid = 0;
  int lPresenterUid = 0;
  int lRoomId = 0;
  String sTraceSource = "";
  String sPassword = "";
  int iRoomId = 0;
  int iFreeFlowFlag = 0;
  int iIpStack = 0;

  @override
  void readFrom(TarsInputStream _is) {
    tId = _is.read(tId, 0, false);
    lTopSid = _is.read(lTopSid, 1, false);
    lSubSid = _is.read(lSubSid, 2, false);
    lPresenterUid = _is.read(lPresenterUid, 3, false);
    lRoomId = _is.read(lRoomId, 4, false);
    sTraceSource = _is.read(sTraceSource, 5, false);
    sPassword = _is.read(sPassword, 6, false);
    iRoomId = _is.read(iRoomId, 7, false);
    iFreeFlowFlag = _is.read(iFreeFlowFlag, 8, false);
    iIpStack = _is.read(iIpStack, 9, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(tId, 0);
    _os.write(lTopSid, 1);
    _os.write(lSubSid, 2);
    _os.write(lPresenterUid, 3);
    _os.write(lRoomId, 4);
    _os.write(sTraceSource, 5);
    _os.write(sPassword, 6);
    _os.write(iRoomId, 7);
    _os.write(iFreeFlowFlag, 8);
    _os.write(iIpStack, 9);
  }

  @override
  Object deepCopy() {
    return GetLivingInfoReq()
      ..tId = tId.deepCopy() as HuyaUserId
      ..lTopSid = lTopSid
      ..lSubSid = lSubSid
      ..lPresenterUid = lPresenterUid
      ..lRoomId = lRoomId
      ..sTraceSource = sTraceSource
      ..sPassword = sPassword
      ..iRoomId = iRoomId
      ..iFreeFlowFlag = iFreeFlowFlag
      ..iIpStack = iIpStack;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayTarsStruct(tId, "tId");
    _ds.DisplayInt(lTopSid, "lTopSid");
    _ds.DisplayInt(lSubSid, "lSubSid");
    _ds.DisplayInt(lPresenterUid, "lPresenterUid");
    _ds.DisplayInt(lRoomId, "lRoomId");
    _ds.DisplayString(sTraceSource, "sTraceSource");
    _ds.DisplayString(sPassword, "sPassword");
    _ds.DisplayInt(iRoomId, "iRoomId");
    _ds.DisplayInt(iFreeFlowFlag, "iFreeFlowFlag");
    _ds.DisplayInt(iIpStack, "iIpStack");
  }
}
