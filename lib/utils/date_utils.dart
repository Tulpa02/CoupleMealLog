// 通用工具：日期处理、数字格式化、提示组件
//
// 说明：为避免引入 intl 等第三方库，日期与数字格式化在本文件中手写实现。
import 'package:flutter/material.dart';

import '../services/tcb_service.dart';

/// 日期工具：统一使用 `yyyy-MM-dd` 字符串作为数据表中的日期字段，
/// 便于按字符串范围查询与本地排序。
class DateUtilsX {
  DateUtilsX._();

  /// 把 DateTime 转成 `yyyy-MM-dd`
  static String format(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  /// 把 `yyyy-MM-dd` 解析为当天 00:00 的 DateTime
  static DateTime parse(String ymd) => DateTime.parse(ymd);

  /// 仅保留年月日（去掉时分秒），便于比较
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// 今天的日期字符串
  static String today() => format(DateTime.now());

  /// 当前月份字符串 `yyyy-MM`
  static String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  /// 中文展示：今天 / 昨天 / 10月20日 周二
  static String label(String ymd) {
    final date = parse(ymd);
    final today = dateOnly(DateTime.now());
    final diff = today.difference(date).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
  }

  /// 当前时间 `HH:mm`（作为记录时间写入数据表，供同精度排序）
  static String nowTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }
}

/// 数字格式化工具（不依赖 intl）
class NumFmt {
  NumFmt._();

  /// 保留 0~1 位小数：12.0 → "12"，12.34 → "12.3"
  static String one(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  /// 热量展示（整数 kcal）
  static String kcal(double v) => v.round().toString();

  /// 安全地把用户输入解析为 double（空串 / 非法输入返回 0）
  static double parse(String? text) {
    if (text == null) return 0;
    final t = text.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? 0;
  }

  /// 把数值转成输入框友好文本（去掉多余的 .0）
  static String input(double v) =>
      v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());
}

/// 全局提示条（SnackBar）快捷方法
void showToast(BuildContext context, String message, {bool isError = false}) {
  // 连续弹出时先收起上一条，避免排队
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        duration: const Duration(seconds: 2),
      ),
    );
}

/// 统一的错误文案转换：把云开发 / 网络异常翻译成中文提示
///
/// 具体映射逻辑在 services/tcb_service.dart 中维护，这里只做入口，
/// 保证各页面调用方式与之前一致。
String friendlyError(Object error) => TcbService.friendlyError(error);
