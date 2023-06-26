//
//  Generated code. Do not modify.
//  source: douyin.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use commentTypeTagDescriptor instead')
const CommentTypeTag$json = {
  '1': 'CommentTypeTag',
  '2': [
    {'1': 'COMMENTTYPETAGUNKNOWN', '2': 0},
    {'1': 'COMMENTTYPETAGSTAR', '2': 1},
  ],
};

/// Descriptor for `CommentTypeTag`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List commentTypeTagDescriptor = $convert.base64Decode(
    'Cg5Db21tZW50VHlwZVRhZxIZChVDT01NRU5UVFlQRVRBR1VOS05PV04QABIWChJDT01NRU5UVF'
    'lQRVRBR1NUQVIQAQ==');

@$core.Deprecated('Use responseDescriptor instead')
const Response$json = {
  '1': 'Response',
  '2': [
    {'1': 'messagesList', '3': 1, '4': 3, '5': 11, '6': '.douyin.Message', '10': 'messagesList'},
    {'1': 'cursor', '3': 2, '4': 1, '5': 9, '10': 'cursor'},
    {'1': 'fetchInterval', '3': 3, '4': 1, '5': 4, '10': 'fetchInterval'},
    {'1': 'now', '3': 4, '4': 1, '5': 4, '10': 'now'},
    {'1': 'internalExt', '3': 5, '4': 1, '5': 9, '10': 'internalExt'},
    {'1': 'fetchType', '3': 6, '4': 1, '5': 13, '10': 'fetchType'},
    {'1': 'routeParams', '3': 7, '4': 3, '5': 11, '6': '.douyin.Response.RouteParamsEntry', '10': 'routeParams'},
    {'1': 'heartbeatDuration', '3': 8, '4': 1, '5': 4, '10': 'heartbeatDuration'},
    {'1': 'needAck', '3': 9, '4': 1, '5': 8, '10': 'needAck'},
    {'1': 'pushServer', '3': 10, '4': 1, '5': 9, '10': 'pushServer'},
    {'1': 'liveCursor', '3': 11, '4': 1, '5': 9, '10': 'liveCursor'},
    {'1': 'historyNoMore', '3': 12, '4': 1, '5': 8, '10': 'historyNoMore'},
  ],
  '3': [Response_RouteParamsEntry$json],
};

@$core.Deprecated('Use responseDescriptor instead')
const Response_RouteParamsEntry$json = {
  '1': 'RouteParamsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List responseDescriptor = $convert.base64Decode(
    'CghSZXNwb25zZRIzCgxtZXNzYWdlc0xpc3QYASADKAsyDy5kb3V5aW4uTWVzc2FnZVIMbWVzc2'
    'FnZXNMaXN0EhYKBmN1cnNvchgCIAEoCVIGY3Vyc29yEiQKDWZldGNoSW50ZXJ2YWwYAyABKARS'
    'DWZldGNoSW50ZXJ2YWwSEAoDbm93GAQgASgEUgNub3cSIAoLaW50ZXJuYWxFeHQYBSABKAlSC2'
    'ludGVybmFsRXh0EhwKCWZldGNoVHlwZRgGIAEoDVIJZmV0Y2hUeXBlEkMKC3JvdXRlUGFyYW1z'
    'GAcgAygLMiEuZG91eWluLlJlc3BvbnNlLlJvdXRlUGFyYW1zRW50cnlSC3JvdXRlUGFyYW1zEi'
    'wKEWhlYXJ0YmVhdER1cmF0aW9uGAggASgEUhFoZWFydGJlYXREdXJhdGlvbhIYCgduZWVkQWNr'
    'GAkgASgIUgduZWVkQWNrEh4KCnB1c2hTZXJ2ZXIYCiABKAlSCnB1c2hTZXJ2ZXISHgoKbGl2ZU'
    'N1cnNvchgLIAEoCVIKbGl2ZUN1cnNvchIkCg1oaXN0b3J5Tm9Nb3JlGAwgASgIUg1oaXN0b3J5'
    'Tm9Nb3JlGj4KEFJvdXRlUGFyYW1zRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAi'
    'ABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use messageDescriptor instead')
const Message$json = {
  '1': 'Message',
  '2': [
    {'1': 'method', '3': 1, '4': 1, '5': 9, '10': 'method'},
    {'1': 'payload', '3': 2, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'msgId', '3': 3, '4': 1, '5': 3, '10': 'msgId'},
    {'1': 'msgType', '3': 4, '4': 1, '5': 5, '10': 'msgType'},
    {'1': 'offset', '3': 5, '4': 1, '5': 3, '10': 'offset'},
    {'1': 'needWrdsStore', '3': 6, '4': 1, '5': 8, '10': 'needWrdsStore'},
    {'1': 'wrdsVersion', '3': 7, '4': 1, '5': 3, '10': 'wrdsVersion'},
    {'1': 'wrdsSubKey', '3': 8, '4': 1, '5': 9, '10': 'wrdsSubKey'},
  ],
};

/// Descriptor for `Message`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageDescriptor = $convert.base64Decode(
    'CgdNZXNzYWdlEhYKBm1ldGhvZBgBIAEoCVIGbWV0aG9kEhgKB3BheWxvYWQYAiABKAxSB3BheW'
    'xvYWQSFAoFbXNnSWQYAyABKANSBW1zZ0lkEhgKB21zZ1R5cGUYBCABKAVSB21zZ1R5cGUSFgoG'
    'b2Zmc2V0GAUgASgDUgZvZmZzZXQSJAoNbmVlZFdyZHNTdG9yZRgGIAEoCFINbmVlZFdyZHNTdG'
    '9yZRIgCgt3cmRzVmVyc2lvbhgHIAEoA1ILd3Jkc1ZlcnNpb24SHgoKd3Jkc1N1YktleRgIIAEo'
    'CVIKd3Jkc1N1YktleQ==');

@$core.Deprecated('Use chatMessageDescriptor instead')
const ChatMessage$json = {
  '1': 'ChatMessage',
  '2': [
    {'1': 'common', '3': 1, '4': 1, '5': 11, '6': '.douyin.Common', '10': 'common'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.douyin.User', '10': 'user'},
    {'1': 'content', '3': 3, '4': 1, '5': 9, '10': 'content'},
    {'1': 'visibleToSender', '3': 4, '4': 1, '5': 8, '10': 'visibleToSender'},
    {'1': 'backgroundImage', '3': 5, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'backgroundImage'},
    {'1': 'fullScreenTextColor', '3': 6, '4': 1, '5': 9, '10': 'fullScreenTextColor'},
    {'1': 'backgroundImageV2', '3': 7, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'backgroundImageV2'},
    {'1': 'publicAreaCommon', '3': 8, '4': 1, '5': 11, '6': '.douyin.PublicAreaCommon', '10': 'publicAreaCommon'},
    {'1': 'giftImage', '3': 9, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'giftImage'},
    {'1': 'agreeMsgId', '3': 11, '4': 1, '5': 4, '10': 'agreeMsgId'},
    {'1': 'priorityLevel', '3': 12, '4': 1, '5': 13, '10': 'priorityLevel'},
    {'1': 'landscapeAreaCommon', '3': 13, '4': 1, '5': 11, '6': '.douyin.LandscapeAreaCommon', '10': 'landscapeAreaCommon'},
    {'1': 'eventTime', '3': 15, '4': 1, '5': 4, '10': 'eventTime'},
    {'1': 'sendReview', '3': 16, '4': 1, '5': 8, '10': 'sendReview'},
    {'1': 'fromIntercom', '3': 17, '4': 1, '5': 8, '10': 'fromIntercom'},
    {'1': 'intercomHideUserCard', '3': 18, '4': 1, '5': 8, '10': 'intercomHideUserCard'},
    {'1': 'chatBy', '3': 20, '4': 1, '5': 9, '10': 'chatBy'},
    {'1': 'individualChatPriority', '3': 21, '4': 1, '5': 13, '10': 'individualChatPriority'},
    {'1': 'rtfContent', '3': 22, '4': 1, '5': 11, '6': '.douyin.Text', '10': 'rtfContent'},
  ],
};

/// Descriptor for `ChatMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatMessageDescriptor = $convert.base64Decode(
    'CgtDaGF0TWVzc2FnZRImCgZjb21tb24YASABKAsyDi5kb3V5aW4uQ29tbW9uUgZjb21tb24SIA'
    'oEdXNlchgCIAEoCzIMLmRvdXlpbi5Vc2VyUgR1c2VyEhgKB2NvbnRlbnQYAyABKAlSB2NvbnRl'
    'bnQSKAoPdmlzaWJsZVRvU2VuZGVyGAQgASgIUg92aXNpYmxlVG9TZW5kZXISNwoPYmFja2dyb3'
    'VuZEltYWdlGAUgASgLMg0uZG91eWluLkltYWdlUg9iYWNrZ3JvdW5kSW1hZ2USMAoTZnVsbFNj'
    'cmVlblRleHRDb2xvchgGIAEoCVITZnVsbFNjcmVlblRleHRDb2xvchI7ChFiYWNrZ3JvdW5kSW'
    '1hZ2VWMhgHIAEoCzINLmRvdXlpbi5JbWFnZVIRYmFja2dyb3VuZEltYWdlVjISRAoQcHVibGlj'
    'QXJlYUNvbW1vbhgIIAEoCzIYLmRvdXlpbi5QdWJsaWNBcmVhQ29tbW9uUhBwdWJsaWNBcmVhQ2'
    '9tbW9uEisKCWdpZnRJbWFnZRgJIAEoCzINLmRvdXlpbi5JbWFnZVIJZ2lmdEltYWdlEh4KCmFn'
    'cmVlTXNnSWQYCyABKARSCmFncmVlTXNnSWQSJAoNcHJpb3JpdHlMZXZlbBgMIAEoDVINcHJpb3'
    'JpdHlMZXZlbBJNChNsYW5kc2NhcGVBcmVhQ29tbW9uGA0gASgLMhsuZG91eWluLkxhbmRzY2Fw'
    'ZUFyZWFDb21tb25SE2xhbmRzY2FwZUFyZWFDb21tb24SHAoJZXZlbnRUaW1lGA8gASgEUglldm'
    'VudFRpbWUSHgoKc2VuZFJldmlldxgQIAEoCFIKc2VuZFJldmlldxIiCgxmcm9tSW50ZXJjb20Y'
    'ESABKAhSDGZyb21JbnRlcmNvbRIyChRpbnRlcmNvbUhpZGVVc2VyQ2FyZBgSIAEoCFIUaW50ZX'
    'Jjb21IaWRlVXNlckNhcmQSFgoGY2hhdEJ5GBQgASgJUgZjaGF0QnkSNgoWaW5kaXZpZHVhbENo'
    'YXRQcmlvcml0eRgVIAEoDVIWaW5kaXZpZHVhbENoYXRQcmlvcml0eRIsCgpydGZDb250ZW50GB'
    'YgASgLMgwuZG91eWluLlRleHRSCnJ0ZkNvbnRlbnQ=');

@$core.Deprecated('Use landscapeAreaCommonDescriptor instead')
const LandscapeAreaCommon$json = {
  '1': 'LandscapeAreaCommon',
  '2': [
    {'1': 'showHead', '3': 1, '4': 1, '5': 8, '10': 'showHead'},
    {'1': 'showNickname', '3': 2, '4': 1, '5': 8, '10': 'showNickname'},
    {'1': 'showFontColor', '3': 3, '4': 1, '5': 8, '10': 'showFontColor'},
    {'1': 'colorValueList', '3': 4, '4': 3, '5': 9, '10': 'colorValueList'},
    {'1': 'commentTypeTagsList', '3': 5, '4': 3, '5': 14, '6': '.douyin.CommentTypeTag', '10': 'commentTypeTagsList'},
  ],
};

/// Descriptor for `LandscapeAreaCommon`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List landscapeAreaCommonDescriptor = $convert.base64Decode(
    'ChNMYW5kc2NhcGVBcmVhQ29tbW9uEhoKCHNob3dIZWFkGAEgASgIUghzaG93SGVhZBIiCgxzaG'
    '93Tmlja25hbWUYAiABKAhSDHNob3dOaWNrbmFtZRIkCg1zaG93Rm9udENvbG9yGAMgASgIUg1z'
    'aG93Rm9udENvbG9yEiYKDmNvbG9yVmFsdWVMaXN0GAQgAygJUg5jb2xvclZhbHVlTGlzdBJICh'
    'Njb21tZW50VHlwZVRhZ3NMaXN0GAUgAygOMhYuZG91eWluLkNvbW1lbnRUeXBlVGFnUhNjb21t'
    'ZW50VHlwZVRhZ3NMaXN0');

