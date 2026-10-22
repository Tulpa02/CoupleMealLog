// 内置食材数据模型
//
// 营养值均以「每 100 克」为基准，用时按实际克数换算。
class FoodItem {
  const FoodItem(
    this.name,
    this.category,
    this.kcalPer100g,
    this.proteinPer100g,
    this.carbPer100g,
    this.fatPer100g,
    this.portionName,
    this.portionGram,
  );

  /// 食材 / 菜品名称
  final String name;

  /// 分类（主食 / 肉蛋水产 / 蛋奶豆 / 蔬菜 / 水果 / 坚果零食 / 家常菜）
  final String category;

  /// 每 100g 热量（kcal）
  final double kcalPer100g;

  /// 每 100g 蛋白质（g）
  final double proteinPer100g;

  /// 每 100g 碳水（g）
  final double carbPer100g;

  /// 每 100g 脂肪（g）
  final double fatPer100g;

  /// 常见份量描述，如「1 碗」
  final String portionName;

  /// 常见份量对应克数，如 150
  final int portionGram;

  /// 按克数换算热量
  double kcalFor(double gram) => kcalPer100g * gram / 100;

  /// 按克数换算蛋白质
  double proteinFor(double gram) => proteinPer100g * gram / 100;

  /// 按克数换算碳水
  double carbFor(double gram) => carbPer100g * gram / 100;

  /// 按克数换算脂肪
  double fatFor(double gram) => fatPer100g * gram / 100;

  /// 份量文本，如「200g（1 碗 = 150g）」
  String portionText(double gram) {
    final g = gram == gram.roundToDouble()
        ? gram.round().toString()
        : gram.toStringAsFixed(1);
    return '$g g（$portionName ≈ ${portionGram}g）';
  }
}
