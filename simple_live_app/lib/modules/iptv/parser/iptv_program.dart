/// 单档节目（XMLTV programme）
class IptvProgram {
  final String channelId;

  /// 统一为 UTC，便于跨时区比较
  final DateTime start;
  final DateTime stop;
  final String title;
  final String desc;

  const IptvProgram({
    required this.channelId,
    required this.start,
    required this.stop,
    required this.title,
    required this.desc,
  });
}

/// 一份 EPG 的全部节目，按频道 id 索引并按开播时间排序
class EpgData {
  final Map<String, List<IptvProgram>> programsByChannel;

  const EpgData(this.programsByChannel);

  List<IptvProgram> programsOf(String channelId) =>
      programsByChannel[channelId] ?? const [];

  /// 当前正在播出的节目
  IptvProgram? nowPlaying(String channelId, {DateTime? at}) {
    final now = at ?? DateTime.now().toUtc();
    return programsOf(channelId)
        .where((item) => !now.isBefore(item.start) && now.isBefore(item.stop))
        .cast<IptvProgram?>()
        .firstWhere((item) => true, orElse: () => null);
  }

  /// 当前节目之后的下一档
  IptvProgram? nextProgram(String channelId, {DateTime? at}) {
    final now = at ?? DateTime.now().toUtc();
    final list = programsOf(channelId);
    return list.cast<IptvProgram?>().firstWhere(
          (item) => item!.start.isAfter(now),
          orElse: () => null,
        );
  }
}
