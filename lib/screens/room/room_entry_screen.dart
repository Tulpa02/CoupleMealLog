// 房间选择页（免注册模式的启动页）
//
// 两个选项：
// 1. 创建房间：输入昵称 → 自动生成 6 位随机房间密钥 → 创建成功直接进入首页；
// 2. 加入房间：输入昵称 + 6 位房间密钥 → 校验通过（房间存在且未满 2 人）→ 进入首页。
//
// 身份标识：使用本机 deviceId，无需账号密码。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_config.dart';
import '../../core/device_service.dart';
import '../../services/tcb_service.dart';
import '../../services/room_service.dart';
import '../../utils/date_utils.dart';

class RoomEntryScreen extends StatefulWidget {
  const RoomEntryScreen({
    super.key,
    required this.deviceId,
    required this.nickname,
    required this.onJoined,
  });

  final String deviceId; // 本机设备标识
  final String nickname; // 上次使用的昵称
  final VoidCallback onJoined; // 创建 / 加入成功后的回调（由门卫重新加载）

  @override
  State<RoomEntryScreen> createState() => _RoomEntryScreenState();
}

class _RoomEntryScreenState extends State<RoomEntryScreen> {
  final _nicknameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _creating = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _nicknameCtrl.text = widget.nickname;
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// 校验昵称（创建与加入共用）
  String? _validateNickname() {
    final name = _nicknameCtrl.text.trim();
    if (name.isEmpty) return '请输入昵称';
    if (name.length > 20) return '昵称最多 20 个字符';
    return null;
  }

  /// 创建房间
  Future<void> _createRoom() async {
    final err = _validateNickname();
    if (err != null) {
      showToast(context, err, isError: true);
      return;
    }
    setState(() => _creating = true);
    try {
      final nickname = _nicknameCtrl.text.trim();
      await DeviceService.instance.saveNickname(nickname);
      final room = await RoomService.instance.createRoom(
        nickname: nickname,
        deviceId: widget.deviceId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RoomCodeDialog(code: room.roomCode),
      );
      widget.onJoined();
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          e is RoomException ? e.message : friendlyError(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  /// 加入房间
  Future<void> _joinRoom() async {
    final err = _validateNickname();
    if (err != null) {
      showToast(context, err, isError: true);
      return;
    }
    final code = _codeCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      showToast(context, '请输入 6 位数字房间密钥', isError: true);
      return;
    }
    setState(() => _joining = true);
    try {
      final nickname = _nicknameCtrl.text.trim();
      await DeviceService.instance.saveNickname(nickname);
      final room = await RoomService.instance.joinRoom(
        nickname: nickname,
        deviceId: widget.deviceId,
        code: code,
      );
      if (!mounted) return;
      showToast(context, '已加入房间 ${room.roomCode}');
      widget.onJoined();
    } catch (e) {
      if (mounted) {
        showToast(
          context,
          e is RoomException ? e.message : friendlyError(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _creating || _joining;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Icon(Icons.favorite, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                '饱饱日记',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '免注册 · 用 6 位房间密钥和 TA 共享餐食记录',
                textAlign: TextAlign.center,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 24),

              // 配置未填写时给出明确提示，避免误以为是网络问题
              if (!TcbService.isConfigured) ...[
                Card(
                  color: theme.colorScheme.errorContainer,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '尚未配置云开发环境：请先在 lib/core/app_config.dart 中填写环境 ID（envId），'
                      '并在 README 第四节完成集合与权限配置。',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 昵称
              TextField(
                controller: _nicknameCtrl,
                maxLength: 20,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '昵称',
                  hintText: '伴侣会看到这个名字',
                  counterText: '',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),

              // ===== 创建房间 =====
              _SectionCard(
                icon: Icons.add_home_outlined,
                title: '创建房间',
                subtitle: '自动生成 6 位房间密钥，把它发给伴侣',
                child: FilledButton.icon(
                  onPressed: busy ? null : _createRoom,
                  icon: _creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.key_outlined),
                  label: const Text('创建共享房间'),
                ),
              ),
              const SizedBox(height: 16),

              // ===== 加入房间 =====
              _SectionCard(
                icon: Icons.group_add_outlined,
                title: '加入伴侣的房间',
                subtitle: '输入伴侣分享的 6 位数字房间密钥',
                child: Column(
                  children: [
                    TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(letterSpacing: 8),
                      decoration: const InputDecoration(
                        hintText: '房间密钥',
                        counterText: '',
                      ),
                      onSubmitted: (_) {
                        if (!busy) _joinRoom();
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : _joinRoom,
                      icon: _joining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('加入房间'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                '说明：\n'
                '· 免注册：以本机设备标识作为身份，无需账号密码；\n'
                '· 每个房间最多 2 人，两人的餐食记录互相可见；\n'
                '· 你只能编辑、删除本设备创建的记录，伴侣的记录仅可查看。\n'
                '· 数据服务：微信云开发 / 腾讯 CloudBase',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 8),
              Text(
                '环境 ID：${AppConfig.envId}',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 房间密钥展示弹窗（创建房间后出现）
class _RoomCodeDialog extends StatelessWidget {
  const _RoomCodeDialog({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('房间创建成功'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('把下面的 6 位房间密钥发给伴侣，让 TA 加入：'),
          const SizedBox(height: 12),
          SelectableText(
            code,
            style: theme.textTheme.displaySmall?.copyWith(
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text('房间密钥也可在「设置」中随时查看', style: TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) showToast(context, '房间密钥已复制');
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('复制'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('进入房间'),
        ),
      ],
    );
  }
}

/// 分组卡片容器
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
