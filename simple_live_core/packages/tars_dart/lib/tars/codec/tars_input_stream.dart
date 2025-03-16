import 'dart:convert';
import 'dart:core';
import 'dart:typed_data';

import 'tars_struct.dart';
import 'tars_decode_exception.dart';

class HeadData {
  int type = 0;
  int tag = 0;

  void clear() {
    type = 0;
    tag = 0;
  }
}

class BinaryReader {
  Uint8List buffer;
  int position = 0;

  BinaryReader(this.buffer);

  int get length => buffer.length;

  /// 从当前流中读取下一个字节，并使流的当前位置提升 1 个字节
  /// 返回下一个字节(0-255)
  int read() {
    var byte = buffer[position];
    position += 1;
    return byte;
  }

  /// 从当前流中读取指定长度的字节整数，并使流的当前位置提升指定长度。
  /// [len] 指定长度
  /// len=1为int8,2为int16,4为int32,8为int64。dart中统一为int类型
  /// 返回整数
  int readInt(int len) {
    var result = 0;
    // if (len == 1) {
    //   result = buffer[position];
    //   position += len;
    //   return result;
    // }
    var bytes =
        Uint8List.fromList(buffer.getRange(position, position + len).toList());
    var byteBuffer = bytes.buffer;
    var data = ByteData.view(byteBuffer);
    if (len == 1) {
      result = data.getUint8(0);
    }
    if (len == 2) {
      result = data.getInt16(0, Endian.big);
    }
    if (len == 4) {
      result = data.getInt32(0, Endian.big);
    }
    if (len == 8) {
      result = data.getInt64(0, Endian.big);
    }
    position += len;
    return result;
  }

  /// 从当前流中读取指定长度的字节数组，并使流的当前位置提升指定长度。
  /// [len] 指定长度
  /// 返回字节数组
  Uint8List readBytes(int len) {
    var bytes =
        Uint8List.fromList(buffer.getRange(position, position + len).toList());
    position += len;
    return bytes;
  }

  /// 从当前流中读取指定长度的字节浮点数，并使流的当前位置提升指定长度。
  /// [len] 指定长度
  /// len=4为float,8为double。dart中统一为double类型
  /// 返回浮点数
  double readFloat(int len) {
    var result = 0.0;
    var bytes =
        Uint8List.fromList(buffer.getRange(position, position + len).toList());
    var byteBuffer = bytes.buffer;
    var data = ByteData.view(byteBuffer);
    if (len == 4) {
      result = data.getFloat32(0, Endian.big);
    }
    if (len == 8) {
      result = data.getFloat64(0, Endian.big);
    }
    position += len;
    return result;
  }
}

class TarsInputStream {
  late BinaryReader br;

  TarsInputStream(Uint8List? bytes, {int pos = 0}) {
    if (bytes != null) {
      br = BinaryReader(bytes);
      br.position = pos;
    }
  }

  void wrap(Uint8List bytes, {int pos = 0}) {
    br = BinaryReader(bytes);
    br.position = pos;
  }

  static int readBinaryReaderHead(HeadData hd, BinaryReader bb) {
    if (bb.position >= bb.length) {
      throw TarsDecodeException('read file to end');
    }
    var b = bb.read();
    hd.type = (b & 15);
    hd.tag = ((b & (15 << 4)) >> 4);
    if (hd.tag == 15) {
      hd.tag = bb.read();
      return 2;
    }
    return 1;
  }

  int readHead(HeadData hd) {
    return readBinaryReaderHead(hd, br);
  }

  int peakHead(HeadData hd) {
    var curPos = br.position;
    var len = readHead(hd);
    br.position = curPos;
    return len;
  }

  void skip(int len) {
    br.position += len;
  }

  bool skipToTag(int tag) {
    try {
      var hd = HeadData();
      while (true) {
        var len = peakHead(hd);
        if (tag <= hd.tag || hd.type == TarsStructType.STRUCT_END.index) {
          return tag == hd.tag;
        }

        skip(len);
        skipFieldWithType(hd.type);
      }
    } catch (e) {
      if (e is TarsDecodeException) {
        print(e);
      }
      print(e);
    }
    return false;
  }

