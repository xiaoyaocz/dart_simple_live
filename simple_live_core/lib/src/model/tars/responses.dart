import 'package:tars_dart/tars/codec/tars_displayer.dart';
import 'package:tars_dart/tars/codec/tars_input_stream.dart';
import 'package:tars_dart/tars/codec/tars_output_stream.dart';
import 'package:tars_dart/tars/codec/tars_struct.dart';

class StreamInfo extends TarsStruct {
  String sCdnType = "";
  int iIsMaster = 0;
  int lChannelId = 0;
  int lSubChannelId = 0;
  int lPresenterUid = 0;
  String sStreamName = "";
  String sFlvUrl = "";
  String sFlvUrlSuffix = "";
  String sFlvAntiCode = "";
  String sHlsUrl = "";
  String sHlsUrlSuffix = "";
  String sHlsAntiCode = "";
  int iLineIndex = 0;
  int iIsMultiStream = 0;
  int iPcPriorityRate = 0;
  int iWebPriorityRate = 0;
  int iMobilePriorityRate = 0;
  List<String> vFlvIpList = [];
  int iIsP2pSupport = 0;
  String sP2pUrl = "";
  String sP2pUrlSuffix = "";
  String sP2pAntiCode = "";
  int lFreeFlag = 0;
  int iIsHevcSupport = 0;
  List<String> vP2pIpList = [];
  Map<String, String> mpExtArgs = {};
  int lTimespan = 0;
  int lUpdateTime = 0;

