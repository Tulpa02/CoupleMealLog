// 常用食物编辑弹窗
//
// 既用于「常用食物管理页」的增改，也用于「新增餐食页」在保存记录的同时
// 顺手加入常用食物库（快速一键填充营养数据）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../utils/date_utils.dart';

class FoodPresetEditorResult {
  const FoodPresetEditorResult({
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

/// 显示常用食物编辑弹窗；返回 null 表示取消
Future<FoodPresetEditorResult?> showFoodPresetEditor(
  BuildContext context, {
  FoodPreset? preset,
}) {
  return showModalBottomSheet<FoodPresetEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FoodPresetEditorSheet(preset: preset),
  );
}

class _FoodPresetEditorSheet extends StatefulWidget {
  const _FoodPresetEditorSheet({this.preset});
  final FoodPreset? preset;

  @override
  State<_FoodPresetEditorSheet> createState() => _FoodPresetEditorSheetState();
}

class _FoodPresetEditorSheetState extends State<_FoodPresetEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _portion;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    _name = TextEditingController(text: p?.name ?? '');
    _portion = TextEditingController(text: p?.portion ?? '');
    _calories = TextEditingController(text: NumFmt.input(p?.calories ?? 0));
    _protein = TextEditingController(text: NumFmt.input(p?.protein ?? 0));
    _carbs = TextEditingController(text: NumFmt.input(p?.carbs ?? 0));
    _fat = TextEditingController(text: NumFmt.input(p?.fat ?? 0));
  }

  @override
  void dispose() {
    _name.dispose();
    _portion.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      FoodPresetEditorResult(
        name: _name.text.trim(),
        portion: _portion.text.trim(),
        calories: NumFmt.parse(_calories.text),
        protein: NumFmt.parse(_protein.text),
        carbs: NumFmt.parse(_carbs.text),
        fat: NumFmt.parse(_fat.text),
      ),
    );
  }

  /// 数字输入框（可选填，默认 0）
  Widget _numField(String label, TextEditingController ctrl, String unit) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(labelText: label, suffixText: unit, isDense: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.preset != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(editing ? '编辑常用食物' : '新增常用食物',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '食物名称',
                  prefixIcon: Icon(Icons.restaurant_menu),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入食物名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portion,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '默认份量（可选）',
                  hintText: '如：1 碗 / 200g / 1 份',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _numField('热量', _calories, 'kcal')),
                  const SizedBox(width: 8),
                  Expanded(child: _numField('蛋白质', _protein, 'g')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _numField('碳水', _carbs, 'g')),
                  const SizedBox(width: 8),
                  Expanded(child: _numField('脂肪', _fat, 'g')),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(editing ? '保存修改' : '添加到常用食物'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
