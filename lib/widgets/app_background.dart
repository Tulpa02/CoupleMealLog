// 应用背景装饰层
//
// 把当前外观设置（纯色 / 渐变 / 自定义图片）渲染成背景。
//
// 明暗处理：
// - 深色背景（或图片背景）叠加**黑色**蒙层，整体压暗，白字清晰，
//   效果类似微信深色背景；
// - 浅色背景不叠加蒙层，保持清爽。
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/appearance_service.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
  });

  /// 前景内容
  final Widget child;

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
              // 黑色蒙层：把照片压暗，白字清晰（微信深色背景同款处理）
              ColoredBox(
                color: Colors.black.withValues(alpha: app.imageDim),
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
