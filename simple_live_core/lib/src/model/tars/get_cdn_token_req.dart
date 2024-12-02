// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:tars_dart/tars/codec/tars_displayer.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

class GetCdnTokenReq extends TarsStruct {
  String url = "";

  String cdnType = "";

  String streamName = "";

  int presenterUid = 0;

  @override
  void readFrom(TarsInputStream _is) {
    url = _is.read(url, 0, false);
    cdnType = _is.read(cdnType, 1, false);
    streamName = _is.read(streamName, 2, false);
    presenterUid = _is.read(presenterUid, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(url, 0);
    _os.write(cdnType, 1);
    _os.write(streamName, 2);
    _os.write(presenterUid, 3);
  }

  @override
  Object deepCopy() {
    return GetCdnTokenReq()
      ..url = url
      ..cdnType = cdnType
      ..streamName = streamName
      ..presenterUid = presenterUid;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayString(url, "url");
    _ds.DisplayString(cdnType, "cdnType");
    _ds.DisplayString(streamName, "streamName");
    _ds.DisplayInt(presenterUid, "presenterUid");
  }
}
