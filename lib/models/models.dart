// 腾讯云开发数据库模型
//
// 三个集合（与之前的数据表一一对应）：
//   room        房间
//   mealRecord  餐食记录
//   foodLibrary 常用食物库
//
// 文档字段说明：
// - `_id`：云开发文档 ID（map 中的键为 `_id`）
// - `_openid`：云开发自动写入的创建者 openid（匿名登录用户）
// - 其余业务字段与需求一致（deviceId / roomId / mealType / calorie / carb / fat ...）
//
// 「我 / 伴侣」通过 deviceId 区分：deviceId 与当前设备一致的是「我」。
import 'meal_type.dart';

/// 云开发文档 ID（有的返回 `_id`，有的返回 `id`，这里统一兼容）
String docId(Map<String, dynamic> data) =>
    (data['_id'] ?? data['id'] ?? '').toString();

/// 任意数值安全转换为 double
double toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// 安全转换为字符串（null → 默认值）
String toStringValue(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  return v.toString();
}

/// 安全转换为字符串列表（兼容数组 / null）
List<String> toStringList(dynamic v) {
  if (v is List) {
    return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  return const [];
}

/// 安全转换为日期（云开发返回 ISO 字符串或 Date 对象）
DateTime? toDate(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// 房间（集合：room）
class Room {
  const Room({
    required this.objectId,
    required this.roomCode,
    required this.memberList,
    required this.memberNames,
    required this.createdAt,
  });

  final String objectId; // 云开发文档 ID（_id）
  final String roomCode; // 6 位房间密钥（同时也是用户输入的房间号）
  final List<String> memberList; // 成员设备 ID 列表（最多 2 个）
  final Map<String, String> memberNames; // 设备 ID → 昵称
  final DateTime? createdAt;

  /// 由云开发文档转换
  factory Room.fromDoc(Map<String, dynamic> data) {
    final names = <String, String>{};
    final rawNames = data['memberNames'];
    if (rawNames is Map) {
      rawNames.forEach((k, v) => names[k.toString()] = v.toString());
    }
    return Room(
      objectId: docId(data),
      roomCode: toStringValue(data['roomCode']),
      memberList: toStringList(data['memberList']),
      memberNames: names,
      createdAt: toDate(data['createdAt']),
    );
  }

  /// 房间是否已满（最多 2 人）
  bool get isFull => memberList.length >= 2;

  /// 根据设备 ID 取昵称
  String nameOf(String deviceId) => memberNames[deviceId] ?? '伴侣';

  /// 取「对方」的设备 ID（房间只有自己时返回 null）
  String? partnerOf(String myDeviceId) {
    for (final id in memberList) {
      if (id != myDeviceId) return id;
    }
    return null;
  }
}

/// 餐食记录（集合：mealRecord）
class MealEntry {
  const MealEntry({
    required this.objectId,
    required this.roomId,
    required this.deviceId,
    required this.nickname,
    required this.date,
    required this.time,
    required this.type,
    required this.foodName,
    required this.portion,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.imageUrl,
    this.imageFileId,
    this.imageUpdatedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String objectId; // 云开发文档 ID（新建时为空）
  final String roomId; // 所属房间文档 ID
  final String deviceId; // 记录人设备 ID
  final String nickname; // 记录人昵称（冗余存储，便于展示/导出）
  final String date; // yyyy-MM-dd
  final String time; // HH:mm
  final MealType type; // 餐次（字段 mealType）
  final String foodName; // 食物名称
  final String portion; // 食用份量
  final double calories; // 热量 kcal（字段 calorie）
  final double protein; // 蛋白质 g
  final double carbs; // 碳水 g（字段 carb）
  final double fat; // 脂肪 g
  final String? imageUrl; // 云存储图片的临时链接
  final String? imageFileId; // 云存储 fileID（cloud://...，删除记录时清理）
  final int? imageUpdatedAt; // 图片上传时间戳，用于缓存刷新临时链接
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 由云开发文档转换
  factory MealEntry.fromDoc(Map<String, dynamic> data) {
    // 历史数据兼容：早期版本把「fileID」和「临时链接」写反了，
    // 这里自动纠正，避免老记录永远显示不出图片。
    var imageUrl = data['imageUrl']?.toString();
    var imageFileId = data['imageFileId']?.toString();
    final urlIsFileId = imageUrl != null && imageUrl.startsWith('cloud://');
    final fileIdIsUrl = imageFileId != null && imageFileId.startsWith('http');
    if (urlIsFileId && fileIdIsUrl) {
      // 两个字段完全对调 → 换回来
      final tmp = imageUrl;
      imageUrl = imageFileId;
      imageFileId = tmp;
    } else if (fileIdIsUrl && (imageUrl == null || imageUrl.isEmpty)) {
      // 只有 fileID 字段存了链接 → 当作可显示链接，fileID 置空（无法再换新链接）
      imageUrl = imageFileId;
      imageFileId = null;
    } else if (urlIsFileId) {
      // imageUrl 里存的是 fileID → 挪到 fileID 字段
      imageFileId ??= imageUrl;
      imageUrl = null;
    }

    return MealEntry(
      objectId: docId(data),
      roomId: toStringValue(data['roomId']),
      deviceId: toStringValue(data['deviceId']),
      nickname: toStringValue(data['nickname'], fallback: '用户'),
      date: toStringValue(data['date']),
      time: toStringValue(data['time'], fallback: '00:00'),
      type:
          MealType.fromCode(toStringValue(data['mealType'], fallback: 'snack')),
      foodName: toStringValue(data['foodName']),
      portion: toStringValue(data['portion']),
      calories: toDouble(data['calorie']),
      protein: toDouble(data['protein']),
      carbs: toDouble(data['carb']),
      fat: toDouble(data['fat']),
      imageUrl: imageUrl,
      imageFileId: imageFileId,
      imageUpdatedAt: data['imageUpdatedAt'] is num
          ? (data['imageUpdatedAt'] as num).toInt()
          : null,
      createdAt: toDate(data['createdAt']),
      updatedAt: toDate(data['updateTime']),
    );
  }

  /// 转为写入云开发的字段（不含 _id / _openid）
  ///
  /// 注意：`imageUrl` 是云存储的**临时链接**，几小时后会失效，
  /// 因此不写入数据库；持久化只存 `imageFileId`，读取时再换新链接。
  Map<String, dynamic> toFields() => {
        'roomId': roomId,
        'deviceId': deviceId,
        'nickname': nickname,
        'date': date,
        'time': time,
        'mealType': type.code,
        'foodName': foodName,
        'portion': portion,
        'calorie': calories,
        'protein': protein,
        'carb': carbs,
        'fat': fat,
        'imageFileId': imageFileId,
        'imageUpdatedAt': imageUpdatedAt,
      };

  /// 编辑时返回一份带新字段的副本（objectId 保持不变）
  MealEntry copyWith({
    String? date,
    String? time,
    MealType? type,
    String? foodName,
    String? portion,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? imageUrl,
    String? imageFileId,
    int? imageUpdatedAt,
  }) =>
      MealEntry(
        objectId: objectId,
        roomId: roomId,
        deviceId: deviceId,
        nickname: nickname,
        date: date ?? this.date,
        time: time ?? this.time,
        type: type ?? this.type,
        foodName: foodName ?? this.foodName,
        portion: portion ?? this.portion,
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        imageUrl: imageUrl ?? this.imageUrl,
        imageFileId: imageFileId ?? this.imageFileId,
        imageUpdatedAt: imageUpdatedAt ?? this.imageUpdatedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// 排序键：日期 + 时间
  String get sortKey => '$date $time';
}

/// 每日每人营养合计
class NutritionTotal {
  const NutritionTotal({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.count = 0,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int count;

  NutritionTotal add(MealEntry e) => NutritionTotal(
        calories: calories + e.calories,
        protein: protein + e.protein,
        carbs: carbs + e.carbs,
        fat: fat + e.fat,
        count: count + 1,
      );

  static NutritionTotal sum(Iterable<MealEntry> list) =>
      list.fold(const NutritionTotal(), (acc, e) => acc.add(e));
}

/// 常用食物（集合：foodLibrary）
class FoodPreset {
  const FoodPreset({
    required this.objectId,
    required this.deviceId,
    required this.name,
    required this.portion,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.createdAt,
  });

  final String objectId;
  final String deviceId;
  final String name;
  final String portion;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime? createdAt;

  factory FoodPreset.fromDoc(Map<String, dynamic> data) => FoodPreset(
        objectId: docId(data),
        deviceId: toStringValue(data['deviceId']),
        name: toStringValue(data['foodName']),
        portion: toStringValue(data['portion']),
        calories: toDouble(data['calorie']),
        protein: toDouble(data['protein']),
        carbs: toDouble(data['carb']),
        fat: toDouble(data['fat']),
        createdAt: toDate(data['createdAt']),
      );

  Map<String, dynamic> toFields() => {
        'deviceId': deviceId,
        'foodName': name,
        'portion': portion,
        'calorie': calories,
        'protein': protein,
        'carb': carbs,
        'fat': fat,
      };
}
