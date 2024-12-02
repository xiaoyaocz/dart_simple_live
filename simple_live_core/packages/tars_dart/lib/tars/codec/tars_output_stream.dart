import 'dart:convert';
import 'dart:typed_data';

import './tars_encode_exception.dart';
import './tars_struct.dart';

class BinaryWriter {
  List<int> buffer;
  int position = 0;

  BinaryWriter(this.buffer);

  int get length => buffer.length;

  void writeBytes(Uint8List list) {
    buffer.addAll(list);
    position += list.length;
  }

  void writeInt(int value, int len) {
    var b = Uint8List(len).buffer;
    var bytes = ByteData.view(b);
    if (len == 1) {
      //写入byte
      bytes.setUint8(0, value.toUnsigned(8));
    }
    if (len == 2) {
      bytes.setInt16(0, value, Endian.big);
    }
    if (len == 4) {
      bytes.setInt32(0, value, Endian.big);
    }
    if (len == 8) {
      bytes.setInt64(0, value, Endian.big);
    }

    buffer.addAll(bytes.buffer.asUint8List());
    position += len;
  }

  void writeDouble(double value, int len) {
    var b = Uint8List(len).buffer;
    var bytes = ByteData.view(b);

    if (len == 4) {
      bytes.setFloat32(0, value, Endian.big);
    }
    if (len == 8) {
      bytes.setFloat64(0, value, Endian.big);
    }

    buffer.addAll(bytes.buffer.asUint8List());
    position += len;
  }
}

class TarsOutputStream {
  late BinaryWriter bw;

  TarsOutputStream({Uint8List? ls}) {
    if (ls != null) {
      bw = BinaryWriter(ls);
    } else {
      bw = BinaryWriter([]);
    }
  }

  void writeHead(int type, int tag) {
    if (tag < 15) {
      var b = ((tag << 4) | type);
      try {
        bw.writeInt(b, 1);
      } catch (e) {
        print(e.toString());
      }
    } else if (tag < 256) {
      try {
        var b = ((15 << 4) | type);
        {
          bw.writeInt(b, 1);
          bw.writeInt(tag, 1);
        }
      } catch (e) {
        print('${toString()} writeHead: $e');
      }
    } else {
      throw TarsEncodeException('tag is too large: $tag');
    }
  }

  void write(dynamic data, int tag) {
    if (data is int || data == int) {
      writeInt(data, tag);
    } else if (data is double || data == double) {
      writeDouble(data, tag);
    } else if (data is bool || data == bool) {
      writeBool(data, tag);
    } else if (data is Uint8List || data == Uint8List) {
      writeUint8List(data, tag);
    } else if (data is String || data == String) {
      writeString(data, tag);
    } else if (data is List || data == List) {
      writeList(data, tag);
    } else if (data is Map || data == Map) {
      writeMap(data, tag);
    } else if (data is TarsStruct || data == TarsStruct) {
      writeTarsStruct(data, tag);
    } else {
      throw TarsEncodeException('type:${data.runtimeType} not supported.');
    }
  }

  /// 写入bool
  /// 对应Tars类型：int1
  void writeBool(bool b, int tag) {
    writeByte(b ? 1 : 0, tag);
  }

  /// 写入字节
  /// 对应Tars类型：int1
  void writeByte(int b, int tag) {
    //紧跟1个字节整型数据
    if (b == 0) {
      writeHead(TarsStructType.ZERO_TAG.index, tag);
    } else {
      writeHead(TarsStructType.BYTE.index, tag);
      try {
        bw.writeInt(b, 1);
      } catch (e) {
        print(e);
      }
    }
  }

  /// 写入整数型
  /// 对应Tars类型：int1、int2、int4、int8
  void writeInt(int n, int tag) {
    //写入byte
    //紧跟1个字节整型数据
    if (n >= -128 && n <= 127) {
      writeByte(n, tag);
      return;
    }
    //int16
    //紧跟2个字节整型数据
    if (n >= -32768 && n <= 32767) {
      writeHead(TarsStructType.SHORT.index, tag);
      bw.writeInt(n, 2);
      return;
    }
    //int32
    //紧跟4个字节整型数据
    if (n >= -2147483648 && n <= 2147483647) {
      writeHead(TarsStructType.INT.index, tag);
      bw.writeInt(n, 4);
      return;
    }
    //int64
    //紧跟8个字节整型数据
    if (n >= -9223372036854775808 && n <= 9223372036854775807) {
      writeHead(TarsStructType.LONG.index, tag);
      bw.writeInt(n, 8);
      return;
    }
  }

  /// 写入浮点数
  /// 对应Tars类型：float
  void writeFloat(double n, int tag) {
    //紧跟4个字节浮点型数据
    writeHead(TarsStructType.FLOAT.index, tag);
    bw.writeDouble(n, 4);
  }

  /// 写入双精度浮点数(Double)
  /// 对应Tars类型：double
  void writeDouble(double n, int tag) {
    //紧跟8个字节浮点型数据
    writeHead(TarsStructType.DOUBLE.index, tag);
    bw.writeDouble(n, 8);
  }

  /// 写入字符串
  /// 对应Tars类型：string1、string4
  void writeString(String s, int tag) {
    //string1:紧跟1个字节长度，再跟内容
    //string4:紧跟4个字节长度，再跟内容
    var bytes = utf8.encode(s);
    if (bytes.isEmpty) {
      writeHead(TarsStructType.STRING1.index, tag);
      bw.writeInt(0, 1);
      return;
    }
    if (bytes.length > 255) {
      writeHead(TarsStructType.STRING4.index, tag);
      bw.writeInt(bytes.length, 4);
      bw.writeBytes(Uint8List.fromList(bytes));
    } else {
      writeHead(TarsStructType.STRING1.index, tag);
      bw.writeInt(bytes.length, 1);
      bw.writeBytes(Uint8List.fromList(bytes));
    }
  }

  /// 写入byte[]
  /// 对应Tars类型：SimpleList
  void writeUint8List(Uint8List ls, int tag) {
    //简单列表（目前用在byte数组），紧跟一个类型字段（目前只支持byte），紧跟一个整型数据表示长度，再跟byte数据
    writeHead(TarsStructType.SIMPLE_LIST.index, tag);
    writeHead(TarsStructType.BYTE.index, 0);
    writeInt(ls.length, 0);
    bw.writeBytes(ls);
  }

  /// 写入Map
  /// 对应Tars类型：Map
  void writeMap<K, V>(Map<K, V> map, int tag) {
    //紧跟一个整型数据表示Map的大小，再跟[key, value]对列表
    writeHead(TarsStructType.MAP.index, tag);
    writeInt(map.length, 0);
    for (var item in map.keys) {
      write(item, 0);
      write(map[item], 1);
    }
  }

  /// 写入列表
  /// 对应Tars类型：List
  void writeList(List ls, int tag) {
    //紧跟一个整型数据表示List的大小，再跟元素列表
    writeHead(TarsStructType.LIST.index, tag);
    write(ls.length, 0);
    for (var item in ls) {
      write(item, 0);
    }
  }

  /// 写入自定义结构
  /// 对应Tars类型：TarsStruct
  void writeTarsStruct(TarsStruct o, int tag) {
    writeHead(TarsStructType.STRUCT_BEGIN.index, tag);
    o.writeTo(this);
    writeHead(TarsStructType.STRUCT_END.index, 0);
  }

  Uint8List toUint8List() {
    return Uint8List.fromList(bw.buffer);
  }

  String sServerEncoding = "UTF-8";

  int setServerEncoding(String se) {
    sServerEncoding = se;
    return 0;
  }
}
