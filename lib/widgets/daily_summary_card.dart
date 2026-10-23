// 每日营养汇总卡片
//
// 展示选中日期下「我」与「伴侣」各自的热量、蛋白质、碳水、脂肪合计，
// 以及两人的合计，供情侣对比当日饮食。
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/date_utils.dart';

class DailySummaryCard extends StatelessWidget {
  const DailySummaryCard({
    super.key,
    required this.myName,
    required this.partnerName,
    required this.mine,
    required this.partner,
  });

  final String myName;
  final String partnerName;
  final NutritionTotal mine;
  final NutritionTotal partner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCal = mine.calories + partner.calories;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, size: 18),
                const SizedBox(width: 6),
                Text('营养汇总', style: theme.textTheme.titleSmall),
                const Spacer(),
                Text('合计 ${NumFmt.kcal(totalCal)} kcal',
                    style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  children: [
                    _header('', theme),
                    _header('热量', theme),
                    _header('蛋白质', theme),
                    _header('碳水', theme),
                    _header('脂肪', theme),
                  ],
                ),
                _row('我', mine, theme, highlight: true),
                _row(partnerName, partner, theme, highlight: false),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '「我」记录 ${mine.count} 条 · 「$partnerName」记录 ${partner.count} 条',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }

  /// 表头单元格
  Widget _header(String text, ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(text,
            style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
      );

  /// 数据行
  TableRow _row(String name, NutritionTotal t, ThemeData theme,
      {required bool highlight}) {
    Widget cell(String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Text(v,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              )),
        );
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlight
                  ? theme.colorScheme.primary
                  : Colors.orange.shade700,
            ),
          ),
        ),
        cell(NumFmt.kcal(t.calories)),
        cell('${NumFmt.one(t.protein)}g'),
        cell('${NumFmt.one(t.carbs)}g'),
        cell('${NumFmt.one(t.fat)}g'),
      ],
    );
  }
}
