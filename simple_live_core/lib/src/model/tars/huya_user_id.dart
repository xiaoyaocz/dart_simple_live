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