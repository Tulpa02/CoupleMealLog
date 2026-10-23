// 应用根组件
//
// 启动后直接进入「房间门卫」（RoomGate）：
// - 设备已加入房间 → 首页；否则 → 房间选择页（创建 / 加入房间）。
//
// 外观：主题色与背景由 AppearanceService 提供，用户可在设置页更换，
// 修改后整个 App 立即刷新，无需重启。
//
// 明暗联动：背景是深色（含图片背景）时自动使用深色主题，
// 卡片、导航栏、文字颜色一起变深/变白，避免「深背景 + 白卡片」刺眼。
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
    // 外观变化时重建 MaterialApp（主题色 / 明暗随之更新）
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
  /// [isDarkBg] 为 true 时返回深色主题：卡片半透明深色、文字自动变白。
  ThemeData _buildTheme({required bool isDarkBg}) {
    final brightness = isDarkBg ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: _appearance.seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      // 背景由 AppBackground 绘制，页面本身透明
      scaffoldBackgroundColor: Colors.transparent,
      // 安卓手机上使用更紧凑的视觉密度，列表能显示更多信息
      visualDensity: VisualDensity.compact,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: isDarkBg
            ? Colors.black.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDarkBg
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.78),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDarkBg
            ? Colors.black.withValues(alpha: 0.42)
            : Colors.white.withValues(alpha: 0.82),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: isDarkBg
            ? scheme.primary.withValues(alpha: 0.32)
            : scheme.primaryContainer,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDarkBg
            ? scheme.primary.withValues(alpha: 0.85)
            : scheme.primaryContainer,
        foregroundColor:
            isDarkBg ? scheme.onPrimary : scheme.onPrimaryContainer,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        isDense: true,
        filled: true,
        fillColor: isDarkBg
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.7),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDarkBg ? const Color(0xFF23262B) : scheme.surface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDarkBg ? const Color(0xFF1E2126) : scheme.surface,
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
    final isDarkBg = _appearance.isDarkBackground;
    final theme = _buildTheme(isDarkBg: isDarkBg);

    return MaterialApp(
      title: '饱饱日记',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: theme,
      // 强制使用当前主题（不跟随系统），否则系统浅色时深色背景会配浅色主题
      themeMode: ThemeMode.light,
      builder: (context, child) => AppBackground(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const RoomGate(),
    );
  }
}
