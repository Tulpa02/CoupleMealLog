// 内置食材库搜索页
//
// 用法：在「记一餐」里点「食材库」，搜索食材 → 输入克数 → 自动填入
// 食物名称、份量、热量、蛋白质、碳水、脂肪。
//
// 数据来自 lib/data/food_database.dart（离线，无需网络）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/food_database.dart';
import '../../data/food_item.dart';
import '../../utils/date_utils.dart';

/// 选中食材后返回的结果
class FoodPickResult {
  const FoodPickResult({
    required this.name,
    required this.portion,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String name;
  final String portion;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
}

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  /// 当前选中的分类，null 表示全部
  String? _category;

  /// 全部分类（按内置数据顺序去重）
  late final List<String> _categories = <String>{
    for (final f in kFoodDatabase) f.category,
  }.toList();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 按关键词与分类过滤
  List<FoodItem> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return kFoodDatabase.where((f) {
      if (_category != null && f.category != _category) return false;
      if (q.isEmpty) return true;
      return f.name.toLowerCase().contains(q) ||
          f.category.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('食材库'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜索食材，如「米饭」「鸡胸肉」',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip('全部', null),
                      for (final c in _categories) _chip(c, c),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '没有找到「${_searchCtrl.text.trim()}」\n可以直接手动填写营养数据',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            )
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) {
                final f = list[index];
                return ListTile(
                  title: Text(f.name),
                  subtitle: Text(
                    '每 100g · 蛋白 ${NumFmt.one(f.proteinPer100g)}g · '
                    '碳水 ${NumFmt.one(f.carbPer100g)}g · '
                    '脂肪 ${NumFmt.one(f.fatPer100g)}g',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        NumFmt.kcal(f.kcalPer100g),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('kcal/100g',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                  onTap: () => _pickGram(f),
                );
              },
            ),
    );
  }

  /// 分类标签
  Widget _chip(String label, String? value) {
    final selected = _category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _category = value),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// 输入克数并确认
  Future<void> _pickGram(FoodItem f) async {
    final gramCtrl = TextEditingController(text: f.portionGram.toString());
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final gram = double.tryParse(gramCtrl.text.trim()) ?? 0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '每 100g：${NumFmt.kcal(f.kcalPer100g)} kcal · '
                    '蛋白 ${NumFmt.one(f.proteinPer100g)}g · '
                    '碳水 ${NumFmt.one(f.carbPer100g)}g · '
                    '脂肪 ${NumFmt.one(f.fatPer100g)}g',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: gramCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      labelText: '吃了多少克',
                      suffixText: 'g',
                      helperText: '常见份量：${f.portionName} ≈ ${f.portionGram}g',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 实时换算结果
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${NumFmt.kcal(f.kcalFor(gram))} kcal · '
                      '蛋白 ${NumFmt.one(f.proteinFor(gram))}g · '
                      '碳水 ${NumFmt.one(f.carbFor(gram))}g · '
                      '脂肪 ${NumFmt.one(f.fatFor(gram))}g',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: gram > 0
                              ? () => Navigator.of(ctx).pop(gram)
                              : null,
                          child: const Text('填入'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    gramCtrl.dispose();
    if (result == null || result <= 0) return;
    if (!mounted) return;
    Navigator.of(context).pop(
      FoodPickResult(
        name: f.name,
        portion: f.portionText(result),
        calories: f.kcalFor(result),
        protein: f.proteinFor(result),
        carbs: f.carbFor(result),
        fat: f.fatFor(result),
      ),
    );
  }
}
