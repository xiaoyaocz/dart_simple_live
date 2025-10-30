class TwitchResponse {
  final Data data;

  TwitchResponse({required this.data});

  factory TwitchResponse.fromJson(Map<String, dynamic> json) {
    return TwitchResponse(
      data: Data.fromJson(json['data']),
    );
  }
}

class Data {
  final UserOrError? userOrError;
  final User? user;

  Data({this.userOrError, this.user});

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      userOrError: json['userOrError'] != null
          ? UserOrError.fromJson(json['userOrError'])
          : null,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}

class Extensions {
  final int durationMilliseconds;
  final String operationName;
  final String requestId;

  Extensions({
    required this.durationMilliseconds,
    required this.operationName,
    required this.requestId,
  });

  factory Extensions.fromJson(Map<String, dynamic> json) {
    return Extensions(
      durationMilliseconds: json['durationMilliseconds'],
      operationName: json['operationName'],
      requestId: json['requestId'],
    );
  }
}

class UserOrError {
  final String id;
  final String login;
  final String displayName;
  final String primaryColorHex;
  final String profileImageUrl;
  final Stream? stream;
  final String typename;

  UserOrError({
    required this.id,
    required this.login,
    required this.displayName,
    required this.primaryColorHex,
    required this.profileImageUrl,
    this.stream,
    required this.typename,
  });

  factory UserOrError.fromJson(Map<String, dynamic> json) {
    return UserOrError(
      id: json['id'] ?? '',
      login: json['login'] ?? '',
      displayName: json['displayName'] ?? '',
      primaryColorHex: json['primaryColorHex'] ?? '',
      profileImageUrl: json['profileImageURL'] ?? '',
      stream: json['stream'] != null ? Stream.fromJson(json['stream']) : null,
      typename: json['__typename'] ?? '',
    );
  }
}

class User {
  final String id;
  final String primaryColorHex;
  final bool isPartner;
  final String profileImageUrl;
  final PrimaryTeam? primaryTeam;
  final Channel channel;
  final LastBroadcast? lastBroadcast;
  final Stream? stream;
  final String typename;

  User({
    required this.id,
    required this.primaryColorHex,
    required this.isPartner,
    required this.profileImageUrl,
    this.primaryTeam,
    required this.channel,
    this.lastBroadcast,
    this.stream,
    required this.typename,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      primaryColorHex: json['primaryColorHex'] ?? '',
      isPartner: json['isPartner'] ?? false,
      profileImageUrl: json['profileImageURL'] ?? '',
      primaryTeam: json['primaryTeam'] != null
          ? PrimaryTeam.fromJson(json['primaryTeam'])
          : null,
      channel: Channel.fromJson(json['channel']),
      lastBroadcast: json['lastBroadcast'] != null
          ? LastBroadcast.fromJson(json['lastBroadcast'])
          : null,
      stream: json['stream'] != null ? Stream.fromJson(json['stream']) : null,
      typename: json['__typename'] ?? '',
    );
  }
}

class Stream {
  final String id;
  final int viewersCount;
  final String typename;
  final String? streamType;
  final String? createdAt;
  final Game? game;

  Stream({
    required this.id,
    required this.viewersCount,
    required this.typename,
    this.streamType,
    this.createdAt,
    this.game,
  });

  factory Stream.fromJson(Map<String, dynamic> json) {
    return Stream(
      id: json['id'] ?? '',
      viewersCount: json['viewersCount'] ?? 0,
      typename: json['__typename'] ?? '',
      streamType: json['type'],
      createdAt: json['createdAt'],
      game: json['game'] != null ? Game.fromJson(json['game']) : null,
    );
  }
}

class Game {
  final String id;
  final String name;
  final String typename;

  Game({
    required this.id,
    required this.name,
    required this.typename,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      typename: json['__typename'] ?? '',
    );
  }
}

class Channel {
  final String id;
  final String typename;
  final ChannelSelfEdge? selfEdge;
  final Trailer? trailer;

  Channel({
    required this.id,
    required this.typename,
    this.selfEdge,
    this.trailer,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] ?? '',
      typename: json['__typename'] ?? '',
      selfEdge:
          json['self'] != null ? ChannelSelfEdge.fromJson(json['self']) : null,
      trailer:
          json['trailer'] != null ? Trailer.fromJson(json['trailer']) : null,
    );
  }
}

class ChannelSelfEdge {
  final bool isAuthorized;
  final String? restrictionType;
  final String typename;

  ChannelSelfEdge({
    required this.isAuthorized,
    this.restrictionType,
    required this.typename,
  });

  factory ChannelSelfEdge.fromJson(Map<String, dynamic> json) {
    return ChannelSelfEdge(
      isAuthorized: json['isAuthorized'] ?? false,
      restrictionType: json['restrictionType'],
      typename: json['__typename'] ?? '',
    );
  }
}

class Trailer {
  final String typename;

  Trailer({
    required this.typename,
  });

  factory Trailer.fromJson(Map<String, dynamic> json) {
    return Trailer(
      typename: json['__typename'] ?? '',
    );
  }
}

class PrimaryTeam {
  final String id;
  final String name;
  final String displayName;
  final String typename;

  PrimaryTeam({
    required this.id,
    required this.name,
    required this.displayName,
    required this.typename,
  });

  factory PrimaryTeam.fromJson(Map<String, dynamic> json) {
    return PrimaryTeam(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? '',
      typename: json['__typename'] ?? '',
    );
  }
}

class LastBroadcast {
  final String id;
  final String title;
  final String typename;

  LastBroadcast({
    required this.id,
    required this.title,
    required this.typename,
  });

  factory LastBroadcast.fromJson(Map<String, dynamic> json) {
    return LastBroadcast(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      typename: json['__typename'] ?? '',
    );
  }
}
