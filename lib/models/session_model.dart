class SessionModel {
  final String userId;         // 사용자 ID
  final String userPassword;   // 사용자 PW
  final String cookie;         // token 값이 포함된 cookie값

  SessionModel({               // 생성자
    required this.userId,
    required this.userPassword,
    required this.cookie,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userPassword': userPassword,
      'cookie': cookie,
    };
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      userId: json['userId'] ?? '',
      userPassword: json['userPassword'] ?? '',
      cookie: json['cookie'] ?? '',
    );
  }

  // cookie를 교체해 세션 갱신하기 위함
  SessionModel copyWith({String? cookie}) {
    return SessionModel(
      userId: userId,
      userPassword: userPassword,
      cookie: cookie ?? this.cookie,
    );
  }
}