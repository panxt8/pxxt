import 'package:flutter/material.dart';
import '../../core/models/course.dart';
import '../course_sign/course_sign_page.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(course.title),
        subtitle: Text('教师：${course.teacher}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CourseSignPage(course: course)),
          );
        },
      ),
    );
  }
}
