// 餐食条目卡片（首页、时间线、每日记录共用）
//
// 展示：记录人标签、餐类型、时间、食物名称、份量、营养数据、图片；
// 权限：只有本人的记录才显示「编辑 / 删除」操作（仅查看伴侣的记录）。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/meal/image_viewer_screen.dart';
import '../utils/date_utils.dart';

class MealCard extends StatelessWidget {
  const MealCard({
    super.key,
    required this.entry,
    required this.isMine,
    this.showDate = false,
    this.onEdit,
    this.onDelete,
  });

  final MealEntry entry;
  final bool isMine; // 是否为本人记录
  final bool showDate; // 时间线中跨天展示日期
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Hero 动画标识，同一列表内需唯一
  String get _heroTag => 'meal-image-${entry.objectId}';

  /// 打开全屏大图
  void _openImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(
          imageUrl: entry.imageUrl,
          imageBase64: entry.imageThumb,
          heroTag: _heroTag,
          title: '${entry.foodName} · ${entry.type.label}',
        ),
      ),
    );
  }

  /// 左侧缩略图
  ///
  /// 优先级：云存储原图 → 数据库里的 Base64 缩略图 → 餐次图标。
  /// 伴侣那台手机通常拿不到原图链接（云存储默认仅创建者可读），
  /// 此时用缩略图兜底，保证「能看到对方的照片」。
  Widget _buildThumb(BuildContext context, ThemeData theme, Color accent) {
    const size = 64.0;
    final thumb = entry.imageThumb;
    final url = entry.imageUrl;

    // 1. 没有原图也没有缩略图 → 餐次图标
    if ((url == null || !url.startsWith('http')) &&
        (thumb == null || thumb.isEmpty)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(entry.type.icon, color: accent),
      );
    }

    Widget fallback() {
      if (thumb != null && thumb.isNotEmpty) {
        return _memoryImage(thumb, size);
      }
      return Tooltip(
        message: isMine ? '图片加载失败，下拉刷新试试' : '暂时看不到这张图片，下拉刷新试试',
        child: Container(
          width: size,
          height: size,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(entry.type.icon, size: 22, color: accent),
        ),
      );
    }

    Widget image = (url != null && url.startsWith('http'))
        ? Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: 192,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(
                    width: size,
                    height: size,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
            errorBuilder: (_, __, ___) => fallback(),
          )
        : _memoryImage(thumb!, size);

    return GestureDetector(
      // 点击缩略图 → 全屏查看，可双指缩放 / 双击放大
      onTap: () => _openImage(context),
      child: Hero(
        tag: _heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: image,
        ),
      ),
    );
  }

  /// Base64 缩略图
  Widget _memoryImage(String base64Text, double size) {
    try {
      final bytes = base64Decode(base64Text);
      return Image.memory(
        Uint8List.fromList(bytes),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 192,
      );
    } catch (_) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey.shade300,
        child: const Icon(Icons.image_not_supported_outlined, size: 20),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isMine ? theme.colorScheme.primary : Colors.orange.shade700;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧：图片或餐类型图标
            _buildThumb(context, theme, accent),
            const SizedBox(width: 12),

            // 右侧：文字信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 记录人标签：我 / 伴侣昵称
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isMine ? '我' : entry.nickname,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${entry.type.label} · ${entry.time}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.hintColor),
                      ),
                      if (showDate) ...[
                        const SizedBox(width: 6),
                        Text(
                          DateUtilsX.label(entry.date),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.foodName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${NumFmt.kcal(entry.calories)} kcal'
                    '${entry.portion.isEmpty ? '' : ' · ${entry.portion}'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '蛋白质 ${NumFmt.one(entry.protein)}g · '
                    '碳水 ${NumFmt.one(entry.carbs)}g · '
                    '脂肪 ${NumFmt.one(entry.fat)}g',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),

            // 仅本人记录显示操作菜单
            if (isMine)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) {
                  if (v == 'edit') onEdit?.call();
                  if (v == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined, size: 20),
                      title: Text('编辑'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline,
                          size: 20, color: Colors.red),
                      title: Text('删除', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(Icons.visibility_outlined,
                    size: 18, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

/// 删除确认弹窗
Future<bool> confirmDeleteMeal(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('删除记录'),
      content: const Text('确定删除这条餐食记录吗？删除后无法恢复，关联图片也会一并删除。'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
