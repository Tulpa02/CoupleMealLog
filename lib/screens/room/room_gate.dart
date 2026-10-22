// 房间门卫（RoomGate）
//
// 免注册模式的启动分流：
// - 本设备没有加入任何房间 → 显示「房间选择页」（创建 / 加入房间）；
// - 已加入房间 → 拉取最新房间信息（成员 / 昵称）后进入主框架 HomeShell。
import 'package:flutter/material.dart';

import '../../core/device_service.dart';
import '../../models/models.dart';
import '../../services/room_service.dart';
import '../../services/tcb_service.dart';
import '../../utils/date_utils.dart';
import '../home/home_shell.dart';
import 'room_entry_screen.dart';

class RoomGate extends StatefulWidget {
  const RoomGate({super.key});

  @override
  State<RoomGate> createState() => _RoomGateState();
}

class _RoomGateState extends State<RoomGate> {
  String _deviceId = '';
  String _nickname = '';
  Room? _room;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// 初始化设备身份并读取当前房间
  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 确保云开发已初始化且匿名登录成功；失败时给出可操作的中文提示
      await TcbService.init();
      final deviceId = await DeviceService.instance.getDeviceId();
      final nickname = await DeviceService.instance.getNickname();
      final room = await RoomService.instance.currentRoom();
      if (!mounted) return;
      setState(() {
        _deviceId = deviceId;
        _nickname = nickname;
        _room = room;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('初始化失败：${friendlyError(_error!)}', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _bootstrap, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
    }

    final room = _room;
    final fallbackNickname = _nickname.isEmpty
        ? (_deviceId.length > 6 ? _deviceId.substring(_deviceId.length - 6) : _deviceId)
        : _nickname;
    if (room == null) {
      // 未加入房间 → 房间选择页，加入/创建成功后重新加载
      return RoomEntryScreen(
        deviceId: _deviceId,
        nickname: _nickname,
        onJoined: _bootstrap,
      );
    }
    // 已加入房间 → 主框架
    return HomeShell(
      deviceId: _deviceId,
      nickname: fallbackNickname,
      room: room,
      onLeftRoom: _bootstrap,
    );
  }
}
