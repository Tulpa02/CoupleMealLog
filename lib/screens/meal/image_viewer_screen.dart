// 图片查看页（全屏大图）
//
// 功能：
// - 双指缩放 / 拖动；
// - 双击放大或还原；
// - 从卡片缩略图点击进入时带 Hero 过渡动画；
// - 支持网络图片（云存储临时链接）与本地文件（刚拍完还没上传）两种来源。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.imageBase64,
    this.heroTag,
    this.title,
  }) : assert(
          imageUrl != null || imageFile != null || imageBase64 != null,
          '三种图片来源至少要有一个',
        );

  /// 网络图片地址（云存储临时链接）
  final String? imageUrl;

  /// 本地图片文件
  final File? imageFile;

  /// Base64 编码的图片（数据库缩略图，拿不到原图时的兜底）
  final String? imageBase64;

  /// Hero 动画标识（与来源控件保持一致）
  final String? heroTag;

  /// 顶部标题，如「番茄炒蛋 · 午餐」
  final String? title;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();

  /// 双击缩放动画
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnimation;

  /// 当前是否已放大
  bool get _zoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  /// 双击：在点击位置放大到 2.5 倍，或还原
  void _handleDoubleTap(TapDownDetails details) {
    final Matrix4 end;
    if (_zoomed) {
      end = Matrix4.identity();
    } else {
      const scale = 2.5;
      final position = details.localPosition;
      end = Matrix4.identity()
        ..translateByDouble(
          -position.dx * (scale - 1),
          -position.dy * (scale - 1),
          0,
          1,
        )
        ..scaleByDouble(scale, scale, scale, 1);
    }
    _zoomAnimation = Matrix4Tween(
      begin: _transform.value,
      end: end,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOut));
    _animation
      ..removeListener(_onAnimate)
      ..addListener(_onAnimate)
      ..forward(from: 0);
  }

  void _onAnimate() {
    final value = _zoomAnimation?.value;
    if (value != null) _transform.value = value;
  }

  @override
  Widget build(BuildContext context) {
    final fallbackBase64 = widget.imageBase64;

    /// 原图拿不到时退回数据库里的缩略图
    Widget thumbFallback() {
      if (fallbackBase64 == null || fallbackBase64.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 48),
                SizedBox(height: 12),
                Text(
                  '图片加载失败\n链接可能已过期，返回列表下拉刷新后重试',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      }
      try {
        final bytes = base64Decode(fallbackBase64);
        return Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.contain,
        );
      } catch (_) {
        return const Center(
          child: Icon(Icons.broken_image_outlined,
              color: Colors.white54, size: 48),
        );
      }
    }

    final Widget image;
    if (widget.imageFile != null) {
      image = Image.file(widget.imageFile!, fit: BoxFit.contain);
    } else if (widget.imageUrl != null && widget.imageUrl!.startsWith('http')) {
      image = Image.network(
        widget.imageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
        errorBuilder: (_, __, ___) => thumbFallback(),
      );
    } else {
      image = thumbFallback();
    }

    final content = widget.heroTag == null
        ? image
        : Hero(tag: widget.heroTag!, child: image);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title ?? '查看图片',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
        ),
        actions: [
          // 双击缩放提示
          IconButton(
            tooltip: '重置缩放',
            icon: const Icon(Icons.center_focus_strong_outlined),
            onPressed: () => _transform.value = Matrix4.identity(),
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTapDown: _handleDoubleTap,
        // 双击手势需要 onDoubleTap 非空才会触发
        onDoubleTap: () {},
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: 5,
          clipBehavior: Clip.none,
          child: SizedBox.expand(
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
