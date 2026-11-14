class FollowRefreshScope {
  final String scopeKey;
  final bool includeAllNormals;
  final bool automatic;
  final bool allowBackgroundSpecials;
  final String stage;
  final String backgroundStage;

  const FollowRefreshScope({
    required this.scopeKey,
    required this.includeAllNormals,
    required this.automatic,
    required this.allowBackgroundSpecials,
    required this.stage,
    required this.backgroundStage,
  });

  const FollowRefreshScope.all({bool automatic = false})
    : this(
        scopeKey: "all",
        includeAllNormals: true,
        automatic: automatic,
        allowBackgroundSpecials: false,
        stage: "正在刷新关注状态",
        backgroundStage: "",
      );

  const FollowRefreshScope.page({
    required String scopeKey,
    bool automatic = false,
  }) : this(
         scopeKey: scopeKey,
         includeAllNormals: false,
         automatic: automatic,
         allowBackgroundSpecials: true,
         stage: "正在刷新关注状态",
         backgroundStage: "当前页已完成，后台补充特别关注",
       );

  FollowRefreshScope.tag({
    required String tagId,
    required String tagName,
    bool automatic = false,
  }) : this(
         scopeKey: "tag:$tagId",
         includeAllNormals: true,
         automatic: automatic,
         allowBackgroundSpecials: false,
         stage: "正在刷新标签「$tagName」",
         backgroundStage: "",
       );
}