@$core.Deprecated('Use roomUserSeqMessageDescriptor instead')
const RoomUserSeqMessage$json = {
  '1': 'RoomUserSeqMessage',
  '2': [
    {'1': 'common', '3': 1, '4': 1, '5': 11, '6': '.douyin.Common', '10': 'common'},
    {'1': 'ranksList', '3': 2, '4': 3, '5': 11, '6': '.douyin.RoomUserSeqMessageContributor', '10': 'ranksList'},
    {'1': 'total', '3': 3, '4': 1, '5': 3, '10': 'total'},
    {'1': 'popStr', '3': 4, '4': 1, '5': 9, '10': 'popStr'},
    {'1': 'seatsList', '3': 5, '4': 3, '5': 11, '6': '.douyin.RoomUserSeqMessageContributor', '10': 'seatsList'},
    {'1': 'popularity', '3': 6, '4': 1, '5': 3, '10': 'popularity'},
    {'1': 'totalUser', '3': 7, '4': 1, '5': 3, '10': 'totalUser'},
    {'1': 'totalUserStr', '3': 8, '4': 1, '5': 9, '10': 'totalUserStr'},
    {'1': 'totalStr', '3': 9, '4': 1, '5': 9, '10': 'totalStr'},
    {'1': 'onlineUserForAnchor', '3': 10, '4': 1, '5': 9, '10': 'onlineUserForAnchor'},
    {'1': 'totalPvForAnchor', '3': 11, '4': 1, '5': 9, '10': 'totalPvForAnchor'},
    {'1': 'upRightStatsStr', '3': 12, '4': 1, '5': 9, '10': 'upRightStatsStr'},
    {'1': 'upRightStatsStrComplete', '3': 13, '4': 1, '5': 9, '10': 'upRightStatsStrComplete'},
  ],
};

/// Descriptor for `RoomUserSeqMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roomUserSeqMessageDescriptor = $convert.base64Decode(
    'ChJSb29tVXNlclNlcU1lc3NhZ2USJgoGY29tbW9uGAEgASgLMg4uZG91eWluLkNvbW1vblIGY2'
    '9tbW9uEkMKCXJhbmtzTGlzdBgCIAMoCzIlLmRvdXlpbi5Sb29tVXNlclNlcU1lc3NhZ2VDb250'
    'cmlidXRvclIJcmFua3NMaXN0EhQKBXRvdGFsGAMgASgDUgV0b3RhbBIWCgZwb3BTdHIYBCABKA'
    'lSBnBvcFN0chJDCglzZWF0c0xpc3QYBSADKAsyJS5kb3V5aW4uUm9vbVVzZXJTZXFNZXNzYWdl'
    'Q29udHJpYnV0b3JSCXNlYXRzTGlzdBIeCgpwb3B1bGFyaXR5GAYgASgDUgpwb3B1bGFyaXR5Eh'
    'wKCXRvdGFsVXNlchgHIAEoA1IJdG90YWxVc2VyEiIKDHRvdGFsVXNlclN0chgIIAEoCVIMdG90'
    'YWxVc2VyU3RyEhoKCHRvdGFsU3RyGAkgASgJUgh0b3RhbFN0chIwChNvbmxpbmVVc2VyRm9yQW'
    '5jaG9yGAogASgJUhNvbmxpbmVVc2VyRm9yQW5jaG9yEioKEHRvdGFsUHZGb3JBbmNob3IYCyAB'
    'KAlSEHRvdGFsUHZGb3JBbmNob3ISKAoPdXBSaWdodFN0YXRzU3RyGAwgASgJUg91cFJpZ2h0U3'
    'RhdHNTdHISOAoXdXBSaWdodFN0YXRzU3RyQ29tcGxldGUYDSABKAlSF3VwUmlnaHRTdGF0c1N0'
    'ckNvbXBsZXRl');

@$core.Deprecated('Use commonTextMessageDescriptor instead')
const CommonTextMessage$json = {
  '1': 'CommonTextMessage',
  '2': [
    {'1': 'common', '3': 1, '4': 1, '5': 11, '6': '.douyin.Common', '10': 'common'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.douyin.User', '10': 'user'},
    {'1': 'scene', '3': 3, '4': 1, '5': 9, '10': 'scene'},
  ],
};

/// Descriptor for `CommonTextMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonTextMessageDescriptor = $convert.base64Decode(
    'ChFDb21tb25UZXh0TWVzc2FnZRImCgZjb21tb24YASABKAsyDi5kb3V5aW4uQ29tbW9uUgZjb2'
    '1tb24SIAoEdXNlchgCIAEoCzIMLmRvdXlpbi5Vc2VyUgR1c2VyEhQKBXNjZW5lGAMgASgJUgVz'
    'Y2VuZQ==');

@$core.Deprecated('Use updateFanTicketMessageDescriptor instead')
const UpdateFanTicketMessage$json = {
  '1': 'UpdateFanTicketMessage',
  '2': [
    {'1': 'common', '3': 1, '4': 1, '5': 11, '6': '.douyin.Common', '10': 'common'},
    {'1': 'roomFanTicketCountText', '3': 2, '4': 1, '5': 9, '10': 'roomFanTicketCountText'},
    {'1': 'roomFanTicketCount', '3': 3, '4': 1, '5': 4, '10': 'roomFanTicketCount'},
    {'1': 'forceUpdate', '3': 4, '4': 1, '5': 8, '10': 'forceUpdate'},
  ],
};

/// Descriptor for `UpdateFanTicketMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateFanTicketMessageDescriptor = $convert.base64Decode(
    'ChZVcGRhdGVGYW5UaWNrZXRNZXNzYWdlEiYKBmNvbW1vbhgBIAEoCzIOLmRvdXlpbi5Db21tb2'
    '5SBmNvbW1vbhI2ChZyb29tRmFuVGlja2V0Q291bnRUZXh0GAIgASgJUhZyb29tRmFuVGlja2V0'
    'Q291bnRUZXh0Ei4KEnJvb21GYW5UaWNrZXRDb3VudBgDIAEoBFIScm9vbUZhblRpY2tldENvdW'
    '50EiAKC2ZvcmNlVXBkYXRlGAQgASgIUgtmb3JjZVVwZGF0ZQ==');

@$core.Deprecated('Use roomUserSeqMessageContributorDescriptor instead')
const RoomUserSeqMessageContributor$json = {
  '1': 'RoomUserSeqMessageContributor',
  '2': [
    {'1': 'score', '3': 1, '4': 1, '5': 4, '10': 'score'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.douyin.User', '10': 'user'},
    {'1': 'rank', '3': 3, '4': 1, '5': 4, '10': 'rank'},
    {'1': 'delta', '3': 4, '4': 1, '5': 4, '10': 'delta'},
    {'1': 'isHidden', '3': 5, '4': 1, '5': 8, '10': 'isHidden'},
    {'1': 'scoreDescription', '3': 6, '4': 1, '5': 9, '10': 'scoreDescription'},
    {'1': 'exactlyScore', '3': 7, '4': 1, '5': 9, '10': 'exactlyScore'},
  ],
};

/// Descriptor for `RoomUserSeqMessageContributor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List roomUserSeqMessageContributorDescriptor = $convert.base64Decode(
    'Ch1Sb29tVXNlclNlcU1lc3NhZ2VDb250cmlidXRvchIUCgVzY29yZRgBIAEoBFIFc2NvcmUSIA'
    'oEdXNlchgCIAEoCzIMLmRvdXlpbi5Vc2VyUgR1c2VyEhIKBHJhbmsYAyABKARSBHJhbmsSFAoF'
    'ZGVsdGEYBCABKARSBWRlbHRhEhoKCGlzSGlkZGVuGAUgASgIUghpc0hpZGRlbhIqChBzY29yZU'
    'Rlc2NyaXB0aW9uGAYgASgJUhBzY29yZURlc2NyaXB0aW9uEiIKDGV4YWN0bHlTY29yZRgHIAEo'
    'CVIMZXhhY3RseVNjb3Jl');

@$core.Deprecated('Use giftMessageDescriptor instead')
const GiftMessage$json = {
  '1': 'GiftMessage',
  '2': [
    {'1': 'common', '3': 1, '4': 1, '5': 11, '6': '.douyin.Common', '10': 'common'},
    {'1': 'giftId', '3': 2, '4': 1, '5': 4, '10': 'giftId'},
    {'1': 'fanTicketCount', '3': 3, '4': 1, '5': 4, '10': 'fanTicketCount'},
    {'1': 'groupCount', '3': 4, '4': 1, '5': 4, '10': 'groupCount'},
    {'1': 'repeatCount', '3': 5, '4': 1, '5': 4, '10': 'repeatCount'},
    {'1': 'comboCount', '3': 6, '4': 1, '5': 4, '10': 'comboCount'},
    {'1': 'user', '3': 7, '4': 1, '5': 11, '6': '.douyin.User', '10': 'user'},
    {'1': 'toUser', '3': 8, '4': 1, '5': 11, '6': '.douyin.User', '10': 'toUser'},
    {'1': 'repeatEnd', '3': 9, '4': 1, '5': 13, '10': 'repeatEnd'},
    {'1': 'textEffect', '3': 10, '4': 1, '5': 11, '6': '.douyin.TextEffect', '10': 'textEffect'},
    {'1': 'groupId', '3': 11, '4': 1, '5': 4, '10': 'groupId'},
    {'1': 'incomeTaskgifts', '3': 12, '4': 1, '5': 4, '10': 'incomeTaskgifts'},
    {'1': 'roomFanTicketCount', '3': 13, '4': 1, '5': 4, '10': 'roomFanTicketCount'},
    {'1': 'priority', '3': 14, '4': 1, '5': 11, '6': '.douyin.GiftIMPriority', '10': 'priority'},
    {'1': 'gift', '3': 15, '4': 1, '5': 11, '6': '.douyin.GiftStruct', '10': 'gift'},
    {'1': 'logId', '3': 16, '4': 1, '5': 9, '10': 'logId'},
    {'1': 'sendType', '3': 17, '4': 1, '5': 4, '10': 'sendType'},
    {'1': 'publicAreaCommon', '3': 18, '4': 1, '5': 11, '6': '.douyin.PublicAreaCommon', '10': 'publicAreaCommon'},
    {'1': 'trayDisplayText', '3': 19, '4': 1, '5': 11, '6': '.douyin.Text', '10': 'trayDisplayText'},
    {'1': 'bannedDisplayEffects', '3': 20, '4': 1, '5': 4, '10': 'bannedDisplayEffects'},
    {'1': 'displayForSelf', '3': 25, '4': 1, '5': 8, '10': 'displayForSelf'},
    {'1': 'interactGiftInfo', '3': 26, '4': 1, '5': 9, '10': 'interactGiftInfo'},
    {'1': 'diyItemInfo', '3': 27, '4': 1, '5': 9, '10': 'diyItemInfo'},
    {'1': 'minAssetSetList', '3': 28, '4': 3, '5': 4, '10': 'minAssetSetList'},
    {'1': 'totalCount', '3': 29, '4': 1, '5': 4, '10': 'totalCount'},
    {'1': 'clientGiftSource', '3': 30, '4': 1, '5': 13, '10': 'clientGiftSource'},
    {'1': 'toUserIdsList', '3': 32, '4': 3, '5': 4, '10': 'toUserIdsList'},
    {'1': 'sendTime', '3': 33, '4': 1, '5': 4, '10': 'sendTime'},
    {'1': 'forceDisplayEffects', '3': 34, '4': 1, '5': 4, '10': 'forceDisplayEffects'},
    {'1': 'traceId', '3': 35, '4': 1, '5': 9, '10': 'traceId'},
    {'1': 'effectDisplayTs', '3': 36, '4': 1, '5': 4, '10': 'effectDisplayTs'},
  ],
};

