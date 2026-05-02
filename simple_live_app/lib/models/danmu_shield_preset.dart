class DanmuShieldPreset {
  final String name;
  final List<String> keywords;
  final List<String> users;

  const DanmuShieldPreset({
    required this.name,
    required this.keywords,
    required this.users,
  });

  Map<String, dynamic> toJson() {
    return {
      'keywords': keywords,
      'users': users,
    };
  }
}
