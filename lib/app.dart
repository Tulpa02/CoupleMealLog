// 应用根组件
//
// 启动后直接进入「房间门卫」（RoomGate）：
// - 设备已加入房间 → 首页；否则 → 房间选择页（创建 / 加入房间）。
//
// 外观：主题色与背景由 AppearanceService 提供，用户可在设置页更换，
// 修改后整个 App 立即刷新，无需重启。
import 'package:flutter/material.dart';

import 'core/appearance_service.dart';
import 'screens/room/room_gate.dart';
import 'widgets/app_background.dart';

/// 全局导航 Key：用于「退出房间」后清空页面栈回到根节点
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class CoupleMealLogApp extends StatefulWidget {
  const CoupleMealLogApp({super.key});

  @override
  State<CoupleMealLogApp> createState() => _CoupleMealLogAppState();
}

class _CoupleMealLogAppState extends State<CoupleMealLogApp> {
  final AppearanceService _appearance = AppearanceService.instance;

  @override
  void initState() {
    super.initState();
    // 外观变化时重建 MaterialApp（主题色随之更新）
    _appearance.addListener(_onAppearanceChanged);
  }

  @override
  void dispose() {
    _appearance.removeListener(_onAppearanceChanged);
    super.dispose();
  }

  void _onAppearanceChanged() {
    if (mounted) setState(() {});
  }

  /// 构建主题
  ///
  /// 卡片 / 导航栏使用半透明表面色，这样自定义背景图能透出来，
  /// 同时保证文字对比度。
  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _appearance.seedColor,
      brightness: brightness,
    );
    final isLight = brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // 安卓手机上使用更紧凑的视觉密度，列表能显示更多信息
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: isLight
            ? Colors.white.withValues(alpha: 0.72)
            : scheme.surface.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isLight
            ? Colors.white.withValues(alpha: 0.78)
            : scheme.surfaceContainer.withValues(alpha: 0.78),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight
            ? Colors.white.withValues(alpha: 0.82)
            : scheme.surfaceContainer.withValues(alpha: 0.82),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        isDense: true,
        filled: true,
        fillColor: isLight
            ? Colors.white.withValues(alpha: 0.7)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '饱饱日记',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      // 全局背景层：所有页面（含对话框、底部弹窗）共享同一张背景
      builder: (context, child) => AppBackground(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const RoomGate(),
    );
  }
}
