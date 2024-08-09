import 'dart:async';
import 'dart:io';

import 'package:signalr_netcore/signalr_client.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';

enum SignalRConnectionState {
  connecting,
  connected,
  disconnected,
}

class SignalRService {
  static const String kUrl = "https://sync1.nsapps.cn/sync";

  SignalRConnectionState state = SignalRConnectionState.connecting;

  final _stateStreamController =
      StreamController<SignalRConnectionState>.broadcast();
  Stream<SignalRConnectionState> get stateStream =>
      _stateStreamController.stream;

  final _onFavoriteStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onFavoriteStream =>
      _onFavoriteStreamController.stream;

  final _onHistoryStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onHistoryStream =>
      _onHistoryStreamController.stream;

  final _onShieldWordStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onShieldWordStream =>
      _onShieldWordStreamController.stream;

  final _onBiliAccountStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onBiliAccountStream =>
      _onBiliAccountStreamController.stream;

  final _onRoomDestroyedStreamController = StreamController<String>.broadcast();
  Stream<String> get onRoomDestroyedStream =>
      _onRoomDestroyedStreamController.stream;

  final _onRoomUserUpdatedStreamController =
      StreamController<List<RoomUser>>.broadcast();
  Stream<List<RoomUser>> get onRoomUserUpdatedStream =>
      _onRoomUserUpdatedStreamController.stream;

  HubConnection? hubConnection;
  Future<void> connect() async {
    hubConnection = HubConnectionBuilder().withUrl(kUrl).build();
    hubConnection!.onclose(({Exception? error}) {
      state = SignalRConnectionState.disconnected;
      _stateStreamController.add(state);
    });
    hubConnection!.onreconnected(({String? connectionId}) {
      Log.d("reconnected: $connectionId");
      state = SignalRConnectionState.connected;
      _stateStreamController.add(state);
    });
    await hubConnection!.start();
    state = SignalRConnectionState.connected;
    _stateStreamController.add(state);
    _listen();
  }

  void _listen() {
    hubConnection?.on("onFavoriteReceived", (args) {
      _onFavoriteStreamController.add((args![0] as bool, args[1] as String));
    });
    hubConnection?.on("onHistoryReceived", (args) {
      _onHistoryStreamController.add((args![0] as bool, args[1] as String));
    });
    hubConnection?.on("onShieldWordReceived", (args) {
      _onShieldWordStreamController.add((args![0] as bool, args[1] as String));
    });
    hubConnection?.on("onBiliAccountReceived", (args) {
      _onBiliAccountStreamController.add((args![0] as bool, args[1] as String));
    });
    hubConnection?.on("onRoomDestroyed", (args) {
      _onRoomDestroyedStreamController.add(args![0].toString());
    });
    hubConnection?.on("onUserUpdated", (args) {
      var list = (args![0] as List).map((e) => RoomUser.fromObject(e)).toList();
      _onRoomUserUpdatedStreamController.add(list);
    });
  }

  Future<void> disconnect() async {
    await hubConnection?.stop();
    state = SignalRConnectionState.disconnected;
    _stateStreamController.add(state);
  }

  Future<Resp<String>> createRoom() async {
    if (state != SignalRConnectionState.connected) {
      throw Exception("not connected");
    }
    String app = "Simple Live";
    String platform = Platform.operatingSystem;
    String version = Utils.packageInfo.version;
    var resp = await hubConnection
        ?.invoke("CreateRoom", args: [app, platform, version]);
    return Resp<String>.fromObject(resp);
  }

  Future<Resp> joinRoom(String roomId) async {
    if (state != SignalRConnectionState.connected) {
      throw Exception("not connected");
    }
    String app = "Simple Live";
    String platform = Platform.operatingSystem;
    String version = Utils.packageInfo.version;
    var resp = await hubConnection
        ?.invoke("JoinRoom", args: [roomId, app, platform, version]);
    return Resp.fromObject(resp);
  }

  Future<Resp> sendContent({
    required String roomName,
    required String action,
    required bool overlay,
    required String content,
  }) async {
    if (state != SignalRConnectionState.connected) {
      throw Exception("not connected");
    }
    var resp =
        await hubConnection?.invoke(action, args: [roomName, overlay, content]);
    return Resp.fromObject(resp);
  }

  void dispose() {
    _stateStreamController.close();
    _onFavoriteStreamController.close();
    _onHistoryStreamController.close();
    _onShieldWordStreamController.close();
    _onBiliAccountStreamController.close();
    _onRoomDestroyedStreamController.close();
    _onRoomUserUpdatedStreamController.close();

    hubConnection?.stop();
  }
}

class Resp<T> {
  final bool isSuccess;
  final String message;
  final T? data;
  Resp(this.isSuccess, this.message, this.data);

  factory Resp.fromJson(Map<String, dynamic> json) {
    return Resp(
      json['isSuccess'],
      json['message'] ?? "",
      json['data'],
    );
  }

  factory Resp.fromObject(Object? obj) {
    if (obj is Map<String, dynamic>) {
      return Resp.fromJson(obj);
    }
    return Resp(false, "unknown", null);
  }
}

class RoomUser {
  final String connectionId;
  final String shortId;
  final String platform;
  final String version;
  final String app;
  final bool? isCreator;

  RoomUser({
    required this.connectionId,
    required this.shortId,
    required this.platform,
    required this.version,
    required this.app,
    this.isCreator = false,
  });

  factory RoomUser.fromJson(Map<String, dynamic> json) {
    return RoomUser(
      connectionId: json['connectionId'],
      shortId: json['shortId'],
      platform: json['platform'],
      version: json['version'],
      app: json['app'],
      isCreator: json['isCreator'],
    );
  }

  factory RoomUser.fromObject(Object? obj) {
    if (obj is Map<String, dynamic>) {
      return RoomUser.fromJson(obj);
    }
    return RoomUser(
      connectionId: "",
      shortId: "",
      platform: "",
      version: "",
      app: "",
    );
  }
}