  @override
  void readFrom(TarsInputStream _is) {
    sCdnType = _is.read(sCdnType, 0, false);
    iIsMaster = _is.read(iIsMaster, 1, false);
    lChannelId = _is.read(lChannelId, 2, false);
    lSubChannelId = _is.read(lSubChannelId, 3, false);
    lPresenterUid = _is.read(lPresenterUid, 4, false);
    sStreamName = _is.read(sStreamName, 5, false);
    sFlvUrl = _is.read(sFlvUrl, 6, false);
    sFlvUrlSuffix = _is.read(sFlvUrlSuffix, 7, false);
    sFlvAntiCode = _is.read(sFlvAntiCode, 8, false);
    sHlsUrl = _is.read(sHlsUrl, 9, false);
    sHlsUrlSuffix = _is.read(sHlsUrlSuffix, 10, false);
    sHlsAntiCode = _is.read(sHlsAntiCode, 11, false);
    iLineIndex = _is.read(iLineIndex, 12, false);
    iIsMultiStream = _is.read(iIsMultiStream, 13, false);
    iPcPriorityRate = _is.read(iPcPriorityRate, 14, false);
    iWebPriorityRate = _is.read(iWebPriorityRate, 15, false);
    iMobilePriorityRate = _is.read(iMobilePriorityRate, 16, false);
    vFlvIpList = _is.read(vFlvIpList, 17, false);
    iIsP2pSupport = _is.read(iIsP2pSupport, 18, false);
    sP2pUrl = _is.read(sP2pUrl, 19, false);
    sP2pUrlSuffix = _is.read(sP2pUrlSuffix, 20, false);
    sP2pAntiCode = _is.read(sP2pAntiCode, 21, false);
    lFreeFlag = _is.read(lFreeFlag, 22, false);
    iIsHevcSupport = _is.read(iIsHevcSupport, 23, false);
    vP2pIpList = _is.read(vP2pIpList, 24, false);
    mpExtArgs = _is.read(mpExtArgs, 25, false);
    lTimespan = _is.read(lTimespan, 26, false);
    lUpdateTime = _is.read(lUpdateTime, 27, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(sCdnType, 0);
    _os.write(iIsMaster, 1);
    _os.write(lChannelId, 2);
    _os.write(lSubChannelId, 3);
    _os.write(lPresenterUid, 4);
    _os.write(sStreamName, 5);
    _os.write(sFlvUrl, 6);
    _os.write(sFlvUrlSuffix, 7);
    _os.write(sFlvAntiCode, 8);
    _os.write(sHlsUrl, 9);
    _os.write(sHlsUrlSuffix, 10);
    _os.write(sHlsAntiCode, 11);
    _os.write(iLineIndex, 12);
    _os.write(iIsMultiStream, 13);
    _os.write(iPcPriorityRate, 14);
    _os.write(iWebPriorityRate, 15);
    _os.write(iMobilePriorityRate, 16);
    _os.write(vFlvIpList, 17);
    _os.write(iIsP2pSupport, 18);
    _os.write(sP2pUrl, 19);
    _os.write(sP2pUrlSuffix, 20);
    _os.write(sP2pAntiCode, 21);
    _os.write(lFreeFlag, 22);
    _os.write(iIsHevcSupport, 23);
    _os.write(vP2pIpList, 24);
    _os.write(mpExtArgs, 25);
    _os.write(lTimespan, 26);
    _os.write(lUpdateTime, 27);
  }

  @override
  Object deepCopy() {
    return StreamInfo()
      ..sCdnType = sCdnType
      ..iIsMaster = iIsMaster
      ..lChannelId = lChannelId
      ..lSubChannelId = lSubChannelId
      ..lPresenterUid = lPresenterUid
      ..sStreamName = sStreamName
      ..sFlvUrl = sFlvUrl
      ..sFlvUrlSuffix = sFlvUrlSuffix
      ..sFlvAntiCode = sFlvAntiCode
      ..sHlsUrl = sHlsUrl
      ..sHlsUrlSuffix = sHlsUrlSuffix
      ..sHlsAntiCode = sHlsAntiCode
      ..iLineIndex = iLineIndex
      ..iIsMultiStream = iIsMultiStream
      ..iPcPriorityRate = iPcPriorityRate
      ..iWebPriorityRate = iWebPriorityRate
      ..iMobilePriorityRate = iMobilePriorityRate
      ..vFlvIpList = List.from(vFlvIpList)
      ..iIsP2pSupport = iIsP2pSupport
      ..sP2pUrl = sP2pUrl
      ..sP2pUrlSuffix = sP2pUrlSuffix
      ..sP2pAntiCode = sP2pAntiCode
      ..lFreeFlag = lFreeFlag
      ..iIsHevcSupport = iIsHevcSupport
      ..vP2pIpList = List.from(vP2pIpList)
      ..mpExtArgs = Map.from(mpExtArgs)
      ..lTimespan = lTimespan
      ..lUpdateTime = lUpdateTime;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayString(sCdnType, "sCdnType");
    _ds.DisplayInt(iIsMaster, "iIsMaster");
    _ds.DisplayInt(lChannelId, "lChannelId");
    _ds.DisplayInt(lSubChannelId, "lSubChannelId");
    _ds.DisplayInt(lPresenterUid, "lPresenterUid");
    _ds.DisplayString(sStreamName, "sStreamName");
    _ds.DisplayString(sFlvUrl, "sFlvUrl");
    _ds.DisplayString(sFlvUrlSuffix, "sFlvUrlSuffix");
    _ds.DisplayString(sFlvAntiCode, "sFlvAntiCode");
    _ds.DisplayString(sHlsUrl, "sHlsUrl");
    _ds.DisplayString(sHlsUrlSuffix, "sHlsUrlSuffix");
    _ds.DisplayString(sHlsAntiCode, "sHlsAntiCode");
    _ds.DisplayInt(iLineIndex, "iLineIndex");
    _ds.DisplayInt(iIsMultiStream, "iIsMultiStream");
    _ds.DisplayInt(iPcPriorityRate, "iPcPriorityRate");
    _ds.DisplayInt(iWebPriorityRate, "iWebPriorityRate");
    _ds.DisplayInt(iMobilePriorityRate, "iMobilePriorityRate");
    _ds.DisplayList(vFlvIpList, "vFlvIpList");
    _ds.DisplayInt(iIsP2pSupport, "iIsP2pSupport");
    _ds.DisplayString(sP2pUrl, "sP2pUrl");
    _ds.DisplayString(sP2pUrlSuffix, "sP2pUrlSuffix");
    _ds.DisplayString(sP2pAntiCode, "sP2pAntiCode");
    _ds.DisplayInt(lFreeFlag, "lFreeFlag");
    _ds.DisplayInt(iIsHevcSupport, "iIsHevcSupport");
    _ds.DisplayList(vP2pIpList, "vP2pIpList");
    _ds.DisplayMap(mpExtArgs, "mpExtArgs");
    _ds.DisplayInt(lTimespan, "lTimespan");
    _ds.DisplayInt(lUpdateTime, "lUpdateTime");
  }
}

class MultiStreamInfo extends TarsStruct {
  String sDisplayName = "";
  int iBitRate = 0;
  int iCodecType = 0;
  int iCompatibleFlag = 0;
  int iHevcBitRate = -1;
  int iEnable = 1;
  int iEnableMethod = 0;
  String sEnableUrl = "";
  String sTipText = "";
  String sTagText = "";
  String sTagUrl = "";
  int iFrameRate = 0;
  int iSortValue = 0;

