// 历史时间线页面
//
// 按日期倒序展示房间内两个人的全部餐食记录：
// 顶部为日期分组标题（今天 / 昨天 / 具体日期 + 当日合计），下面为记录卡片，
// 卡片上标注记录人、图片与食物信息；本设备记录可编辑/删除，伴侣记录仅查看。
// 支持下拉刷新；离线时从本地缓存读取最近数据。
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/cache_service.dart';
import '../../services/meal_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/meal_card.dart';
import 'meal_actions.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({
    super.key,
    required this.deviceId,
    required this.room,
  });

  final String deviceId;
  final Room room;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<MealEntry> _meals = const [];
  bool _loading = true;
  bool _offline = false;

  String get _roomId => widget.room.objectId;

  @override
  void initState() {
    super.initState();
    // 缓存被清除后刷新页面
    CacheService.instance.addListener(_onCacheChanged);
    _load();
  }

  @override
  void dispose() {
    CacheService.instance.removeListener(_onCacheChanged);
    super.dispose();
  }

  void _onCacheChanged() {
    if (mounted) _load();
  }

  /// 加载最近记录；失败时回退到本地缓存
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await MealService.instance.fetchLatest(_roomId, limit: 200);
      if (!mounted) return;
      setState(() {
        _meals = _sortDesc(list);
        _offline = false;
        _loading = false;
      });
    } catch (e) {
      final cached = await CacheService.instance.readAll(_roomId);
      if (!mounted) return;
      setState(() {
        _meals = _sortDesc(cached);
        _offline = true;
        _loading = false;
      });
    }
  }

  Future<void> _edit(MealEntry e) async {
    final ok = await openEditMeal(
      context,
      roomId: _roomId,
      deviceId: widget.deviceId,
      nickname: e.nickname,
      entry: e,
    );
    if (ok == true) _load();
  }

  Future<void> _delete(MealEntry e) async {
    final ok = await deleteMealFlow(
      context,
      deviceId: widget.deviceId,
      entry: e,
    );
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_meals.isEmpty && _offline) {
      return _OfflineEmpty(onRetry: _load);
    }
    if (_meals.isEmpty) {
      return const _EmptyTimeline();
    }
    return _ListView(
      meals: _meals,
      offline: _offline,
      deviceId: widget.deviceId,
      onEdit: _edit,
      onDelete: _delete,
      onRefresh: _load,
    );
  }

  /// 按日期 + 时间倒序
  static List<MealEntry> _sortDesc(List<MealEntry> list) {
    final copy = List<MealEntry>.from(list);
    copy.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return copy;
  }
}

/// 时间线列表
class _ListView extends StatelessWidget {
  const _ListView({
    required this.meals,
    required this.offline,
    required this.deviceId,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  final List<MealEntry> meals;
  final bool offline;
  final String deviceId;
  final Future<void> Function(MealEntry) onEdit;
  final Future<void> Function(MealEntry) onDelete;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 按日期分组
    final groups = <String, List<MealEntry>>{};
    for (final m in meals) {
      groups.putIfAbsent(m.date, () => []).add(m);
    }
    final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final children = <Widget>[];
    if (offline) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 16, color: theme.hintColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text('当前离线，显示本地缓存的记录',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
            ),
          ],
        ),
      ));
    }

    for (final date in dates) {
      final items = groups[date]!;
      final total = NutritionTotal.sum(items);
      children.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Row(
          children: [
            Text(DateUtilsX.label(date),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text(
              '${total.count} 条 · ${NumFmt.kcal(total.calories)} kcal',
              style:
                  theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            ),
            const Spacer(),
            Text(
              '蛋${NumFmt.one(total.protein)} 碳${NumFmt.one(total.carbs)} '
              '脂${NumFmt.one(total.fat)}',
              style:
                  theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ));
      for (final m in items) {
        final isMine = m.deviceId == deviceId;
        children.add(MealCard(
          entry: m,
          isMine: isMine,
          onEdit: isMine ? () => onEdit(m) : null,
          onDelete: isMine ? () => onDelete(m) : null,
        ));
      }
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        // 始终可滚动，保证空列表时也能下拉刷新
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: children,
      ),
    );
  }
}

/// 时间线为空
class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 56, color: theme.hintColor),
          const SizedBox(height: 12),
          Text('还没有任何餐食记录', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('去「今日」页面添加第一顿饭吧',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
        ],
      ),
    );
  }
}

/// 离线且无缓存
class _OfflineEmpty extends StatelessWidget {
  const _OfflineEmpty({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 56),
          const SizedBox(height: 12),
          const Text('网络不可用，且没有本地缓存'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
