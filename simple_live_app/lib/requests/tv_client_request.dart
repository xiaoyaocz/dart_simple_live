import 'package:simple_live_app/models/tv_client_info_model.dart';
import 'package:simple_live_app/requests/http_client.dart';
import 'package:simple_live_app/services/tv_service.dart';

class TVClientRequest {
  Future<TVClientInfoModel> getClientInfo(TVClinet client) async {
    var url = "http://${client.deviceIp}:${client.devicePort}/info";
    var data = await HttpClient.instance.getJson(url);

    return TVClientInfoModel.fromJson(data);
  }

  Future<bool> syncFollow(TVClinet client, dynamic body) async {
    var url = "http://${client.deviceIp}:${client.devicePort}/sync/follow";
    var data = await HttpClient.instance.postJson(
      url,
      data: body,
    );

    if (data["status"]) {
      return true;
    } else {
      throw data["message"];
    }
  }

  Future<bool> syncHistory(TVClinet client, dynamic body) async {
    var url = "http://${client.deviceIp}:${client.devicePort}/sync/history";
    var data = await HttpClient.instance.postJson(
      url,
      data: body,
    );

    if (data["status"]) {
      return true;
    } else {
      throw data["message"];
    }
  }

  Future<bool> syncBlockedWord(TVClinet client, dynamic body) async {
    var url =
        "http://${client.deviceIp}:${client.devicePort}/sync/blocked_word";
    var data = await HttpClient.instance.postJson(
      url,
      data: body,
    );

    if (data["status"]) {
      return true;
    } else {
      throw data["message"];
    }
  }

  Future<bool> syncBiliAccount(TVClinet client, String cookie) async {
    var url =
        "http://${client.deviceIp}:${client.devicePort}/sync/account/bilibili";
    var data = await HttpClient.instance.postJson(
      url,
      data: {
        "cookie": cookie,
      },
    );

    if (data["status"]) {
      return true;
    } else {
      throw data["message"];
    }
  }
}
