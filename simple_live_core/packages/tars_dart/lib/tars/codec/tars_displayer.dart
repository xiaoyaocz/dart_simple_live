// ignore_for_file: non_constant_identifier_names

import 'dart:typed_data';

import './tars_encode_exception.dart';
import './tars_struct.dart';

class TarsDisplayer {
  late StringBuffer sb;
  int _level = 0;
  TarsDisplayer(this.sb, {int level = 0}) {
    _level = level;
  }

  void ps(String? fieldName) {
    for (var i = 0; i < _level; ++i) {
      sb.write('\t');
    }

    if (fieldName != null) {
      sb.write(fieldName);
      sb.write(': ');
    }
  }

  TarsDisplayer? display(dynamic value, String? fieldName) {
    if (value is bool) {
      return DisplayBool(value, fieldName);
    }
    if (value is int) {
      return DisplayInt(value, fieldName);
    }
    if (value is double) {
      return DisplayDouble(value, fieldName);
    }
    if (value is String) {
      return DisplayString(value, fieldName);
    }
    if (value is Uint8List) {
      return DisplayUint8List(value, fieldName);
    }
    if (value is List) {
      return DisplayArray(value, fieldName);
    }
    if (value is Map) {
      return DisplayMap(value, fieldName);
    }
    if (value is TarsStruct) {
      return DisplayTarsStruct(value, fieldName);
    }
    throw TarsEncodeException('write object error: unsupport type.');
  }

  TarsDisplayer DisplayBool(bool b, String? fieldName) {
    ps(fieldName);
    sb.write(b ? 'T' : 'F');
    sb.write('\n');
    return this;
  }

  TarsDisplayer DisplayInt(int n, String? fieldName) {
    ps(fieldName);
    sb.write(n);
    sb.write('\n');
    return this;
  }

  TarsDisplayer DisplayDouble(double n, String? fieldName) {
    ps(fieldName);
    sb.write(n);
    sb.write('\n');
    return this;
  }

  TarsDisplayer DisplayString(String? s, String? fieldName) {
    ps(fieldName);
    if (null == s) {
      sb.write('null');
      sb.write('\n');
    } else {
      sb.write(s);
      sb.write('\n');
    }

    return this;
  }

  TarsDisplayer DisplayUint8List(Uint8List? v, String? fieldName) {
    ps(fieldName);
    if (null == v) {
      sb.write('null');
      sb.write('\n');
      return this;
    }
    if (v.isEmpty) {
      sb.write(v.length);
      sb.write(', []');
      sb.write('\n');
      return this;
    }
    sb.write(v.length);
    sb.write(', []');
    sb.write('\n');
    var jd = TarsDisplayer(sb, level: _level + 1);
    for (var o in v) {
      jd.display(o, null);
    }

    display(']', null);
    return this;
  }

  TarsDisplayer DisplayMap<K, V>(Map<K, V>? m, String? fieldName) {
    ps(fieldName);
    if (null == m) {
      sb.write('null');
      sb.write('\n');
      return this;
    }
    if (m.isEmpty) {
      sb.write(m.length);
      sb.write(', {}');
      sb.write('\n');
      return this;
    }
    sb.write(m.length);
    sb.write(', {');
    sb.write('\n');
    var jd1 = TarsDisplayer(sb, level: _level + 1);
    var jd = TarsDisplayer(sb, level: _level + 2);
    for (var key in m.keys) {
      jd1.display('(', null);
      jd.display(key, null);
      jd.display(m[key], null);
      jd1.display(')', null);
    }
    display('}', null);
    return this;
  }

  TarsDisplayer DisplayArray<T>(List<T>? v, String? fieldName) {
    ps(fieldName);
    if (null == v) {
      sb.write('null');
      sb.write('\n');
      return this;
    }
    if (v.isEmpty) {
      sb.write(v.length);
      sb.write(', []');
      sb.write('\n');
      return this;
    }
    sb.write(v.length);
    sb.write(', [');
    sb.write('\n');
    var jd = TarsDisplayer(sb, level: _level + 1);
    for (var o in v) {
      jd.display(o, null);
    }
    display(']', null);
    return this;
  }

  TarsDisplayer DisplayList<T>(List<T>? v, String? fieldName) {
    if (null == v) {
      ps(fieldName);
      sb.write('null');
      sb.write('\n');
      return this;
    } else {
      for (var item in v) {
        display(item, fieldName);
      }

      return this;
    }
  }

  TarsDisplayer DisplayTarsStruct(TarsStruct? v, String? fieldName) {
    display('{', fieldName);
    if (null == v) {
      sb.write('\t');
      sb.write('null');
    } else {
      v.displayAsString(sb, _level + 1);
    }

    display('}', null);
    return this;
  }
}
