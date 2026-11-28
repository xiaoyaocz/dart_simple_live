import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';
import '../model/live_emoticon.dart';

/// Official wupui.getExpressionEmoticonPackage, same TUP3 transport as web.
/// Kept separate from websocket heartbeat and room messages.
abstract final class HuyaEmoticons {
  static Uint8List request({required int presenterUid}) {
    final req = TarsOutputStream();
    req.writeHead(TarsStructType.STRUCT_BEGIN.index, 0);
    req.writeHead(TarsStructType.STRUCT_BEGIN.index, 0); // UserId
    req.write(0, 0);
    req.write('', 1);
    req.write('', 2);
    req.write('webh5&1.0.0&webh5', 3);
    req.write('', 4);
    req.writeHead(TarsStructType.STRUCT_END.index, 0);
    req.write(presenterUid, 1);
    req.write(0, 2); // all game categories
    req.write(0, 3); // public chat
    req.writeHead(TarsStructType.STRUCT_END.index, 0);
    final params = TarsOutputStream()..writeMap({'tReq': req.toUint8List()}, 0);
    final out = TarsOutputStream()
      ..write(3, 1)
      ..write(0, 2)
      ..write(0, 3)
      ..write(1, 4)
      ..write('wupui', 5)
      ..write('getExpressionEmoticonPackage', 6)
      ..write(params.toUint8List(), 7)
      ..write(4000, 8)
      ..writeMap(<String, String>{}, 9)
      ..writeMap(<String, String>{}, 10);
    final body = out.toUint8List();
    return Uint8List(body.length + 4)
      ..buffer.asByteData().setInt32(0, body.length + 4)
      ..setRange(4, body.length + 4, body);
  }

  static Future<List<LiveEmoticon>> load(
    Dio dio,
    int presenterUid, {
    CancelToken? cancel,
  }) async {
    final response = await dio.post<List<int>>(
      'https://cdnws.api.huya.com/',
      data: Stream.value(request(presenterUid: presenterUid)),
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.bytes,
        contentType: 'application/octet-stream',
        headers: {
          'Referer': 'https://www.huya.com/',
          'User-Agent': 'Mozilla/5.0',
        },
        sendTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ),
    );
    return parse(Uint8List.fromList(response.data!));
  }

  static List<LiveEmoticon> parse(Uint8List bytes) {
    if (bytes.length < 4 || bytes.length > 4 * 1024 * 1024)
      throw const FormatException('Invalid Huya WUP length');
    final input = TarsInputStream(bytes, pos: 4);
    if (input.read(0, 1, true) != 3)
      throw const FormatException('Expected TUP3');
    final body = input.readBytes(7, true);
    final params = TarsInputStream(
      body,
    ).readMap<String, Uint8List>({'': Uint8List(0)}, 0, true);
    final value = params['tRsp'] ?? params['tResp'];
    if (value == null)
      throw const FormatException('Missing Huya expression response');
    final rsp =
        TarsInputStream(value).readTarsStruct(_ExpressionResponse(), 0, true)
            as _ExpressionResponse;
    return [
      for (final pack in rsp.packages)
        for (final item in pack.items)
          for (final token in {
            item.name,
            item.escape,
          }.where((s) => s.isNotEmpty))
            if (LiveEmoticon.normalizeUrl(item.url) case final String url)
              LiveEmoticon(
                text: token,
                url: url.replaceFirst(
                  'http://cdnfile2.msstatic.com/',
                  'https://cdnfile2.msstatic.com/',
                ),
                headers: const {'Referer': 'https://www.huya.com/'},
              ),
    ];
  }
}

class _ExpressionResponse extends TarsStruct {
  List<_ExpressionPackage> packages = [];
  @override
  void readFrom(TarsInputStream input) {
    packages = input.readList<_ExpressionPackage>(
      [_ExpressionPackage()],
      1,
      false,
    );
  }

  @override
  void writeTo(TarsOutputStream out) {
    out.writeList(packages, 1);
  }

  @override
  Object deepCopy() => _ExpressionResponse()..packages = List.of(packages);
  @override
  void displayAsString(StringBuffer sb, int level) {
    sb.write('ExpressionResponse(${packages.length})');
  }
}

class _ExpressionPackage extends TarsStruct {
  List<_ExpressionItem> items = [];
  @override
  void readFrom(TarsInputStream input) {
    items = input.readList<_ExpressionItem>([_ExpressionItem()], 4, false);
  }

  @override
  void writeTo(TarsOutputStream out) {
    out.writeList(items, 4);
  }

  @override
  Object deepCopy() => _ExpressionPackage()..items = List.of(items);
  @override
  void displayAsString(StringBuffer sb, int level) {
    sb.write('ExpressionPackage(${items.length})');
  }
}

class _ExpressionItem extends TarsStruct {
  String name = '', escape = '', url = '';
  @override
  void readFrom(TarsInputStream input) {
    name = input.read('', 1, false);
    escape = input.read('', 2, false);
    url = input.read('', 3, false);
    // ExtraUrl may be JSON/sprite instructions, not a normal image. Do not
    // mistake it for a GIF URL; the ordinary sUrl is the actual public image.
  }

  @override
  void writeTo(TarsOutputStream out) {
    out.write(name, 1);
    out.write(escape, 2);
    out.write(url, 3);
  }

  @override
  Object deepCopy() => _ExpressionItem()
    ..name = name
    ..escape = escape
    ..url = url;
  @override
  void displayAsString(StringBuffer sb, int level) {
    sb.write(name);
  }
}
