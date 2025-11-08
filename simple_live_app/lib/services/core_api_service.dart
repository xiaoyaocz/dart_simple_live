// 用于解耦simple_live_core
// 候选方案，目前项目强耦合core，需要逐步剥离
import 'package:get/get.dart';

/// api:
/// 获取All-Sites: getAllSites()->List<Site>
/// 获取平台首页推荐： site.getRecommends()->List<Room>
/// 获取平台分类：site.getCategories()->List<Category>()
/// 获取平台分类详情： site.getCategoryDetail()->List<Room>
/// 更新关注列表状态： site.roomId.getFollowLiveState()->bool
/// 获取房间详情： site.roomId.getRoomDetail()->roomDetail
/// 获取房间播放链列表：site.roomId.getRoomPlayList()->List<playList>
/// 获取房间清晰度列表： site.roomId.getRoomPlayQualities()->List<playQuality>
/// 获取房间弹幕：site.roomId.getRoomDanmaku()->websocket
/// 获取平台cookie有效性检测：site.getUserInfo("cookie")->bool
///
/// 实现逻辑：
/// 1: 命令模式-example：
/// core.api(
///   {
///     site: "bilibli",
///     roomId:"",
///     func: getRecommends,
///     func-params:{...}
///   }
/// )
///
/// 2。 builder设计-example:
/// builder
///       .setSite("douyu")
///       .setRoomId("")
///       .setFuncName("getRecommendation")
///       .getParam("limit":"50")
///       .build();
/// 均需要多重设计，部分model需要copy并实现json接口
/// 参数列表，函数列表字典
/// api字典

class CoreApiBuilder {
  String? _site;
  String? _roomId;
  String? _funcName;
  final Map<String, dynamic> _params = {};

  CoreApiBuilder();

  CoreApiBuilder site(String site) {
    _site = site;
    return this;
  }

  CoreApiBuilder room(String roomId) {
    _roomId = roomId;
    return this;
  }

  CoreApiBuilder func(String funcName) {
    _funcName = funcName;
    return this;
  }

  CoreApiBuilder param(String key, dynamic value) {
    _params[key] = value;
    return this;
  }

  CoreApiBuilder params(Map<String, dynamic> params) {
    _params.addAll(params);
    return this;
  }

  Future<Map<String, dynamic>> build() {
    if (_site == null) {
      throw Exception("site must be set.");
    }
    if (_funcName == null) {
      throw Exception("funcName must be set.");
    }

    return CoreDispatcher.dispatch(
      site: _site!,
      funcName: _funcName!,
      roomId: _roomId,
      params: _params,
    );
  }
}

class CoreDispatcher {
  static Future<Map<String, dynamic>> dispatch({
    required String site,
    required String funcName,
    String? roomId,
    Map<String, dynamic>? params,
  }) async {
    //缺少参数检查
    return {
      'site': site,
      'roomId': roomId,
      'funcName': funcName,
      'func-params': params ?? {},
    };
  }
}

class CoreApiService extends GetxService {

  CoreApiBuilder get builder => CoreApiBuilder();

  // demo
  void exampleUsage() {
    builder
        .site("bilibili")
        .func("getRecommends")
        .param("limit", 1)
        .build();
    // builder
    //     .site("douyu")
    //     .room("12345")
    //     .func("getRoomDetail")
    //     .build();
    // var res = core.api(arg=builder)
    // 参数类型选择器->json to model

    // simple_live_core 应该实现 参数解析器->统一返回json->调用端：json to model 实现解耦
    // 目的： 自建 api 或 ffi 调用
    // 该工作非必要，暂且备份为草稿
  }
}