/// Descriptor for `GiftMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List giftMessageDescriptor = $convert.base64Decode(
    'CgtHaWZ0TWVzc2FnZRImCgZjb21tb24YASABKAsyDi5kb3V5aW4uQ29tbW9uUgZjb21tb24SFg'
    'oGZ2lmdElkGAIgASgEUgZnaWZ0SWQSJgoOZmFuVGlja2V0Q291bnQYAyABKARSDmZhblRpY2tl'
    'dENvdW50Eh4KCmdyb3VwQ291bnQYBCABKARSCmdyb3VwQ291bnQSIAoLcmVwZWF0Q291bnQYBS'
    'ABKARSC3JlcGVhdENvdW50Eh4KCmNvbWJvQ291bnQYBiABKARSCmNvbWJvQ291bnQSIAoEdXNl'
    'chgHIAEoCzIMLmRvdXlpbi5Vc2VyUgR1c2VyEiQKBnRvVXNlchgIIAEoCzIMLmRvdXlpbi5Vc2'
    'VyUgZ0b1VzZXISHAoJcmVwZWF0RW5kGAkgASgNUglyZXBlYXRFbmQSMgoKdGV4dEVmZmVjdBgK'
    'IAEoCzISLmRvdXlpbi5UZXh0RWZmZWN0Ugp0ZXh0RWZmZWN0EhgKB2dyb3VwSWQYCyABKARSB2'
    'dyb3VwSWQSKAoPaW5jb21lVGFza2dpZnRzGAwgASgEUg9pbmNvbWVUYXNrZ2lmdHMSLgoScm9v'
    'bUZhblRpY2tldENvdW50GA0gASgEUhJyb29tRmFuVGlja2V0Q291bnQSMgoIcHJpb3JpdHkYDi'
    'ABKAsyFi5kb3V5aW4uR2lmdElNUHJpb3JpdHlSCHByaW9yaXR5EiYKBGdpZnQYDyABKAsyEi5k'
    'b3V5aW4uR2lmdFN0cnVjdFIEZ2lmdBIUCgVsb2dJZBgQIAEoCVIFbG9nSWQSGgoIc2VuZFR5cG'
    'UYESABKARSCHNlbmRUeXBlEkQKEHB1YmxpY0FyZWFDb21tb24YEiABKAsyGC5kb3V5aW4uUHVi'
    'bGljQXJlYUNvbW1vblIQcHVibGljQXJlYUNvbW1vbhI2Cg90cmF5RGlzcGxheVRleHQYEyABKA'
    'syDC5kb3V5aW4uVGV4dFIPdHJheURpc3BsYXlUZXh0EjIKFGJhbm5lZERpc3BsYXlFZmZlY3Rz'
    'GBQgASgEUhRiYW5uZWREaXNwbGF5RWZmZWN0cxImCg5kaXNwbGF5Rm9yU2VsZhgZIAEoCFIOZG'
    'lzcGxheUZvclNlbGYSKgoQaW50ZXJhY3RHaWZ0SW5mbxgaIAEoCVIQaW50ZXJhY3RHaWZ0SW5m'
    'bxIgCgtkaXlJdGVtSW5mbxgbIAEoCVILZGl5SXRlbUluZm8SKAoPbWluQXNzZXRTZXRMaXN0GB'
    'wgAygEUg9taW5Bc3NldFNldExpc3QSHgoKdG90YWxDb3VudBgdIAEoBFIKdG90YWxDb3VudBIq'
    'ChBjbGllbnRHaWZ0U291cmNlGB4gASgNUhBjbGllbnRHaWZ0U291cmNlEiQKDXRvVXNlcklkc0'
    'xpc3QYICADKARSDXRvVXNlcklkc0xpc3QSGgoIc2VuZFRpbWUYISABKARSCHNlbmRUaW1lEjAK'
    'E2ZvcmNlRGlzcGxheUVmZmVjdHMYIiABKARSE2ZvcmNlRGlzcGxheUVmZmVjdHMSGAoHdHJhY2'
    'VJZBgjIAEoCVIHdHJhY2VJZBIoCg9lZmZlY3REaXNwbGF5VHMYJCABKARSD2VmZmVjdERpc3Bs'
    'YXlUcw==');

@$core.Deprecated('Use giftStructDescriptor instead')
const GiftStruct$json = {
  '1': 'GiftStruct',
  '2': [
    {'1': 'image', '3': 1, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'image'},
    {'1': 'describe', '3': 2, '4': 1, '5': 9, '10': 'describe'},
    {'1': 'notify', '3': 3, '4': 1, '5': 8, '10': 'notify'},
    {'1': 'duration', '3': 4, '4': 1, '5': 4, '10': 'duration'},
    {'1': 'id', '3': 5, '4': 1, '5': 4, '10': 'id'},
    {'1': 'forLinkmic', '3': 7, '4': 1, '5': 8, '10': 'forLinkmic'},
    {'1': 'doodle', '3': 8, '4': 1, '5': 8, '10': 'doodle'},
    {'1': 'forFansclub', '3': 9, '4': 1, '5': 8, '10': 'forFansclub'},
    {'1': 'combo', '3': 10, '4': 1, '5': 8, '10': 'combo'},
    {'1': 'type', '3': 11, '4': 1, '5': 13, '10': 'type'},
    {'1': 'diamondCount', '3': 12, '4': 1, '5': 13, '10': 'diamondCount'},
    {'1': 'isDisplayedOnPanel', '3': 13, '4': 1, '5': 8, '10': 'isDisplayedOnPanel'},
    {'1': 'primaryEffectId', '3': 14, '4': 1, '5': 4, '10': 'primaryEffectId'},
    {'1': 'giftLabelIcon', '3': 15, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'giftLabelIcon'},
    {'1': 'name', '3': 16, '4': 1, '5': 9, '10': 'name'},
    {'1': 'region', '3': 17, '4': 1, '5': 9, '10': 'region'},
    {'1': 'manual', '3': 18, '4': 1, '5': 9, '10': 'manual'},
    {'1': 'forCustom', '3': 19, '4': 1, '5': 8, '10': 'forCustom'},
    {'1': 'icon', '3': 21, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'icon'},
    {'1': 'actionType', '3': 22, '4': 1, '5': 13, '10': 'actionType'},
  ],
};

/// Descriptor for `GiftStruct`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List giftStructDescriptor = $convert.base64Decode(
    'CgpHaWZ0U3RydWN0EiMKBWltYWdlGAEgASgLMg0uZG91eWluLkltYWdlUgVpbWFnZRIaCghkZX'
    'NjcmliZRgCIAEoCVIIZGVzY3JpYmUSFgoGbm90aWZ5GAMgASgIUgZub3RpZnkSGgoIZHVyYXRp'
    'b24YBCABKARSCGR1cmF0aW9uEg4KAmlkGAUgASgEUgJpZBIeCgpmb3JMaW5rbWljGAcgASgIUg'
    'pmb3JMaW5rbWljEhYKBmRvb2RsZRgIIAEoCFIGZG9vZGxlEiAKC2ZvckZhbnNjbHViGAkgASgI'
    'Ugtmb3JGYW5zY2x1YhIUCgVjb21ibxgKIAEoCFIFY29tYm8SEgoEdHlwZRgLIAEoDVIEdHlwZR'
    'IiCgxkaWFtb25kQ291bnQYDCABKA1SDGRpYW1vbmRDb3VudBIuChJpc0Rpc3BsYXllZE9uUGFu'
    'ZWwYDSABKAhSEmlzRGlzcGxheWVkT25QYW5lbBIoCg9wcmltYXJ5RWZmZWN0SWQYDiABKARSD3'
    'ByaW1hcnlFZmZlY3RJZBIzCg1naWZ0TGFiZWxJY29uGA8gASgLMg0uZG91eWluLkltYWdlUg1n'
    'aWZ0TGFiZWxJY29uEhIKBG5hbWUYECABKAlSBG5hbWUSFgoGcmVnaW9uGBEgASgJUgZyZWdpb2'
    '4SFgoGbWFudWFsGBIgASgJUgZtYW51YWwSHAoJZm9yQ3VzdG9tGBMgASgIUglmb3JDdXN0b20S'
    'IQoEaWNvbhgVIAEoCzINLmRvdXlpbi5JbWFnZVIEaWNvbhIeCgphY3Rpb25UeXBlGBYgASgNUg'
    'phY3Rpb25UeXBl');

@$core.Deprecated('Use giftIMPriorityDescriptor instead')
const GiftIMPriority$json = {
  '1': 'GiftIMPriority',
  '2': [
    {'1': 'queueSizesList', '3': 1, '4': 3, '5': 4, '10': 'queueSizesList'},
    {'1': 'selfQueuePriority', '3': 2, '4': 1, '5': 4, '10': 'selfQueuePriority'},
    {'1': 'priority', '3': 3, '4': 1, '5': 4, '10': 'priority'},
  ],
};

/// Descriptor for `GiftIMPriority`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List giftIMPriorityDescriptor = $convert.base64Decode(
    'Cg5HaWZ0SU1Qcmlvcml0eRImCg5xdWV1ZVNpemVzTGlzdBgBIAMoBFIOcXVldWVTaXplc0xpc3'
    'QSLAoRc2VsZlF1ZXVlUHJpb3JpdHkYAiABKARSEXNlbGZRdWV1ZVByaW9yaXR5EhoKCHByaW9y'
    'aXR5GAMgASgEUghwcmlvcml0eQ==');

@$core.Deprecated('Use textEffectDescriptor instead')
const TextEffect$json = {
  '1': 'TextEffect',
  '2': [
    {'1': 'portrait', '3': 1, '4': 1, '5': 11, '6': '.douyin.TextEffectDetail', '10': 'portrait'},
    {'1': 'landscape', '3': 2, '4': 1, '5': 11, '6': '.douyin.TextEffectDetail', '10': 'landscape'},
  ],
};

/// Descriptor for `TextEffect`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textEffectDescriptor = $convert.base64Decode(
    'CgpUZXh0RWZmZWN0EjQKCHBvcnRyYWl0GAEgASgLMhguZG91eWluLlRleHRFZmZlY3REZXRhaW'
    'xSCHBvcnRyYWl0EjYKCWxhbmRzY2FwZRgCIAEoCzIYLmRvdXlpbi5UZXh0RWZmZWN0RGV0YWls'
    'UglsYW5kc2NhcGU=');

@$core.Deprecated('Use textEffectDetailDescriptor instead')
const TextEffectDetail$json = {
  '1': 'TextEffectDetail',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 11, '6': '.douyin.Text', '10': 'text'},
    {'1': 'textFontSize', '3': 2, '4': 1, '5': 13, '10': 'textFontSize'},
    {'1': 'background', '3': 3, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'background'},
    {'1': 'start', '3': 4, '4': 1, '5': 13, '10': 'start'},
    {'1': 'duration', '3': 5, '4': 1, '5': 13, '10': 'duration'},
    {'1': 'x', '3': 6, '4': 1, '5': 13, '10': 'x'},
    {'1': 'y', '3': 7, '4': 1, '5': 13, '10': 'y'},
    {'1': 'width', '3': 8, '4': 1, '5': 13, '10': 'width'},
    {'1': 'height', '3': 9, '4': 1, '5': 13, '10': 'height'},
    {'1': 'shadowDx', '3': 10, '4': 1, '5': 13, '10': 'shadowDx'},
    {'1': 'shadowDy', '3': 11, '4': 1, '5': 13, '10': 'shadowDy'},
    {'1': 'shadowRadius', '3': 12, '4': 1, '5': 13, '10': 'shadowRadius'},
    {'1': 'shadowColor', '3': 13, '4': 1, '5': 9, '10': 'shadowColor'},
    {'1': 'strokeColor', '3': 14, '4': 1, '5': 9, '10': 'strokeColor'},
    {'1': 'strokeWidth', '3': 15, '4': 1, '5': 13, '10': 'strokeWidth'},
  ],
};

/// Descriptor for `TextEffectDetail`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textEffectDetailDescriptor = $convert.base64Decode(
    'ChBUZXh0RWZmZWN0RGV0YWlsEiAKBHRleHQYASABKAsyDC5kb3V5aW4uVGV4dFIEdGV4dBIiCg'
    'x0ZXh0Rm9udFNpemUYAiABKA1SDHRleHRGb250U2l6ZRItCgpiYWNrZ3JvdW5kGAMgASgLMg0u'
    'ZG91eWluLkltYWdlUgpiYWNrZ3JvdW5kEhQKBXN0YXJ0GAQgASgNUgVzdGFydBIaCghkdXJhdG'
    'lvbhgFIAEoDVIIZHVyYXRpb24SDAoBeBgGIAEoDVIBeBIMCgF5GAcgASgNUgF5EhQKBXdpZHRo'
    'GAggASgNUgV3aWR0aBIWCgZoZWlnaHQYCSABKA1SBmhlaWdodBIaCghzaGFkb3dEeBgKIAEoDV'
    'IIc2hhZG93RHgSGgoIc2hhZG93RHkYCyABKA1SCHNoYWRvd0R5EiIKDHNoYWRvd1JhZGl1cxgM'
    'IAEoDVIMc2hhZG93UmFkaXVzEiAKC3NoYWRvd0NvbG9yGA0gASgJUgtzaGFkb3dDb2xvchIgCg'
    'tzdHJva2VDb2xvchgOIAEoCVILc3Ryb2tlQ29sb3ISIAoLc3Ryb2tlV2lkdGgYDyABKA1SC3N0'
    'cm9rZVdpZHRo');

