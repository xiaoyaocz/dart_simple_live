import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';
import 'package:simple_live_app/app/log.dart';

class WebDAVController extends BaseController {
  Future<bool> showOverlayDialog() async {
    var overlay = await Utils.showAlertDialog(
      "是否覆盖当前数据？",
      title: "数据覆盖",
      confirm: "覆盖",
      cancel: "不覆盖",
    );
    return overlay;
  }

  var webdavAct = "".obs;
  var webdavPsd = "";
  var webdavLink = "";

  @override
  void onInit() {
    webdavAct.value = LocalStorageService.instance
        .getValue(LocalStorageService.kWebdavAct, "");
    webdavPsd = LocalStorageService.instance
        .getValue(LocalStorageService.kWebdavPsd, "");
    webdavLink = LocalStorageService.instance
        .getValue(LocalStorageService.kWebdavLink, "");
    SmartDialog.showToast("账号信息：${webdavAct.value}$webdavLink");
    super.onInit();
  }

  void setActInfo(String act) {
    webdavAct.value = act;
    LocalStorageService.instance
        .setValue(LocalStorageService.kWebdavAct, webdavAct.value);
  }

  void setPsdInfo(String psd) {
    webdavPsd = psd;
    LocalStorageService.instance
        .setValue(LocalStorageService.kWebdavPsd, webdavPsd);
  }

  void setLinkInfo(String link) {
    webdavLink = link;
    LocalStorageService.instance
        .setValue(LocalStorageService.kWebdavLink, webdavLink);
  }

  void deleteWebDAVAccount() {
    webdavAct.value = "";
    webdavPsd = "";
    webdavLink = "";
    LocalStorageService.instance
        .setValue(LocalStorageService.kWebdavAct, webdavAct);
    LocalStorageService.instance
        .setValue(LocalStorageService.kWebdavPsd, webdavPsd);
    LocalStorageService.instance
        .setValue(LocalStorageService.kWebdavLink, webdavLink);
  }

  void sendFavoritesToWebDAV() async {
    if (webdavAct.isEmpty || webdavPsd.isEmpty || webdavLink.isEmpty) {
      SmartDialog.showToast("请先登录WebDAV账号");
      return;
    }
    SmartDialog.showToast("开始同步");
    // 同步
    var users = DBService.instance.getFollowList();
    var data = json.encode(users.map((e) => e.toJson()).toList());
    var helper = WebDavHelper(webdavLink, webdavAct.value, webdavPsd);
    await helper.checkAndCreateFolder();
    var follow = {
      "follow": data,
    };
    var send = await helper.uploadJsonToWebDav(jsonEncode(follow));
    if (!send) {
      SmartDialog.showToast("同步失败");
      return;
    }
    SmartDialog.showToast("同步成功");
  }

  void getFavoritesFromWebDAV() async {
    if (webdavAct.isEmpty || webdavPsd.isEmpty || webdavLink.isEmpty) {
      SmartDialog.showToast("请先登录WebDAV账号");
      return;
    }
    SmartDialog.showToast("开始同步$webdavLink${webdavAct.value}");
    //  同步
    var helper = WebDavHelper(webdavLink, webdavAct.value, webdavPsd);
    var jsonData = await helper.downloadFileToTempAndReadJson();
    if (jsonData == null) {
      SmartDialog.showToast("同步失败");
      return;
    }
    var overlay = await showOverlayDialog();
    if (overlay) {
      await DBService.instance.followBox.clear();
    }
    var jsonBody = jsonDecode(jsonData["follow"]);
    for (var item in jsonBody) {
      var user = FollowUser.fromJson(item);
      await DBService.instance.followBox.put(user.id, user);
    }
    SmartDialog.showToast('已同步关注用户列表');
    EventBus.instance.emit(Constant.kUpdateFollow, 0);
    SmartDialog.showToast("已同步关注列表");
  }
}

class WebDavHelper {
  final String webdavLink;
  final String webdavAct;
  final String webdavPsd;
  final String folderPath = 'simple_live/';
  final String filePath = 'simple_live/favorite.json';
  WebDavHelper(this.webdavLink, this.webdavAct, this.webdavPsd);
  Future<void> checkAndCreateFolder() async {
    var client = http.Client();
    try {
      var exists = await checkExistsOnWebDav(
          webdavLink, folderPath, webdavAct, webdavPsd);
      if (exists) {
        var exists1 = await checkExistsOnWebDav(
            webdavLink, filePath, webdavAct, webdavPsd);
        if (exists1) {
          await deleteFileOnWebDav(webdavLink, filePath, webdavAct, webdavPsd);
        }
      } else {
        await createWebDavFolder(folderPath);
      }
    } catch (e) {
      Log.d('Exception: $e');
    } finally {
      client.close();
    }
  }

