// 餐类型定义：早餐 / 午餐 / 晚餐 / 加餐
import 'package:flutter/material.dart';

/// 餐类型枚举（code 为写入 云开发集合 mealRecord 中 mealType 字段的字符串值）
enum MealType {
  breakfast('breakfast', '早餐', Icons.free_breakfast_outlined),
  lunch('lunch', '午餐', Icons.lunch_dining_outlined),
  dinner('dinner', '晚餐', Icons.dinner_dining_outlined),
  snack('snack', '加餐', Icons.icecream_outlined);

  const MealType(this.code, this.label, this.icon);

  final String code;
  final String label;
  final IconData icon;

  /// 由云开发文档中的 code 还原枚举
  static MealType fromCode(String code) {
    for (final t in MealType.values) {
      if (t.code == code) return t;
    }
    return MealType.snack;
  }

  /// 推荐的默认记录时间（新增餐食时按当前时间智能选择）
  static MealType guessFromNow([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 10) return MealType.breakfast;
    if (hour < 14) return MealType.lunch;
    if (hour < 17) return MealType.snack;
    if (hour < 21) return MealType.dinner;
    return MealType.snack;
  }
}