@$core.Deprecated('Use memberMessageDescriptor instead')
const MemberMessage$json = {
  '1': 'MemberMessage',
  '2': [
    {'1': 'common', '3': 1, '4': 1, '5': 11, '6': '.douyin.Common', '10': 'common'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.douyin.User', '10': 'user'},
    {'1': 'memberCount', '3': 3, '4': 1, '5': 4, '10': 'memberCount'},
    {'1': 'operator', '3': 4, '4': 1, '5': 11, '6': '.douyin.User', '10': 'operator'},
    {'1': 'isSetToAdmin', '3': 5, '4': 1, '5': 8, '10': 'isSetToAdmin'},
    {'1': 'isTopUser', '3': 6, '4': 1, '5': 8, '10': 'isTopUser'},
    {'1': 'rankScore', '3': 7, '4': 1, '5': 4, '10': 'rankScore'},
    {'1': 'topUserNo', '3': 8, '4': 1, '5': 4, '10': 'topUserNo'},
    {'1': 'enterType', '3': 9, '4': 1, '5': 4, '10': 'enterType'},
    {'1': 'action', '3': 10, '4': 1, '5': 4, '10': 'action'},
    {'1': 'actionDescription', '3': 11, '4': 1, '5': 9, '10': 'actionDescription'},
    {'1': 'userId', '3': 12, '4': 1, '5': 4, '10': 'userId'},
    {'1': 'effectConfig', '3': 13, '4': 1, '5': 11, '6': '.douyin.EffectConfig', '10': 'effectConfig'},
    {'1': 'popStr', '3': 14, '4': 1, '5': 9, '10': 'popStr'},
    {'1': 'enterEffectConfig', '3': 15, '4': 1, '5': 11, '6': '.douyin.EffectConfig', '10': 'enterEffectConfig'},
    {'1': 'backgroundImage', '3': 16, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'backgroundImage'},
    {'1': 'backgroundImageV2', '3': 17, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'backgroundImageV2'},
    {'1': 'anchorDisplayText', '3': 18, '4': 1, '5': 11, '6': '.douyin.Text', '10': 'anchorDisplayText'},
    {'1': 'publicAreaCommon', '3': 19, '4': 1, '5': 11, '6': '.douyin.PublicAreaCommon', '10': 'publicAreaCommon'},
    {'1': 'userEnterTipType', '3': 20, '4': 1, '5': 4, '10': 'userEnterTipType'},
    {'1': 'anchorEnterTipType', '3': 21, '4': 1, '5': 4, '10': 'anchorEnterTipType'},
  ],
};

/// Descriptor for `MemberMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List memberMessageDescriptor = $convert.base64Decode(
    'Cg1NZW1iZXJNZXNzYWdlEiYKBmNvbW1vbhgBIAEoCzIOLmRvdXlpbi5Db21tb25SBmNvbW1vbh'
    'IgCgR1c2VyGAIgASgLMgwuZG91eWluLlVzZXJSBHVzZXISIAoLbWVtYmVyQ291bnQYAyABKARS'
    'C21lbWJlckNvdW50EigKCG9wZXJhdG9yGAQgASgLMgwuZG91eWluLlVzZXJSCG9wZXJhdG9yEi'
    'IKDGlzU2V0VG9BZG1pbhgFIAEoCFIMaXNTZXRUb0FkbWluEhwKCWlzVG9wVXNlchgGIAEoCFIJ'
    'aXNUb3BVc2VyEhwKCXJhbmtTY29yZRgHIAEoBFIJcmFua1Njb3JlEhwKCXRvcFVzZXJObxgIIA'
    'EoBFIJdG9wVXNlck5vEhwKCWVudGVyVHlwZRgJIAEoBFIJZW50ZXJUeXBlEhYKBmFjdGlvbhgK'
    'IAEoBFIGYWN0aW9uEiwKEWFjdGlvbkRlc2NyaXB0aW9uGAsgASgJUhFhY3Rpb25EZXNjcmlwdG'
    'lvbhIWCgZ1c2VySWQYDCABKARSBnVzZXJJZBI4CgxlZmZlY3RDb25maWcYDSABKAsyFC5kb3V5'
    'aW4uRWZmZWN0Q29uZmlnUgxlZmZlY3RDb25maWcSFgoGcG9wU3RyGA4gASgJUgZwb3BTdHISQg'
    'oRZW50ZXJFZmZlY3RDb25maWcYDyABKAsyFC5kb3V5aW4uRWZmZWN0Q29uZmlnUhFlbnRlckVm'
    'ZmVjdENvbmZpZxI3Cg9iYWNrZ3JvdW5kSW1hZ2UYECABKAsyDS5kb3V5aW4uSW1hZ2VSD2JhY2'
    'tncm91bmRJbWFnZRI7ChFiYWNrZ3JvdW5kSW1hZ2VWMhgRIAEoCzINLmRvdXlpbi5JbWFnZVIR'
    'YmFja2dyb3VuZEltYWdlVjISOgoRYW5jaG9yRGlzcGxheVRleHQYEiABKAsyDC5kb3V5aW4uVG'
    'V4dFIRYW5jaG9yRGlzcGxheVRleHQSRAoQcHVibGljQXJlYUNvbW1vbhgTIAEoCzIYLmRvdXlp'
    'bi5QdWJsaWNBcmVhQ29tbW9uUhBwdWJsaWNBcmVhQ29tbW9uEioKEHVzZXJFbnRlclRpcFR5cG'
    'UYFCABKARSEHVzZXJFbnRlclRpcFR5cGUSLgoSYW5jaG9yRW50ZXJUaXBUeXBlGBUgASgEUhJh'
    'bmNob3JFbnRlclRpcFR5cGU=');

@$core.Deprecated('Use publicAreaCommonDescriptor instead')
const PublicAreaCommon$json = {
  '1': 'PublicAreaCommon',
  '2': [
    {'1': 'userLabel', '3': 1, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'userLabel'},
    {'1': 'userConsumeInRoom', '3': 2, '4': 1, '5': 4, '10': 'userConsumeInRoom'},
    {'1': 'userSendGiftCntInRoom', '3': 3, '4': 1, '5': 4, '10': 'userSendGiftCntInRoom'},
  ],
};

/// Descriptor for `PublicAreaCommon`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List publicAreaCommonDescriptor = $convert.base64Decode(
    'ChBQdWJsaWNBcmVhQ29tbW9uEisKCXVzZXJMYWJlbBgBIAEoCzINLmRvdXlpbi5JbWFnZVIJdX'
    'NlckxhYmVsEiwKEXVzZXJDb25zdW1lSW5Sb29tGAIgASgEUhF1c2VyQ29uc3VtZUluUm9vbRI0'
    'ChV1c2VyU2VuZEdpZnRDbnRJblJvb20YAyABKARSFXVzZXJTZW5kR2lmdENudEluUm9vbQ==');

@$core.Deprecated('Use effectConfigDescriptor instead')
const EffectConfig$json = {
  '1': 'EffectConfig',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 4, '10': 'type'},
    {'1': 'icon', '3': 2, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'icon'},
    {'1': 'avatarPos', '3': 3, '4': 1, '5': 4, '10': 'avatarPos'},
    {'1': 'text', '3': 4, '4': 1, '5': 11, '6': '.douyin.Text', '10': 'text'},
    {'1': 'textIcon', '3': 5, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'textIcon'},
    {'1': 'stayTime', '3': 6, '4': 1, '5': 13, '10': 'stayTime'},
    {'1': 'animAssetId', '3': 7, '4': 1, '5': 4, '10': 'animAssetId'},
    {'1': 'badge', '3': 8, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'badge'},
    {'1': 'flexSettingArrayList', '3': 9, '4': 3, '5': 4, '10': 'flexSettingArrayList'},
    {'1': 'textIconOverlay', '3': 10, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'textIconOverlay'},
    {'1': 'animatedBadge', '3': 11, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'animatedBadge'},
    {'1': 'hasSweepLight', '3': 12, '4': 1, '5': 8, '10': 'hasSweepLight'},
    {'1': 'textFlexSettingArrayList', '3': 13, '4': 3, '5': 4, '10': 'textFlexSettingArrayList'},
    {'1': 'centerAnimAssetId', '3': 14, '4': 1, '5': 4, '10': 'centerAnimAssetId'},
    {'1': 'dynamicImage', '3': 15, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'dynamicImage'},
    {'1': 'extraMap', '3': 16, '4': 3, '5': 11, '6': '.douyin.EffectConfig.ExtraMapEntry', '10': 'extraMap'},
    {'1': 'mp4AnimAssetId', '3': 17, '4': 1, '5': 4, '10': 'mp4AnimAssetId'},
    {'1': 'priority', '3': 18, '4': 1, '5': 4, '10': 'priority'},
    {'1': 'maxWaitTime', '3': 19, '4': 1, '5': 4, '10': 'maxWaitTime'},
    {'1': 'dressId', '3': 20, '4': 1, '5': 9, '10': 'dressId'},
    {'1': 'alignment', '3': 21, '4': 1, '5': 4, '10': 'alignment'},
    {'1': 'alignmentOffset', '3': 22, '4': 1, '5': 4, '10': 'alignmentOffset'},
  ],
  '3': [EffectConfig_ExtraMapEntry$json],
};

@$core.Deprecated('Use effectConfigDescriptor instead')
const EffectConfig_ExtraMapEntry$json = {
  '1': 'ExtraMapEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `EffectConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List effectConfigDescriptor = $convert.base64Decode(
    'CgxFZmZlY3RDb25maWcSEgoEdHlwZRgBIAEoBFIEdHlwZRIhCgRpY29uGAIgASgLMg0uZG91eW'
    'luLkltYWdlUgRpY29uEhwKCWF2YXRhclBvcxgDIAEoBFIJYXZhdGFyUG9zEiAKBHRleHQYBCAB'
    'KAsyDC5kb3V5aW4uVGV4dFIEdGV4dBIpCgh0ZXh0SWNvbhgFIAEoCzINLmRvdXlpbi5JbWFnZV'
    'IIdGV4dEljb24SGgoIc3RheVRpbWUYBiABKA1SCHN0YXlUaW1lEiAKC2FuaW1Bc3NldElkGAcg'
    'ASgEUgthbmltQXNzZXRJZBIjCgViYWRnZRgIIAEoCzINLmRvdXlpbi5JbWFnZVIFYmFkZ2USMg'
    'oUZmxleFNldHRpbmdBcnJheUxpc3QYCSADKARSFGZsZXhTZXR0aW5nQXJyYXlMaXN0EjcKD3Rl'
    'eHRJY29uT3ZlcmxheRgKIAEoCzINLmRvdXlpbi5JbWFnZVIPdGV4dEljb25PdmVybGF5EjMKDW'
    'FuaW1hdGVkQmFkZ2UYCyABKAsyDS5kb3V5aW4uSW1hZ2VSDWFuaW1hdGVkQmFkZ2USJAoNaGFz'
    'U3dlZXBMaWdodBgMIAEoCFINaGFzU3dlZXBMaWdodBI6Chh0ZXh0RmxleFNldHRpbmdBcnJheU'
    'xpc3QYDSADKARSGHRleHRGbGV4U2V0dGluZ0FycmF5TGlzdBIsChFjZW50ZXJBbmltQXNzZXRJ'
    'ZBgOIAEoBFIRY2VudGVyQW5pbUFzc2V0SWQSMQoMZHluYW1pY0ltYWdlGA8gASgLMg0uZG91eW'
    'luLkltYWdlUgxkeW5hbWljSW1hZ2USPgoIZXh0cmFNYXAYECADKAsyIi5kb3V5aW4uRWZmZWN0'
    'Q29uZmlnLkV4dHJhTWFwRW50cnlSCGV4dHJhTWFwEiYKDm1wNEFuaW1Bc3NldElkGBEgASgEUg'
    '5tcDRBbmltQXNzZXRJZBIaCghwcmlvcml0eRgSIAEoBFIIcHJpb3JpdHkSIAoLbWF4V2FpdFRp'
    'bWUYEyABKARSC21heFdhaXRUaW1lEhgKB2RyZXNzSWQYFCABKAlSB2RyZXNzSWQSHAoJYWxpZ2'
    '5tZW50GBUgASgEUglhbGlnbm1lbnQSKAoPYWxpZ25tZW50T2Zmc2V0GBYgASgEUg9hbGlnbm1l'
    'bnRPZmZzZXQaOwoNRXh0cmFNYXBFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIA'
    'EoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use textDescriptor instead')
const Text$json = {
  '1': 'Text',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'defaultPatter', '3': 2, '4': 1, '5': 9, '10': 'defaultPatter'},
    {'1': 'defaultFormat', '3': 3, '4': 1, '5': 11, '6': '.douyin.TextFormat', '10': 'defaultFormat'},
    {'1': 'piecesList', '3': 4, '4': 3, '5': 11, '6': '.douyin.TextPiece', '10': 'piecesList'},
  ],
};

/// Descriptor for `Text`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textDescriptor = $convert.base64Decode(
    'CgRUZXh0EhAKA2tleRgBIAEoCVIDa2V5EiQKDWRlZmF1bHRQYXR0ZXIYAiABKAlSDWRlZmF1bH'
    'RQYXR0ZXISOAoNZGVmYXVsdEZvcm1hdBgDIAEoCzISLmRvdXlpbi5UZXh0Rm9ybWF0Ug1kZWZh'
    'dWx0Rm9ybWF0EjEKCnBpZWNlc0xpc3QYBCADKAsyES5kb3V5aW4uVGV4dFBpZWNlUgpwaWVjZX'
    'NMaXN0');

