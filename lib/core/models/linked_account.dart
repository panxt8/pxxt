class LinkedAccount {
  const LinkedAccount({
    required this.username,
    required this.password,
    this.remark = '',
    this.uid = '',
  });

  final String username;
  final String password;
  final String remark;
  final String uid;

  String get displayName => remark.isNotEmpty ? remark : username;

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'remark': remark,
      'uid': uid,
    };
  }

  static LinkedAccount fromJson(Map<String, dynamic> json) {
    return LinkedAccount(
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
      uid: json['uid']?.toString() ?? '',
    );
  }
}