  @override
  void readFrom(TarsInputStream _is) {
    sDisplayName = _is.read(sDisplayName, 0, false);
    iBitRate = _is.read(iBitRate, 1, false);
    iCodecType = _is.read(iCodecType, 2, false);
    iCompatibleFlag = _is.read(iCompatibleFlag, 3, false);
    iHevcBitRate = _is.read(iHevcBitRate, 4, false);
    iEnable = _is.read(iEnable, 5, false);
    iEnableMethod = _is.read(iEnableMethod, 6, false);
    sEnableUrl = _is.read(sEnableUrl, 7, false);
    sTipText = _is.read(sTipText, 8, false);
    sTagText = _is.read(sTagText, 9, false);
    sTagUrl = _is.read(sTagUrl, 10, false);
    iFrameRate = _is.read(iFrameRate, 11, false);
    iSortValue = _is.read(iSortValue, 12, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(sDisplayName, 0);
    _os.write(iBitRate, 1);
    _os.write(iCodecType, 2);
    _os.write(iCompatibleFlag, 3);
    _os.write(iHevcBitRate, 4);
    _os.write(iEnable, 5);
    _os.write(iEnableMethod, 6);
    _os.write(sEnableUrl, 7);
    _os.write(sTipText, 8);
    _os.write(sTagText, 9);
    _os.write(sTagUrl, 10);
    _os.write(iFrameRate, 11);
    _os.write(iSortValue, 12);
  }

  @override
  Object deepCopy() {
    return MultiStreamInfo()
      ..sDisplayName = sDisplayName
      ..iBitRate = iBitRate
      ..iCodecType = iCodecType
      ..iCompatibleFlag = iCompatibleFlag
      ..iHevcBitRate = iHevcBitRate
      ..iEnable = iEnable
      ..iEnableMethod = iEnableMethod
      ..sEnableUrl = sEnableUrl
      ..sTipText = sTipText
      ..sTagText = sTagText
      ..sTagUrl = sTagUrl
      ..iFrameRate = iFrameRate
      ..iSortValue = iSortValue;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayString(sDisplayName, "sDisplayName");
    _ds.DisplayInt(iBitRate, "iBitRate");
    _ds.DisplayInt(iCodecType, "iCodecType");
    _ds.DisplayInt(iCompatibleFlag, "iCompatibleFlag");
    _ds.DisplayInt(iHevcBitRate, "iHevcBitRate");
    _ds.DisplayInt(iEnable, "iEnable");
    _ds.DisplayInt(iEnableMethod, "iEnableMethod");
    _ds.DisplayString(sEnableUrl, "sEnableUrl");
    _ds.DisplayString(sTipText, "sTipText");
    _ds.DisplayString(sTagText, "sTagText");
    _ds.DisplayString(sTagUrl, "sTagUrl");
    _ds.DisplayInt(iFrameRate, "iFrameRate");
    _ds.DisplayInt(iSortValue, "iSortValue");
  }
}

class BeginLiveNotice extends TarsStruct {
  int lPresenterUid = 0;
  int iGameId = 0;
  String sGameName = "";
  int iRandomRange = 0;
  int iStreamType = 0;
  List<StreamInfo> vStreamInfo = [];
  List<String> vCdnList = [];
  int lLiveId = 0;
  int iPcDefaultBitRate = 0;
  int iWebDefaultBitRate = 0;
  int iMobileDefaultBitRate = 0;
  int lMultiStreamFlag = 0;
  String sNick = "";
  int lYyId = 0;
  int lAttendeeCount = 0;
  int iCodecType = 0;
  int iScreenType = 0;
  List<MultiStreamInfo> vMultiStreamInfo = [];
  String sLiveDesc = "";
  int lLiveCompatibleFlag = 0;
  String sAvatarUrl = "";
  int iSourceType = 0;
  String sSubchannelName = "";
  String sVideoCaptureUrl = "";
  int iStartTime = 0;
  int lChannelId = 0;
  int lSubChannelId = 0;
  String sLocation = "";
  int iCdnPolicyLevel = 0;
  int iGameType = 0;
  Map<String, String> mMiscInfo = {};
  int iShortChannel = 0;
  int iRoomId = 0;
  int bIsRoomSecret = 0;
  int iHashPolicy = 0;
  int lSignChannel = 0;
  int iMobileWifiDefaultBitRate = 0;
  int iEnableAutoBitRate = 0;
  int iTemplate = 0;
  int iReplay = 0;

