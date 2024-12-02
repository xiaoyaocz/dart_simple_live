// ignore_for_file: non_constant_identifier_names, constant_identifier_names, no_leading_underscores_for_local_identifiers

import 'dart:typed_data';

import './tars_input_stream.dart';
import './tars_output_stream.dart';
import './tars_deep_copyable.dart';

enum TarsStructType {
  BYTE,
  SHORT,
  INT,
  LONG,
  FLOAT,
  DOUBLE,
  STRING1,
  STRING4,
  MAP,
  LIST,
  STRUCT_BEGIN,
  STRUCT_END,
  ZERO_TAG,
  SIMPLE_LIST,
}

abstract class TarsStruct extends DeepCopyable {
  static int TARS_MAX_STRING_LENGTH = 100 * 1024 * 1024;
  void writeTo(TarsOutputStream _os);
  void readFrom(TarsInputStream _is);
  void displayAsString(StringBuffer sb, int level);

  Uint8List toByteArray() {
    TarsOutputStream os = TarsOutputStream();
    writeTo(os);
    return os.toUint8List();
  }
}
