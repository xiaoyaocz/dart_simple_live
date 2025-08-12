import 'dart:convert';

T? asT<T>(dynamic value) {
  if (value is T) {
    return value;
  }
  return null;
}

class DouyinUserInfoModel {
  DouyinUserInfoModel({
    this.id,
    this.nickname,
    this.shortId,
    this.sign,
    this.birthday,
    this.gender,
  });

  factory DouyinUserInfoModel.fromJson(Map<String, dynamic> json) =>
      DouyinUserInfoModel(
        id: asT<String?>(json['id_str']),
        nickname: asT<String?>(json['nickname']),
        shortId: asT<String?>(json['short_id']),
        sign: asT<String?>(json['sign']),
        birthday: asT<String?>(json['birthday']),
        gender: asT<String?>(json['gender']),
      );

  String? id;
  String? nickname;
  String? shortId;
  String? sign;
  String? birthday;
  String? gender;

  @override
  String toString() {
    return jsonEncode(this);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'nickname': nickname,
        'short_id': shortId,
        'sign': sign,
        'birthday': birthday,
        'gender': gender,
      };
}
