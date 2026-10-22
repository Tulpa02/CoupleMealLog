// 餐食条目卡片（首页、时间线、每日记录共用）
//
// 展示：记录人标签、餐类型、时间、食物名称、份量、营养数据、图片；
// 权限：只有本人的记录才显示「编辑 / 删除」操作（仅查看伴侣的记录）。
import 'package:flutter/material.dart';

import '../models/models.dart';
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
            // 只有拿到有效 http 链接时才显示图片，否则退化为餐次图标
            if (entry.imageUrl != null && entry.imageUrl!.startsWith('http'))
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  entry.imageUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  // 按显示尺寸解码，降低内存占用
                  cacheWidth: 192,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Container(
                          width: 64,
                          height: 64,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(entry.type.icon, size: 22, color: accent),
                  ),
                ),
              )
            else
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(entry.type.icon, color: accent),
              ),
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