@$core.Deprecated('Use textPieceDescriptor instead')
const TextPiece$json = {
  '1': 'TextPiece',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 8, '10': 'type'},
    {'1': 'format', '3': 2, '4': 1, '5': 11, '6': '.douyin.TextFormat', '10': 'format'},
    {'1': 'stringValue', '3': 3, '4': 1, '5': 9, '10': 'stringValue'},
    {'1': 'userValue', '3': 4, '4': 1, '5': 11, '6': '.douyin.TextPieceUser', '10': 'userValue'},
    {'1': 'giftValue', '3': 5, '4': 1, '5': 11, '6': '.douyin.TextPieceGift', '10': 'giftValue'},
    {'1': 'heartValue', '3': 6, '4': 1, '5': 11, '6': '.douyin.TextPieceHeart', '10': 'heartValue'},
    {'1': 'patternRefValue', '3': 7, '4': 1, '5': 11, '6': '.douyin.TextPiecePatternRef', '10': 'patternRefValue'},
    {'1': 'imageValue', '3': 8, '4': 1, '5': 11, '6': '.douyin.TextPieceImage', '10': 'imageValue'},
  ],
};

/// Descriptor for `TextPiece`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textPieceDescriptor = $convert.base64Decode(
    'CglUZXh0UGllY2USEgoEdHlwZRgBIAEoCFIEdHlwZRIqCgZmb3JtYXQYAiABKAsyEi5kb3V5aW'
    '4uVGV4dEZvcm1hdFIGZm9ybWF0EiAKC3N0cmluZ1ZhbHVlGAMgASgJUgtzdHJpbmdWYWx1ZRIz'
    'Cgl1c2VyVmFsdWUYBCABKAsyFS5kb3V5aW4uVGV4dFBpZWNlVXNlclIJdXNlclZhbHVlEjMKCW'
    'dpZnRWYWx1ZRgFIAEoCzIVLmRvdXlpbi5UZXh0UGllY2VHaWZ0UglnaWZ0VmFsdWUSNgoKaGVh'
    'cnRWYWx1ZRgGIAEoCzIWLmRvdXlpbi5UZXh0UGllY2VIZWFydFIKaGVhcnRWYWx1ZRJFCg9wYX'
    'R0ZXJuUmVmVmFsdWUYByABKAsyGy5kb3V5aW4uVGV4dFBpZWNlUGF0dGVyblJlZlIPcGF0dGVy'
    'blJlZlZhbHVlEjYKCmltYWdlVmFsdWUYCCABKAsyFi5kb3V5aW4uVGV4dFBpZWNlSW1hZ2VSCm'
    'ltYWdlVmFsdWU=');

@$core.Deprecated('Use textPieceImageDescriptor instead')
const TextPieceImage$json = {
  '1': 'TextPieceImage',
  '2': [
    {'1': 'image', '3': 1, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'image'},
    {'1': 'scalingRate', '3': 2, '4': 1, '5': 2, '10': 'scalingRate'},
  ],
};

/// Descriptor for `TextPieceImage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textPieceImageDescriptor = $convert.base64Decode(
    'Cg5UZXh0UGllY2VJbWFnZRIjCgVpbWFnZRgBIAEoCzINLmRvdXlpbi5JbWFnZVIFaW1hZ2USIA'
    'oLc2NhbGluZ1JhdGUYAiABKAJSC3NjYWxpbmdSYXRl');

@$core.Deprecated('Use textPiecePatternRefDescriptor instead')
const TextPiecePatternRef$json = {
  '1': 'TextPiecePatternRef',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'defaultPattern', '3': 2, '4': 1, '5': 9, '10': 'defaultPattern'},
  ],
};

/// Descriptor for `TextPiecePatternRef`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textPiecePatternRefDescriptor = $convert.base64Decode(
    'ChNUZXh0UGllY2VQYXR0ZXJuUmVmEhAKA2tleRgBIAEoCVIDa2V5EiYKDmRlZmF1bHRQYXR0ZX'
    'JuGAIgASgJUg5kZWZhdWx0UGF0dGVybg==');

@$core.Deprecated('Use textPieceHeartDescriptor instead')
const TextPieceHeart$json = {
  '1': 'TextPieceHeart',
  '2': [
    {'1': 'color', '3': 1, '4': 1, '5': 9, '10': 'color'},
  ],
};

/// Descriptor for `TextPieceHeart`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textPieceHeartDescriptor = $convert.base64Decode(
    'Cg5UZXh0UGllY2VIZWFydBIUCgVjb2xvchgBIAEoCVIFY29sb3I=');

@$core.Deprecated('Use textPieceGiftDescriptor instead')
const TextPieceGift$json = {
  '1': 'TextPieceGift',
  '2': [
    {'1': 'giftId', '3': 1, '4': 1, '5': 4, '10': 'giftId'},
    {'1': 'nameRef', '3': 2, '4': 1, '5': 11, '6': '.douyin.PatternRef', '10': 'nameRef'},
  ],
};

/// Descriptor for `TextPieceGift`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textPieceGiftDescriptor = $convert.base64Decode(
    'Cg1UZXh0UGllY2VHaWZ0EhYKBmdpZnRJZBgBIAEoBFIGZ2lmdElkEiwKB25hbWVSZWYYAiABKA'
    'syEi5kb3V5aW4uUGF0dGVyblJlZlIHbmFtZVJlZg==');

@$core.Deprecated('Use patternRefDescriptor instead')
const PatternRef$json = {
  '1': 'PatternRef',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'defaultPattern', '3': 2, '4': 1, '5': 9, '10': 'defaultPattern'},
  ],
};

/// Descriptor for `PatternRef`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List patternRefDescriptor = $convert.base64Decode(
    'CgpQYXR0ZXJuUmVmEhAKA2tleRgBIAEoCVIDa2V5EiYKDmRlZmF1bHRQYXR0ZXJuGAIgASgJUg'
    '5kZWZhdWx0UGF0dGVybg==');

@$core.Deprecated('Use textPieceUserDescriptor instead')
const TextPieceUser$json = {
  '1': 'TextPieceUser',
  '2': [
    {'1': 'user', '3': 1, '4': 1, '5': 11, '6': '.douyin.User', '10': 'user'},
    {'1': 'withColon', '3': 2, '4': 1, '5': 8, '10': 'withColon'},
  ],
};

/// Descriptor for `TextPieceUser`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textPieceUserDescriptor = $convert.base64Decode(
    'Cg1UZXh0UGllY2VVc2VyEiAKBHVzZXIYASABKAsyDC5kb3V5aW4uVXNlclIEdXNlchIcCgl3aX'
    'RoQ29sb24YAiABKAhSCXdpdGhDb2xvbg==');

@$core.Deprecated('Use textFormatDescriptor instead')
const TextFormat$json = {
  '1': 'TextFormat',
  '2': [
    {'1': 'color', '3': 1, '4': 1, '5': 9, '10': 'color'},
    {'1': 'bold', '3': 2, '4': 1, '5': 8, '10': 'bold'},
    {'1': 'italic', '3': 3, '4': 1, '5': 8, '10': 'italic'},
    {'1': 'weight', '3': 4, '4': 1, '5': 13, '10': 'weight'},
    {'1': 'italicAngle', '3': 5, '4': 1, '5': 13, '10': 'italicAngle'},
    {'1': 'fontSize', '3': 6, '4': 1, '5': 13, '10': 'fontSize'},
    {'1': 'useHeighLightColor', '3': 7, '4': 1, '5': 8, '10': 'useHeighLightColor'},
    {'1': 'useRemoteClor', '3': 8, '4': 1, '5': 8, '10': 'useRemoteClor'},
  ],
};

/// Descriptor for `TextFormat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List textFormatDescriptor = $convert.base64Decode(
    'CgpUZXh0Rm9ybWF0EhQKBWNvbG9yGAEgASgJUgVjb2xvchISCgRib2xkGAIgASgIUgRib2xkEh'
    'YKBml0YWxpYxgDIAEoCFIGaXRhbGljEhYKBndlaWdodBgEIAEoDVIGd2VpZ2h0EiAKC2l0YWxp'
    'Y0FuZ2xlGAUgASgNUgtpdGFsaWNBbmdsZRIaCghmb250U2l6ZRgGIAEoDVIIZm9udFNpemUSLg'
    'oSdXNlSGVpZ2hMaWdodENvbG9yGAcgASgIUhJ1c2VIZWlnaExpZ2h0Q29sb3ISJAoNdXNlUmVt'
    'b3RlQ2xvchgIIAEoCFINdXNlUmVtb3RlQ2xvcg==');

@$core.Deprecated('Use likeMessageDescriptor instead')
const LikeMessage$json = {
  '1': 'LikeMessage',
  '2': [
    {'1': 'common', '3': 1, '4': 1, '5': 11, '6': '.douyin.Common', '10': 'common'},
    {'1': 'count', '3': 2, '4': 1, '5': 4, '10': 'count'},
    {'1': 'total', '3': 3, '4': 1, '5': 4, '10': 'total'},
    {'1': 'color', '3': 4, '4': 1, '5': 4, '10': 'color'},
    {'1': 'user', '3': 5, '4': 1, '5': 11, '6': '.douyin.User', '10': 'user'},
    {'1': 'icon', '3': 6, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'doubleLikeDetail', '3': 7, '4': 1, '5': 11, '6': '.douyin.DoubleLikeDetail', '10': 'doubleLikeDetail'},
    {'1': 'displayControlInfo', '3': 8, '4': 1, '5': 11, '6': '.douyin.DisplayControlInfo', '10': 'displayControlInfo'},
    {'1': 'linkmicGuestUid', '3': 9, '4': 1, '5': 4, '10': 'linkmicGuestUid'},
    {'1': 'scene', '3': 10, '4': 1, '5': 9, '10': 'scene'},
    {'1': 'picoDisplayInfo', '3': 11, '4': 1, '5': 11, '6': '.douyin.PicoDisplayInfo', '10': 'picoDisplayInfo'},
  ],
};

/// Descriptor for `LikeMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List likeMessageDescriptor = $convert.base64Decode(
    'CgtMaWtlTWVzc2FnZRImCgZjb21tb24YASABKAsyDi5kb3V5aW4uQ29tbW9uUgZjb21tb24SFA'
    'oFY291bnQYAiABKARSBWNvdW50EhQKBXRvdGFsGAMgASgEUgV0b3RhbBIUCgVjb2xvchgEIAEo'
    'BFIFY29sb3ISIAoEdXNlchgFIAEoCzIMLmRvdXlpbi5Vc2VyUgR1c2VyEhIKBGljb24YBiABKA'
    'lSBGljb24SRAoQZG91YmxlTGlrZURldGFpbBgHIAEoCzIYLmRvdXlpbi5Eb3VibGVMaWtlRGV0'
    'YWlsUhBkb3VibGVMaWtlRGV0YWlsEkoKEmRpc3BsYXlDb250cm9sSW5mbxgIIAEoCzIaLmRvdX'
    'lpbi5EaXNwbGF5Q29udHJvbEluZm9SEmRpc3BsYXlDb250cm9sSW5mbxIoCg9saW5rbWljR3Vl'
    'c3RVaWQYCSABKARSD2xpbmttaWNHdWVzdFVpZBIUCgVzY2VuZRgKIAEoCVIFc2NlbmUSQQoPcG'
    'ljb0Rpc3BsYXlJbmZvGAsgASgLMhcuZG91eWluLlBpY29EaXNwbGF5SW5mb1IPcGljb0Rpc3Bs'
    'YXlJbmZv');

@$core.Deprecated('Use socialMessageDescriptor instead')
const SocialMessage$json = {
  '1': 'SocialMessage',
  '2': [
    {'1': 'common', '3': 1, '4': 1, '5': 11, '6': '.douyin.Common', '10': 'common'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.douyin.User', '10': 'user'},
    {'1': 'shareType', '3': 3, '4': 1, '5': 4, '10': 'shareType'},
    {'1': 'action', '3': 4, '4': 1, '5': 4, '10': 'action'},
    {'1': 'shareTarget', '3': 5, '4': 1, '5': 9, '10': 'shareTarget'},
    {'1': 'followCount', '3': 6, '4': 1, '5': 4, '10': 'followCount'},
    {'1': 'publicAreaCommon', '3': 7, '4': 1, '5': 11, '6': '.douyin.PublicAreaCommon', '10': 'publicAreaCommon'},
  ],
};

/// Descriptor for `SocialMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List socialMessageDescriptor = $convert.base64Decode(
    'Cg1Tb2NpYWxNZXNzYWdlEiYKBmNvbW1vbhgBIAEoCzIOLmRvdXlpbi5Db21tb25SBmNvbW1vbh'
    'IgCgR1c2VyGAIgASgLMgwuZG91eWluLlVzZXJSBHVzZXISHAoJc2hhcmVUeXBlGAMgASgEUglz'
    'aGFyZVR5cGUSFgoGYWN0aW9uGAQgASgEUgZhY3Rpb24SIAoLc2hhcmVUYXJnZXQYBSABKAlSC3'
    'NoYXJlVGFyZ2V0EiAKC2ZvbGxvd0NvdW50GAYgASgEUgtmb2xsb3dDb3VudBJEChBwdWJsaWNB'
    'cmVhQ29tbW9uGAcgASgLMhguZG91eWluLlB1YmxpY0FyZWFDb21tb25SEHB1YmxpY0FyZWFDb2'
    '1tb24=');

