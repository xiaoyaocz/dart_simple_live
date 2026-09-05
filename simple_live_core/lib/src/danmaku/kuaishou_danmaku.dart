import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/web_socket_util.dart';

class KuaishouDanmakuArgs {
  final String roomId;
  final String liveStreamId;
  final String token;
  final List<String> websocketUrls;
  final String pageId;
  final String expTag;
  final String attach;
  final String cookie;
  final String userAgent;

  KuaishouDanmakuArgs({
    required this.roomId,
    required this.liveStreamId,
    required this.token,
    required this.websocketUrls,
    required this.pageId,
    this.expTag = '',
    this.attach = '',
    this.cookie = '',
    this.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  });

  @override
  String toString() {
    return json.encode({
      "roomId": roomId,
      "liveStreamId": liveStreamId,
      "token": token.isEmpty ? "" : "***",
      "websocketUrls": websocketUrls,
      "pageId": pageId,
      "expTag": expTag,
      "attach": attach,
      "cookie": cookie.isEmpty ? "" : "***",
      "userAgent": userAgent,
    });
  }
}

class KuaishouDanmaku extends LiveDanmaku {
  KuaishouDanmaku() {
    heartbeatTime = 20 * 1000;
  }

  WebScoketUtils? webScoketUtils;
  KuaishouDanmakuArgs? danmakuArgs;

