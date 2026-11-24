class DanmuShieldPreset {
  final String name;
  final List<String> keywords;
  final List<String> users;
  final Map<String, List<String>> userGroups;

  const DanmuShieldPreset({
    required this.name,
    required this.keywords,
    required this.users,
    this.userGroups = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'keywords': keywords,
      'users': users,
      'userGroups': userGroups,
    };
  }
}
