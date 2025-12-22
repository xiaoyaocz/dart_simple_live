import 'package:tars_dart/tars/codec/tars_displayer.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

class GetCdnTokenExResp extends TarsStruct {
  String sFlvToken = ""; //tag 0
  int iExpireTime = 0; //tag 1

  @override
  void readFrom(TarsInputStream _is) {
    sFlvToken = _is.read(sFlvToken, 0, false);
    iExpireTime = _is.read(iExpireTime, 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(sFlvToken, 0);
    _os.write(iExpireTime, 1);
  }

  @override
  TarsStruct deepCopy() {
    return GetCdnTokenExResp()
      ..sFlvToken = sFlvToken
      ..iExpireTime = iExpireTime;
  }

  @override
  displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayString(sFlvToken, "sFlvToken");
    _ds.DisplayInt(iExpireTime, "iExpireTime");
  }
}
