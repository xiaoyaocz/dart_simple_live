
import 'package:tars_dart/tars/codec/tars_displayer.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

import 'huya_user_id.dart';

class GetCdnTokenExReq extends TarsStruct {
  String sFlvUrl = ""; //tag 0
  String sStreamName = ""; //tag 1
  int iLoopTime = 0; //tag 2
  HuyaUserId tId = HuyaUserId(); //tag 3
  int iAppId = 66; //tag 4

  @override
  void readFrom(TarsInputStream _is) {
    sFlvUrl = _is.read(sFlvUrl, 0, false);
    sStreamName = _is.read(sStreamName, 1, false);
    iLoopTime = _is.read(iLoopTime, 2, false);
    tId = _is.read(tId, 3, false);
    iAppId = _is.read(iAppId, 4, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(sFlvUrl, 0);
    _os.write(sStreamName, 1);
    _os.write(iLoopTime, 2);
    _os.write(tId, 3);
    _os.write(iAppId, 4);
  }

  @override
  TarsStruct deepCopy() {
    return GetCdnTokenExReq()
      ..sFlvUrl = sFlvUrl
      ..sStreamName = sStreamName
      ..iLoopTime = iLoopTime
      ..tId = tId
      ..iAppId = iAppId;
  }

  @override
  displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayString(sFlvUrl, "sFlvUrl");
    _ds.DisplayString(sStreamName, "sStreamName");
    _ds.DisplayInt(iLoopTime, "iLoopTime");
    _ds.DisplayTarsStruct(tId, "tId");
    _ds.DisplayInt(iAppId, "iAppId");
  }
}
