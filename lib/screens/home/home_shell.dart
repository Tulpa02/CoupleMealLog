// 主框架：底部导航（今日 / 时间线 / 统计 / 设置）
//
// - 顶部展示房间信息与 6 位房间密钥；
// - 首页右下角悬浮按钮用于快速新增餐食；
// - 四个 Tab 使用 IndexedStack 保持各自页面状态；
// - 提供「刷新房间」方法，伴侣加入 / 退出后可手动同步成员信息。
import 'package:flutter/material.dart';

import '../../models/models.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'meal_actions.dart';
import 'settings_screen.dart';
import 'timeline_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.deviceId,
    required this.nickname,
    required this.room,
    required this.onLeftRoom,
  });

  final String deviceId; // 本机设备标识（身份凭证）
  final String nickname; // 本机昵称
  final Room room; // 当前房间
  final VoidCallback onLeftRoom; // 退出房间后的回调（回到房间选择页）

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late Room _room = widget.room;
  int _refreshKey = 0; // 下拉刷新时递增，重建子页面以重新拉取数据

  List<Widget> get _pages => [
        HomeScreen(
          key: ValueKey('home-$_refreshKey'),
          deviceId: widget.deviceId,
          nickname: widget.nickname,
          room: _room,
          onRoomRefreshed: _onRoomRefreshed,
        ),
        TimelineScreen(
          key: ValueKey('timeline-$_refreshKey'),
          deviceId: widget.deviceId,
          room: _room,
        ),
        CalendarScreen(
          key: ValueKey('calendar-$_refreshKey'),
          deviceId: widget.deviceId,
          nickname: widget.nickname,
          room: _room,
        ),
        SettingsScreen(
          key: ValueKey('settings-$_refreshKey'),
          deviceId: widget.deviceId,
          nickname: widget.nickname,
          room: _room,
          onLeftRoom: widget.onLeftRoom,
        ),
      ];

  /// 子页面刷新到最新房间信息后回传
  void _onRoomRefreshed(Room room) {
    if (!mounted) return;
    setState(() => _room = room);
  }

  /// 首页悬浮按钮：快速新增今天的餐食
  Future<void> _quickAdd() async {
    await openAddMeal(
      context,
      roomId: _room.objectId,
      deviceId: widget.deviceId,
      nickname: widget.nickname,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite,
                size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '情侣餐记 · 房间 ${_room.roomCode}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '刷新房间信息',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _refreshKey++),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _quickAdd,
              icon: const Icon(Icons.add),
              label: const Text('记一餐'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: '时间线',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
