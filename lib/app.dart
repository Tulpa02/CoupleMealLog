// 应用根组件
//
// 改为免注册模式后，不再监听登录状态：
// - 启动后直接进入「房间门卫」（RoomGate）；
// - 设备已加入房间 → 首页；否则 → 房间选择页（创建 / 加入房间）。
import 'package:flutter/material.dart';

import 'screens/room/room_gate.dart';

/// 全局导航 Key：用于「退出房间」后清空页面栈回到根节点
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class CoupleMealLogApp extends StatelessWidget {
  const CoupleMealLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '情侣餐记 CoupleMealLog',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E63), // 情侣主题粉色
          brightness: Brightness.light,
        ),
        // 安卓手机上使用更紧凑的视觉密度，列表能显示更多信息
        visualDensity: VisualDensity.compact,
        appBarTheme: const AppBarTheme(centerTitle: false),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const RoomGate(),
    );
  }
}
