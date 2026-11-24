import 'dart:convert';

class LiveContributionRankItem {
  final int rank;
  final String userName;
  final String avatar;
  final String scoreText;
  final String? scoreDetail;
  final int? userLevel;
  final String? userLevelText;
  final String? userLevelIcon;
  final int? fansLevel;
  final String? fansName;
  final String? fansIcon;

  LiveContributionRankItem({
    required this.rank,
    required this.userName,
    required this.avatar,
    required this.scoreText,
    this.scoreDetail,
    this.userLevel,
    this.userLevelText,
    this.userLevelIcon,
    this.fansLevel,
    this.fansName,
    this.fansIcon,
  });

  @override
  String toString() {
    return jsonEncode({
      "rank": rank,
      "userName": userName,
      "avatar": avatar,
      "scoreText": scoreText,
      "scoreDetail": scoreDetail,
      "userLevel": userLevel,
      "userLevelText": userLevelText,
      "userLevelIcon": userLevelIcon,
      "fansLevel": fansLevel,
      "fansName": fansName,
      "fansIcon": fansIcon,
    });
  }
}
