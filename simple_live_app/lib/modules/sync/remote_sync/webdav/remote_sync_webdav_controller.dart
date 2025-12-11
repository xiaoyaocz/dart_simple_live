import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/app/utils/archive.dart';
import 'package:simple_live_app/app/utils/document.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/requests/webdav_client.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/services/migration_service.dart';

class RemoteSyncWebDAVController extends BaseController {
  // ui
  var passwordVisible = true.obs;

  // ui-用户选择是否同步
  var isSyncFollows = true.obs;
  var isSyncHistories = true.obs;
  var isSyncBlockWord = true.obs;
  var isSyncAccount = true.obs;
  var isSyncSetting = true.obs;

  late DAVClient davClient;
  var user = "--".obs;
  var lastRecoverTime = "--".obs;
  var lastUploadTime = "--".obs;
  var uri = "";
  var password = "";
  var webDavBackupDirectory = "/simple_live_app".obs;

  final _userFollowJsonName = 'SimpleLive_follows.json';
  final _userHistoriesJsonName = 'SimpleLive_histories.json';
  final _userBlockedWordJsonName = 'SimpleLive_blocked_word.json';
  final _userAccountJsonName = 'SimpleLive_bilibili_account.json';
  final _userTagsJsonName = 'SimpleLive_Tags.json';
  final _userSettingsJsonName = 'SimpleLive_Settings.json';

  @override
  void onInit() {
    doWebDAVInit();
    super.onInit();
  }

  void setWebDavBackupDirectory({required String newDirectory}) {
    if (newDirectory == webDavBackupDirectory.value) {
      return;
    }
    webDavBackupDirectory.value = newDirectory;
    LocalStorageService.instance.setValue(
      LocalStorageService.kWebDAVDirectory,
      webDavBackupDirectory.value,
    );
    // 重定义/应该单例化
    davClient = DAVClient(
      uri,
      user.value,
      password,
      webDAVDirectory: webDavBackupDirectory.value,
    );
  }

