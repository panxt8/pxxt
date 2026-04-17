import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/models/active_task.dart';
import '../../core/models/course.dart';
import '../../core/models/sign_flow_result.dart';
import '../../core/network/app_dio.dart';
import '../../core/storage/app_storage.dart';
import 'course_sign_controller.dart';
import 'location_pick_page.dart';

class CourseSignPage extends StatelessWidget {
  const CourseSignPage({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CourseSignController>(
      create: (context) => CourseSignController(
        dio: context.read<AppDio>(),
        storage: context.read<AppStorage>(),
        course: course,
      )..load(),
      child: _CourseSignView(course: course),
    );
  }
}

class _CourseSignView extends StatelessWidget {
  const _CourseSignView({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CourseSignController>();
    return Scaffold(
      appBar: AppBar(title: Text(course.title)),
      body: RefreshIndicator(
        onRefresh: () => context.read<CourseSignController>().load(),
        child: Builder(
          builder: (context) {
            if (controller.loading && controller.tasks.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!controller.loading && controller.tasks.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('当前没有可读取到的签到活动')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: controller.tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = controller.tasks[index];
                return Card(
                  child: ListTile(
                    title: Text(task.name),
                    subtitle: Text(task.isClosed ? '已结束' : '可签到'),
                    trailing: controller.signing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: controller.signing
                        ? null
                        : () => _onTapTask(context, task),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _onTapTask(BuildContext context, ActiveTask task) async {
    if (task.isClosed) {
      _showMessage(context, '签到已结束');
      return;
    }
    final controller = context.read<CourseSignController>();
    final signType = await controller.fetchSignType(task);
    if (!context.mounted) return;
    if (signType.isQrCodeSign) {
      await controller.preSignForQr(task);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _QrSignPage(task: task, controller: controller),
        ),
      );
      return;
    }
    if (signType.isPhotoSign) {
      final result = await Navigator.of(context).push<SignFlowResult>(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: controller,
            child: _PhotoSignPage(task: task, controller: controller),
          ),
        ),
      );
      if (result == null || !context.mounted) return;
      _showMessage(context, result.success ? '拍照签到成功' : result.message);
      return;
    }
    if (signType.isCodeSign || signType.isGestureSign) {
      final signAid = signType.activeId.isNotEmpty
          ? signType.activeId
          : task.id;
      if (!context.mounted) return;
      String? code;
      if (signType.isGestureSign) {
        code = await _showGestureDialog(context);
      } else {
        code = await _showSignCodeDialog(
          context,
          title: '输入签到码',
          hintText: '请输入签到码',
        );
      }
      if (!context.mounted || code == null || code.isEmpty) return;
      final result = await controller.normalSign(
        task,
        signCode: code,
        aid: signAid,
      );
      if (!context.mounted) return;
      _showMessage(context, result.success ? '签到成功' : result.message);
      return;
    }
    if (signType.isLocationSign) {
      final signAid = signType.activeId.isNotEmpty
          ? signType.activeId
          : task.id;
      final allowDirectSign = await controller.canUseDirectLocationSign(
        signAid,
      );
      if (!context.mounted) return;
      final mode = await _showLocationSignModeDialog(
        context,
        allowDirectSign: allowDirectSign,
      );
      if (!context.mounted || mode == null) return;
      late final SignFlowResult result;
      if (mode == _LocationSignMode.current) {
        final fallbackAddress = await _showLocationNameDialog(
          context,
          title: '当前位置地点名称',
        );
        if (!context.mounted || fallbackAddress == null) return;
        result = await controller.locationSign(
          task,
          aid: signAid,
          fallbackAddress: fallbackAddress,
        );
      } else if (mode == _LocationSignMode.direct) {
        result = await controller.locationDirectSign(task, aid: signAid);
      } else {
        final picked = await Navigator.of(context).push<LocationPickResult>(
          MaterialPageRoute(builder: (_) => const LocationPickPage()),
        );
        if (!context.mounted || picked == null) return;
        result = await controller.locationSignAt(
          task,
          aid: signAid,
          latitude: picked.latitude,
          longitude: picked.longitude,
          fallbackAddress: picked.locationName,
        );
      }
      if (!context.mounted) return;
      _showMessage(context, result.success ? '定位签到成功' : result.message);
      return;
    }
    final result = await controller.normalSign(task);
    if (!context.mounted) return;
    _showMessage(context, result.success ? '签到成功' : result.message);
  }

  Future<String?> _showSignCodeDialog(
    BuildContext context, {
    String title = '输入签到码',
    String hintText = '',
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: hintText.isEmpty
                ? null
                : InputDecoration(hintText: hintText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showLocationNameDialog(
    BuildContext context, {
    required String title,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '可留空'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _showGestureDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _GestureInputDialog(),
    );
  }

  Future<_LocationSignMode?> _showLocationSignModeDialog(
    BuildContext context, {
    required bool allowDirectSign,
  }) {
    return showDialog<_LocationSignMode>(
      context: context,
      builder: (context) {
        Widget signModeButton({
          required String text,
          required _LocationSignMode mode,
        }) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(mode),
              child: Text(text),
            ),
          );
        }

        return AlertDialog(
          title: const Text('位置签到方式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('请选择签到位置来源'),
              const SizedBox(height: 12),
              signModeButton(text: '选择位置签到', mode: _LocationSignMode.pickOnMap),
              const SizedBox(height: 8),
              if (allowDirectSign) ...[
                signModeButton(text: '直接签到', mode: _LocationSignMode.direct),
                const SizedBox(height: 8),
              ],
              signModeButton(text: '当前位置签到', mode: _LocationSignMode.current),
            ],
          ),
          actionsAlignment: MainAxisAlignment.start,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _PhotoSignPage extends StatefulWidget {
  const _PhotoSignPage({required this.task, required this.controller});

  final ActiveTask task;
  final CourseSignController controller;

  @override
  State<_PhotoSignPage> createState() => _PhotoSignPageState();
}

class _PhotoSignPageState extends State<_PhotoSignPage> {
  static const _mainKey = '__main__';
  final ImagePicker _picker = ImagePicker();
  final Map<String, String> _paths = <String, String>{};

  List<_PhotoAccountTarget> get _targets {
    final mainLabel = widget.controller.mainUsername.trim().isEmpty
        ? '主账号'
        : '主账号(${widget.controller.mainUsername.trim()})';
    return [
      _PhotoAccountTarget(key: _mainKey, displayName: mainLabel),
      for (final account in widget.controller.linkedAccounts)
        _PhotoAccountTarget(
          key: account.username,
          displayName: account.displayName,
          subtitle: account.username,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final signing = context.watch<CourseSignController>().signing;
    return Scaffold(
      appBar: AppBar(title: const Text('照片签到')),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: _targets.length,
        itemBuilder: (context, index) {
          final target = _targets[index];
          final path = _paths[target.key] ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (target.subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        target.subtitle,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: signing
                            ? null
                            : () => _pickFor(target.key, ImageSource.camera),
                        child: const Text('拍照'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: signing
                            ? null
                            : () => _pickFor(target.key, ImageSource.gallery),
                        child: const Text('相册'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (path.isEmpty)
                    Text('未选择照片', style: TextStyle(color: Colors.grey.shade700))
                  else
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(path),
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 58,
                              height: 58,
                              color: Colors.grey.shade300,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            path.split('/').last,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: FilledButton(
            onPressed: signing ? null : _submit,
            child: signing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('一键签到'),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFor(String key, ImageSource source) async {
    final image = await _picker.pickImage(source: source);
    if (!mounted || image == null) return;
    setState(() {
      _paths[key] = image.path;
    });
  }

  Future<void> _submit() async {
    final mainPath = (_paths[_mainKey] ?? '').trim();
    if (mainPath.isEmpty) {
      _showMessage('请先为主账号选择照片');
      return;
    }
    for (final account in widget.controller.linkedAccounts) {
      final linkedPath = (_paths[account.username] ?? '').trim();
      if (linkedPath.isEmpty) {
        _showMessage('请为 ${account.displayName} 选择照片');
        return;
      }
    }

    final linkedMap = <String, String>{
      for (final account in widget.controller.linkedAccounts)
        account.username: _paths[account.username]!.trim(),
    };
    final result = await widget.controller.photoSignBatch(
      widget.task,
      mainFilePath: mainPath,
      linkedFilePaths: linkedMap,
    );
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PhotoAccountTarget {
  const _PhotoAccountTarget({
    required this.key,
    required this.displayName,
    this.subtitle = '',
  });

  final String key;
  final String displayName;
  final String subtitle;
}

class _QrSignPage extends StatefulWidget {
  const _QrSignPage({required this.task, required this.controller});

  final ActiveTask task;
  final CourseSignController controller;

  @override
  State<_QrSignPage> createState() => _QrSignPageState();
}

enum _LocationSignMode { current, pickOnMap, direct }

class _GestureInputDialog extends StatefulWidget {
  const _GestureInputDialog();

  @override
  State<_GestureInputDialog> createState() => _GestureInputDialogState();
}

class _GestureInputDialogState extends State<_GestureInputDialog> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('滑动手势签到'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 260,
            height: 260,
            child: _GestureBoard(
              onChanged: (value) {
                setState(() {
                  _code = value;
                });
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _code.length < 2
              ? null
              : () => Navigator.of(context).pop(_code),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _GestureBoard extends StatefulWidget {
  const _GestureBoard({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_GestureBoard> createState() => _GestureBoardState();
}

class _GestureBoardState extends State<_GestureBoard> {
  static const int _grid = 3;
  static const double _nodeRadius = 18;
  final List<int> _path = <int>[];
  Offset? _finger;
  bool _drawing = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final centers = _buildCenters(size);
        return GestureDetector(
          onPanStart: (details) {
            _drawing = true;
            _path.clear();
            _finger = details.localPosition;
            _addIfHit(details.localPosition, centers);
            _emit();
            setState(() {});
          },
          onPanUpdate: (details) {
            if (!_drawing) return;
            _finger = details.localPosition;
            _addIfHit(details.localPosition, centers);
            _emit();
            setState(() {});
          },
          onPanEnd: (_) {
            _drawing = false;
            _finger = null;
            setState(() {});
          },
          child: CustomPaint(
            painter: _GestureBoardPainter(
              centers: centers,
              selected: _path,
              finger: _finger,
              nodeRadius: _nodeRadius,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  List<Offset> _buildCenters(Size size) {
    final stepX = size.width / (_grid + 1);
    final stepY = size.height / (_grid + 1);
    final result = <Offset>[];
    for (var r = 1; r <= _grid; r++) {
      for (var c = 1; c <= _grid; c++) {
        result.add(Offset(stepX * c, stepY * r));
      }
    }
    return result;
  }

  void _addIfHit(Offset p, List<Offset> centers) {
    for (var i = 0; i < centers.length; i++) {
      if (_path.contains(i)) continue;
      final d = (centers[i] - p).distance;
      if (d <= _nodeRadius * 1.4) {
        _path.add(i);
        break;
      }
    }
  }

  void _emit() {
    final code = _path.map((i) => (i + 1).toString()).join();
    widget.onChanged(code);
  }
}

class _GestureBoardPainter extends CustomPainter {
  _GestureBoardPainter({
    required this.centers,
    required this.selected,
    required this.finger,
    required this.nodeRadius,
  });

  final List<Offset> centers;
  final List<int> selected;
  final Offset? finger;
  final double nodeRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final normalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.grey.shade500;
    final selectedPaint = Paint()..color = const Color(0xFF2E7D32);

    for (var i = 0; i + 1 < selected.length; i++) {
      canvas.drawLine(
        centers[selected[i]],
        centers[selected[i + 1]],
        linePaint,
      );
    }
    if (selected.isNotEmpty && finger != null) {
      canvas.drawLine(centers[selected.last], finger!, linePaint);
    }

    for (var i = 0; i < centers.length; i++) {
      final c = centers[i];
      canvas.drawCircle(c, nodeRadius, normalPaint);
      if (selected.contains(i)) {
        canvas.drawCircle(c, nodeRadius * 0.45, selectedPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GestureBoardPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.finger != finger ||
        oldDelegate.centers != centers;
  }
}

class _QrSignPageState extends State<_QrSignPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _handling = false;
  String _tip = '将二维码放入取景框内';

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('二维码签到')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) async {
              if (_handling || capture.barcodes.isEmpty) return;
              final raw = capture.barcodes.first.rawValue;
              if (raw == null || raw.isEmpty) {
                setState(() {
                  _tip = '未识别到有效二维码内容';
                });
                return;
              }
              setState(() {
                _handling = true;
                _tip = '已识别二维码，正在提交签到...';
              });
              try {
                await widget.controller
                    .qrCodeSign(widget.task, raw)
                    .timeout(const Duration(seconds: 30));
                if (!context.mounted) return;
                Navigator.of(context).pop();
              } catch (_) {
                if (!mounted) return;
                setState(() {
                  _handling = false;
                  _tip = '提交失败，请重试';
                });
              }
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _tip,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