  // 跳到当前结构的结束位置
  void skipToStructEnd() {
    var hd = HeadData();
    do {
      readHead(hd);
      skipFieldWithType(hd.type);
    } while (hd.type != TarsStructType.STRUCT_END.index);
  }

  // 跳过一个字段
  void skipField() {
    var hd = HeadData();
    readHead(hd);
    skipFieldWithType(hd.type);
  }

  void skipFieldWithType(int type) {
    var t = TarsStructType.values[type];
    switch (t) {
      case TarsStructType.BYTE:
        skip(1);
        break;
      case TarsStructType.SHORT:
        skip(2);
        break;
      case TarsStructType.INT:
        skip(4);
        break;
      case TarsStructType.LONG:
        skip(8);
        break;
      case TarsStructType.FLOAT:
        skip(4);
        break;
      case TarsStructType.DOUBLE:
        skip(8);
        break;
      case TarsStructType.STRING1:
        {
          var len = br.read();
          if (len < 0) {
            len += 256;
          }
          skip(len);
          break;
        }
      case TarsStructType.STRING4:
        {
          skip(br.readInt(4));
          break;
        }
      case TarsStructType.MAP:
        {
          var size = readInt(0, true);
          for (var i = 0; i < size * 2; ++i) {
            skipField();
          }
          break;
        }
      case TarsStructType.LIST:
        {
          var size = readInt(0, true);
          for (var i = 0; i < size; ++i) {
            skipField();
          }
          break;
        }
      case TarsStructType.SIMPLE_LIST:
        {
          var hd = HeadData();
          readHead(hd);
          if (hd.type != TarsStructType.BYTE.index) {
            throw TarsDecodeException(
                'skipField with invalid type, type value: $type,${hd.type}');
          }
          var size = readInt(0, true);
          skip(size);
          break;
        }
      case TarsStructType.STRUCT_BEGIN:
        skipToStructEnd();
        break;
      case TarsStructType.STRUCT_END:
      case TarsStructType.ZERO_TAG:
        break;
    }
  }

  dynamic read<T>(dynamic data, int tag, bool isRequire) {
    if (data is int || data == int) {
      data = readInt(tag, isRequire);
    } else if (data is double || data == double) {
      data = readFloat(tag, isRequire);
    } else if (data is bool || data == bool) {
      data = readBool(tag, isRequire);
    } else if (data is Uint8List || data == Uint8List) {
      data = readBytes(tag, isRequire);
    } else if (data is String || data == String) {
      data = readString(tag, isRequire);
    } else if (data is List || data == List) {
      data = readList<T>(data, tag, isRequire);
    } else if (data is Map || data == Map) {
      data = readMap(data, tag, isRequire);
    } else if (data is TarsStruct || data == TarsStruct) {
      data = readTarsStruct(data, tag, isRequire);
    } else {
      throw TarsDecodeException('type:${data.runtimeType} not supported.');
    }
    return data;
  }

  /// 读取整数
  /// 对应Tars类型：int1、int2、int4、int8
  int readInt(int tag, bool isRequire) {
    var n = 0;
    if (skipToTag(tag)) {
      var hd = HeadData();
      readHead(hd);
      var t = TarsStructType.values[hd.type];
      switch (t) {
        case TarsStructType.ZERO_TAG:
          n = 0;
          break;
        case TarsStructType.BYTE:
          n = br.readInt(1);
          break;
        case TarsStructType.SHORT:
          n = br.readInt(2);
          break;
        case TarsStructType.INT:
          n = br.readInt(4);
          break;
        case TarsStructType.LONG:
          n = br.readInt(8);
          break;
        default:
          throw TarsDecodeException('type mismatch.');
      }
    } else if (isRequire) {
      throw TarsDecodeException('require field not exist.');
    }
    return n;
  }

  /// 读取bool
  /// 对应Tars类型：int1
  bool readBool(int tag, bool isRequire) {
    return readInt(tag, isRequire) != 0;
  }

  /// 读取单字char
  /// 对应Tars类型：int
  String readChar(int tag, bool isRequire) {
    var char = readInt(tag, isRequire);
    return String.fromCharCode(char);
  }

