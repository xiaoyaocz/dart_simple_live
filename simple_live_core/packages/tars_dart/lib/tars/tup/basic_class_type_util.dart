class BasicClassTypeUtil {
  static String dart2UniType(String type, dynamic obj) {
    if (type == 'String') {
      return 'string';
    }
    if (type.contains('List')) {
      return 'list';
    }
    if (type.contains('Map')) {
      return 'map';
    }
    if (type == 'bool') {
      return 'bool';
    }
    // 如果是int,需要检查short/ushort/int32/uint32
    if (type == 'int') {
      if (obj is int) {
        if (obj >= -32768 && obj <= 32767) {
          return 'short';
        }
        if (obj >= 0 && obj <= 65535) {
          return 'ushort';
        }
        if (obj >= -2147483648 && obj <= 2147483647) {
          return 'int32';
        }
        if (obj >= 0 && obj <= 4294967295) {
          return 'uint32';
        }
      } else {
        return 'int32';
      }
    }
    // 检查int64/uint64
    if (type == BigInt.one.runtimeType.toString()) {
      if (obj is BigInt) {
        if (obj >= BigInt.from(-9223372036854775808) &&
            obj <= BigInt.from(9223372036854775807)) {
          return 'int64';
        }
        if (obj >= BigInt.zero && obj <= BigInt.parse('18446744073709551615')) {
          return 'uint64';
        }
      }
      return 'int64';
    }

    if (type == 'double') {
      return 'double';
    }

    return type;
  }

  /// 将嵌套的类型转成字符串
  static String transTypeList(List<String> listType) {
    var sb = StringBuffer();

    for (var i = 0; i < listType.length; i++) {
      listType[i] = dart2UniType(listType[i], null);
    }

    listType = listType.reversed.toList();

    for (var i = 0; i < listType.length; i++) {
      var type = listType[i];

      if (type == 'Null') {
        continue;
      }

      if (type == 'list') {
        listType[i - 1] = '<${listType[i - 1]}';
        listType[0] = '${listType[0]}>';
      } else if (type == 'map') {
        listType[i - 1] = '<${listType[i - 1]},';
        listType[0] = '${listType[0]}>';
      } else if (type == 'Array') {
        listType[i - 1] = '<${listType[i - 1]}';
        listType[0] = '${listType[0]}>';
      }
    }
    listType = listType.reversed.toList();

    for (var s in listType) {
      sb.write(s);
    }
    return sb.toString();
  }

  static Object? createObject(Type type) {
    if (type == String) {
      return '';
    }
    if (type == int) {
      return 0;
    }
    if (type == double) {
      return 0.0;
    }
    if (type == bool) {
      return false;
    }
    if (type == BigInt) {
      return BigInt.zero;
    }
    if (type == List) {
      return <dynamic>[];
    }
    if (type == Map) {
      return <dynamic, dynamic>{};
    }
    return null;
  }

  static T createObjectT<T>() {
    if (T == String) {
      return '' as T;
    }
    if (T == int) {
      return 0 as T;
    }
    if (T == double) {
      return 0.0 as T;
    }
    if (T == bool) {
      return false as T;
    }
    if (T == BigInt) {
      return BigInt.zero as T;
    }
    if (T == List) {
      return <dynamic>[] as T;
    }
    if (T == Map) {
      return <dynamic, dynamic>{} as T;
    }
    return null as T;
  }
}