  Future<bool> checkExistsOnWebDav(String webdavLink, String path,
      String webdavAct, String webdavPsd) async {
    var client = http.Client();
    try {
      var url = Uri.parse('$webdavLink$path');
      var headers = {
        'Content-Type': 'text/xml',
        'Depth': '0',
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$webdavAct:$webdavPsd'))}',
      };
      var response = await client.send(
        http.Request('PROPFIND', url)..headers.addAll(headers),
      );
      return response.statusCode == 207; // 207 Multi-Status 表示存在
    } catch (e) {
      // print('Exception: $e');
      return false;
    } finally {
      client.close();
    }
  }

  Future<bool> deleteFileOnWebDav(String webdavLink, String filePath,
      String webdavAct, String webdavPsd) async {
    var client = http.Client();
    try {
      var url = Uri.parse('$webdavLink$filePath');
      var headers = {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$webdavAct:$webdavPsd'))}',
      };
      var response = await client.delete(url, headers: headers);
      return response.statusCode == 204; // 204 No Content 表示删除成功
    } catch (e) {
      Log.d('Exception: $e');
      return false;
    } finally {
      client.close();
    }
  }

  Future<void> createWebDavFolder(String folderPath) async {
    var client = http.Client();
    try {
      var url = Uri.parse('$webdavLink$folderPath');
      var headers = {
        'Content-Type': 'text/xml',
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$webdavAct:$webdavPsd'))}',
      };
      var request = http.Request('MKCOL', url)..headers.addAll(headers);
      var response = await client.send(request);
      if (response.statusCode == 201) {
        Log.d('Folder created successfully.');
      } else {
        Log.d('Failed to create folder. Status code: ${response.statusCode}');
      }
    } catch (e) {
      Log.d('Exception: $e');
    } finally {
      client.close();
    }
  }

  Future<bool> uploadJsonToWebDav(String jsonData) async {
    try {
      // 获取应用程序文档目录
      final directory = await getApplicationDocumentsDirectory();
      // 创建一个临时文件路径
      final tempFilePath = '${directory.path}/temp.json';
      // 创建一个临时文件来存储 JSON 数据
      File tempFile = File(tempFilePath);
      await tempFile.writeAsString(jsonData);
      // 调用上传函数
      await uploadFileToWebDav(
          webdavLink, filePath, webdavAct, webdavPsd, tempFile);
      // 上传完成后删除临时文件
      await tempFile.delete();
      return true; // 上传成功
    } catch (e) {
      // print('Exception: $e');
      return false; // 上传失败
    }
  }

  Future<void> uploadFileToWebDav(String webdavLink, String filePath,
      String webdavAct, String webdavPsd, File file) async {
    var client = http.Client();
    try {
      var url = Uri.parse('$webdavLink$filePath');
      // https://dav.jianguoyun.com/dav/hhrm_tools/temp.json
      var headers = {
        'Content-Type': 'application/octet-stream',
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$webdavAct:$webdavPsd'))}',
      };
      var request = http.Request('PUT', url)
        ..headers.addAll(headers)
        ..bodyBytes = await file.readAsBytes();
      var response = await client.send(request);
      if (response.statusCode == 201 ||
          response.statusCode == 200 ||
          response.statusCode == 204) {
        // 代码 204，提示已有文件，但是仍会上传，顶替已有文件
        Log.d('File uploaded successfully.');
      } else {
        Log.d('Failed to upload file. Status code: ${response.statusCode}');
      }
    } catch (e) {
      Log.d('Exception: $e');
    } finally {
      client.close();
    }
  }

  Future<dynamic> downloadFileToTempAndReadJson() async {
    var client = http.Client();
    try {
      // 构建请求 URL 和头部
      var url = Uri.parse('$webdavLink$filePath');
      var exists1 =
          await checkExistsOnWebDav(webdavLink, filePath, webdavAct, webdavPsd);
      if (!exists1) {
        Log.d('File not exists.');
        return null;
      }
      var headers = {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$webdavAct:$webdavPsd'))}',
      };
      // 发送 GET 请求下载文件
      var response = await client.get(url, headers: headers);
      if (response.statusCode == 200) {
        // 获取临时目录
        var tempDir = await getTemporaryDirectory();
        var tempFile = File('${tempDir.path}/temp_download.json');
        // 将响应体写入临时文件
        await tempFile.writeAsBytes(response.bodyBytes);
        // 读取临时文件内容到 JSON
        String content = await tempFile.readAsString();
        Log.d('Response content: $content');

        try {
          var jsonData = jsonDecode(content);
          // 删除临时文件
          await tempFile.delete();
          return jsonData;
        } catch (e) {
          Log.d('Failed to parse JSON. Exception: $e');
          return null;
        }
      } else {
        Log.d('Failed to download file. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      Log.d('Exception: $e');
      return null;
    } finally {
      client.close();
    }
  }
}