  /// 读取字符串
  /// 对应Tars类型：string1、string4
  String readString(int tag, bool isRequire) {
    var n = '';
    if (skipToTag(tag)) {
      var hd = HeadData();
      readHead(hd);
      var t = TarsStructType.values[hd.type];
      switch (t) {
        case TarsStructType.STRING1:
          n = _readString1();
          break;
        case TarsStructType.STRING4:
          n = _readString4();
          break;

        default:
          throw TarsDecodeException('type mismatch.');
      }
    } else if (isRequire) {
      throw TarsDecodeException('require field not exist.');
    }
    return n;
  }

  String _readString1() {
    var len = 0;
    len = br.readInt(1);
    if (len < 0) {
      len += 256;
    }

    var ss = br.readBytes(len);

    return utf8.decode(ss);
  }

  String _readString4() {
    var len = 0;
    len = br.readInt(4);
    if (len > TarsStruct.TARS_MAX_STRING_LENGTH || len < 0) {
      throw TarsDecodeException('string too long: $len');
    }

    var ss = br.readBytes(len);

    return utf8.decode(ss);
  }

  /// 读取浮点数
  /// 对应Tars类型：double、float
  double readFloat(int tag, bool isRequire) {
    var n = 0.0;
    if (skipToTag(tag)) {
      var hd = HeadData();
      readHead(hd);
      var t = TarsStructType.values[hd.type];
      switch (t) {
        case TarsStructType.ZERO_TAG:
          n = 0;
          break;
        case TarsStructType.FLOAT:
          {
            n = br.readFloat(4);
          }
          break;
        case TarsStructType.DOUBLE:
          {
            n = br.readFloat(8);
          }
          break;
        default:
          throw TarsDecodeException('type mismatch.');
      }
    } else if (isRequire) {
      throw TarsDecodeException('require field not exist.');
    }
    return n;
  }

  /// 读取byte[]
  /// 对应Tars类型：SimpleList
  Uint8List readBytes(int tag, bool isRequire) {
    var lr = Uint8List(0);
    if (skipToTag(tag)) {
      var hd = HeadData();
      readHead(hd);
      var t = TarsStructType.values[hd.type];
      switch (t) {
        case TarsStructType.SIMPLE_LIST:
          {
            var hh = HeadData();
            readHead(hh);
            if (hh.type != TarsStructType.BYTE.index) {
              throw TarsDecodeException(
                  'type mismatch, tag: $tag,type:${hd.type},${hh.type}');
            }
            var size = readInt(0, true);
            if (size < 0) {
              throw TarsDecodeException(
                  'invalid size, tag: $tag, type: ${hd.type}, ${hh.type}  size:$size');
            }

            lr = Uint8List(size);
            try {
              lr = br.readBytes(size);
            } catch (e) {
              //QTrace.Trace(e.Message);
              print(e);
              return Uint8List(0);
            }
          }
          break;
        case TarsStructType.LIST:
          {
            var size = readInt(0, true);
            if (size < 0) throw TarsDecodeException('size invalid: $size');
            lr = Uint8List(size);
            for (var i = 0; i < size; ++i) {
              lr[i] = readInt(0, true);
            }
          }
          break;
        default:
          throw TarsDecodeException('type mismatch.');
      }
    } else if (isRequire) {
      throw TarsDecodeException('require field not exist.');
    }
    return lr;
  }

  /// 读取Map
  /// 需要指定键、值的类型
  /// 对应Tars类型：Map
  Map<K, V> readMap<K, V>(Map<K, V> data, int tag, bool isRequire) {
    Iterable<MapEntry<K, V>> it = data.entries;
    MapEntry<K, V> en = it.first;
    K k = en.key;
    V v = en.value;
    Map<K, V> map = <K, V>{};

    if (skipToTag(tag)) {
      var hd = HeadData();
      readHead(hd);
      var t = TarsStructType.values[hd.type];
      if (t == TarsStructType.MAP) {
        var size = readInt(0, true);
        if (size < 0) {
          throw TarsDecodeException('size invalid:$size');
        }
        for (var i = 0; i < size; ++i) {
          var mk = read(k, 0, true);
          var mv = read(v, 1, true);
          if (mk != null) {
            if (map.containsKey(mk)) {
              map[mk] = mv;
            } else {
              map.addAll({mk: mv});
            }
          }
        }
      } else {
        throw TarsDecodeException('type mismatch.');
      }
    } else if (isRequire) {
      throw TarsDecodeException('require field not exist.');
    }
    return map;
  }