  // webDAV 逻辑
  // 初始化webDAV
  void doWebDAVInit() {
    uri = LocalStorageService.instance
        .getValue(LocalStorageService.kWebDAVUri, "");
    if (uri.isEmpty) {
      notLogin.value = true;
    } else {
      user.value = LocalStorageService.instance
          .getValue(LocalStorageService.kWebDAVUser, "");
      password = LocalStorageService.instance
          .getValue(LocalStorageService.kWebDAVPassword, "");
      webDavBackupDirectory.value = LocalStorageService.instance.getValue(
        LocalStorageService.kWebDAVDirectory,
        "/simple_live_app",
      );
      davClient = DAVClient(
        uri,
        user.value,
        password,
        webDAVDirectory: webDavBackupDirectory.value,
      );
      // 从未同步过默认为最新数据
      lastRecoverTime.value = Utils.parseTime(
        DateTime.fromMillisecondsSinceEpoch(
          LocalStorageService.instance.getValue(
            LocalStorageService.kWebDAVLastRecoverTime,
            DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );
      lastUploadTime.value = Utils.parseTime(
        DateTime.fromMillisecondsSinceEpoch(
          LocalStorageService.instance.getValue(
            LocalStorageService.kWebDAVLastUploadTime,
            DateTime.now().millisecondsSinceEpoch,
          ),
        ),
      );
      checkIsLogin();
    }
  }

  // 检查webDAV登录状态
  Future<void> checkIsLogin() async {
    try {
      // 返回登录结果
      bool value = await davClient.pingCompleter.future;
      notLogin.value = !value;
    } catch (e) {
      Log.e("$e", StackTrace.current);
      notLogin.value = true;
    }
  }

  // WebDAV登录
  void doWebDAVLogin(
      String webDAVUri, String webDAVUser, String webDAVPassword) async {
    // 确认登录
    davClient = DAVClient(webDAVUri, webDAVUser, webDAVPassword);
    await checkIsLogin();
    if (!notLogin.value) {
      // 保存到本地
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVUri, webDAVUri);
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVUser, webDAVUser);
      user.value = webDAVUser;
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVPassword, webDAVPassword);
      Get.back();
      SmartDialog.showToast("登录成功！");
    } else {
      SmartDialog.showToast("WebDAV账号密码验证失败，请重新输入！");
    }
  }

  // WebDAV登出
  @override
  Future<void> onLogout() async {
    var result = await Utils.showAlertDialog("确定要登出WebDAV账号？", title: "退出登录");
    if (result) {
      // 清除本地账号数据
      LocalStorageService.instance.setValue(LocalStorageService.kWebDAVUri, "");
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVUser, "");
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVPassword, "");
      notLogin.value = true;
    }
  }

  // webDAV上传到云端
  Future<void> doWebDAVUpload() async {
    SmartDialog.showLoading(msg: "正在上传到云端");
    _backupData().then((value) async {
      SmartDialog.dismiss();
      if (value.isNotEmpty) {
        var result = await davClient.backup(Uint8List.fromList(value));
        if (result) {
          SmartDialog.showToast("上传成功");
          DateTime uploadTime = DateTime.now();
          lastUploadTime.value = Utils.parseTime(uploadTime);
          LocalStorageService.instance.setValue(
              LocalStorageService.kWebDAVLastUploadTime,
              uploadTime.millisecondsSinceEpoch);
        } else {
          Log.e("备份失败", StackTrace.current);
          SmartDialog.showToast("上传失败");
        }
      } else {
        SmartDialog.showToast("上传失败");
      }
    });
  }

  // 备份所有数据
  Future<List<int>> _backupData() async {
    final archive = Archive();
    List<int> zipBytes = [];
    // 获取本地备份路径
    var dir = (await getApplicationSupportDirectory()).path;
    var profile = Directory(join(dir, 'backup'));
    if (!profile.existsSync()) {
      profile.createSync();
    }
    try {
      // archive.add(filepath, data_map) 会导致文件损坏
      // follows
      var userFollowList = DBService.instance.getFollowList();
      var dataFollowsMap = {
        'data': userFollowList.map((e) => e.toJson()).toList()
      };
      final userFollowJsonFile = File(join(profile.path, _userFollowJsonName));
      await userFollowJsonFile.writeAsString(jsonEncode(dataFollowsMap));
      // 用户自定义标签
      var userTagsList = DBService.instance.getFollowTagList();
      var dataTagsMap = {'data': userTagsList.map((e) => e.toJson()).toList()};
      var userTagsJsonFile = File(join(profile.path, _userTagsJsonName));
      await userTagsJsonFile.writeAsString(jsonEncode(dataTagsMap));
      // histories
      var userHistoriesList = DBService.instance.getHistories();
      var dataHistoriesMap = {
        'data': userHistoriesList.map((e) => e.toJson()).toList()
      };
      final userHistoriesJsonFile =
          File(join(profile.path, _userHistoriesJsonName));
      await userHistoriesJsonFile.writeAsString(jsonEncode(dataHistoriesMap));

      // blocked_word
      var userShieldList = AppSettingsController.instance.shieldList;
      var dataShieldListMap = {'data': userShieldList.toList()};
      final userBlockedWordJsonFile =
          File(join(profile.path, _userBlockedWordJsonName));
      await userBlockedWordJsonFile
          .writeAsString(jsonEncode(dataShieldListMap));

      // bilibili_account
      var userAccountCookieMap = {
        'data': {
          'cookie': BiliBiliAccountService.instance.cookie,
          'douyin_cookie': DouyinAccountService.instance.cookie
        }
      };
      final accountJsonFile = File(join(profile.path, _userAccountJsonName));
      await accountJsonFile.writeAsString(jsonEncode(userAccountCookieMap));
      await userTagsJsonFile.writeAsString(jsonEncode(dataTagsMap));
      // 全量备份用户设置，为修改包名无痛迁移数据做准备
      // v1.8.3 修改为按平台备份/恢复用户设置
      var settingList = LocalStorageService.instance.settingsBox.toMap();
      var dataSettingListMap = {
        "data": {
          Platform.operatingSystem: settingList,
        },
      };
      final settingJsonFile = File(join(profile.path, _userSettingsJsonName));
      await settingJsonFile.writeAsString(jsonEncode(dataSettingListMap));

      // 遍历profile路径下的所有文件压缩
      archive.addDirectoryToArchive(profile.path, profile.path);
      final zipEncoder = ZipEncoder();
      zipBytes = zipEncoder.encode(archive);
      profile.clearSync();
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("备份失败：$e");
    }
    return zipBytes;
  }

  // webDAV恢复到本地
  void doWebDAVRecovery() async {
    SmartDialog.showLoading(msg: "正在恢复到本地");
    final data = await davClient.recovery();
    final archive = await Isolate.run<Archive>(() {
      final zipDecoder = ZipDecoder();
      return zipDecoder.decodeBytes(data);
    });
    for (ArchiveFile file in archive) {
      await _recovery(file);
    }
    // 旧版本备份需要迁移
    MigrationService.migrateDataByVersion();
    SmartDialog.dismiss();
    SmartDialog.showToast('同步完成');
    DateTime recoverTime = DateTime.now();
    lastRecoverTime.value = Utils.parseTime(recoverTime);
    LocalStorageService.instance.setValue(
        LocalStorageService.kWebDAVLastRecoverTime,
        recoverTime.millisecondsSinceEpoch);
  }

  // todo: 后续迁出实现无感同步
  Future<void> _recovery(ArchiveFile file) async {
    if (file.isFile && file.name.endsWith('.json')) {
      var jsonString = utf8.decode(file.content);
      var jsonData = json.decode(jsonString)['data'];
      // 同步follows
      if (file.name == _userFollowJsonName && isSyncFollows.value) {
        // 修改为多端一致
        try {
          // 清空本地关注列表
          await DBService.instance.followBox.clear();
          for (var item in jsonData) {
            var user = FollowUser.fromJson(item);
            await DBService.instance.followBox.put(user.id, user);
          }
          Log.i('已同步关注用户列表');
        } catch (e) {
          Log.e('同步关注用户列表失败: $e', StackTrace.current);
        }
      } else if (file.name == _userHistoriesJsonName && isSyncHistories.value) {
        try {
          for (var item in jsonData) {
            var history = History.fromJson(item);
            // 完全同步机制
            await DBService.instance.addOrUpdateHistory(history);
          }
          Log.i('已同步用户观看历史记录');
        } catch (e) {
          Log.e('同步用户观看历史记录失败: $e', StackTrace.current);
        }
      } else if (file.name == _userBlockedWordJsonName &&
          isSyncBlockWord.value) {
        try {
          for (var keyword in jsonData) {
            AppSettingsController.instance.addShieldList(keyword.trim());
          }
          Log.i('已同步用户屏蔽词');
        } catch (e) {
          Log.e('同步用户屏蔽词失败:$e', StackTrace.current);
        }
      } else if (file.name == _userAccountJsonName && isSyncAccount.value) {
        try {
          var biliCookie = jsonData['cookie'];
          BiliBiliAccountService.instance.setCookie(biliCookie);
          BiliBiliAccountService.instance.loadUserInfo();
          var douyinCookie = jsonData['douyin_cookie'];
          DouyinAccountService.instance.setCookie(douyinCookie);
          DouyinAccountService.instance.loadUserInfo();
          Log.i('已同步用户平台账号');
        } catch (e) {
          Log.e('同步用户平台账号失败：$e', StackTrace.current);
        }
      } else if (file.name == _userSettingsJsonName && isSyncSetting.value) {
        try {
          var platform = Platform.operatingSystem;
          if ((jsonData as Map).containsKey(platform)) {
            jsonDecode(jsonData[platform]).forEach(
              (key, value) {
                LocalStorageService.instance.setValue(key, value);
              },
            );
          } else {
            Log.i("缺少$platform对应平台用户设置备份");
          }
          Log.i('已同步用户设置');
        } catch (e) {
          Log.e("同步用户设置失败：$e", StackTrace.current);
        }
      } else if (file.name == _userTagsJsonName && isSyncFollows.value) {
        try {
          // 标签功能和关注具有依赖关系，必须同时同步
          // 清空本地标签列表
          await DBService.instance.tagBox.clear();
          for (var item in jsonData) {
            var tag = FollowUserTag.fromJson(item);
            await DBService.instance.tagBox.put(tag.id, tag);
            // 插入之后验证
            var insertedTag = DBService.instance.tagBox.get(tag.id);
            Log.i('Inserted tag: ${insertedTag?.tag}');
          }
          Log.i('已同步用户自定义标签');
          // 确保tag同步完成后，更新关注列表
          EventBus.instance.emit(Constant.kUpdateFollow, 0);
        } catch (e) {
          Log.e('同步用户自定义标签失败:$e', StackTrace.current);
        }
      } else {
        return;
      }
    } else {
      Log.i('不是正确的文件名');
    }
  }

  // ui控制--密码可见控制
  void changePasswordVisible() {
    passwordVisible.value = !passwordVisible.value;
  }

  void changeIsSyncFollows() {
    isSyncFollows.value = !isSyncFollows.value;
  }

  void changeIsSyncHistories() {
    isSyncHistories.value = !isSyncHistories.value;
  }

  void changeIsSyncBlockWord() {
    isSyncBlockWord.value = !isSyncBlockWord.value;
  }

  void changeIsSyncAccount() {
    isSyncAccount.value = !isSyncAccount.value;
  }

  void changeIsSyncSetting() {
    isSyncSetting.value = !isSyncSetting.value;
  }
}