  @override
  void readFrom(TarsInputStream _is) {
    lPresenterUid = _is.read(lPresenterUid, 0, false);
    iGameId = _is.read(iGameId, 1, false);
    sGameName = _is.read(sGameName, 2, false);
    iRandomRange = _is.read(iRandomRange, 3, false);
    iStreamType = _is.read(iStreamType, 4, false);
    vStreamInfo = _is.read(vStreamInfo, 5, false);
    vCdnList = _is.read(vCdnList, 6, false);
    lLiveId = _is.read(lLiveId, 7, false);
    iPcDefaultBitRate = _is.read(iPcDefaultBitRate, 8, false);
    iWebDefaultBitRate = _is.read(iWebDefaultBitRate, 9, false);
    iMobileDefaultBitRate = _is.read(iMobileDefaultBitRate, 10, false);
    lMultiStreamFlag = _is.read(lMultiStreamFlag, 11, false);
    sNick = _is.read(sNick, 12, false);
    lYyId = _is.read(lYyId, 13, false);
    lAttendeeCount = _is.read(lAttendeeCount, 14, false);
    iCodecType = _is.read(iCodecType, 15, false);
    iScreenType = _is.read(iScreenType, 16, false);
    vMultiStreamInfo = _is.read(vMultiStreamInfo, 17, false);
    sLiveDesc = _is.read(sLiveDesc, 18, false);
    lLiveCompatibleFlag = _is.read(lLiveCompatibleFlag, 19, false);
    sAvatarUrl = _is.read(sAvatarUrl, 20, false);
    iSourceType = _is.read(iSourceType, 21, false);
    sSubchannelName = _is.read(sSubchannelName, 22, false);
    sVideoCaptureUrl = _is.read(sVideoCaptureUrl, 23, false);
    iStartTime = _is.read(iStartTime, 24, false);
    lChannelId = _is.read(lChannelId, 25, false);
    lSubChannelId = _is.read(lSubChannelId, 26, false);
    sLocation = _is.read(sLocation, 27, false);
    iCdnPolicyLevel = _is.read(iCdnPolicyLevel, 28, false);
    iGameType = _is.read(iGameType, 29, false);
    mMiscInfo = _is.read(mMiscInfo, 30, false);
    iShortChannel = _is.read(iShortChannel, 31, false);
    iRoomId = _is.read(iRoomId, 32, false);
    bIsRoomSecret = _is.read(bIsRoomSecret, 33, false);
    iHashPolicy = _is.read(iHashPolicy, 34, false);
    lSignChannel = _is.read(lSignChannel, 35, false);
    iMobileWifiDefaultBitRate = _is.read(iMobileWifiDefaultBitRate, 36, false);
    iEnableAutoBitRate = _is.read(iEnableAutoBitRate, 37, false);
    iTemplate = _is.read(iTemplate, 38, false);
    iReplay = _is.read(iReplay, 39, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(lPresenterUid, 0);
    _os.write(iGameId, 1);
    _os.write(sGameName, 2);
    _os.write(iRandomRange, 3);
    _os.write(iStreamType, 4);
    _os.write(vStreamInfo, 5);
    _os.write(vCdnList, 6);
    _os.write(lLiveId, 7);
    _os.write(iPcDefaultBitRate, 8);
    _os.write(iWebDefaultBitRate, 9);
    _os.write(iMobileDefaultBitRate, 10);
    _os.write(lMultiStreamFlag, 11);
    _os.write(sNick, 12);
    _os.write(lYyId, 13);
    _os.write(lAttendeeCount, 14);
    _os.write(iCodecType, 15);
    _os.write(iScreenType, 16);
    _os.write(vMultiStreamInfo, 17);
    _os.write(sLiveDesc, 18);
    _os.write(lLiveCompatibleFlag, 19);
    _os.write(sAvatarUrl, 20);
    _os.write(iSourceType, 21);
    _os.write(sSubchannelName, 22);
    _os.write(sVideoCaptureUrl, 23);
    _os.write(iStartTime, 24);
    _os.write(lChannelId, 25);
    _os.write(lSubChannelId, 26);
    _os.write(sLocation, 27);
    _os.write(iCdnPolicyLevel, 28);
    _os.write(iGameType, 29);
    _os.write(mMiscInfo, 30);
    _os.write(iShortChannel, 31);
    _os.write(iRoomId, 32);
    _os.write(bIsRoomSecret, 33);
    _os.write(iHashPolicy, 34);
    _os.write(lSignChannel, 35);
    _os.write(iMobileWifiDefaultBitRate, 36);
    _os.write(iEnableAutoBitRate, 37);
    _os.write(iTemplate, 38);
    _os.write(iReplay, 39);
  }

  @override
  Object deepCopy() {
    return BeginLiveNotice()
      ..lPresenterUid = lPresenterUid
      ..iGameId = iGameId
      ..sGameName = sGameName
      ..iRandomRange = iRandomRange
      ..iStreamType = iStreamType
      ..vStreamInfo =
          vStreamInfo.map((e) => e.deepCopy() as StreamInfo).toList()
      ..vCdnList = List.from(vCdnList)
      ..lLiveId = lLiveId
      ..iPcDefaultBitRate = iPcDefaultBitRate
      ..iWebDefaultBitRate = iWebDefaultBitRate
      ..iMobileDefaultBitRate = iMobileDefaultBitRate
      ..lMultiStreamFlag = lMultiStreamFlag
      ..sNick = sNick
      ..lYyId = lYyId
      ..lAttendeeCount = lAttendeeCount
      ..iCodecType = iCodecType
      ..iScreenType = iScreenType
      ..vMultiStreamInfo =
          vMultiStreamInfo.map((e) => e.deepCopy() as MultiStreamInfo).toList()
      ..sLiveDesc = sLiveDesc
      ..lLiveCompatibleFlag = lLiveCompatibleFlag
      ..sAvatarUrl = sAvatarUrl
      ..iSourceType = iSourceType
      ..sSubchannelName = sSubchannelName
      ..sVideoCaptureUrl = sVideoCaptureUrl
      ..iStartTime = iStartTime
      ..lChannelId = lChannelId
      ..lSubChannelId = lSubChannelId
      ..sLocation = sLocation
      ..iCdnPolicyLevel = iCdnPolicyLevel
      ..iGameType = iGameType
      ..mMiscInfo = Map.from(mMiscInfo)
      ..iShortChannel = iShortChannel
      ..iRoomId = iRoomId
      ..bIsRoomSecret = bIsRoomSecret
      ..iHashPolicy = iHashPolicy
      ..lSignChannel = lSignChannel
      ..iMobileWifiDefaultBitRate = iMobileWifiDefaultBitRate
      ..iEnableAutoBitRate = iEnableAutoBitRate
      ..iTemplate = iTemplate
      ..iReplay = iReplay;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayInt(lPresenterUid, "lPresenterUid");
    _ds.DisplayInt(iGameId, "iGameId");
    _ds.DisplayString(sGameName, "sGameName");
    _ds.DisplayInt(iRandomRange, "iRandomRange");
    _ds.DisplayInt(iStreamType, "iStreamType");
    _ds.DisplayList(vStreamInfo, "vStreamInfo");
    _ds.DisplayList(vCdnList, "vCdnList");
    _ds.DisplayInt(lLiveId, "lLiveId");
    _ds.DisplayInt(iPcDefaultBitRate, "iPcDefaultBitRate");
    _ds.DisplayInt(iWebDefaultBitRate, "iWebDefaultBitRate");
    _ds.DisplayInt(iMobileDefaultBitRate, "iMobileDefaultBitRate");
    _ds.DisplayInt(lMultiStreamFlag, "lMultiStreamFlag");
    _ds.DisplayString(sNick, "sNick");
    _ds.DisplayInt(lYyId, "lYyId");
    _ds.DisplayInt(lAttendeeCount, "lAttendeeCount");
    _ds.DisplayInt(iCodecType, "iCodecType");
    _ds.DisplayInt(iScreenType, "iScreenType");
    _ds.DisplayList(vMultiStreamInfo, "vMultiStreamInfo");
    _ds.DisplayString(sLiveDesc, "sLiveDesc");
    _ds.DisplayInt(lLiveCompatibleFlag, "lLiveCompatibleFlag");
    _ds.DisplayString(sAvatarUrl, "sAvatarUrl");
    _ds.DisplayInt(iSourceType, "iSourceType");
    _ds.DisplayString(sSubchannelName, "sSubchannelName");
    _ds.DisplayString(sVideoCaptureUrl, "sVideoCaptureUrl");
    _ds.DisplayInt(iStartTime, "iStartTime");
    _ds.DisplayInt(lChannelId, "lChannelId");
    _ds.DisplayInt(lSubChannelId, "lSubChannelId");
    _ds.DisplayString(sLocation, "sLocation");
    _ds.DisplayInt(iCdnPolicyLevel, "iCdnPolicyLevel");
    _ds.DisplayInt(iGameType, "iGameType");
    _ds.DisplayMap(mMiscInfo, "mMiscInfo");
    _ds.DisplayInt(iShortChannel, "iShortChannel");
    _ds.DisplayInt(iRoomId, "iRoomId");
    _ds.DisplayInt(bIsRoomSecret, "bIsRoomSecret");
    _ds.DisplayInt(iHashPolicy, "iHashPolicy");
    _ds.DisplayInt(lSignChannel, "lSignChannel");
    _ds.DisplayInt(iMobileWifiDefaultBitRate, "iMobileWifiDefaultBitRate");
    _ds.DisplayInt(iEnableAutoBitRate, "iEnableAutoBitRate");
    _ds.DisplayInt(iTemplate, "iTemplate");
    _ds.DisplayInt(iReplay, "iReplay");
  }
}

class StreamSettingNotice extends TarsStruct {
  int lPresenterUid = 0;
  int iBitRate = 0;
  int iResolution = 0;
  int iFrameRate = 0;
  int lLiveId = 0;
  String sDisplayName = "";
  int iScreenType = 0;
  String sVideoLayout = "";
  int iLowDelayMode = 0;

