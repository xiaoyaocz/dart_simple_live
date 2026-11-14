import 'package:simple_live_core/src/model/tars/huya_user_id.dart';
import 'package:tars_dart/tars/codec/tars_displayer.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

class GetGameEventMessageBoardReq extends TarsStruct {
  int lPid = 0;
  String sOffset = "";
  HuyaUserId tId = HuyaUserId();
  int iMessageBoardScope = 0;
  int iPageSize = 10;

  @override
  void readFrom(TarsInputStream _is) {
    lPid = _is.read(lPid, 0, false);
    sOffset = _is.read(sOffset, 1, false);
    tId = _is.read(tId, 2, false);
    iMessageBoardScope = _is.read(iMessageBoardScope, 3, false);
    iPageSize = _is.read(iPageSize, 4, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(lPid, 0);
    _os.write(sOffset, 1);
    _os.write(tId, 2);
    _os.write(iMessageBoardScope, 3);
    _os.write(iPageSize, 4);
  }

  @override
  Object deepCopy() {
    return GetGameEventMessageBoardReq()
      ..lPid = lPid
      ..sOffset = sOffset
      ..tId = tId.deepCopy() as HuyaUserId
      ..iMessageBoardScope = iMessageBoardScope
      ..iPageSize = iPageSize;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.DisplayInt(lPid, "lPid");
    ds.DisplayString(sOffset, "sOffset");
    ds.display(tId, "tId");
    ds.DisplayInt(iMessageBoardScope, "iMessageBoardScope");
    ds.DisplayInt(iPageSize, "iPageSize");
  }
}

class GetGameEventMessageBoardRsp extends TarsStruct {
  GameEventMessageBoardPanel tMessageBoardPanel = GameEventMessageBoardPanel();

  @override
  void readFrom(TarsInputStream _is) {
    tMessageBoardPanel = _is.read(tMessageBoardPanel, 1, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(tMessageBoardPanel, 1);
  }

  @override
  Object deepCopy() {
    return GetGameEventMessageBoardRsp()
      ..tMessageBoardPanel =
          tMessageBoardPanel.deepCopy() as GameEventMessageBoardPanel;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.display(tMessageBoardPanel, "tMessageBoardPanel");
  }
}

class GameEventMessageBoardPanel extends TarsStruct {
  List<GameEventMessageBoardInfo> vGameEventMessageBoardInfo = [
    GameEventMessageBoardInfo(),
  ];

  @override
  void readFrom(TarsInputStream _is) {
    vGameEventMessageBoardInfo = _is
        .read(vGameEventMessageBoardInfo, 1, false)
        .cast<GameEventMessageBoardInfo>();
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(vGameEventMessageBoardInfo, 1);
  }

  @override
  Object deepCopy() {
    return GameEventMessageBoardPanel()
      ..vGameEventMessageBoardInfo = vGameEventMessageBoardInfo
          .map((e) => e.deepCopy() as GameEventMessageBoardInfo)
          .toList();
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.display(vGameEventMessageBoardInfo, "vGameEventMessageBoardInfo");
  }
}

class GameEventMessageBoardInfo extends TarsStruct {
  MessageUser tMessageUser = MessageUser();
  String sContent = "";
  int iCost = 0;
  int iTotalSec = 0;
  int iCountDown = 0;
  int lMessageId = 0;
  int iCostPay = 0;

  @override
  void readFrom(TarsInputStream _is) {
    tMessageUser = _is.read(tMessageUser, 0, false);
    sContent = _is.read(sContent, 1, false);
    iCost = _is.read(iCost, 2, false);
    iTotalSec = _is.read(iTotalSec, 4, false);
    iCountDown = _is.read(iCountDown, 5, false);
    lMessageId = _is.read(lMessageId, 9, false);
    iCostPay = _is.read(iCostPay, 12, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(tMessageUser, 0);
    _os.write(sContent, 1);
    _os.write(iCost, 2);
    _os.write(iTotalSec, 4);
    _os.write(iCountDown, 5);
    _os.write(lMessageId, 9);
    _os.write(iCostPay, 12);
  }

  @override
  Object deepCopy() {
    return GameEventMessageBoardInfo()
      ..tMessageUser = tMessageUser.deepCopy() as MessageUser
      ..sContent = sContent
      ..iCost = iCost
      ..iTotalSec = iTotalSec
      ..iCountDown = iCountDown
      ..lMessageId = lMessageId
      ..iCostPay = iCostPay;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.display(tMessageUser, "tMessageUser");
    ds.DisplayString(sContent, "sContent");
    ds.DisplayInt(iCost, "iCost");
    ds.DisplayInt(iTotalSec, "iTotalSec");
    ds.DisplayInt(iCountDown, "iCountDown");
    ds.DisplayInt(lMessageId, "lMessageId");
    ds.DisplayInt(iCostPay, "iCostPay");
  }
}

class MessageUser extends TarsStruct {
  String sNick = "";
  String sAvatar = "";

  @override
  void readFrom(TarsInputStream _is) {
    sNick = _is.read(sNick, 1, false);
    sAvatar = _is.read(sAvatar, 2, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(sNick, 1);
    _os.write(sAvatar, 2);
  }

  @override
  Object deepCopy() {
    return MessageUser()
      ..sNick = sNick
      ..sAvatar = sAvatar;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.DisplayString(sNick, "sNick");
    ds.DisplayString(sAvatar, "sAvatar");
  }
}
