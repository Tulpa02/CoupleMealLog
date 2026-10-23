// 常用食物服务（云开发集合：foodLibrary）
//
// 字段：_id、deviceId、foodName、portion、calorie、protein、carb、fat、createdAt
// 每个设备的常用食物库相互独立，只有本设备能读写自己的数据。
import '../core/app_config.dart';
import '../models/models.dart';
import 'tcb_service.dart';

class FoodPresetService {
  FoodPresetService._();

  static final FoodPresetService instance = FoodPresetService._();

  static const String tableFood = AppConfig.collectionFood;

  /// 查询本设备的常用食物（按创建时间倒序）
  Future<List<FoodPreset>> fetchAll(String deviceId) async {
    if (deviceId.isEmpty) return const [];
    final docs = await TcbService.queryWhere(
      tableFood,
      {'deviceId': deviceId},
      orderField: 'createdAt',
      desc: true,
      limit: 500,
    );
    return docs.map(FoodPreset.fromDoc).toList();
  }

  /// 新增常用食物
  Future<void> add({
    required String deviceId,
    required String name,
    required String portion,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) async {
    final fields = FoodPreset(
      objectId: '',
      deviceId: deviceId,
      name: name,
      portion: portion,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    ).toFields();
    fields['createdAt'] = DateTime.now().toIso8601String();
    await TcbService.add(tableFood, fields);
  }

  /// 修改常用食物（仅本设备的数据）
  Future<void> update(FoodPreset preset, {required String deviceId}) async {
    final doc = await _getDoc(preset.objectId);
    if (doc == null) throw Exception('常用食物不存在或已被删除');
    if (toStringValue(doc['deviceId']) != deviceId) {
      throw Exception('只能修改本设备的常用食物');
    }
    await TcbService.update(tableFood, preset.objectId, preset.toFields());
  }

  /// 删除常用食物（仅本设备的数据）
  Future<void> delete(String objectId, {required String deviceId}) async {
    final doc = await _getDoc(objectId);
    if (doc == null) return;
    if (toStringValue(doc['deviceId']) != deviceId) {
      throw Exception('只能删除本设备的常用食物');
    }
    await TcbService.remove(tableFood, objectId);
  }

  Future<Map<String, dynamic>?> _getDoc(String docId) async {
    if (docId.isEmpty) return null;
    final list =
        await TcbService.queryWhere(tableFood, {'_id': docId}, limit: 1);
    return list.isEmpty ? null : list.first;
  }
}
