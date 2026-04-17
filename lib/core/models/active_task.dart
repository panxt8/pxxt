class ActiveTask {
  const ActiveTask({
    required this.id,
    required this.name,
    required this.status,
    required this.type,
    required this.preSignUrl,
  });

  final String id;
  final String name;
  final String status;
  final String type;
  final String preSignUrl;

  bool get isClosed => status == '2';
}