  @override
  void readFrom(TarsInputStream _is) {
    lPresenterUid = _is.read(lPresenterUid, 0, false);
    iBitRate = _is.read(iBitRate, 1, false);
    iResolution = _is.read(iResolution, 2, false);
    iFrameRate = _is.read(iFrameRate, 3, false);
    lLiveId = _is.read(lLiveId, 4, false);
    sDisplayName = _is.read(sDisplayName, 5, false);
    iScreenType = _is.read(iScreenType, 6, false);
    sVideoLayout = _is.read(sVideoLayout, 7, false);
    iLowDelayMode = _is.read(iLowDelayMode, 8, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(lPresenterUid, 0);
    _os.write(iBitRate, 1);
    _os.write(iResolution, 2);
    _os.write(iFrameRate, 3);
    _os.write(lLiveId, 4);
    _os.write(sDisplayName, 5);
    _os.write(iScreenType, 6);
    _os.write(sVideoLayout, 7);
    _os.write(iLowDelayMode, 8);
  }

  @override
  TarsStruct deepCopy() {
    return StreamSettingNotice()
      ..lPresenterUid = lPresenterUid
      ..iBitRate = iBitRate
      ..iResolution = iResolution
      ..iFrameRate = iFrameRate
      ..lLiveId = lLiveId
      ..sDisplayName = sDisplayName
      ..iScreenType = iScreenType
      ..sVideoLayout = sVideoLayout
      ..iLowDelayMode = iLowDelayMode;
  }

  @override
  displayAsString(StringBuffer sb, int level) {
    TarsDisplayer _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayInt(lPresenterUid, "lPresenterUid");
    _ds.DisplayInt(iBitRate, "iBitRate");
    _ds.DisplayInt(iResolution, "iResolution");
    _ds.DisplayInt(iFrameRate, "iFrameRate");
    _ds.DisplayInt(lLiveId, "lLiveId");
    _ds.DisplayString(sDisplayName, "sDisplayName");
    _ds.DisplayInt(iScreenType, "iScreenType");
    _ds.DisplayString(sVideoLayout, "sVideoLayout");
    _ds.DisplayInt(iLowDelayMode, "iLowDelayMode");
  }
}

class GetLivingInfoRsp extends TarsStruct {
  int bIsLiving = 0;
  BeginLiveNotice tNotice = BeginLiveNotice();
  StreamSettingNotice tStreamSettingNotice = StreamSettingNotice();
  int bIsSelfLiving = 0;
  String sMessage = "";
  int iShowTitleForImmersion = 0;

