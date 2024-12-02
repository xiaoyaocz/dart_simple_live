// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:tars_dart/tars/codec/tars_displayer.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

class GetCdnTokenResp extends TarsStruct {
  String url = "";

  String cdnType = "";

  String streamName = "";

  int presenterUid = 0;

  String antiCode = "";

  String sTime = "";

  String flvAntiCode = "";

  String hlsAntiCode = "";

  @override
  void readFrom(TarsInputStream _is) {
    url = _is.read(url, 0, false);
    cdnType = _is.read(cdnType, 1, false);
    streamName = _is.read(streamName, 2, false);
    presenterUid = _is.read(presenterUid, 3, false);
    antiCode = _is.read(antiCode, 4, false);
    sTime = _is.read(sTime, 5, false);
    flvAntiCode = _is.read(flvAntiCode, 6, false);
    hlsAntiCode = _is.read(hlsAntiCode, 7, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(url, 0);
    _os.write(cdnType, 1);
    _os.write(streamName, 2);
    _os.write(presenterUid, 3);
    _os.write(antiCode, 4);
    _os.write(sTime, 5);
    _os.write(flvAntiCode, 6);
    _os.write(hlsAntiCode, 7);
  }

  @override
  Object deepCopy() {
    return GetCdnTokenResp()
      ..url = url
      ..cdnType = cdnType
      ..streamName = streamName
      ..presenterUid = presenterUid
      ..antiCode = antiCode
      ..sTime = sTime
      ..flvAntiCode = flvAntiCode
      ..hlsAntiCode = hlsAntiCode;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayString(url, "url");
    _ds.DisplayString(cdnType, "cdnType");
    _ds.DisplayString(streamName, "streamName");
    _ds.DisplayInt(presenterUid, "presenterUid");
    _ds.DisplayString(antiCode, "antiCode");
    _ds.DisplayString(sTime, "sTime");
    _ds.DisplayString(flvAntiCode, "flvAntiCode");
    _ds.DisplayString(hlsAntiCode, "hlsAntiCode");
  }
}
