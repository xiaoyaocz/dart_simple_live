import 'package:simple_live_app/app/log.dart';

// 定义筛选条件之间的逻辑关系
enum LogicalOperator { and, or }

// 定义支持的筛选比较运算符
enum FilterOperator {
  equals, // ==
  notEquals, // !=
  greaterThan, // >
  lessThan, // <
  greaterThanOrEqual, // >=
  lessThanOrEqual, // <=
  contains, // 包含（用于List或String）
}

/// 表示一个单独的筛选条件。
class Condition {
  final String field;
  final FilterOperator operator;
  final dynamic value;

  /// (可选) 字段转换器
  ///
  /// 字段转换器在比较前将数据项中的原始值转换为一个`Comparable`类型。
  /// 目的对historyModel数据以非标准格式（时长字符串 "HH:MM:SS"）存储。
  ///
  /// 该函数接收来自数据项的原始值，通过转换器返回一个`Comparable`对象
  /// (例如, `Duration`, `int`, `DateTime`)。
  /// 此`Condition`的`value`字段应为相同`Comparable`类型。
  final Comparable? Function(dynamic rawValue)? comparableValueProvider;

  Condition(
    this.field,
    this.operator,
    this.value, {
    this.comparableValueProvider,
  });
}

/// 接口:标记可以被转换为Map的对象。
/// 数据模型类应该实现这个接口
abstract class Mappable {
  /// 将对象转换为Map<String, dynamic>。
  Map<String, dynamic> toMap();
}

/// (可选) 高级接口用于让模型类自定义实现筛选逻辑。
///
/// 模型实现了这个接口，`dynamicFilter` 将会调用其 `evaluate` 方法来判断条件，
/// 用于实现最高效或最特殊的比较逻辑。
abstract class Filterable {
  /// 模型自己判断是否满足某个条件。
  /// 返回 `true` 表示满足，`false` 表示不满足。
  bool evaluate(Condition condition);
}

/// 一个用于动态多条件过滤列表的工具。
///
/// 根据一组动态条件过滤一个 `Mappable` 对象列表。
///
/// 此函数采用“渐进式增强”的设计：
/// - 对于简单的模型（只实现 `Mappable`），它会自动通过 `toMap()` 进行筛选。
/// - 对于复杂的模型（额外实现了 `Filterable`），它会将筛选逻辑的控制权完全交给模型自身的 `evaluate()` 方法。
///
/// [T]: 必须是实现了 `Mappable` 接口的类型。
/// [list]: 要过滤的对象列表。
/// [conditions]: `Condition` 对象列表，定义了过滤规则。
/// [logic]: 条件间的逻辑关系 (`and` 或 `or`)。
/// [takeLast]: (可选) 从结果中获取最后N个元素。
///
/// 返回一个 `List<T>`，其中包含通过所有筛选条件的原始对象。
List<T> dynamicFilter<T extends Mappable>(
  List<T> list,
  List<Condition> conditions, {
  LogicalOperator logic = LogicalOperator.and,
  int? takeLast = 15,
}) {
  // 1. 内容筛选
  var filteredList = list.where((item) {
    if (conditions.isEmpty) {
      return true;
    }

    bool check(Condition c) {
      if (item is Filterable) {
        return (item as Filterable).evaluate(c);
      } else {
        // 使用默认逻辑
        late final Map<String, dynamic> itemMap;
        try {
          itemMap = item.toMap();
        } catch (e, s) {
          Log.e(
              "Filter:Failed to convert item to map for default filtering.", s);
          return false;
        }
        return checkConditionOnMap(itemMap, c);
      }
    }

    if (logic == LogicalOperator.and) {
      return conditions.every(check);
    } else {
      return conditions.any(check);
    }
  }).toList();

  // 2. 位置筛选
  if (takeLast != null && takeLast > 0) {
    if (takeLast >= filteredList.length) {
      return filteredList;
    }
    return filteredList.sublist(filteredList.length - takeLast);
  }

  return filteredList;
}

/// 默认的、基于Map的条件检查逻辑。
/// 当一个对象没有实现`Filterable`接口时，`dynamicFilter`会调用此函数。
bool checkConditionOnMap(Map<String, dynamic> itemMap, Condition condition) {
  if (!itemMap.containsKey(condition.field)) {
    return true;
  }

  final itemValue = itemMap[condition.field];
  final operand = condition.value;

  // 统一处理需要转换的场景
  final dynamic transformedItemValue;
  if (condition.comparableValueProvider != null) {
    transformedItemValue = condition.comparableValueProvider!(itemValue);
  } else {
    transformedItemValue = itemValue;
  }

  switch (condition.operator) {
    case FilterOperator.equals:
      return transformedItemValue == operand;
    case FilterOperator.notEquals:
      return transformedItemValue != operand;

    case FilterOperator.greaterThan:
    case FilterOperator.lessThan:
    case FilterOperator.greaterThanOrEqual:
    case FilterOperator.lessThanOrEqual:
      {
        if (transformedItemValue == null ||
            !_isComparable(transformedItemValue, operand)) {
          return false;
        }
        final comparison =
            (transformedItemValue as Comparable).compareTo(operand);

        if (condition.operator == FilterOperator.greaterThan) {
          return comparison > 0;
        }
        if (condition.operator == FilterOperator.lessThan) {
          return comparison < 0;
        }
        if (condition.operator == FilterOperator.greaterThanOrEqual) {
          return comparison >= 0;
        }
        if (condition.operator == FilterOperator.lessThanOrEqual) {
          return comparison <= 0;
        }
        return false;
      }

    case FilterOperator.contains:
      // 'contains' 通常不适用于自定义转换，它在原始值上操作
      if (itemValue is List) return itemValue.contains(operand);
      if (itemValue is String && operand is String) {
        return itemValue.contains(operand);
      }
      return false;
  }
}

/// 辅助函数，检查两个值是否是可比较的相同类型。
bool _isComparable(dynamic a, dynamic b) {
  return a is Comparable && b is Comparable && a.runtimeType == b.runtimeType;
}
