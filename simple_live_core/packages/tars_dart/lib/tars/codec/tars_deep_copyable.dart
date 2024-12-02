abstract class DeepCopyable {
  Object deepCopy();
}

List<T> listDeepCopy<T>(List list) {
  List<T> newList = List<T>.filled(0, list[0], growable: true);
  for (var value in list) {
    newList.add(value is Map
        ? mapDeepCopy(value)
        : value is List
            ? listDeepCopy(value)
            : value is Set
                ? setDeepCopy(value)
                : value is DeepCopyable
                    ? value.deepCopy() as T
                    : value);
  }
  return newList;
}

Set<T> setDeepCopy<T>(Set s) {
  Set<T> newSet = <T>{};
  for (var value in s) {
    newSet.add(value is Map
        ? mapDeepCopy(value)
        : value is List
            ? listDeepCopy(value)
            : value is Set
                ? setDeepCopy(value)
                : value is DeepCopyable
                    ? value.deepCopy() as T
                    : value);
  }
  return newSet;
}

Map<K, V> mapDeepCopy<K, V>(Map<K, V> map) {
  Map<K, V> newMap = <K, V>{};

  map.forEach((key, value) {
    newMap[key] = (value is Map
        ? mapDeepCopy(value)
        : value is List
            ? listDeepCopy(value)
            : value is Set
                ? setDeepCopy(value)
                : value is DeepCopyable
                    ? value.deepCopy() as V
                    : value) as V;
  });

  return newMap;
}

Map<K, List<V>> mapListDeepCopy<K, V>(Map<K, List<V>> map) {
  Map<K, List<V>> newMap = <K, List<V>>{};
  map.forEach((key, value) {
    newMap[key] = listDeepCopy<V>(value);
  });
  return newMap;
}
