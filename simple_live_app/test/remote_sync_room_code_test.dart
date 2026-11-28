import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/modules/sync/remote_sync/room/remote_sync_room_controller.dart';
import 'package:simple_live_app/services/signalr_service.dart';

void main() {
  test('普通房间号仍可加入', () {
    final controller = RemoteSyncRoomController('ABC123');
    expect(controller.roomId, 'ABC123');
    expect(controller.relayAddresses, isEmpty);
    controller.signalR.dispose();
  });

  test('扫码房间号优先携带局域网转接地址', () {
    final controller =
        RemoteSyncRoomController('ABC123|192.168.3.139;192.168.3.140');
    expect(controller.roomId, 'ABC123');
    expect(controller.relayAddresses, ['192.168.3.139', '192.168.3.140']);
    controller.signalR.dispose();
  });

  test('二维码仅在新设备加入后关闭', () {
    final knownIds = {'self', 'existing'};
    final self = RoomUser.fromObject({
      'connectionId': 'self',
      'isSelf': true,
    });
    final existing = RoomUser.fromObject({'connectionId': 'existing'});
    final newcomer = RoomUser.fromObject({'connectionId': 'newcomer'});

    expect(RemoteSyncRoomController.hasNewRemoteUser(knownIds, [self]), false);
    expect(
      RemoteSyncRoomController.hasNewRemoteUser(knownIds, [self, existing]),
      false,
    );
    expect(
      RemoteSyncRoomController.hasNewRemoteUser(
        knownIds,
        [self, existing, newcomer],
      ),
      true,
    );
  });

  testWidgets('新设备加入后关闭正在显示的房间二维码', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: Text('房间'))),
    );
    final controller = RemoteSyncRoomController('ABC123');
    final self = RoomUser.fromObject({
      'connectionId': 'self',
      'isSelf': true,
    });
    final newcomer = RoomUser.fromObject({'connectionId': 'newcomer'});

    controller.onRoomUsersUpdated([self]);
    controller.showQRInfo();
    await tester.pumpAndSettle();
    expect(find.text('房间信息'), findsOneWidget);

    controller.onRoomUsersUpdated([self]);
    await tester.pumpAndSettle();
    expect(find.text('房间信息'), findsOneWidget);

    controller.onRoomUsersUpdated([self, newcomer]);
    await tester.pumpAndSettle();
    expect(find.text('房间信息'), findsNothing);
    controller.signalR.dispose();
  });
}
