// 常用食物管理页面（云开发集合：foodLibrary）
//
// - 列表展示本设备保存的常用食物（名称、默认份量、营养数据）；
// - 支持新增、编辑、删除（仅本设备的数据）；
// - 记录餐食时可从这些数据一键填充。
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/food_preset_service.dart';
import '../../utils/date_utils.dart';
import 'food_preset_editor.dart';

class FoodPresetsScreen extends StatefulWidget {
  const FoodPresetsScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<FoodPresetsScreen> createState() => _FoodPresetsScreenState();
}

class _FoodPresetsScreenState extends State<FoodPresetsScreen> {
  List<FoodPreset> _list = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 拉取本设备的常用食物
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await FoodPresetService.instance.fetchAll(widget.deviceId);
      if (!mounted) return;
      setState(() {
        _list = list;
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

  /// 新增
  Future<void> _add() async {
    final result = await showFoodPresetEditor(context);
    if (result == null) return;
    try {
      await FoodPresetService.instance.add(
        deviceId: widget.deviceId,
        name: result.name,
        portion: result.portion,
        calories: result.calories,
        protein: result.protein,
        carbs: result.carbs,
        fat: result.fat,
      );
      if (mounted) showToast(context, '已添加「${result.name}」');
      _load();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), isError: true);
    }
  }

  /// 编辑
  Future<void> _edit(FoodPreset preset) async {
    final result = await showFoodPresetEditor(context, preset: preset);
    if (result == null) return;
    try {
      await FoodPresetService.instance.update(
        FoodPreset(
          objectId: preset.objectId,
          deviceId: preset.deviceId,
          name: result.name,
          portion: result.portion,
          calories: result.calories,
          protein: result.protein,
          carbs: result.carbs,
          fat: result.fat,
        ),
        deviceId: widget.deviceId,
      );
      if (mounted) showToast(context, '已保存修改');
      _load();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), isError: true);
    }
  }

  /// 删除
  Future<void> _delete(FoodPreset preset) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除常用食物'),
        content: Text('确定删除「${preset.name}」吗？'),
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
    if (ok != true) return;
    try {
      await FoodPresetService.instance.delete(
        preset.objectId,
        deviceId: widget.deviceId,
      );
      if (mounted) showToast(context, '已删除');
      _load();
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('常用食物')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('新增'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败：${friendlyError(_error!)}'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '还没有常用食物。\n点击右下角「新增」，或在记录餐食时勾选「同时加入常用食物」。',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: _list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final p = _list[i];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.fastfood)),
              title: Text(p.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${NumFmt.kcal(p.calories)} kcal'
                    '${p.portion.isEmpty ? '' : ' · ${p.portion}'}',
                  ),
                  Text(
                    '蛋白质 ${NumFmt.one(p.protein)}g · '
                    '碳水 ${NumFmt.one(p.carbs)}g · '
                    '脂肪 ${NumFmt.one(p.fat)}g',
                    style: TextStyle(
                        color: Theme.of(context).hintColor, fontSize: 12),
                  ),
                ],
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _edit(p);
                  if (v == 'delete') _delete(p);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
              onTap: () => _edit(p),
            ),
          );
        },
      ),
    );
  }
}
