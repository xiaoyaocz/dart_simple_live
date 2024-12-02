// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:core';
import 'dart:typed_data';

import 'package:tars_dart/tars/tup/basic_class_type_util.dart';

import '/tars/codec/tars_input_stream.dart';
import '/tars/codec/tars_output_stream.dart';
import '/tars/codec/tars_struct.dart';
import 'const.dart';
import 'object_create_exception.dart';

class UniAttribute extends TarsStruct {
  /// 精简版tup，PACKET_TYPE_TUP3类型
  Map<String, Uint8List> newData = {};

  //PACKET_TYPE_TUP类型
  Map<String, Map<String, Uint8List>> oldData = {};

  /// 存储get后的数据 避免多次解析
  Map<String, Object> cachedData = <String, Object>{};

  int version = Const.PACKET_TYPE_TUP;
  String encodeName = 'UTF-8';

  final TarsInputStream _is = TarsInputStream(null);

  /// 清除缓存的解析过的数据
  void clearCacheData() {
    cachedData.clear();
  }

  bool isEmpty() {
    if (version == Const.PACKET_TYPE_TUP3) {
      return newData.isEmpty;
    } else {
      return oldData.isEmpty;
    }
  }

  int get length {
    if (version == Const.PACKET_TYPE_TUP3) {
      return newData.length;
    } else {
      return oldData.length;
    }
  }

  bool containsKey(String key) {
    if (version == Const.PACKET_TYPE_TUP3) {
      return newData.containsKey(key);
    } else {
      return oldData.containsKey(key);
    }
  }

  /// 放入一个元素
  /// @param <T>
  /// @param name
  /// @param t
  void put<T>(String name, T t) {
    if (name.isEmpty) {
      throw ArgumentError("put key can not is null");
    }
    if (t == null) {
      throw ArgumentError("put value can not is null");
    }

    TarsOutputStream _out = TarsOutputStream();
    _out.setServerEncoding(encodeName);
    _out.write(t, 0);
    Uint8List sBuffer = _out.toUint8List();

    if (version == Const.PACKET_TYPE_TUP3) {
      cachedData.remove(name);

      if (newData.containsKey(name)) {
        newData[name] = sBuffer;
      } else {
        newData[name] = sBuffer;
      }
    } else {
      var listType = <String>[];
      checkObjectType(listType, t);
      var className = BasicClassTypeUtil.transTypeList(listType);

      var pair = <String, Uint8List>{};
      pair[className] = sBuffer;
      cachedData.remove(name);
      oldData[name] = pair;
    }
  }

  void checkObjectType(List<String> listType, dynamic o) {
    if (o == null) {
      throw Exception('object is null');
    }

    if (o is List) {
      listType.add('list');
      if (o.isNotEmpty) {
        checkObjectType(listType, o[0]);
      } else {
        listType.add('?');
      }
    } else if (o is Map) {
      listType.add('map');
      if (o.isNotEmpty) {
        var key = o.keys.first;
        listType.add(
            BasicClassTypeUtil.dart2UniType(key.runtimeType.toString(), key));
        checkObjectType(listType, o[key]);
      } else {
        listType.add('?');
        listType.add('?');
        // throw ArgumentError("map cannot be empty");
      }
    } else if (o is Iterable) {
      listType.add('list');
      // 如果是Iterable但不是List，可以处理其他类型的集合
      var iterator = o.iterator;
      if (iterator.moveNext()) {
        checkObjectType(listType, iterator.current);
      } else {
        listType.add('?');
      }
    } else {
      listType
          .add(BasicClassTypeUtil.dart2UniType(o.runtimeType.toString(), o));
    }
  }

  Object decodeData(Uint8List data, Object? proxy) {
    _is.wrap(data);
    _is.setServerEncoding(encodeName);
    Object o = _is.read(proxy, 0, true);
    return o;
  }

  /// 获取tup精简版本编码的数据,兼容旧版本tup
  /// @param <T>
  /// @param name
  /// @param proxy
  /// @return
  /// @throws ObjectCreateException
  T getByClass<T>(String name, T proxy) {
    Object? obj;
    if (version == Const.PACKET_TYPE_TUP3) {
      if (!newData.containsKey(name)) {
        return obj as T;
      } else if (cachedData.containsKey(name)) {
        obj = cachedData[name];
        return obj as T;
      } else {
        try {
          Uint8List data = newData[name] as Uint8List;
          Object o = decodeData(data, proxy!);
          saveDataCache(name, o);
          return o as T;
        } catch (ex) {
          throw ObjectCreateException(ex.toString());
        }
      }
    } else {
      //兼容tup2
      return get2<T>(name);
    }
  }

  // 获取一个元素,只能用于tup版本2，如果待获取的数据为tup3，则抛异常
  T get2<T>(String name, {T? proxy}) {
    if (version == Const.PACKET_TYPE_TUP3) {
      throw Exception('data is not in tup2 format');
    }

    if (cachedData.containsKey(name)) {
      return cachedData[name] as T;
    }

    if (!oldData.containsKey(name)) {
      return null as T;
    }

    var data = oldData[name]!;
    var className = data.keys.first;
    var sBuffer = data[className]!;
    var o = decodeData(sBuffer, proxy);
    saveDataCache(name, o);
    return o as T;
  }

  /// 获取一个元素,tup新旧版本都兼容
  /// @param Name
  /// @param DefaultObj
  /// @return
  /// @throws ObjectCreateException
  T get<T>(String name, T defaultObj) {
    try {
      Object? result;
      if (version == Const.PACKET_TYPE_TUP3) {
        result = getByClass<T>(name, defaultObj);
      } else {
        //tup2
        return get2(name, proxy: defaultObj);
      }
      if (result == null) {
        return defaultObj;
      }
      return result as T;
    } catch (ex) {
      return defaultObj;
    }
  }

  void saveDataCache(String name, Object o) {
    cachedData[name] = o;
  }

  Uint8List encode() {
    TarsOutputStream _os = TarsOutputStream();
    _os.setServerEncoding(encodeName);
    if (version == Const.PACKET_TYPE_TUP3) {
      _os.write(newData, 0);
    } else {
      _os.write(oldData, 0);
    }
    return _os.toUint8List();
  }

  void decode(Uint8List buffer, {int index = 0}) {
    //try tup3
    try {
      _is.wrap(buffer, pos: index);
      _is.setServerEncoding(encodeName);
      version = Const.PACKET_TYPE_TUP;
      oldData = _is.readMapMap<String, String, Uint8List>(oldData, 0, false);
    } catch (ex) {
      version = Const.PACKET_TYPE_TUP3;
      _is.wrap(buffer, pos: index);
      _is.setServerEncoding(encodeName);

      newData = _is.readMap<String, Uint8List>({
        "": Uint8List.fromList([0x0])
      }, 0, false);
    }
  }

  @override
  void writeTo(TarsOutputStream _os) {
    if (version == Const.PACKET_TYPE_TUP3) {
      _os.write(newData, 0);
    } else {
      _os.write(oldData, 0);
    }
  }

  @override
  void readFrom(TarsInputStream _is) {
    if (version == Const.PACKET_TYPE_TUP3) {
      newData = {
        "": Uint8List.fromList([0x0])
      };
      _is.readMap<String, Uint8List>(newData, 0, false);
    } else {
      oldData = _is.readMapMap<String, String, Uint8List>(oldData, 0, false);
    }
  }

  @override
  Object deepCopy() {
    throw UnimplementedError();
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    throw UnimplementedError();
  }
}
