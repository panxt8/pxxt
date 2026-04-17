class SignSession {
  const SignSession({
    required this.cookie,
    required this.uid,
    required this.fid,
    required this.username,
  });

  final String cookie;
  final String uid;
  final String fid;
  final String username;

  bool get isValid => cookie.isNotEmpty && uid.isNotEmpty;
}