  @override
  void readFrom(TarsInputStream _is) {
    bIsLiving = _is.read(bIsLiving, 0, false);
    tNotice = _is.read(tNotice, 1, false);
    tStreamSettingNotice = _is.read(tStreamSettingNotice, 2, false);
    bIsSelfLiving = _is.read(bIsSelfLiving, 3, false);
    sMessage = _is.read(sMessage, 4, false);
    iShowTitleForImmersion = _is.read(iShowTitleForImmersion, 5, false);
  }

  @override
  void writeTo(TarsOutputStream _os) {
    _os.write(bIsLiving, 0);
    _os.write(tNotice, 1);
    _os.write(tStreamSettingNotice, 2);
    _os.write(bIsSelfLiving, 3);
    _os.write(sMessage, 4);
    _os.write(iShowTitleForImmersion, 5);
  }

  @override
  TarsStruct deepCopy() {
    return GetLivingInfoRsp()
      ..bIsLiving = bIsLiving
      ..tNotice = tNotice
      ..tStreamSettingNotice = tStreamSettingNotice
      ..bIsSelfLiving = bIsSelfLiving
      ..sMessage = sMessage
      ..iShowTitleForImmersion = iShowTitleForImmersion;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {
    final _ds = TarsDisplayer(sb, level: level);
    _ds.DisplayInt(bIsLiving, "bIsLiving");
    _ds.DisplayTarsStruct(tNotice, "tNotice");
    _ds.DisplayTarsStruct(tStreamSettingNotice, "tStreamSettingNotice");
    _ds.DisplayInt(bIsSelfLiving, "bIsSelfLiving");
    _ds.DisplayString(sMessage, "sMessage");
    _ds.DisplayInt(iShowTitleForImmersion, "iShowTitleForImmersion");
  }
}
