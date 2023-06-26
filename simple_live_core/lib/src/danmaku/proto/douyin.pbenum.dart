//
//  Generated code. Do not modify.
//  source: douyin.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class CommentTypeTag extends $pb.ProtobufEnum {
  static const CommentTypeTag COMMENTTYPETAGUNKNOWN = CommentTypeTag._(0, _omitEnumNames ? '' : 'COMMENTTYPETAGUNKNOWN');
  static const CommentTypeTag COMMENTTYPETAGSTAR = CommentTypeTag._(1, _omitEnumNames ? '' : 'COMMENTTYPETAGSTAR');

  static const $core.List<CommentTypeTag> values = <CommentTypeTag> [
    COMMENTTYPETAGUNKNOWN,
    COMMENTTYPETAGSTAR,
  ];

  static final $core.Map<$core.int, CommentTypeTag> _byValue = $pb.ProtobufEnum.initByValue(values);
  static CommentTypeTag? valueOf($core.int value) => _byValue[value];

  const CommentTypeTag._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