  @override
  Future start(dynamic args) async {
    if (args is! KuaishouDanmakuArgs ||
        args.liveStreamId.isEmpty ||
        args.token.isEmpty ||
        args.websocketUrls.isEmpty) {
      onClose?.call("快手弹幕凭证无效，请在账号设置中重新登录并完成验证");
      return;
    }

    danmakuArgs = args;
    webScoketUtils = WebScoketUtils(
      url: args.websocketUrls.first,
      backupUrls: args.websocketUrls.skip(1).toList(),
      heartBeatTime: heartbeatTime,
      headers: {
        "User-Agent": args.userAgent,
        "Origin": "https://live.kuaishou.com",
        "Referer": "https://live.kuaishou.com/u/${args.roomId}",
        if (args.cookie.isNotEmpty) "Cookie": args.cookie,
      },
      onMessage: decodeMessage,
      onReady: () {
        onReady?.call();
        joinRoom();
      },
      onHeartBeat: heartbeat,
      onReconnect: () {
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    onReady = null;
    webScoketUtils?.close();
    webScoketUtils = null;
    danmakuArgs = null;
  }

  void joinRoom() {
    final args = danmakuArgs;
    if (args == null) {
      return;
    }
    final payload = _KuaishouProtoWriter()
      ..writeString(1, args.token)
      ..writeString(2, args.liveStreamId)
      ..writeVarintField(3, 0)
      ..writeVarintField(4, 0)
      ..writeString(5, args.expTag)
      ..writeString(6, args.attach)
      ..writeString(7, args.pageId);
    webScoketUtils?.sendMessage(_encodeSocketMessage(200, payload.takeBytes()));
  }

  @override
  void heartbeat() {
    final payload = _KuaishouProtoWriter()
      ..writeVarintField(1, DateTime.now().millisecondsSinceEpoch);
    webScoketUtils?.sendMessage(_encodeSocketMessage(1, payload.takeBytes()));
  }

  void decodeMessage(dynamic data) {
    try {
      if (data is ByteBuffer) {
        data = data.asUint8List();
      }
      if (data is! List<int>) {
        return;
      }

      final socketMessage = _decodeSocketMessage(data);
      var payload = socketMessage.payload;
      if (payload.isEmpty) {
        return;
      }
      if (socketMessage.compressionType == 2) {
        payload = gzip.decode(payload);
      } else if (socketMessage.compressionType == 3) {
        CoreLog.i("[KuaishouDanmaku] 暂不支持 AES 压缩弹幕包");
        return;
      }

      switch (socketMessage.payloadType) {
        case 103:
          final error = _decodeError(payload);
          if (error.isNotEmpty) {
            onClose?.call(error);
          }
          break;
        case 310:
          _decodeFeedPush(payload);
          break;
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }

  Uint8List _encodeSocketMessage(int payloadType, List<int> payload) {
    final writer = _KuaishouProtoWriter()
      ..writeVarintField(1, payloadType)
      ..writeBytes(3, payload);
    return writer.takeBytes();
  }

  _KuaishouSocketMessage _decodeSocketMessage(List<int> data) {
    final reader = _KuaishouProtoReader(data);
    var payloadType = 0;
    var compressionType = 0;
    var payload = <int>[];
    reader.readFields((fieldNumber, wireType) {
      if (fieldNumber == 1 && wireType == 0) {
        payloadType = reader.readVarint();
      } else if (fieldNumber == 2 && wireType == 0) {
        compressionType = reader.readVarint();
      } else if (fieldNumber == 3 && wireType == 2) {
        payload = reader.readBytes();
      } else {
        reader.skip(wireType);
      }
    });
    return _KuaishouSocketMessage(
      payloadType: payloadType,
      compressionType: compressionType,
      payload: payload,
    );
  }

  String _decodeError(List<int> payload) {
    final reader = _KuaishouProtoReader(payload);
    var code = 0;
    var message = '';
    reader.readFields((fieldNumber, wireType) {
      if (fieldNumber == 1 && wireType == 0) {
        code = reader.readVarint();
      } else if (fieldNumber == 2 && wireType == 2) {
        message = reader.readString();
      } else {
        reader.skip(wireType);
      }
    });
    if (message.isEmpty && code == 0) {
      return '';
    }
    return message.isEmpty ? "快手弹幕错误：$code" : "快手弹幕错误：$message";
  }

  void _decodeFeedPush(List<int> payload) {
    final reader = _KuaishouProtoReader(payload);
    reader.readFields((fieldNumber, wireType) {
      if (fieldNumber == 5 && wireType == 2) {
        final message = _decodeCommentFeed(reader.readBytes());
        if (message != null) {
          onMessage?.call(message);
        }
      } else {
        reader.skip(wireType);
      }
    });
  }

  LiveMessage? _decodeCommentFeed(List<int> payload) {
    final reader = _KuaishouProtoReader(payload);
    var userName = '';
    var content = '';
    var color = LiveMessageColor.white;
    var hidden = false;

    reader.readFields((fieldNumber, wireType) {
      if (fieldNumber == 2 && wireType == 2) {
        userName = _decodeSimpleUserInfo(reader.readBytes());
      } else if (fieldNumber == 3 && wireType == 2) {
        content = reader.readString();
      } else if (fieldNumber == 6 && wireType == 2) {
        color = _parseColor(reader.readString());
      } else if (fieldNumber == 7 && wireType == 0) {
        hidden = reader.readVarint() == 2;
      } else {
        reader.skip(wireType);
      }
    });

    if (hidden || content.isEmpty) {
      return null;
    }

    return LiveMessage(
      type: LiveMessageType.chat,
      userName: userName,
      message: content,
      color: color,
    );
  }

  String _decodeSimpleUserInfo(List<int> payload) {
    final reader = _KuaishouProtoReader(payload);
    var userName = '';
    reader.readFields((fieldNumber, wireType) {
      if (fieldNumber == 2 && wireType == 2) {
        userName = reader.readString();
      } else {
        reader.skip(wireType);
      }
    });
    return userName;
  }

  LiveMessageColor _parseColor(String value) {
    final colorText = value.trim().replaceFirst('#', '');
    if (colorText.length == 6) {
      final colorValue = int.tryParse(colorText, radix: 16);
      if (colorValue != null) {
        return LiveMessageColor.numberToColor(colorValue);
      }
    }
    return LiveMessageColor.white;
  }
}

class _KuaishouSocketMessage {
  final int payloadType;
  final int compressionType;
  final List<int> payload;

  _KuaishouSocketMessage({
    required this.payloadType,
    required this.compressionType,
    required this.payload,
  });
}

class _KuaishouProtoWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  void writeVarintField(int fieldNumber, int value) {
    _writeVarint((fieldNumber << 3) | 0);
    _writeVarint(value);
  }

  void writeString(int fieldNumber, String value) {
    if (value.isEmpty) {
      return;
    }
    writeBytes(fieldNumber, utf8.encode(value));
  }

  void writeBytes(int fieldNumber, List<int> value) {
    _writeVarint((fieldNumber << 3) | 2);
    _writeVarint(value.length);
    _builder.add(value);
  }

  void _writeVarint(int value) {
    var current = value;
    while (current >= 0x80) {
      _builder.addByte((current & 0x7f) | 0x80);
      current >>= 7;
    }
    _builder.addByte(current);
  }

  Uint8List takeBytes() => _builder.takeBytes();
}

class _KuaishouProtoReader {
  final List<int> _data;
  int _offset = 0;

  _KuaishouProtoReader(List<int> data) : _data = data;

  void readFields(void Function(int fieldNumber, int wireType) onField) {
    while (_offset < _data.length) {
      final tag = readVarint();
      if (tag == 0) {
        return;
      }
      onField(tag >> 3, tag & 0x07);
    }
  }

  int readVarint() {
    var shift = 0;
    var result = 0;
    while (_offset < _data.length) {
      final byte = _data[_offset++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) {
        return result;
      }
      shift += 7;
      if (shift > 63) {
        throw FormatException("Invalid protobuf varint");
      }
    }
    throw FormatException("Unexpected protobuf EOF");
  }

  List<int> readBytes() {
    final length = readVarint();
    final end = _offset + length;
    if (end > _data.length) {
      throw FormatException("Unexpected protobuf bytes EOF");
    }
    final result = _data.sublist(_offset, end);
    _offset = end;
    return result;
  }

  String readString() {
    return utf8.decode(readBytes(), allowMalformed: true);
  }

  void skip(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
        break;
      case 1:
        _offset += 8;
        break;
      case 2:
        final length = readVarint();
        _offset += length;
        break;
      case 5:
        _offset += 4;
        break;
      default:
        throw FormatException("Unsupported protobuf wire type: $wireType");
    }
    if (_offset > _data.length) {
      throw FormatException("Unexpected protobuf skip EOF");
    }
  }
}