@$core.Deprecated('Use picoDisplayInfoDescriptor instead')
const PicoDisplayInfo$json = {
  '1': 'PicoDisplayInfo',
  '2': [
    {'1': 'comboSumCount', '3': 1, '4': 1, '5': 4, '10': 'comboSumCount'},
    {'1': 'emoji', '3': 2, '4': 1, '5': 9, '10': 'emoji'},
    {'1': 'emojiIcon', '3': 3, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'emojiIcon'},
    {'1': 'emojiText', '3': 4, '4': 1, '5': 9, '10': 'emojiText'},
  ],
};

/// Descriptor for `PicoDisplayInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List picoDisplayInfoDescriptor = $convert.base64Decode(
    'Cg9QaWNvRGlzcGxheUluZm8SJAoNY29tYm9TdW1Db3VudBgBIAEoBFINY29tYm9TdW1Db3VudB'
    'IUCgVlbW9qaRgCIAEoCVIFZW1vamkSKwoJZW1vamlJY29uGAMgASgLMg0uZG91eWluLkltYWdl'
    'UgllbW9qaUljb24SHAoJZW1vamlUZXh0GAQgASgJUgllbW9qaVRleHQ=');

@$core.Deprecated('Use doubleLikeDetailDescriptor instead')
const DoubleLikeDetail$json = {
  '1': 'DoubleLikeDetail',
  '2': [
    {'1': 'doubleFlag', '3': 1, '4': 1, '5': 8, '10': 'doubleFlag'},
    {'1': 'seqId', '3': 2, '4': 1, '5': 13, '10': 'seqId'},
    {'1': 'renewalsNum', '3': 3, '4': 1, '5': 13, '10': 'renewalsNum'},
    {'1': 'triggersNum', '3': 4, '4': 1, '5': 13, '10': 'triggersNum'},
  ],
};

/// Descriptor for `DoubleLikeDetail`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List doubleLikeDetailDescriptor = $convert.base64Decode(
    'ChBEb3VibGVMaWtlRGV0YWlsEh4KCmRvdWJsZUZsYWcYASABKAhSCmRvdWJsZUZsYWcSFAoFc2'
    'VxSWQYAiABKA1SBXNlcUlkEiAKC3JlbmV3YWxzTnVtGAMgASgNUgtyZW5ld2Fsc051bRIgCgt0'
    'cmlnZ2Vyc051bRgEIAEoDVILdHJpZ2dlcnNOdW0=');

@$core.Deprecated('Use displayControlInfoDescriptor instead')
const DisplayControlInfo$json = {
  '1': 'DisplayControlInfo',
  '2': [
    {'1': 'showText', '3': 1, '4': 1, '5': 8, '10': 'showText'},
    {'1': 'showIcons', '3': 2, '4': 1, '5': 8, '10': 'showIcons'},
  ],
};

/// Descriptor for `DisplayControlInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List displayControlInfoDescriptor = $convert.base64Decode(
    'ChJEaXNwbGF5Q29udHJvbEluZm8SGgoIc2hvd1RleHQYASABKAhSCHNob3dUZXh0EhwKCXNob3'
    'dJY29ucxgCIAEoCFIJc2hvd0ljb25z');

@$core.Deprecated('Use episodeChatMessageDescriptor instead')
const EpisodeChatMessage$json = {
  '1': 'EpisodeChatMessage',
  '2': [
    {'1': 'common', '3': 1, '4': 1, '5': 11, '6': '.douyin.Message', '10': 'common'},
    {'1': 'user', '3': 2, '4': 1, '5': 11, '6': '.douyin.User', '10': 'user'},
    {'1': 'content', '3': 3, '4': 1, '5': 9, '10': 'content'},
    {'1': 'visibleToSende', '3': 4, '4': 1, '5': 8, '10': 'visibleToSende'},
    {'1': 'giftImage', '3': 7, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'giftImage'},
    {'1': 'agreeMsgId', '3': 8, '4': 1, '5': 4, '10': 'agreeMsgId'},
    {'1': 'colorValueList', '3': 9, '4': 3, '5': 9, '10': 'colorValueList'},
  ],
};

/// Descriptor for `EpisodeChatMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List episodeChatMessageDescriptor = $convert.base64Decode(
    'ChJFcGlzb2RlQ2hhdE1lc3NhZ2USJwoGY29tbW9uGAEgASgLMg8uZG91eWluLk1lc3NhZ2VSBm'
    'NvbW1vbhIgCgR1c2VyGAIgASgLMgwuZG91eWluLlVzZXJSBHVzZXISGAoHY29udGVudBgDIAEo'
    'CVIHY29udGVudBImCg52aXNpYmxlVG9TZW5kZRgEIAEoCFIOdmlzaWJsZVRvU2VuZGUSKwoJZ2'
    'lmdEltYWdlGAcgASgLMg0uZG91eWluLkltYWdlUglnaWZ0SW1hZ2USHgoKYWdyZWVNc2dJZBgI'
    'IAEoBFIKYWdyZWVNc2dJZBImCg5jb2xvclZhbHVlTGlzdBgJIAMoCVIOY29sb3JWYWx1ZUxpc3'
    'Q=');

@$core.Deprecated('Use matchAgainstScoreMessageDescriptor instead')
const MatchAgainstScoreMessage$json = {
  '1': 'MatchAgainstScoreMessage',
  '2': [
    {'1': 'common', '3': 1, '4': 1, '5': 11, '6': '.douyin.Common', '10': 'common'},
    {'1': 'against', '3': 2, '4': 1, '5': 11, '6': '.douyin.Against', '10': 'against'},
    {'1': 'matchStatus', '3': 3, '4': 1, '5': 13, '10': 'matchStatus'},
    {'1': 'displayStatus', '3': 4, '4': 1, '5': 13, '10': 'displayStatus'},
  ],
};

/// Descriptor for `MatchAgainstScoreMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List matchAgainstScoreMessageDescriptor = $convert.base64Decode(
    'ChhNYXRjaEFnYWluc3RTY29yZU1lc3NhZ2USJgoGY29tbW9uGAEgASgLMg4uZG91eWluLkNvbW'
    '1vblIGY29tbW9uEikKB2FnYWluc3QYAiABKAsyDy5kb3V5aW4uQWdhaW5zdFIHYWdhaW5zdBIg'
    'CgttYXRjaFN0YXR1cxgDIAEoDVILbWF0Y2hTdGF0dXMSJAoNZGlzcGxheVN0YXR1cxgEIAEoDV'
    'INZGlzcGxheVN0YXR1cw==');

@$core.Deprecated('Use againstDescriptor instead')
const Against$json = {
  '1': 'Against',
  '2': [
    {'1': 'leftName', '3': 1, '4': 1, '5': 9, '10': 'leftName'},
    {'1': 'leftLogo', '3': 2, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'leftLogo'},
    {'1': 'leftGoal', '3': 3, '4': 1, '5': 9, '10': 'leftGoal'},
    {'1': 'rightName', '3': 6, '4': 1, '5': 9, '10': 'rightName'},
    {'1': 'rightLogo', '3': 7, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'rightLogo'},
    {'1': 'rightGoal', '3': 8, '4': 1, '5': 9, '10': 'rightGoal'},
    {'1': 'timestamp', '3': 11, '4': 1, '5': 4, '10': 'timestamp'},
    {'1': 'version', '3': 12, '4': 1, '5': 4, '10': 'version'},
    {'1': 'leftTeamId', '3': 13, '4': 1, '5': 4, '10': 'leftTeamId'},
    {'1': 'rightTeamId', '3': 14, '4': 1, '5': 4, '10': 'rightTeamId'},
    {'1': 'diffSei2absSecond', '3': 15, '4': 1, '5': 4, '10': 'diffSei2absSecond'},
    {'1': 'finalGoalStage', '3': 16, '4': 1, '5': 13, '10': 'finalGoalStage'},
    {'1': 'currentGoalStage', '3': 17, '4': 1, '5': 13, '10': 'currentGoalStage'},
    {'1': 'leftScoreAddition', '3': 18, '4': 1, '5': 13, '10': 'leftScoreAddition'},
    {'1': 'rightScoreAddition', '3': 19, '4': 1, '5': 13, '10': 'rightScoreAddition'},
    {'1': 'leftGoalInt', '3': 20, '4': 1, '5': 4, '10': 'leftGoalInt'},
    {'1': 'rightGoalInt', '3': 21, '4': 1, '5': 4, '10': 'rightGoalInt'},
  ],
};

/// Descriptor for `Against`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List againstDescriptor = $convert.base64Decode(
    'CgdBZ2FpbnN0EhoKCGxlZnROYW1lGAEgASgJUghsZWZ0TmFtZRIpCghsZWZ0TG9nbxgCIAEoCz'
    'INLmRvdXlpbi5JbWFnZVIIbGVmdExvZ28SGgoIbGVmdEdvYWwYAyABKAlSCGxlZnRHb2FsEhwK'
    'CXJpZ2h0TmFtZRgGIAEoCVIJcmlnaHROYW1lEisKCXJpZ2h0TG9nbxgHIAEoCzINLmRvdXlpbi'
    '5JbWFnZVIJcmlnaHRMb2dvEhwKCXJpZ2h0R29hbBgIIAEoCVIJcmlnaHRHb2FsEhwKCXRpbWVz'
    'dGFtcBgLIAEoBFIJdGltZXN0YW1wEhgKB3ZlcnNpb24YDCABKARSB3ZlcnNpb24SHgoKbGVmdF'
    'RlYW1JZBgNIAEoBFIKbGVmdFRlYW1JZBIgCgtyaWdodFRlYW1JZBgOIAEoBFILcmlnaHRUZWFt'
    'SWQSLAoRZGlmZlNlaTJhYnNTZWNvbmQYDyABKARSEWRpZmZTZWkyYWJzU2Vjb25kEiYKDmZpbm'
    'FsR29hbFN0YWdlGBAgASgNUg5maW5hbEdvYWxTdGFnZRIqChBjdXJyZW50R29hbFN0YWdlGBEg'
    'ASgNUhBjdXJyZW50R29hbFN0YWdlEiwKEWxlZnRTY29yZUFkZGl0aW9uGBIgASgNUhFsZWZ0U2'
    'NvcmVBZGRpdGlvbhIuChJyaWdodFNjb3JlQWRkaXRpb24YEyABKA1SEnJpZ2h0U2NvcmVBZGRp'
    'dGlvbhIgCgtsZWZ0R29hbEludBgUIAEoBFILbGVmdEdvYWxJbnQSIgoMcmlnaHRHb2FsSW50GB'
    'UgASgEUgxyaWdodEdvYWxJbnQ=');

@$core.Deprecated('Use commonDescriptor instead')
const Common$json = {
  '1': 'Common',
  '2': [
    {'1': 'method', '3': 1, '4': 1, '5': 9, '10': 'method'},
    {'1': 'msgId', '3': 2, '4': 1, '5': 4, '10': 'msgId'},
    {'1': 'roomId', '3': 3, '4': 1, '5': 4, '10': 'roomId'},
    {'1': 'createTime', '3': 4, '4': 1, '5': 4, '10': 'createTime'},
    {'1': 'monitor', '3': 5, '4': 1, '5': 13, '10': 'monitor'},
    {'1': 'isShowMsg', '3': 6, '4': 1, '5': 8, '10': 'isShowMsg'},
    {'1': 'describe', '3': 7, '4': 1, '5': 9, '10': 'describe'},
    {'1': 'foldType', '3': 9, '4': 1, '5': 4, '10': 'foldType'},
    {'1': 'anchorFoldType', '3': 10, '4': 1, '5': 4, '10': 'anchorFoldType'},
    {'1': 'priorityScore', '3': 11, '4': 1, '5': 4, '10': 'priorityScore'},
    {'1': 'logId', '3': 12, '4': 1, '5': 9, '10': 'logId'},
    {'1': 'msgProcessFilterK', '3': 13, '4': 1, '5': 9, '10': 'msgProcessFilterK'},
    {'1': 'msgProcessFilterV', '3': 14, '4': 1, '5': 9, '10': 'msgProcessFilterV'},
    {'1': 'user', '3': 15, '4': 1, '5': 11, '6': '.douyin.User', '10': 'user'},
    {'1': 'anchorFoldTypeV2', '3': 17, '4': 1, '5': 4, '10': 'anchorFoldTypeV2'},
    {'1': 'processAtSeiTimeMs', '3': 18, '4': 1, '5': 4, '10': 'processAtSeiTimeMs'},
    {'1': 'randomDispatchMs', '3': 19, '4': 1, '5': 4, '10': 'randomDispatchMs'},
    {'1': 'isDispatch', '3': 20, '4': 1, '5': 8, '10': 'isDispatch'},
    {'1': 'channelId', '3': 21, '4': 1, '5': 4, '10': 'channelId'},
    {'1': 'diffSei2absSecond', '3': 22, '4': 1, '5': 4, '10': 'diffSei2absSecond'},
    {'1': 'anchorFoldDuration', '3': 23, '4': 1, '5': 4, '10': 'anchorFoldDuration'},
  ],
};

