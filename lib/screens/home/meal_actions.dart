// 应用内通用操作封装：新增/编辑/删除餐食记录
//
// 首页、时间线、日历统计页共用这些方法，避免重复代码。
// 身份统一使用 deviceId：只有本设备创建的记录才允许编辑 / 删除。
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/image_service.dart';
import '../../services/meal_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/meal_card.dart';
import '../meal/add_meal_screen.dart';

/// 打开新增餐食页面，返回 true 表示已保存
Future<bool?> openAddMeal(
  BuildContext context, {
  required String roomId,
  required String deviceId,
  required String nickname,
  String? initialDate,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => AddMealScreen(
        roomId: roomId,
        deviceId: deviceId,
        nickname: nickname,
        initialDate: initialDate,
      ),
    ),
  );
}

/// 打开编辑餐食页面，返回 true 表示已保存
Future<bool?> openEditMeal(
  BuildContext context, {
  required String roomId,
  required String deviceId,
  required String nickname,
  required MealEntry entry,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => AddMealScreen(
        roomId: roomId,
        deviceId: deviceId,
        nickname: nickname,
        existing: entry,
      ),
    ),
  );
}

/// 删除记录（带二次确认），返回是否删除成功
Future<bool> deleteMealFlow(
  BuildContext context, {
  required String deviceId,
  required MealEntry entry,
}) async {
  final ok = await confirmDeleteMeal(context);
  if (!ok) return false;
  try {
    await MealService.instance.deleteMeal(entry: entry, deviceId: deviceId);
    // 清理云存储上的图片文件（失败忽略）
    if (entry.imageFileId != null) {
      await ImageService.instance.deleteImage(entry.imageFileId);
    }
    if (context.mounted) showToast(context, '已删除记录');
    return true;
  } catch (e) {
    if (context.mounted) showToast(context, friendlyError(e), isError: true);
    return false;
  }
}
