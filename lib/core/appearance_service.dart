// 外观设置服务（背景色 / 背景图 / 主题色）
//
// 设计原则：
// - 所有外观配置只存在**本机**（SharedPreferences + 应用私有目录），
//   不同步到数据库，两台设备可以各自设置成不同的样子；
// - 自定义背景图会被复制到应用私有目录，避免用户从相册删除后失效；
// - 提供变更通知，界面可实时刷新，无需重启。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 背景样式
enum BgStyle {
  /// 纯色（使用主题色或自定义色）
  solid,

  /// 渐变（柔和的双色渐变）
  gradient,

  /// 自定义图片
  image,
}

/// 预设背景配色
class BgPreset {
  const BgPreset({
    required this.name,
    required this.colors,
  });

  final String name;

  /// 1 个颜色 = 纯色；2 个颜色 = 渐变
  final List<Color> colors;

  Color get primary => colors.first;

  bool get isGradient => colors.length > 1;
}

/// 内置背景预设（柔和、低饱和，保证文字可读）
const List<BgPreset> kBgPresets = [
  BgPreset(name: '樱花粉', colors: [Color(0xFFFFF1F5)]),
  BgPreset(name: '奶油白', colors: [Color(0xFFFFFBF5)]),
  BgPreset(name: '薄荷绿', colors: [Color(0xFFF0FAF5)]),
  BgPreset(name: '天空蓝', colors: [Color(0xFFF1F7FF)]),
  BgPreset(name: '暖杏色', colors: [Color(0xFFFFF6EC)]),
  BgPreset(name: '淡紫', colors: [Color(0xFFF7F2FF)]),
  BgPreset(name: '晨雾', colors: [Color(0xFFFFF5F0), Color(0xFFF3F7FF)]),
  BgPreset(name: '桃气', colors: [Color(0xFFFFF0F0), Color(0xFFFFF8E8)]),
  BgPreset(name: '青柠', colors: [Color(0xFFF2FBEF), Color(0xFFEFF9FF)]),
  BgPreset(name: '暮色', colors: [Color(0xFFF5F0FF), Color(0xFFFFF0F6)]),
];

class AppearanceService {
  AppearanceService._();

  static final AppearanceService instance = AppearanceService._();

  static const String _keyStyle = 'appearance_bg_style';
  static const String _keyColor = 'appearance_bg_color';
  static const String _keyColorEnd = 'appearance_bg_color_end';
  static const String _keyImage = 'appearance_bg_image';
  static const String _keySeed = 'appearance_seed_color';

  /// 背景样式
  BgStyle _style = BgStyle.solid;

  /// 背景起始色（纯色时只用它）
  Color _color = const Color(0xFFFFF1F5);

  /// 渐变结束色
  Color _colorEnd = const Color(0xFFF3F7FF);

  /// 自定义背景图（已复制到应用私有目录）
  String? _imagePath;

  /// 主题种子色（影响按钮、图标等强调色）
  Color _seedColor = const Color(0xFFE91E63);

  BgStyle get style => _style;
  Color get color => _color;
  Color get colorEnd => _colorEnd;
  String? get imagePath => _imagePath;
  Color get seedColor => _seedColor;

  /// 变更监听（页面注册后可在设置变化时立即刷新）
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notify() {
    for (final l in List<VoidCallback>.of(_listeners)) {
      l();
    }
  }

  /// 启动时读取本机配置
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final styleIndex = prefs.getInt(_keyStyle);
    if (styleIndex != null &&
        styleIndex >= 0 &&
        styleIndex < BgStyle.values.length) {
      _style = BgStyle.values[styleIndex];
    }
    final colorValue = prefs.getInt(_keyColor);
    if (colorValue != null) _color = Color(colorValue);
    final colorEndValue = prefs.getInt(_keyColorEnd);
    if (colorEndValue != null) _colorEnd = Color(colorEndValue);
    final seed = prefs.getInt(_keySeed);
    if (seed != null) _seedColor = Color(seed);
    _imagePath = prefs.getString(_keyImage);

    // 图片被系统清理或用户手动删除时回退到纯色
    if (_style == BgStyle.image) {
      final path = _imagePath;
      if (path == null || !File(path).existsSync()) {
        _style = BgStyle.solid;
        _imagePath = null;
      }
    }
  }

  /// 设为纯色
  Future<void> setSolid(Color color) async {
    _style = BgStyle.solid;
    _color = color;
    await _persist();
    _notify();
  }

  /// 设为渐变
  Future<void> setGradient(Color start, Color end) async {
    _style = BgStyle.gradient;
    _color = start;
    _colorEnd = end;
    await _persist();
    _notify();
  }

  /// 应用预设
  Future<void> applyPreset(BgPreset preset) async {
    if (preset.isGradient) {
      await setGradient(preset.colors.first, preset.colors[1]);
    } else {
      await setSolid(preset.primary);
    }
  }

  /// 设为自定义图片背景
  ///
  /// [source] 用户选择的原图；会复制到应用私有目录，原图删掉也不影响。
  Future<void> setImage(File source) async {
    final dir = await getApplicationSupportDirectory();
    final bgDir = Directory('${dir.path}/backgrounds');
    if (!await bgDir.exists()) {
      await bgDir.create(recursive: true);
    }
    // 先清理旧图，避免越攒越多
    await _deleteImageFile();
    final target = File(
      '${bgDir.path}/bg_${DateTime.now().millisecondsSinceEpoch}'
      '.${_ext(source.path)}',
    );
    await source.copy(target.path);

    _style = BgStyle.image;
    _imagePath = target.path;
    await _persist();
    _notify();
  }

  /// 清除自定义背景图
  Future<void> clearImage() async {
    await _deleteImageFile();
    _imagePath = null;
    if (_style == BgStyle.image) _style = BgStyle.solid;
    await _persist();
    _notify();
  }

  /// 修改主题强调色
  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    await _persist();
    _notify();
  }

  Future<void> _deleteImageFile() async {
    final path = _imagePath;
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // 删除失败不影响后续流程
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStyle, _style.index);
    await prefs.setInt(_keyColor, _color.toARGB32());
    await prefs.setInt(_keyColorEnd, _colorEnd.toARGB32());
    await prefs.setInt(_keySeed, _seedColor.toARGB32());
    if (_imagePath == null) {
      await prefs.remove(_keyImage);
    } else {
      await prefs.setString(_keyImage, _imagePath!);
    }
  }

  static String _ext(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return 'jpg';
    final ext = path.substring(dot + 1).toLowerCase();
    return (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp')
        ? ext
        : 'jpg';
  }
}
