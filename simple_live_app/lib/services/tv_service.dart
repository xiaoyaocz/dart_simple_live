import 'dart:convert';

import 'package:get/get.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:udp/udp.dart';

class TVService extends GetxService {
  static TVService get instance => Get.find<TVService>();

  UDP? udp;
  RxList<TVClinet> clients = <TVClinet>[].obs;
  static const int udpPort = 23235;
  static const int httpPort = 23234;

  @override
  void onInit() {
    Log.d('TVService init');
    listenUDP();
    super.onInit();
  }

  /// 监听TV端UDP广播的回复
  /// - 通过UDP广播获取TV端的IP地址
  void listenUDP() async {
    udp = await UDP.bind(Endpoint.any(port: const Port(udpPort)));
    udp!.asStream().listen((datagram) {
      var str = String.fromCharCodes(datagram!.data);
      Log.i("Received: $str from ${datagram.address}:${datagram.port}");
      if (str.startsWith('{') && str.endsWith('}')) {
        var data = json.decode(str);
        if (data['type'] == 'tv') {
          var address = datagram.address.address;
          //检查是否已经存在
          var index =
              clients.indexWhere((element) => element.deviceIp == address);
          if (index == -1) {
            clients.add(
              TVClinet(
                deviceName: data['name'],
                deviceIp: address,
                devicePort: httpPort,
              ),
            );
          }
        }
      }
    });
  }

  /// 发送UDP广播至TV端
  /// - 发送指令：Who is SimpleLiveTV?
  /// - TV端收到指令后会回复客户端信息：
  /// ```{"type":"tv","name":"TVName","ip":"192.168.3.1","version":"1.0.1"}```
  void sendUPD() async {
    await udp!.send(
      "Who is SimpleLiveTV?".codeUnits,
      Endpoint.broadcast(
        port: const Port(udpPort),
      ),
    );
    Log.i("send udp");
  }

  void refreshClients() {
    clients.clear();
    sendUPD();
  }

  @override
  void onClose() {
    Log.d('TVService close');
    udp?.close();
    super.onClose();
  }
}

class TVClinet {
  final String deviceName;
  final String deviceIp;
  final int devicePort;
  TVClinet({
    required this.deviceName,
    required this.deviceIp,
    required this.devicePort,
  });
}
