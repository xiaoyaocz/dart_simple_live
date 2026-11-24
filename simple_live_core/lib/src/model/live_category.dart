import 'dart:convert';

class LiveCategory {
  final String name;
  final String id;
  final String? pic;
  final List<LiveSubCategory> children;
  LiveCategory({
    required this.id,
    required this.name,
    required this.children,
    this.pic,
  });

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "id": id,
      "pic": pic,
      "children": children.map((item) => item.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return json.encode(toJson());
  }
}

class LiveSubCategory {
  final String name;
  final String? pic;
  final String id;
  final String parentId;
  final List<LiveSubCategory> children; // 支持多级嵌套

  LiveSubCategory({
    required this.id,
    required this.name,
    required this.parentId,
    this.pic,
    this.children = const [], // 默认空列表
  });

  bool get hasChildren => children.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "id": id,
      "parentId": parentId,
      "pic": pic,
      "children": children.map((item) => item.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return json.encode(toJson());
  }
}
