// 首页：今日（或选中日期）两人餐食列表 + 快速新增
//
// - 顶部：日期切换（前一天 / 后一天 / 点日期选择）+ 下拉刷新；
// - 营养汇总：两人各自的热量、蛋白质、碳水、脂肪合计；
// - 列表：先展示「我」的记录，再展示伴侣的记录；
// - 悬浮按钮（在 HomeShell 中）快速新增餐食。
//
// 数据来源：云开发集合 mealRecord（按 roomId + date 查询，并写入本地缓存）。
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/cache_service.dart';
import '../../services/meal_service.dart';
import '../../services/room_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/daily_summary_card.dart';
import '../../widgets/meal_card.dart';
import 'meal_actions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.deviceId,
    required this.nickname,
    required this.room,
    this.onRoomRefreshed,
  });

  final String deviceId;
  final String nickname;
  final Room room;
  final ValueChanged<Room>? onRoomRefreshed;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _date = DateUtilsX.today();
  late Room _room = widget.room;
  List<MealEntry> _meals = const [];
  bool _loading = true;
  Object? _error;

  String get _roomId => _room.objectId;

  @override
  void initState() {
    super.initState();
    _load();
    // 房间成员可能刚变化，进入首页时刷新一次
    _refreshRoom();
  }

  /// 伙伴昵称（房间只有一个成员时显示「伴侣」）
  String get _partnerName {
    final partner = _room.partnerOf(widget.deviceId);
    return partner == null ? '伴侣' : _room.nameOf(partner);
  }

  /// 刷新房间成员信息
  Future<void> _refreshRoom() async {
    try {
      final room = await RoomService.instance.fetchRoom(_roomId);
      if (room != null && mounted) {
        setState(() => _room = room);
        widget.onRoomRefreshed?.call(room);
      }
    } catch (_) {
      // 离线时忽略
    }
  }

  /// 加载当天记录；网络失败时回退到本地缓存
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await MealService.instance.fetchByDate(_roomId, _date);
      if (!mounted) return;
      setState(() {
        _meals = list;
        _loading = false;
      });
    } catch (e) {
      final cached = await CacheService.instance.readDay(_roomId, _date);
      if (!mounted) return;
      setState(() {
        if (cached != null) {
          _meals = cached;
          _error = null;
        } else {
          _error = e;
        }
        _loading = false;
      });
    }
  }

  /// 切换日期
  void _shiftDay(int days) {
    final d = DateUtilsX.parse(_date).add(Duration(days: days));
    setState(() => _date = DateUtilsX.format(d));
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateUtilsX.parse(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '选择日期',
    );
    if (picked != null) {
      setState(() => _date = DateUtilsX.format(picked));
      _load();
    }
  }

  /// 编辑记录
  Future<void> _edit(MealEntry entry) async {
    final ok = await openEditMeal(
      context,
      roomId: _roomId,
      deviceId: widget.deviceId,
      nickname: widget.nickname,
      entry: entry,
    );
    if (ok == true) _load();
  }

  /// 删除记录
  Future<void> _delete(MealEntry entry) async {
    final ok = await deleteMealFlow(
      context,
      deviceId: widget.deviceId,
      entry: entry,
    );
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _date == DateUtilsX.today();

    return Column(
      children: [
        // ===== 日期切换栏 =====
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: '前一天',
                onPressed: () => _shiftDay(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          isToday ? '今天' : DateUtilsX.label(_date),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(_date,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.hintColor)),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '后一天',
                onPressed: isToday ? null : () => _shiftDay(1),
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: () {
                  _refreshRoom();
                  _load();
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ===== 列表 + 汇总 =====
        Expanded(child: _buildBody(theme, isToday)),
      ],
    );
  }

  Widget _buildBody(ThemeData theme, bool isToday) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _load);
    }

    final all = _meals;
    final mine = all.where((e) => e.deviceId == widget.deviceId).toList();
    final partner = all.where((e) => e.deviceId != widget.deviceId).toList();

    return RefreshIndicator(
      onRefresh: () async {
        _refreshRoom();
        await _load();
      },
      child: ListView(
        // 始终可滚动，保证空列表时也能下拉刷新
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          DailySummaryCard(
            myName: widget.nickname,
            partnerName: _partnerName,
            mine: NutritionTotal.sum(mine),
            partner: NutritionTotal.sum(partner),
          ),
          const SizedBox(height: 16),

          if (all.isEmpty)
            _EmptyView(
              isToday: isToday,
              onAdd: () async {
                await openAddMeal(
                  context,
                  roomId: _roomId,
                  deviceId: widget.deviceId,
                  nickname: widget.nickname,
                  initialDate: _date,
                );
                _load();
              },
            ),

          // 我的记录
          if (mine.isNotEmpty) ...[
            _SectionTitle(
              title: '我的记录',
              count: mine.length,
              kcal: NutritionTotal.sum(mine).calories,
            ),
            ...mine.map((e) => MealCard(
                  entry: e,
                  isMine: true,
                  onEdit: () => _edit(e),
                  onDelete: () => _delete(e),
                )),
            const SizedBox(height: 12),
          ],

          // 伴侣的记录（仅查看）
          if (partner.isNotEmpty) ...[
            _SectionTitle(
              title: '$_partnerName 的记录',
              count: partner.length,
              kcal: NutritionTotal.sum(partner).calories,
            ),
            ...partner.map((e) => MealCard(entry: e, isMine: false)),
          ],
        ],
      ),
    );
  }
}

/// 分组标题：名称 + 条数 + 热量
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.count,
    required this.kcal,
  });

  final String title;
  final int count;
  final double kcal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(width: 6),
          Text('$count 条 · ${NumFmt.kcal(kcal)} kcal',
              style:
                  theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
        ],
      ),
    );
  }
}

/// 空状态
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.isToday, required this.onAdd});
  final bool isToday;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.no_food_outlined, size: 56, color: theme.hintColor),
          const SizedBox(height: 12),
          Text(isToday ? '今天还没有餐食记录' : '这一天还没有餐食记录',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('记录每一餐，和 TA 一起坚持饮食管理',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('添加记录'),
          ),
        ],
      ),
    );
  }
}

/// 加载错误视图
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text('加载失败：${friendlyError(error)}', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