/// Descriptor for `Common`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonDescriptor = $convert.base64Decode(
    'CgZDb21tb24SFgoGbWV0aG9kGAEgASgJUgZtZXRob2QSFAoFbXNnSWQYAiABKARSBW1zZ0lkEh'
    'YKBnJvb21JZBgDIAEoBFIGcm9vbUlkEh4KCmNyZWF0ZVRpbWUYBCABKARSCmNyZWF0ZVRpbWUS'
    'GAoHbW9uaXRvchgFIAEoDVIHbW9uaXRvchIcCglpc1Nob3dNc2cYBiABKAhSCWlzU2hvd01zZx'
    'IaCghkZXNjcmliZRgHIAEoCVIIZGVzY3JpYmUSGgoIZm9sZFR5cGUYCSABKARSCGZvbGRUeXBl'
    'EiYKDmFuY2hvckZvbGRUeXBlGAogASgEUg5hbmNob3JGb2xkVHlwZRIkCg1wcmlvcml0eVNjb3'
    'JlGAsgASgEUg1wcmlvcml0eVNjb3JlEhQKBWxvZ0lkGAwgASgJUgVsb2dJZBIsChFtc2dQcm9j'
    'ZXNzRmlsdGVySxgNIAEoCVIRbXNnUHJvY2Vzc0ZpbHRlcksSLAoRbXNnUHJvY2Vzc0ZpbHRlcl'
    'YYDiABKAlSEW1zZ1Byb2Nlc3NGaWx0ZXJWEiAKBHVzZXIYDyABKAsyDC5kb3V5aW4uVXNlclIE'
    'dXNlchIqChBhbmNob3JGb2xkVHlwZVYyGBEgASgEUhBhbmNob3JGb2xkVHlwZVYyEi4KEnByb2'
    'Nlc3NBdFNlaVRpbWVNcxgSIAEoBFIScHJvY2Vzc0F0U2VpVGltZU1zEioKEHJhbmRvbURpc3Bh'
    'dGNoTXMYEyABKARSEHJhbmRvbURpc3BhdGNoTXMSHgoKaXNEaXNwYXRjaBgUIAEoCFIKaXNEaX'
    'NwYXRjaBIcCgljaGFubmVsSWQYFSABKARSCWNoYW5uZWxJZBIsChFkaWZmU2VpMmFic1NlY29u'
    'ZBgWIAEoBFIRZGlmZlNlaTJhYnNTZWNvbmQSLgoSYW5jaG9yRm9sZER1cmF0aW9uGBcgASgEUh'
    'JhbmNob3JGb2xkRHVyYXRpb24=');

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 4, '10': 'id'},
    {'1': 'shortId', '3': 2, '4': 1, '5': 4, '10': 'shortId'},
    {'1': 'nickName', '3': 3, '4': 1, '5': 9, '10': 'nickName'},
    {'1': 'gender', '3': 4, '4': 1, '5': 13, '10': 'gender'},
    {'1': 'Signature', '3': 5, '4': 1, '5': 9, '10': 'Signature'},
    {'1': 'Level', '3': 6, '4': 1, '5': 13, '10': 'Level'},
    {'1': 'Birthday', '3': 7, '4': 1, '5': 4, '10': 'Birthday'},
    {'1': 'Telephone', '3': 8, '4': 1, '5': 9, '10': 'Telephone'},
    {'1': 'AvatarThumb', '3': 9, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'AvatarThumb'},
    {'1': 'AvatarMedium', '3': 10, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'AvatarMedium'},
    {'1': 'AvatarLarge', '3': 11, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'AvatarLarge'},
    {'1': 'Verified', '3': 12, '4': 1, '5': 8, '10': 'Verified'},
    {'1': 'Experience', '3': 13, '4': 1, '5': 13, '10': 'Experience'},
    {'1': 'city', '3': 14, '4': 1, '5': 9, '10': 'city'},
    {'1': 'Status', '3': 15, '4': 1, '5': 5, '10': 'Status'},
    {'1': 'CreateTime', '3': 16, '4': 1, '5': 4, '10': 'CreateTime'},
    {'1': 'ModifyTime', '3': 17, '4': 1, '5': 4, '10': 'ModifyTime'},
    {'1': 'Secret', '3': 18, '4': 1, '5': 13, '10': 'Secret'},
    {'1': 'ShareQrcodeUri', '3': 19, '4': 1, '5': 9, '10': 'ShareQrcodeUri'},
    {'1': 'IncomeSharePercent', '3': 20, '4': 1, '5': 13, '10': 'IncomeSharePercent'},
    {'1': 'BadgeImageList', '3': 21, '4': 3, '5': 11, '6': '.douyin.Image', '10': 'BadgeImageList'},
    {'1': 'FollowInfo', '3': 22, '4': 1, '5': 11, '6': '.douyin.FollowInfo', '10': 'FollowInfo'},
    {'1': 'SpecialId', '3': 26, '4': 1, '5': 9, '10': 'SpecialId'},
    {'1': 'AvatarBorder', '3': 27, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'AvatarBorder'},
    {'1': 'Medal', '3': 28, '4': 1, '5': 11, '6': '.douyin.Image', '10': 'Medal'},
    {'1': 'RealTimeIconsList', '3': 29, '4': 3, '5': 11, '6': '.douyin.Image', '10': 'RealTimeIconsList'},
    {'1': 'displayId', '3': 38, '4': 1, '5': 9, '10': 'displayId'},
    {'1': 'secUid', '3': 46, '4': 1, '5': 9, '10': 'secUid'},
    {'1': 'fanTicketCount', '3': 1022, '4': 1, '5': 4, '10': 'fanTicketCount'},
    {'1': 'idStr', '3': 1028, '4': 1, '5': 9, '10': 'idStr'},
    {'1': 'ageRange', '3': 1045, '4': 1, '5': 13, '10': 'ageRange'},
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor = $convert.base64Decode(
    'CgRVc2VyEg4KAmlkGAEgASgEUgJpZBIYCgdzaG9ydElkGAIgASgEUgdzaG9ydElkEhoKCG5pY2'
    'tOYW1lGAMgASgJUghuaWNrTmFtZRIWCgZnZW5kZXIYBCABKA1SBmdlbmRlchIcCglTaWduYXR1'
    'cmUYBSABKAlSCVNpZ25hdHVyZRIUCgVMZXZlbBgGIAEoDVIFTGV2ZWwSGgoIQmlydGhkYXkYBy'
    'ABKARSCEJpcnRoZGF5EhwKCVRlbGVwaG9uZRgIIAEoCVIJVGVsZXBob25lEi8KC0F2YXRhclRo'
    'dW1iGAkgASgLMg0uZG91eWluLkltYWdlUgtBdmF0YXJUaHVtYhIxCgxBdmF0YXJNZWRpdW0YCi'
    'ABKAsyDS5kb3V5aW4uSW1hZ2VSDEF2YXRhck1lZGl1bRIvCgtBdmF0YXJMYXJnZRgLIAEoCzIN'
    'LmRvdXlpbi5JbWFnZVILQXZhdGFyTGFyZ2USGgoIVmVyaWZpZWQYDCABKAhSCFZlcmlmaWVkEh'
    '4KCkV4cGVyaWVuY2UYDSABKA1SCkV4cGVyaWVuY2USEgoEY2l0eRgOIAEoCVIEY2l0eRIWCgZT'
    'dGF0dXMYDyABKAVSBlN0YXR1cxIeCgpDcmVhdGVUaW1lGBAgASgEUgpDcmVhdGVUaW1lEh4KCk'
    '1vZGlmeVRpbWUYESABKARSCk1vZGlmeVRpbWUSFgoGU2VjcmV0GBIgASgNUgZTZWNyZXQSJgoO'
    'U2hhcmVRcmNvZGVVcmkYEyABKAlSDlNoYXJlUXJjb2RlVXJpEi4KEkluY29tZVNoYXJlUGVyY2'
    'VudBgUIAEoDVISSW5jb21lU2hhcmVQZXJjZW50EjUKDkJhZGdlSW1hZ2VMaXN0GBUgAygLMg0u'
    'ZG91eWluLkltYWdlUg5CYWRnZUltYWdlTGlzdBIyCgpGb2xsb3dJbmZvGBYgASgLMhIuZG91eW'
    'luLkZvbGxvd0luZm9SCkZvbGxvd0luZm8SHAoJU3BlY2lhbElkGBogASgJUglTcGVjaWFsSWQS'
    'MQoMQXZhdGFyQm9yZGVyGBsgASgLMg0uZG91eWluLkltYWdlUgxBdmF0YXJCb3JkZXISIwoFTW'
    'VkYWwYHCABKAsyDS5kb3V5aW4uSW1hZ2VSBU1lZGFsEjsKEVJlYWxUaW1lSWNvbnNMaXN0GB0g'
    'AygLMg0uZG91eWluLkltYWdlUhFSZWFsVGltZUljb25zTGlzdBIcCglkaXNwbGF5SWQYJiABKA'
    'lSCWRpc3BsYXlJZBIWCgZzZWNVaWQYLiABKAlSBnNlY1VpZBInCg5mYW5UaWNrZXRDb3VudBj+'
    'ByABKARSDmZhblRpY2tldENvdW50EhUKBWlkU3RyGIQIIAEoCVIFaWRTdHISGwoIYWdlUmFuZ2'
    'UYlQggASgNUghhZ2VSYW5nZQ==');

@$core.Deprecated('Use followInfoDescriptor instead')
const FollowInfo$json = {
  '1': 'FollowInfo',
  '2': [
    {'1': 'followingCount', '3': 1, '4': 1, '5': 4, '10': 'followingCount'},
    {'1': 'followerCount', '3': 2, '4': 1, '5': 4, '10': 'followerCount'},
    {'1': 'followStatus', '3': 3, '4': 1, '5': 4, '10': 'followStatus'},
    {'1': 'pushStatus', '3': 4, '4': 1, '5': 4, '10': 'pushStatus'},
    {'1': 'remarkName', '3': 5, '4': 1, '5': 9, '10': 'remarkName'},
    {'1': 'followerCountStr', '3': 6, '4': 1, '5': 9, '10': 'followerCountStr'},
    {'1': 'followingCountStr', '3': 7, '4': 1, '5': 9, '10': 'followingCountStr'},
  ],
};

/// Descriptor for `FollowInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List followInfoDescriptor = $convert.base64Decode(
    'CgpGb2xsb3dJbmZvEiYKDmZvbGxvd2luZ0NvdW50GAEgASgEUg5mb2xsb3dpbmdDb3VudBIkCg'
    '1mb2xsb3dlckNvdW50GAIgASgEUg1mb2xsb3dlckNvdW50EiIKDGZvbGxvd1N0YXR1cxgDIAEo'
    'BFIMZm9sbG93U3RhdHVzEh4KCnB1c2hTdGF0dXMYBCABKARSCnB1c2hTdGF0dXMSHgoKcmVtYX'
    'JrTmFtZRgFIAEoCVIKcmVtYXJrTmFtZRIqChBmb2xsb3dlckNvdW50U3RyGAYgASgJUhBmb2xs'
    'b3dlckNvdW50U3RyEiwKEWZvbGxvd2luZ0NvdW50U3RyGAcgASgJUhFmb2xsb3dpbmdDb3VudF'
    'N0cg==');

@$core.Deprecated('Use imageDescriptor instead')
const Image$json = {
  '1': 'Image',
  '2': [
    {'1': 'urlListList', '3': 1, '4': 3, '5': 9, '10': 'urlListList'},
    {'1': 'uri', '3': 2, '4': 1, '5': 9, '10': 'uri'},
    {'1': 'height', '3': 3, '4': 1, '5': 4, '10': 'height'},
    {'1': 'width', '3': 4, '4': 1, '5': 4, '10': 'width'},
    {'1': 'avgColor', '3': 5, '4': 1, '5': 9, '10': 'avgColor'},
    {'1': 'imageType', '3': 6, '4': 1, '5': 13, '10': 'imageType'},
    {'1': 'openWebUrl', '3': 7, '4': 1, '5': 9, '10': 'openWebUrl'},
    {'1': 'content', '3': 8, '4': 1, '5': 11, '6': '.douyin.ImageContent', '10': 'content'},
    {'1': 'isAnimated', '3': 9, '4': 1, '5': 8, '10': 'isAnimated'},
    {'1': 'FlexSettingList', '3': 10, '4': 1, '5': 11, '6': '.douyin.NinePatchSetting', '10': 'FlexSettingList'},
    {'1': 'TextSettingList', '3': 11, '4': 1, '5': 11, '6': '.douyin.NinePatchSetting', '10': 'TextSettingList'},
  ],
};

