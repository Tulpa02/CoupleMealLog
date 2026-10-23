// 外观设置页
//
// 功能：
// - 主题强调色（影响按钮、选中态等）；
// - 背景：浅色预设 / 深色预设 / 自定义颜色 / 自定义图片；
// - 图片背景可调暗度（像微信深色背景那样压暗，白字更清晰）；
// - 自定义背景图只保存在本机，不上传数据库。
import 'package:flutter/material.dart';

import '../../core/appearance_service.dart';
import '../../services/image_service.dart';
import '../../utils/date_utils.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final AppearanceService _app = AppearanceService.instance;

  /// 主题色候选
  static const List<Color> _seedColors = [
    Color(0xFFE91E63), // 玫瑰粉
    Color(0xFFFF7043), // 珊瑚橙
    Color(0xFFFFB300), // 蜂蜜黄
    Color(0xFF66BB6A), // 抹茶绿
    Color(0xFF26A69A), // 湖水绿
    Color(0xFF42A5F5), // 天空蓝
    Color(0xFF7E57C2), // 葡萄紫
    Color(0xFF8D6E63), // 可可棕
  ];

  @override
  void initState() {
    super.initState();
    // 设置变化时刷新预览
    _app.addListener(_onChanged);
  }

  @override
  void dispose() {
    _app.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// 从相册选一张图作为背景
  Future<void> _pickBackground() async {
    try {
      final file = await ImageService.instance.pickFromGallery();
      if (file == null) {
        if (mounted) showToast(context, '没有选择图片');
        return;
      }
      await _app.setImage(file);
      if (mounted) showToast(context, '背景已更换，可拖动滑块调整明暗');
    } catch (e) {
      if (mounted) showToast(context, '设置背景失败：$e', isError: true);
    }
  }

  /// 自定义纯色 / 渐变
  ///
  /// [asGradient] true = 选渐变结束色；false = 选纯色
  Future<void> _pickCustomColor({required bool asGradient}) async {
    final base = asGradient ? _app.colorEnd : _app.color;
    var hsv = HSVColor.fromColor(base);
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(asGradient ? '自定义渐变结束色' : '自定义背景色'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) {
            return SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: hsv.toColor(),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(ctx).dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      hsv.toColor().computeLuminance() < 0.35
                          ? '深色（自动白字）'
                          : '浅色（自动深字）',
                      style: TextStyle(
                        color: hsv.toColor().computeLuminance() < 0.35
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 色相
                  Slider(
                    value: hsv.hue,
                    max: 360,
                    divisions: 360,
                    label: '色相 ${hsv.hue.round()}',
                    onChanged: (v) => setDialogState(
                      () => hsv = hsv.withHue(v),
                    ),
                  ),
                  // 饱和度
                  Slider(
                    value: hsv.saturation,
                    label: '饱和度 ${(hsv.saturation * 100).round()}%',
                    onChanged: (v) => setDialogState(
                      () => hsv = hsv.withSaturation(v),
                    ),
                  ),
                  // 明度：放开到很低，方便调出深色背景
                  Slider(
                    value: hsv.value,
                    min: 0.06,
                    label: '明度 ${(hsv.value * 100).round()}%',
                    onChanged: (v) => setDialogState(
                      () => hsv = hsv.withValue(v),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, hsv.toColor()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    if (asGradient) {
      await _app.setGradient(_app.color, result);
    } else {
      await _app.setSolid(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('背景与主题')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== 主题色 =====
          _sectionTitle(theme, '主题色', '影响按钮、图标与选中态'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in _seedColors)
                _ColorDot(
                  color: c,
                  selected: _app.seedColor.toARGB32() == c.toARGB32(),
                  onTap: () => _app.setSeedColor(c),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ===== 浅色背景 =====
          _sectionTitle(theme, '浅色背景', '明亮清爽，适合白天'),
          const SizedBox(height: 8),
          _presetGrid(kBgPresetsLight),
          const SizedBox(height: 24),

          // ===== 深色背景 =====
          _sectionTitle(theme, '深色背景', '护眼，自动切换深色主题'),
          const SizedBox(height: 8),
          _presetGrid(kBgPresetsDark),
          const SizedBox(height: 24),

          // ===== 自定义 =====
          _sectionTitle(theme, '自定义', '背景图只保存在本机，不上传数据库'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.colorize_outlined),
                  title: const Text('自定义纯色背景'),
                  subtitle: const Text('可调到很暗，自动配白字'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickCustomColor(asGradient: false),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gradient_outlined),
                  title: const Text('自定义渐变背景'),
                  subtitle: const Text('保留当前起始色，选择结束色'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickCustomColor(asGradient: true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('从相册选择背景图'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickBackground,
                ),

                // 图片暗度调节（只在有背景图时出现）
                if (_app.imagePath != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.brightness_6_outlined, size: 20),
                            const SizedBox(width: 12),
                            const Text('背景暗度'),
                            const Spacer(),
                            Text(
                              '${(_app.imageDim * 100).round()}%',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _app.imageDim,
                          max: 0.85,
                          divisions: 17,
                          label: '${(_app.imageDim * 100).round()}%',
                          onChanged: (v) => _app.setImageDim(v),
                        ),
                        Text(
                          '往右拖动让背景更暗、白字更清晰（推荐 45% 以上）',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    title: Text(
                      '删除自定义背景图',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    onTap: () async {
                      await _app.clearImage();
                      if (context.mounted) showToast(context, '已删除背景图');
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ===== 实时预览 =====
          _sectionTitle(theme, '效果预览', '下方就是当前背景的实际效果'),
          const SizedBox(height: 8),
          _PreviewCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 预设背景网格
  Widget _presetGrid(List<BgPreset> presets) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: presets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, i) {
        final preset = presets[i];
        return _PresetTile(
          preset: preset,
          onTap: () => _app.applyPreset(preset),
        );
      },
    );
  }

  Widget _sectionTitle(ThemeData theme, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}

/// 圆形色块
class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2.5,
                )
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, size: 20, color: Colors.white)
            : null,
      ),
    );
  }
}

/// 背景预设卡片
class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.onTap});

  final BgPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 深色预设用白字，浅色预设用深字
    final textColor = preset.luminance < 0.35
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.7);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: preset.isGradient
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: preset.colors,
                )
              : null,
          color: preset.isGradient ? null : preset.primary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        alignment: Alignment.center,
        child: Text(
          preset.name,
          style: theme.textTheme.labelMedium?.copyWith(color: textColor),
        ),
      ),
    );
  }
}

/// 预览卡片（模拟首页的一条记录）
class _PreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.restaurant, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '番茄炒蛋',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text('午餐 · 172 kcal', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    '蛋白质 9.0g · 碳水 8.0g · 脂肪 10.0g',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
