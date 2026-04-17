class AppSession {
  const AppSession({
    required this.cookie,
    required this.uid,
    required this.fid,
  });

  final String cookie;
  final String uid;
  final String fid;

  bool get isValid => cookie.isNotEmpty && uid.isNotEmpty;
}
