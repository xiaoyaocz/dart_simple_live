import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_core/src/common/http_client.dart';
class _Network implements HttpClientAdapter {
  final requests=<RequestOptions>[];
  bool alwaysFail=false;
  DioExceptionType failure=DioExceptionType.connectionError;
  @override
  Future<ResponseBody> fetch(RequestOptions options,Stream<Uint8List>? body,Future<void>? cancelFuture) async {
    requests.add(options);
    if(alwaysFail || requests.length==1) throw DioException(requestOptions:options,type:failure);
    return ResponseBody.fromString('{"ok":true}',200,headers:{'content-type':['application/json']});
  }
  @override
  void close({bool force=false}) {}
}
void main(){
  for(final method in ['GET text','GET json','HEAD']){
    test('$method recovers one transient connection error without losing request parameters',() async {
      final client=HttpClient();final network=_Network();client.dio.httpClientAdapter=network;
      if(method=='GET text') await client.getText('https://example.invalid/rooms',queryParameters:{'page':2});
      if(method=='GET json') expect(await client.getJson('https://example.invalid/rooms',queryParameters:{'page':2}),{'ok':true});
      if(method=='HEAD') expect((await client.head('https://example.invalid/rooms',queryParameters:{'page':2})).statusCode,200);
      expect(network.requests.length,2);expect(network.requests.last.queryParameters,{'page':2});
    });
  }
  test('persistent connection failure retries only once',() async {
    final client=HttpClient();final network=_Network()..alwaysFail=true;client.dio.httpClientAdapter=network;
    await expectLater(client.getText('https://example.invalid/rooms'),throwsA(anything));expect(network.requests.length,2);
  });
  test('cancelling during connection backoff prevents the second read',() async {
    final client=HttpClient();final network=_Network();client.dio.httpClientAdapter=network;
    final cancel=CancelToken();
    final result=expectLater(client.getText('https://example.invalid/rooms',cancel:cancel),throwsA(anything));
    await Future<void>.delayed(const Duration(milliseconds:50));cancel.cancel();
    await result;expect(network.requests.length,1);
  });  test('POST and cancellation are never replayed',() async {
    final client=HttpClient();final network=_Network();client.dio.httpClientAdapter=network;
    await expectLater(client.postJson('https://example.invalid/message',data:{'text':'not replayed'}),throwsA(anything));expect(network.requests.length,1);
    network.requests.clear();network.failure=DioExceptionType.cancel;
    await expectLater(client.getText('https://example.invalid/rooms'),throwsA(anything));expect(network.requests.length,1);
  });
}