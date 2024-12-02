// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

class HYPushMessage extends TarsStruct {
  int pushType = 0;
  int uri = 0;
  List<int> msg = <int>[];
  int protocolType = 0;

  @override
  void readFrom(TarsInputStream _is) {
    pushType = _is.read(pushType, 0, false);
    uri = _is.read(uri, 1, false);
    msg = _is.readBytes(2, false);
    protocolType = _is.read(protocolType, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYPushMessage()
      ..pushType = pushType
      ..uri = uri
      ..msg = List<int>.from(msg)
      ..protocolType = protocolType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYSender extends TarsStruct {
  int uid = 0;
  int lMid = 0;
  String nickName = "";
  int gender = 0;

  @override
  void readFrom(TarsInputStream _is) {
    uid = _is.read(uid, 0, false);
    lMid = _is.read(lMid, 0, false);
    nickName = _is.read(nickName, 2, false);
    gender = _is.read(gender, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYSender()
      ..uid = uid
      ..lMid = lMid
      ..nickName = nickName
      ..gender = gender;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYMessage extends TarsStruct {
  HYSender userInfo = HYSender();
  String content = "";
  HYBulletFormat bulletFormat = HYBulletFormat();

  @override
  void readFrom(TarsInputStream _is) {
    userInfo = _is.readTarsStruct(userInfo, 0, false) as HYSender;
    content = _is.read(content, 3, false);
    bulletFormat = _is.readTarsStruct(bulletFormat, 6, false) as HYBulletFormat;
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYMessage()
      ..userInfo = userInfo.deepCopy() as HYSender
      ..content = content
      ..bulletFormat = bulletFormat.deepCopy() as HYBulletFormat;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYBulletFormat extends TarsStruct {
  int fontColor = 0;
  int fontSize = 4;
  int textSpeed = 0;
  int transitionType = 1;

  @override
  void readFrom(TarsInputStream _is) {
    fontColor = _is.read(fontColor, 0, false);
    fontSize = _is.read(fontSize, 1, false);
    textSpeed = _is.read(textSpeed, 2, false);
    transitionType = _is.read(transitionType, 3, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {}

  @override
  Object deepCopy() {
    return HYBulletFormat()
      ..fontColor = fontColor
      ..fontSize = fontSize
      ..textSpeed = textSpeed
      ..transitionType = transitionType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}
