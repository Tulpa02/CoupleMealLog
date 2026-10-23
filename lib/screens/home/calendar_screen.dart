// 日历 + 每日营养统计页面
//
// - 顶部月份切换；
// - 月历网格：有记录的日期打点，点击日期直接跳转当天餐食记录；
// - 选中日期下方：两人各自的每日营养合计（热量/蛋白质/碳水/脂肪），
//   以及当天两人的全部餐食记录（本设备可编辑删除）。
//
// 数据来源：云开发集合 mealRecord。
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/meal_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/daily_summary_card.dart';
import '../../widgets/meal_card.dart';
import 'meal_actions.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.deviceId,
    required this.nickname,
    required this.room,
  });

  final String deviceId;
  final String nickname;
  final Room room;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _selected = DateUtilsX.today();
  Set<String> _datesWithMeals = {};

  String get _roomId => widget.room.objectId;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  /// 加载当前月份的「有记录日期」用于打点；失败时提示并支持重试
  Future<void> _loadMarkers() async {
    final from = DateTime(_month.year, _month.month, 1);
    final to = DateTime(_month.year, _month.month + 1, 0);
    try {
      final dates = await MealService.instance.fetchDatesWithMeals(
        _roomId,
        from: DateUtilsX.format(from),
        to: DateUtilsX.format(to),
      );
      if (mounted) setState(() => _datesWithMeals = dates);
    } catch (e) {
      if (mounted) {
        showToast(context, '统计加载失败：${friendlyError(e)}', isError: true);
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _datesWithMeals = {};
    });
    _loadMarkers();
  }

  /// 点击日期 → 选中并显示当天记录
  void _selectDate(DateTime date) {
    setState(() => _selected = DateUtilsX.format(date));
  }

  String get _partnerName {
    final partner = widget.room.partnerOf(widget.deviceId);
    return partner == null ? '伴侣' : widget.room.nameOf(partner);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _MonthCalendar(
          month: _month,
          selected: _selected,
          marked: _datesWithMeals,
          onPrev: () => _changeMonth(-1),
          // 不允许翻到未来月份
          onNext: isCurrentMonth ? null : () => _changeMonth(1),
          onSelect: _selectDate,
        ),
        const SizedBox(height: 12),
        _DaySection(
          key: ValueKey(_selected),
          date: _selected,
          roomId: _roomId,
          deviceId: widget.deviceId,
          nickname: widget.nickname,
          partnerName: _partnerName,
        ),
      ],
    );
  }
}

/// 自绘月历（不引入第三方日历库）
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.marked,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final String selected;
  final Set<String> marked;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final void Function(DateTime) onSelect;

  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // 周一为一周开始：weekday 1~7 → 偏移 0~6
    final leading = firstDay.weekday - 1;
    final today = DateUtilsX.today();

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final key = DateUtilsX.format(date);
      final isSelected = key == selected;
      final isToday = key == today;
      final hasMeal = marked.contains(key);

      cells.add(InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => onSelect(date),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? theme.colorScheme.primary : null,
            border: isToday && !isSelected
                ? Border.all(color: theme.colorScheme.primary)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected ? theme.colorScheme.onPrimary : null,
                  fontWeight: isToday ? FontWeight.bold : null,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasMeal
                      ? (isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.primary)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onPrev,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${month.year} 年 ${month.month} 月',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.95,
              children: [
                for (final w in _weekLabels)
                  Center(
                    child: Text(w,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.hintColor)),
                  ),
                ...cells,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 选中日期的营养汇总 + 餐食列表（异步加载云开发数据）
class _DaySection extends StatefulWidget {
  const _DaySection({
    super.key,
    required this.date,
    required this.roomId,
    required this.deviceId,
    required this.nickname,
    required this.partnerName,
  });

  final String date;
  final String roomId;
  final String deviceId;
  final String nickname;
  final String partnerName;

  @override
  State<_DaySection> createState() => _DaySectionState();
}

class _DaySectionState extends State<_DaySection> {
  List<MealEntry> _all = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await MealService.instance.fetchByDate(widget.roomId, widget.date);
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _edit(MealEntry e) async {
    final ok = await openEditMeal(
      context,
      roomId: widget.roomId,
      deviceId: widget.deviceId,
      nickname: widget.nickname,
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

  Future<void> _add() async {
    final ok = await openAddMeal(
      context,
      roomId: widget.roomId,
      deviceId: widget.deviceId,
      nickname: widget.nickname,
      initialDate: widget.date,
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(DateUtilsX.label(widget.date),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text(widget.date,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.hintColor)),
            const Spacer(),
            IconButton(
              tooltip: '刷新',
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
            IconButton(
              tooltip: '添加当天记录',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _add,
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('加载失败：${friendlyError(_error!)}'),
          )
        else
          ..._buildContent(theme),
      ],
    );
  }

  List<Widget> _buildContent(ThemeData theme) {
    final mine = _all.where((e) => e.deviceId == widget.deviceId).toList();
    final partner = _all.where((e) => e.deviceId != widget.deviceId).toList();

    // 当天排序：按餐类型 + 时间
    int cmp(MealEntry a, MealEntry b) => a.sortKey.compareTo(b.sortKey);
    mine.sort(cmp);
    partner.sort(cmp);

    return [
      DailySummaryCard(
        myName: widget.nickname,
        partnerName: widget.partnerName,
        mine: NutritionTotal.sum(mine),
        partner: NutritionTotal.sum(partner),
      ),
      const SizedBox(height: 12),
      if (_all.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text('当天暂无餐食记录',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.hintColor)),
          ),
        ),
      for (final e in mine)
        MealCard(
          entry: e,
          isMine: true,
          onEdit: () => _edit(e),
          onDelete: () => _delete(e),
        ),
      for (final e in partner) MealCard(entry: e, isMine: false),
    ];
  }
}
