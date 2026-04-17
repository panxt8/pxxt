import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/app_dio.dart';
import '../../core/storage/app_storage.dart';
import '../auth/auth_controller.dart';
import 'course_card.dart';
import 'home_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeController>(
      create: (context) => HomeController(
        dio: context.read<AppDio>(),
        storage: context.read<AppStorage>(),
      )..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!auth.isLoggedIn) {
      return const Scaffold(
        appBar: null,
        body: Center(
          child: Text(
            '请先登录账号',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    final controller = context.watch<HomeController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.username.isEmpty ? '首页' : controller.username),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<HomeController>().load(),
        child: Builder(
          builder: (context) {
            if (controller.loading && controller.courses.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.error != null && controller.courses.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(controller.error!)),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: controller.courses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return CourseCard(course: controller.courses[index]);
              },
            );
          },
        ),
      ),
    );
  }
}
