class TupResponse<T> {
  int code = 0;
  T? response;

  TupResponse({this.code = 0, this.response});
}
