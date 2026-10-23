// 应用背景装饰层
//
// 把当前外观设置（纯色 / 渐变 / 自定义图片）渲染成背景，
// 图片背景会自动叠加一层白色半透明蒙层，保证前景文字始终清晰可读。
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/appearance_service.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.dim = 0.55,
  });

  /// 前景内容
  final Widget child;

  /// 图片背景的白色蒙层不透明度（0~1，越大越淡）
  final double dim;

  @override
  Widget build(BuildContext context) {
    final app = AppearanceService.instance;
    final theme = Theme.of(context);

    Widget? backdrop;
    switch (app.style) {
      case BgStyle.solid:
        backdrop = ColoredBox(color: app.color);
      case BgStyle.gradient:
        backdrop = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [app.color, app.colorEnd],
            ),
          ),
        );
      case BgStyle.image:
        final path = app.imagePath;
        if (path == null) {
          backdrop = ColoredBox(color: app.color);
        } else {
          backdrop = Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(path),
                fit: BoxFit.cover,
                // 降低解码尺寸，避免大图占内存
                cacheWidth: 1080,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: theme.colorScheme.surface),
              ),
              // 白色蒙层：保证卡片与文字可读
              ColoredBox(
                color: Colors.white.withValues(alpha: dim),
              ),
            ],
          );
        }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        backdrop,
        child,
      ],
    );
  }
}
