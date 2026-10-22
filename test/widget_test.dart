// 基础单元测试：日期 / 数字格式化 / 餐类型解析
//
// 说明：界面与数据层依赖 LeanCloud 网络，单元测试环境不初始化服务，
// 因此这里只校验纯 Dart 逻辑；完整业务流程请在真机 / 模拟器上验证。
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_meal_log/models/meal_type.dart';
import 'package:couple_meal_log/utils/date_utils.dart';

void main() {
  test('日期格式化与解析', () {
    final d = DateTime(2026, 1, 5);
    expect(DateUtilsX.format(d), '2026-01-05');
    expect(DateUtilsX.parse('2026-01-05'), d);
    expect(DateUtilsX.monthKey(d), '2026-01');
  });

  test('数字格式化', () {
    expect(NumFmt.one(12.0), '12');
    expect(NumFmt.one(12.34), '12.3');
    expect(NumFmt.parse('12.5'), 12.5);
    expect(NumFmt.parse(''), 0);
    expect(NumFmt.kcal(99.6), '100');
  });

  test('餐类型解析', () {
    expect(MealType.fromCode('breakfast'), MealType.breakfast);
    expect(MealType.fromCode('unknown'), MealType.snack);
    expect(MealType.guessFromNow(DateTime(2026, 1, 1, 8)), MealType.breakfast);
    expect(MealType.guessFromNow(DateTime(2026, 1, 1, 12)), MealType.lunch);
    expect(MealType.guessFromNow(DateTime(2026, 1, 1, 19)), MealType.dinner);
  });
}