/// Descriptor for `Image`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageDescriptor = $convert.base64Decode(
    'CgVJbWFnZRIgCgt1cmxMaXN0TGlzdBgBIAMoCVILdXJsTGlzdExpc3QSEAoDdXJpGAIgASgJUg'
    'N1cmkSFgoGaGVpZ2h0GAMgASgEUgZoZWlnaHQSFAoFd2lkdGgYBCABKARSBXdpZHRoEhoKCGF2'
    'Z0NvbG9yGAUgASgJUghhdmdDb2xvchIcCglpbWFnZVR5cGUYBiABKA1SCWltYWdlVHlwZRIeCg'
    'pvcGVuV2ViVXJsGAcgASgJUgpvcGVuV2ViVXJsEi4KB2NvbnRlbnQYCCABKAsyFC5kb3V5aW4u'
    'SW1hZ2VDb250ZW50Ugdjb250ZW50Eh4KCmlzQW5pbWF0ZWQYCSABKAhSCmlzQW5pbWF0ZWQSQg'
    'oPRmxleFNldHRpbmdMaXN0GAogASgLMhguZG91eWluLk5pbmVQYXRjaFNldHRpbmdSD0ZsZXhT'
    'ZXR0aW5nTGlzdBJCCg9UZXh0U2V0dGluZ0xpc3QYCyABKAsyGC5kb3V5aW4uTmluZVBhdGNoU2'
    'V0dGluZ1IPVGV4dFNldHRpbmdMaXN0');

@$core.Deprecated('Use ninePatchSettingDescriptor instead')
const NinePatchSetting$json = {
  '1': 'NinePatchSetting',
  '2': [
    {'1': 'settingListList', '3': 1, '4': 3, '5': 9, '10': 'settingListList'},
  ],
};

/// Descriptor for `NinePatchSetting`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ninePatchSettingDescriptor = $convert.base64Decode(
    'ChBOaW5lUGF0Y2hTZXR0aW5nEigKD3NldHRpbmdMaXN0TGlzdBgBIAMoCVIPc2V0dGluZ0xpc3'
    'RMaXN0');

@$core.Deprecated('Use imageContentDescriptor instead')
const ImageContent$json = {
  '1': 'ImageContent',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'fontColor', '3': 2, '4': 1, '5': 9, '10': 'fontColor'},
    {'1': 'level', '3': 3, '4': 1, '5': 4, '10': 'level'},
    {'1': 'alternativeText', '3': 4, '4': 1, '5': 9, '10': 'alternativeText'},
  ],
};

/// Descriptor for `ImageContent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageContentDescriptor = $convert.base64Decode(
    'CgxJbWFnZUNvbnRlbnQSEgoEbmFtZRgBIAEoCVIEbmFtZRIcCglmb250Q29sb3IYAiABKAlSCW'
    'ZvbnRDb2xvchIUCgVsZXZlbBgDIAEoBFIFbGV2ZWwSKAoPYWx0ZXJuYXRpdmVUZXh0GAQgASgJ'
    'Ug9hbHRlcm5hdGl2ZVRleHQ=');

@$core.Deprecated('Use pushFrameDescriptor instead')
const PushFrame$json = {
  '1': 'PushFrame',
  '2': [
    {'1': 'seqId', '3': 1, '4': 1, '5': 4, '10': 'seqId'},
    {'1': 'logId', '3': 2, '4': 1, '5': 4, '10': 'logId'},
    {'1': 'service', '3': 3, '4': 1, '5': 4, '10': 'service'},
    {'1': 'method', '3': 4, '4': 1, '5': 4, '10': 'method'},
    {'1': 'headersList', '3': 5, '4': 3, '5': 11, '6': '.douyin.HeadersList', '10': 'headersList'},
    {'1': 'payloadEncoding', '3': 6, '4': 1, '5': 9, '10': 'payloadEncoding'},
    {'1': 'payloadType', '3': 7, '4': 1, '5': 9, '10': 'payloadType'},
    {'1': 'payload', '3': 8, '4': 1, '5': 12, '10': 'payload'},
  ],
};

/// Descriptor for `PushFrame`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pushFrameDescriptor = $convert.base64Decode(
    'CglQdXNoRnJhbWUSFAoFc2VxSWQYASABKARSBXNlcUlkEhQKBWxvZ0lkGAIgASgEUgVsb2dJZB'
    'IYCgdzZXJ2aWNlGAMgASgEUgdzZXJ2aWNlEhYKBm1ldGhvZBgEIAEoBFIGbWV0aG9kEjUKC2hl'
    'YWRlcnNMaXN0GAUgAygLMhMuZG91eWluLkhlYWRlcnNMaXN0UgtoZWFkZXJzTGlzdBIoCg9wYX'
    'lsb2FkRW5jb2RpbmcYBiABKAlSD3BheWxvYWRFbmNvZGluZxIgCgtwYXlsb2FkVHlwZRgHIAEo'
    'CVILcGF5bG9hZFR5cGUSGAoHcGF5bG9hZBgIIAEoDFIHcGF5bG9hZA==');

@$core.Deprecated('Use kkDescriptor instead')
const kk$json = {
  '1': 'kk',
  '2': [
    {'1': 'k', '3': 14, '4': 1, '5': 13, '10': 'k'},
  ],
};

/// Descriptor for `kk`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List kkDescriptor = $convert.base64Decode(
    'CgJraxIMCgFrGA4gASgNUgFr');

@$core.Deprecated('Use sendMessageBodyDescriptor instead')
const SendMessageBody$json = {
  '1': 'SendMessageBody',
  '2': [
    {'1': 'conversationId', '3': 1, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'conversationType', '3': 2, '4': 1, '5': 13, '10': 'conversationType'},
    {'1': 'conversationShortId', '3': 3, '4': 1, '5': 4, '10': 'conversationShortId'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
    {'1': 'ext', '3': 5, '4': 3, '5': 11, '6': '.douyin.ExtList', '10': 'ext'},
    {'1': 'messageType', '3': 6, '4': 1, '5': 13, '10': 'messageType'},
    {'1': 'ticket', '3': 7, '4': 1, '5': 9, '10': 'ticket'},
    {'1': 'clientMessageId', '3': 8, '4': 1, '5': 9, '10': 'clientMessageId'},
  ],
};

/// Descriptor for `SendMessageBody`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendMessageBodyDescriptor = $convert.base64Decode(
    'Cg9TZW5kTWVzc2FnZUJvZHkSJgoOY29udmVyc2F0aW9uSWQYASABKAlSDmNvbnZlcnNhdGlvbk'
    'lkEioKEGNvbnZlcnNhdGlvblR5cGUYAiABKA1SEGNvbnZlcnNhdGlvblR5cGUSMAoTY29udmVy'
    'c2F0aW9uU2hvcnRJZBgDIAEoBFITY29udmVyc2F0aW9uU2hvcnRJZBIYCgdjb250ZW50GAQgAS'
    'gJUgdjb250ZW50EiEKA2V4dBgFIAMoCzIPLmRvdXlpbi5FeHRMaXN0UgNleHQSIAoLbWVzc2Fn'
    'ZVR5cGUYBiABKA1SC21lc3NhZ2VUeXBlEhYKBnRpY2tldBgHIAEoCVIGdGlja2V0EigKD2NsaW'
    'VudE1lc3NhZ2VJZBgIIAEoCVIPY2xpZW50TWVzc2FnZUlk');

@$core.Deprecated('Use extListDescriptor instead')
const ExtList$json = {
  '1': 'ExtList',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `ExtList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List extListDescriptor = $convert.base64Decode(
    'CgdFeHRMaXN0EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZQ==');

@$core.Deprecated('Use rspDescriptor instead')
const Rsp$json = {
  '1': 'Rsp',
  '2': [
    {'1': 'a', '3': 1, '4': 1, '5': 5, '10': 'a'},
    {'1': 'b', '3': 2, '4': 1, '5': 5, '10': 'b'},
    {'1': 'c', '3': 3, '4': 1, '5': 5, '10': 'c'},
    {'1': 'd', '3': 4, '4': 1, '5': 9, '10': 'd'},
    {'1': 'e', '3': 5, '4': 1, '5': 5, '10': 'e'},
    {'1': 'f', '3': 6, '4': 1, '5': 11, '6': '.douyin.Rsp.F', '10': 'f'},
    {'1': 'g', '3': 7, '4': 1, '5': 9, '10': 'g'},
    {'1': 'h', '3': 10, '4': 1, '5': 4, '10': 'h'},
    {'1': 'i', '3': 11, '4': 1, '5': 4, '10': 'i'},
    {'1': 'j', '3': 13, '4': 1, '5': 4, '10': 'j'},
  ],
  '3': [Rsp_F$json],
};

@$core.Deprecated('Use rspDescriptor instead')
const Rsp_F$json = {
  '1': 'F',
  '2': [
    {'1': 'q1', '3': 1, '4': 1, '5': 4, '10': 'q1'},
    {'1': 'q3', '3': 3, '4': 1, '5': 4, '10': 'q3'},
    {'1': 'q4', '3': 4, '4': 1, '5': 9, '10': 'q4'},
    {'1': 'q5', '3': 5, '4': 1, '5': 4, '10': 'q5'},
  ],
};

/// Descriptor for `Rsp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rspDescriptor = $convert.base64Decode(
    'CgNSc3ASDAoBYRgBIAEoBVIBYRIMCgFiGAIgASgFUgFiEgwKAWMYAyABKAVSAWMSDAoBZBgEIA'
    'EoCVIBZBIMCgFlGAUgASgFUgFlEhsKAWYYBiABKAsyDS5kb3V5aW4uUnNwLkZSAWYSDAoBZxgH'
    'IAEoCVIBZxIMCgFoGAogASgEUgFoEgwKAWkYCyABKARSAWkSDAoBahgNIAEoBFIBahpDCgFGEg'
    '4KAnExGAEgASgEUgJxMRIOCgJxMxgDIAEoBFICcTMSDgoCcTQYBCABKAlSAnE0Eg4KAnE1GAUg'
    'ASgEUgJxNQ==');

@$core.Deprecated('Use preMessageDescriptor instead')
const PreMessage$json = {
  '1': 'PreMessage',
  '2': [
    {'1': 'cmd', '3': 1, '4': 1, '5': 13, '10': 'cmd'},
    {'1': 'sequenceId', '3': 2, '4': 1, '5': 13, '10': 'sequenceId'},
    {'1': 'sdkVersion', '3': 3, '4': 1, '5': 9, '10': 'sdkVersion'},
    {'1': 'token', '3': 4, '4': 1, '5': 9, '10': 'token'},
    {'1': 'refer', '3': 5, '4': 1, '5': 13, '10': 'refer'},
    {'1': 'inboxType', '3': 6, '4': 1, '5': 13, '10': 'inboxType'},
    {'1': 'buildNumber', '3': 7, '4': 1, '5': 9, '10': 'buildNumber'},
    {'1': 'sendMessageBody', '3': 8, '4': 1, '5': 11, '6': '.douyin.SendMessageBody', '10': 'sendMessageBody'},
    {'1': 'aa', '3': 9, '4': 1, '5': 9, '10': 'aa'},
    {'1': 'devicePlatform', '3': 11, '4': 1, '5': 9, '10': 'devicePlatform'},
    {'1': 'headers', '3': 15, '4': 3, '5': 11, '6': '.douyin.HeadersList', '10': 'headers'},
    {'1': 'authType', '3': 18, '4': 1, '5': 13, '10': 'authType'},
    {'1': 'biz', '3': 21, '4': 1, '5': 9, '10': 'biz'},
    {'1': 'access', '3': 22, '4': 1, '5': 9, '10': 'access'},
  ],
};

/// Descriptor for `PreMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List preMessageDescriptor = $convert.base64Decode(
    'CgpQcmVNZXNzYWdlEhAKA2NtZBgBIAEoDVIDY21kEh4KCnNlcXVlbmNlSWQYAiABKA1SCnNlcX'
    'VlbmNlSWQSHgoKc2RrVmVyc2lvbhgDIAEoCVIKc2RrVmVyc2lvbhIUCgV0b2tlbhgEIAEoCVIF'
    'dG9rZW4SFAoFcmVmZXIYBSABKA1SBXJlZmVyEhwKCWluYm94VHlwZRgGIAEoDVIJaW5ib3hUeX'
    'BlEiAKC2J1aWxkTnVtYmVyGAcgASgJUgtidWlsZE51bWJlchJBCg9zZW5kTWVzc2FnZUJvZHkY'
    'CCABKAsyFy5kb3V5aW4uU2VuZE1lc3NhZ2VCb2R5Ug9zZW5kTWVzc2FnZUJvZHkSDgoCYWEYCS'
    'ABKAlSAmFhEiYKDmRldmljZVBsYXRmb3JtGAsgASgJUg5kZXZpY2VQbGF0Zm9ybRItCgdoZWFk'
    'ZXJzGA8gAygLMhMuZG91eWluLkhlYWRlcnNMaXN0UgdoZWFkZXJzEhoKCGF1dGhUeXBlGBIgAS'
    'gNUghhdXRoVHlwZRIQCgNiaXoYFSABKAlSA2JpehIWCgZhY2Nlc3MYFiABKAlSBmFjY2Vzcw==');

@$core.Deprecated('Use headersListDescriptor instead')
const HeadersList$json = {
  '1': 'HeadersList',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `HeadersList`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List headersListDescriptor = $convert.base64Decode(
    'CgtIZWFkZXJzTGlzdBIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU=');

