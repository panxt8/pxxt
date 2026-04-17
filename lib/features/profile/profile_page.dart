import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/linked_account.dart';
import '../../core/network/app_dio.dart';
import '../../core/network/app_urls.dart';
import '../../core/storage/app_storage.dart';
import '../auth/auth_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<LinkedAccount> _accounts = const [];
  AppStorage? _storage;
  bool _adding = false;
  bool _fillingUid = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_storage == null) {
      _storage = context.read<AppStorage>();
      _loadAccounts();
    }
  }

  void _loadAccounts() {
    final storage = _storage;
    if (storage == null || !mounted) return;
    setState(() {
      _accounts = storage.loadLinkedAccounts();
    });
    _fillMissingLinkedUids();
  }

  Future<void> _addAccount() async {
    if (_adding) return;
    final result = await showDialog<LinkedAccount>(
      context: context,
      builder: (context) => const _AddLinkedAccountDialog(),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      _adding = true;
    });

    try {
      final checked = await _validateLinkedAccount(result);
      if (!mounted) return;
      if (checked == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('关联账号或密码错误')));
        return;
      }
      final storage = _storage;
      if (storage == null) return;
      final nextAccounts = [..._accounts]
        ..removeWhere((e) => e.username == checked.username)
        ..add(checked);
      await _saveAccounts(storage, nextAccounts);
      if (!mounted) return;
      _loadAccounts();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('关联账号添加成功')));
    } finally {
      if (mounted) {
        setState(() {
          _adding = false;
        });
      }
    }
  }

  Future<void> _removeAccount(LinkedAccount account) async {
    final storage = _storage;
    if (storage == null) return;
    final nextAccounts = [..._accounts]
      ..removeWhere((e) => e.username == account.username);
    await _saveAccounts(storage, nextAccounts);
    if (!mounted) return;
    _loadAccounts();
  }

  Future<void> _saveAccounts(
    AppStorage storage,
    List<LinkedAccount> accounts,
  ) async {
    await storage.saveLinkedAccounts(accounts);
  }

  Future<LinkedAccount?> _validateLinkedAccount(LinkedAccount account) async {
    try {
      final dio = context.read<AppDio>().client;
      final response = await dio.get<dynamic>(
        AppUrls.login(account.username, account.password),
        options: Options(headers: const {AppDio.forceCookieHeader: ''}),
      );
      final raw = response.data;
      final data = raw is Map<String, dynamic>
          ? raw
          : jsonDecode(raw.toString()) as Map<String, dynamic>;
      final status = data['status'];
      final ok = status == true || status?.toString() == 'true';
      if (!ok) return null;

      final setCookies =
          (response.headers.map['set-cookie'] ?? const <String>[])
              .cast<String>();
      final uidFromCookie = _extractCookieValue(setCookies, 'UID');
      final uid = uidFromCookie.isNotEmpty
          ? uidFromCookie
          : _extractCookieValue(setCookies, '_uid');
      return LinkedAccount(
        username: account.username,
        password: account.password,
        remark: account.remark,
        uid: uid,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _fillMissingLinkedUids() async {
    if (_fillingUid) return;
    if (_accounts.every((e) => e.uid.trim().isNotEmpty)) return;
    final storage = _storage;
    if (storage == null) return;
    _fillingUid = true;
    try {
      var changed = false;
      final next = <LinkedAccount>[];
      for (final account in _accounts) {
        if (account.uid.trim().isNotEmpty) {
          next.add(account);
          continue;
        }
        final checked = await _validateLinkedAccount(account);
        if (checked != null && checked.uid.trim().isNotEmpty) {
          next.add(checked);
          changed = true;
        } else {
          next.add(account);
        }
      }
      if (!mounted || !changed) return;
      await _saveAccounts(storage, next);
      _loadAccounts();
    } finally {
      _fillingUid = false;
    }
  }

  static String _extractCookieValue(List<String> cookies, String key) {
    for (final item in cookies) {
      final first = item.split(';').first;
      if (first.startsWith('$key=')) {
        return first.substring(key.length + 1);
      }
    }
    return '';
  }

  Future<void> _loginMainAccount() async {
    final storage = _storage;
    if (storage == null) return;
    final creds = storage.loadCredentials();
    final result = await showDialog<({String username, String password})>(
      context: context,
      builder: (context) => _MainLoginDialog(
        defaultUsername: creds.username,
        defaultPassword: creds.password,
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    final ok = await context.read<AuthController>().login(
      username: result.username.trim(),
      password: result.password,
    );
    if (!mounted) return;
    if (!ok) {
      final msg = context.read<AuthController>().error ?? '登录失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<bool> _confirmExit({
    required String title,
    required String content,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final session = auth.session;
    final mainLoggedIn = auth.isLoggedIn;
    final mainUid = session?.uid ?? '';
    final mainUsername = context.read<AppStorage>().loadCredentials().username;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SwipeExit(
            dismissKey: 'main-account',
            enabled: mainLoggedIn,
            onConfirm: () async {
              final authController = context.read<AuthController>();
              final ok = await _confirmExit(
                title: '退出主账号',
                content: '确认退出主账号吗？',
              );
              if (!ok) return false;
              await authController.logout();
              return false;
            },
            child: _AccountCard(
              avatarUrl: mainLoggedIn && mainUid.isNotEmpty
                  ? AppUrls.avatar(mainUid)
                  : null,
              showPlus: !mainLoggedIn,
              title: mainLoggedIn
                  ? '账号：${mainUsername.isEmpty ? "-" : mainUsername}'
                  : '主账号',
              subtitle: mainLoggedIn ? 'uid：$mainUid' : '点击登录主账号',
              onTap: mainLoggedIn ? null : _loginMainAccount,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '关联账号',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.tonal(
                onPressed: _adding ? null : _addAccount,
                child: _adding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_accounts.isEmpty) const _EmptyHint(text: '暂无关联账号'),
          ..._accounts.map((account) {
            final uid = account.uid.trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SwipeExit(
                dismissKey: 'linked-${account.username}',
                onConfirm: () async {
                  final ok = await _confirmExit(
                    title: '退出关联账号',
                    content: '确认退出 ${account.displayName} 吗？',
                  );
                  if (!ok) return false;
                  await _removeAccount(account);
                  return true;
                },
                child: _AccountCard(
                  avatarUrl: uid.isEmpty ? null : AppUrls.avatar(uid),
                  title: account.remark.trim().isNotEmpty
                      ? account.remark.trim()
                      : '账号：${account.username}',
                  subtitle: 'uid：${uid.isEmpty ? "-" : uid}',
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.title,
    required this.subtitle,
    this.avatarUrl,
    this.showPlus = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String? avatarUrl;
  final bool showPlus;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _Avatar(avatarUrl: avatarUrl, showPlus: showPlus),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.avatarUrl, required this.showPlus});

  final String? avatarUrl;
  final bool showPlus;
  static const _avatarHeaders = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Referer': 'https://photo.chaoxing.com/',
  };

  @override
  Widget build(BuildContext context) {
    const radius = 22.0;
    if (showPlus) {
      return const CircleAvatar(
        radius: radius,
        child: Icon(Icons.add, size: 22),
      );
    }
    final url = avatarUrl?.trim() ?? '';
    if (url.isEmpty) {
      return const CircleAvatar(
        radius: radius,
        child: Icon(Icons.person_outline),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.network(
          url,
          key: ValueKey<String>(url),
          headers: _avatarHeaders,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, error, stackTrace) {
            return const ColoredBox(
              color: Color(0xFFE6EEF8),
              child: Icon(Icons.person_outline),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const ColoredBox(
              color: Color(0xFFE6EEF8),
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SwipeExit extends StatefulWidget {
  const _SwipeExit({
    required this.dismissKey,
    required this.child,
    this.enabled = true,
    required this.onConfirm,
  });

  final String dismissKey;
  final Widget child;
  final bool enabled;
  final Future<bool> Function() onConfirm;

  @override
  State<_SwipeExit> createState() => _SwipeExitState();
}

class _SwipeExitState extends State<_SwipeExit> {
  static const double _actionWidth = 92;
  static const double _revealWidth = 72;
  double _offset = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    final next = (_offset + details.delta.dx).clamp(-_revealWidth, 0.0);
    if (next != _offset) {
      setState(() => _offset = next);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    final shouldOpen = _offset <= -_revealWidth * 0.4;
    setState(() => _offset = shouldOpen ? -_revealWidth : 0);
  }

  Future<void> _onExitTap() async {
    final ok = await widget.onConfirm();
    if (!mounted) return;
    if (!ok) {
      setState(() => _offset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 76.0;
        return GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: _actionWidth,
                      child: Material(
                        color: Colors.red,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(12),
                          ),
                          onTap: _onExitTap,
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: _actionWidth - _revealWidth,
                            ),
                            child: const Center(
                              child: Text(
                                '退出',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  key: ValueKey<String>(widget.dismissKey),
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  left: _offset,
                  right: -_offset,
                  top: 0,
                  bottom: 0,
                  child: widget.child,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(text),
      ),
    );
  }
}

class _AddLinkedAccountDialog extends StatefulWidget {
  const _AddLinkedAccountDialog();

  @override
  State<_AddLinkedAccountDialog> createState() =>
      _AddLinkedAccountDialogState();
}

class _AddLinkedAccountDialogState extends State<_AddLinkedAccountDialog> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _remark = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加关联账号'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: '账号'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _remark,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final u = _username.text.trim();
            final p = _password.text;
            if (u.isEmpty || p.isEmpty) return;
            Navigator.of(context).pop(
              LinkedAccount(
                username: u,
                password: p,
                remark: _remark.text.trim(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _MainLoginDialog extends StatefulWidget {
  const _MainLoginDialog({
    required this.defaultUsername,
    required this.defaultPassword,
  });

  final String defaultUsername;
  final String defaultPassword;

  @override
  State<_MainLoginDialog> createState() => _MainLoginDialogState();
}

class _MainLoginDialogState extends State<_MainLoginDialog> {
  late final TextEditingController _username;
  late final TextEditingController _password;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.defaultUsername);
    _password = TextEditingController(text: widget.defaultPassword);
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('主账号登录'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: '账号'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              decoration: InputDecoration(
                labelText: '密码',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              obscureText: _obscure,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final username = _username.text.trim();
            final password = _password.text;
            if (username.isEmpty || password.isEmpty) return;
            Navigator.of(context).pop((username: username, password: password));
          },
          child: const Text('登录'),
        ),
      ],
    );
  }
}
