import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/tup/const.dart';
import 'package:tars_dart/tars/tup/tars_uni_packet.dart';
import 'package:tars_dart/tars/tup/tup_response.dart';
import 'package:tars_dart/tars/tup/tup_result_exception.dart';

//tup网络请求封装
//注意:只支持 PACKET_TYPE_TUP3 = 3 类型的封包
class BaseTarsHttp {
  final String baseUrl;
  final String path;
  final String servantName;
  final Map<String, String> headers;

  var timeOut = 60000;
  var debugLog = false;
  late final Dio dio;
  final logger = Logger();

  BaseTarsHttp(
    this.baseUrl,
    this.servantName, {
    this.path = "",
    this.timeOut = 60000,
    this.debugLog = false,
    this.headers = const {},
  }) {
    dio = Dio(BaseOptions(
        connectTimeout: Duration(seconds: timeOut),
        baseUrl: baseUrl,
        responseType: ResponseType.bytes,
        headers: {
          HttpHeaders.contentTypeHeader: "application/x-wup",
          ...headers
        }));
    if (debugLog) {
      dio.interceptors.add(LogInterceptor(responseBody: false)); //开启请求日志
    }
  }

  //发送http请求,不返回状态码,异常状态码直接抛出异常TupResultException
  Future<RSP> tupRequest<REQ, RSP>(
      String methodName, REQ tReq, RSP tRsp) async {
    TupResponse<RSP> response =
        await tupRequestWithRspCode(methodName, tReq, tRsp);
    if (response.code == 0) {
      return response.response!;
    } else {
      logger.e("tupDecode decode error:${response.code}");
      throw TupResultException(response.code);
    }
  }

  //发送http请求,返回状态码及response
  Future<TupResponse<RSP>> tupRequestWithRspCode<REQ, RSP>(
      String methodName, REQ tReq, RSP tRsp) async {
    final data = buildRequest(methodName, tReq);
    dio.options.headers[HttpHeaders.contentLengthHeader] = data.lengthInBytes;
    logger.d("send tupRequest, methodName:$methodName");
    final result = await dio.post<List<int>>(
      path,
      data: Stream.fromIterable(data.map((e) => [e])),
    );
    final value = result.data;
    return tupResponseDecode(methodName, value!, tRsp);
  }

  //发送无response http请求,返回状态码
  Future<TupResponse<void>> tupRequestWithRspCodeNoRsp<REQ>(
      String methodName, REQ tReq) async {
    final data = buildRequest(methodName, tReq);
    dio.options.headers[HttpHeaders.contentLengthHeader] = data.lengthInBytes;
    logger.d("send tupRequestNoRsp, methodName:$methodName");
    final result = await dio.post<List<int>>(
      path,
      data: Stream.fromIterable(data.map((e) => [e])),
    );
    final value = result.data;
    return tupEmptyResponseDecode(methodName, value!);
  }

  //发送无response http请求,不返回状态码,异常状态码直接抛出异常TupResultException
  Future<void> tupRequestNoRsp<REQ>(String methodName, REQ tReq) async {
    TupResponse<void> response =
        await tupRequestWithRspCodeNoRsp(methodName, tReq);
    if (response.code == 0) {
      return;
    } else {
      logger.e("tupDecode decode error:${response.code}");
      throw TupResultException(response.code);
    }
  }

  //封包
  Uint8List buildRequest<REQ>(String methodName, REQ tReq) {
    TarsUniPacket encodePack = TarsUniPacket();
    encodePack.requestId = 0;
    encodePack.setTarsVersion(Const.PACKET_TYPE_TUP3);
    encodePack.setTarsPacketType(Const.PACKET_TYPE_TARSNORMAL);
    encodePack.servantName = servantName;
    encodePack.funcName = methodName;
    encodePack.put("tReq", tReq);
    Uint8List bytes = encodePack.encode();
    return bytes;
  }

  //有response解包
  TupResponse<RSP> tupResponseDecode<RSP>(
      String methodName, List<int> list, RSP tRsp) {
    var bytes = Uint8List.fromList(list);
    BinaryReader br = BinaryReader(bytes);
    int size = br.readInt(4);
    logger.d("size:$size");
    TarsUniPacket respPack = TarsUniPacket();
    respPack.decode(bytes);
    var code = respPack.get("", 0);
    logger.d("get tupRequest response, methodName:$methodName, code:$code");
    RSP rsp = respPack.get<RSP>("tRsp", tRsp);
    return TupResponse<RSP>(code: code, response: rsp);
  }

  //无response解包
  TupResponse<void> tupEmptyResponseDecode(String methodName, List<int> list) {
    var bytes = Uint8List.fromList(list);
    BinaryReader br = BinaryReader(bytes);
    int size = br.readInt(4);
    logger.d("size:$size");
    TarsUniPacket respPack = TarsUniPacket();
    respPack.decode(bytes);
    var code = respPack.get("", 0);
    logger.d("get tupRequest response, methodName:$methodName, code:$code");
    return TupResponse<void>(code: code);
  }
}
