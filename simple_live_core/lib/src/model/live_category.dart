class LiveCategory {
  final String name;
  final String id;
  final List<LiveSubCategory> children;
  LiveCategory({
    required this.id,
    required this.name,
    required this.children,
  });
}

class LiveSubCategory {
  final String name;
  final String? pic;
  final String id;
  final String parentId;
  LiveSubCategory({
    required this.id,
    required this.name,
    required this.parentId,
    this.pic,
  });
}