  /// 读取 k list<V> 结构 Map
  /// 需要指定键、list值的类型
  /// 对应Tars类型：Map
  Map<K, List<V>> readMapList<K, V>(
      Map<K, List<V>> source, int tag, bool isRequire) {
    var map = <K, List<V>>{};
    Iterable<MapEntry<K, List<V>>> it = source.entries;
    MapEntry<K, List<V>> en = it.first;
    K k = en.key;
    List<V> v = en.value;
    if (skipToTag(tag)) {
      var hd = HeadData();
      readHead(hd);
      var t = TarsStructType.values[hd.type];
      if (t == TarsStructType.MAP) {
        var size = readInt(0, true);
        if (size < 0) {
          throw TarsDecodeException('size invalid:$size');
        }
        for (var i = 0; i < size; ++i) {
          var mk = read<K>(k, 0, true);
          var mv = read<V>(v, 1, true);
          if (mk != null) {
            if (map.containsKey(mk)) {
              map[mk] = mv;
            } else {
              map.addAll({mk: mv});
            }
          }
        }
      } else {
        throw TarsDecodeException('type mismatch.');
      }
    } else if (isRequire) {
      throw TarsDecodeException('require field not exist.');
    }
    return map;
  }

  /// 读取 k map<V2,V2> 结构 Map
  /// 需要指定键、子Map键值的类型
  /// 对应Tars类型：Map
  Map<K, Map<K2, V2>> readMapMap<K, K2, V2>(
      Map<K, Map<K2, V2>> source, int tag, bool isRequire) {
    var map = <K, Map<K2, V2>>{};
    Iterable<MapEntry<K, Map<K2, V2>>> it = source.entries;
    MapEntry<K, Map<K2, V2>> en = it.first;
    K k = en.key;
    Map<K2, V2> v = en.value;
    if (skipToTag(tag)) {
      var hd = HeadData();
      readHead(hd);
      var t = TarsStructType.values[hd.type];
      if (t == TarsStructType.MAP) {
        var size = readInt(0, true);
        if (size < 0) {
          throw TarsDecodeException('size invalid:$size');
        }
        for (var i = 0; i < size; ++i) {
          var mk = read<K>(k, 0, true);
          var mv = readMap<K2, V2>(v, 1, true);
          if (mk != null) {
            if (map.containsKey(mk)) {
              map[mk] = mv;
            } else {
              map.addAll({mk: mv});
            }
          }
        }
      } else {
        throw TarsDecodeException('type mismatch.');
      }
    } else if (isRequire) {
      throw TarsDecodeException('require field not exist.');
    }
    return map;
  }

  /// 读取列表
  /// 对应Tars类型：List
  List<T> readList<T>(dynamic data, int tag, bool isRequire) {
    var ls = <T>[];
    if (skipToTag(tag)) {
      var hd = HeadData();
      readHead(hd);
      var t = TarsStructType.values[hd.type];
      switch (t) {
        case TarsStructType.LIST:
          {
            var size = readInt(0, true);
            if (size < 0) throw TarsDecodeException('size invalid: $size');
            ls = <T>[];
            for (var i = 0; i < size; ++i) {
              ls.add(read(data[0], 0, true));
            }
          }
          break;
        default:
          throw TarsDecodeException('type mismatch.');
      }
    } else if (isRequire) {
      throw TarsDecodeException('require field not exist.');
    }
    return ls;
  }

  /// 读取自定义结构
  /// 对应Tars类型：TarsStruct
  TarsStruct readTarsStruct(TarsStruct ts, int tag, bool isRequire) {
    if (skipToTag(tag)) {
      var hd = HeadData();
      readHead(hd);
      var t = TarsStructType.values[hd.type];
      if (t == TarsStructType.STRUCT_BEGIN) {
        var copyTs = ts.deepCopy() as TarsStruct;
        copyTs.readFrom(this);
        skipToStructEnd();
        return copyTs;
      } else {
        throw TarsDecodeException('type mismatch.');
      }
    } else if (isRequire) {
      throw TarsDecodeException('require field not exist.');
    }
    return ts;
  }

  String sServerEncoding = "UTF-8";

  int setServerEncoding(String se) {
    sServerEncoding = se;
    return 0;
  }
}
