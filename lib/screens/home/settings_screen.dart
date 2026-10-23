// 设置页面
//
// 功能：
// - 房间信息（6 位房间密钥一键复制，方便发给伴侣）；
// - 昵称修改（保存在本机，并同步到房间昵称表）；
// - 常用食物管理入口；
// - 导出全部餐食记录为 CSV（保存到手机本地）；
// - 清除本地缓存；
// - 退出房间。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/device_service.dart';
import '../../models/models.dart';
import '../../services/cache_service.dart';
import '../../services/csv_export_service.dart';
import '../../services/meal_service.dart';
import '../../services/room_service.dart';
import '../../utils/date_utils.dart';
import '../food_presets/food_presets_screen.dart';
import 'appearance_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.deviceId,
    required this.nickname,
    required this.room,
    required this.onLeftRoom,
  });

  final String deviceId;
  final String nickname;
  final Room room;
  final VoidCallback onLeftRoom;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _cacheBytes = 0;
  bool _exporting = false;
  late String _nickname = widget.nickname;

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  /// 统计缓存大小
  Future<void> _refreshCacheSize() async {
    final size = await CacheService.instance.cacheSizeBytes();
    if (mounted) setState(() => _cacheBytes = size);
  }

  /// 复制房间密钥
  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.room.roomCode));
    if (mounted) showToast(context, '房间密钥已复制');
  }

  /// 修改昵称
  Future<void> _editNickname() async {
    final ctrl = TextEditingController(text: _nickname);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(labelText: '昵称', counterText: ''),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || name == _nickname) return;
    await DeviceService.instance.saveNickname(name);
    await RoomService.instance.updateNickname(
      room: widget.room,
      deviceId: widget.deviceId,
      nickname: name,
    );
    if (mounted) {
      setState(() => _nickname = name);
      showToast(context, '昵称已更新');
    }
  }

  /// 导出全部餐食记录为 CSV
  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final meals = await MealService.instance.fetchRange(
        roomId: widget.room.objectId,
        from: '2000-01-01',
        to: '2100-12-31',
      );
      if (meals.isEmpty) {
        if (mounted) showToast(context, '暂无可导出的餐食记录');
        return;
      }
      final (path, count) = await CsvExportService.instance.exportMeals(meals);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导出成功'),
          content: SelectableText('共导出 $count 条记录。\n\n文件路径：\n$path'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好的'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        showToast(context, '导出失败：${friendlyError(e)}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 清除本地缓存
  Future<void> _clearCache() async {
    final ok = await _confirm('清除本地缓存', '清除后离线时将无法查看历史记录，联网后会自动重新加载。');
    if (!ok) return;
    await CacheService.instance.clearAll();
    await _refreshCacheSize();
    if (mounted) showToast(context, '本地缓存已清除');
  }

  /// 退出房间
  Future<void> _leaveRoom() async {
    final ok = await _confirm(
      '退出房间',
      '退出后将看不到伴侣的餐食记录。你已创建的记录会保留，'
          '重新加入同一个房间密钥即可再次查看。确定退出吗？',
    );
    if (!ok) return;
    try {
      await RoomService.instance.leaveRoom(
        room: widget.room,
        deviceId: widget.deviceId,
      );
      await CacheService.instance.clearAll();
      // 回到根节点，由房间门卫重新分流到「房间选择页」
      appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      widget.onLeftRoom();
      if (mounted) showToast(context, '已退出房间');
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), isError: true);
    }
  }

  /// 通用二次确认弹窗
  Future<bool> _confirm(String title, String content) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final room = widget.room;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ===== 本机身份 =====
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(_nickname.isEmpty ? '未设置昵称' : _nickname),
                subtitle: Text(
                  '设备 ID：${widget.deviceId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _editNickname,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ===== 外观 =====
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('背景与主题'),
                subtitle: const Text('更换背景颜色、渐变或自定义图片（仅本机生效）'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AppearanceScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ===== 房间 =====
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.meeting_room_outlined),
                title: Text('共享房间 ${room.roomCode}'),
                subtitle: Text(
                  room.isFull
                      ? '成员：${room.memberList.map(room.nameOf).join('、')}'
                      : '等待伴侣加入（每人最多 2 人）',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text('房间密钥'),
                subtitle: Text(room.roomCode,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(letterSpacing: 4)),
                trailing: IconButton(
                  tooltip: '复制房间密钥',
                  icon: const Icon(Icons.copy),
                  onPressed: _copyCode,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ===== 功能 =====
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('常用食物库'),
                subtitle: const Text('保存常吃的食物，记录时一键填充（仅本机可见）'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        FoodPresetsScreen(deviceId: widget.deviceId),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: _exporting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined),
                title: const Text('导出全部记录为 CSV'),
                subtitle:
                    const Text('保存到手机 Download/CoupleMealLog 目录，可用 Excel 打开'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _exporting ? null : _exportCsv,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('清除本地缓存'),
                subtitle: Text('当前占用 ${CacheService.readableSize(_cacheBytes)}，'
                    '仅影响离线查看，不影响云端数据'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _clearCache,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ===== 危险操作 =====
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('退出房间', style: TextStyle(color: Colors.red)),
            subtitle: const Text('退出后不再共享餐食记录'),
            onTap: _leaveRoom,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '饱饱日记 v1.3.0\n'
            '数据存储于微信云开发 / 腾讯 CloudBase，免注册模式',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
