// CSV 导出服务
//
// 不依赖第三方库：
// - 手动实现 RFC 4180 转义（逗号、引号、换行）；
// - UTF-8 BOM 保证 Excel / WPS 在 Windows 下正确识别中文；
// - 文件保存到手机本地「Download/CoupleMealLog」目录，安卓 10+ 无需存储权限；
//   旧版安卓（<10）若无法写入，则回退到应用外部目录。
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../utils/date_utils.dart';

class CsvExportService {
  CsvExportService._();

  static final CsvExportService instance = CsvExportService._();

  /// 导出结果为 (文件绝对路径, 记录条数)
  Future<(String, int)> exportMeals(List<MealEntry> meals) async {
    final dir = await _resolveOutputDir();
    final stamp = DateTime.now();
    final name = 'CoupleMealLog_'
        '${stamp.year}${_two(stamp.month)}${_two(stamp.day)}_'
        '${_two(stamp.hour)}${_two(stamp.minute)}${_two(stamp.second)}.csv';
    final file = File('${dir.path}${Platform.pathSeparator}$name');

    // UTF-8 BOM + CSV 内容
    final content = StringBuffer('\uFEFF');
    content.writeln([
      '日期',
      '餐次',
      '记录人',
      '食物名称',
      '食用份量',
      '热量(kcal)',
      '蛋白质(g)',
      '碳水(g)',
      '脂肪(g)',
      '记录时间',
      '图片地址',
    ].map(_escape).join(','));

    // 按日期、时间排序后导出
    final sorted = List<MealEntry>.from(meals)
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    for (final m in sorted) {
      content.writeln([
        m.date,
        m.type.label,
        m.nickname,
        m.foodName,
        m.portion,
        NumFmt.one(m.calories),
        NumFmt.one(m.protein),
        NumFmt.one(m.carbs),
        NumFmt.one(m.fat),
        m.time,
        m.imageUrl ?? '',
      ].map(_escape).join(','));
    }

    await file.writeAsString(content.toString(), flush: true);
    return (file.path, sorted.length);
  }

  /// 选择输出目录：优先公共 Download 目录
  Future<Directory> _resolveOutputDir() async {
    // 外部存储根目录（Android 10+ 上 App 写入 Download 无需存储权限）
    final external = await getExternalStorageDirectory();
    final storageRoot =
        external?.path.split('/Android/').first ?? '/storage/emulated/0';

    final candidates = <Future<String?> Function()>[
      // 公共下载目录（用户可在文件管理器中直接找到）
      () async => '$storageRoot/Download/CoupleMealLog',
      // 兼容：部分设备/系统镜像的下载目录是 Chinese 名称或旧路径
      () async => '$storageRoot/Download',
      // 回退：应用专属外部目录（无需权限，卸载时一并删除）
      () async => external?.path,
      // 再回退：应用文档目录
      () async => (await getApplicationDocumentsDirectory()).path,
    ];

    Object? lastError;
    for (final resolve in candidates) {
      try {
        final String? path = await resolve();
        if (path == null || path.isEmpty) continue;
        final Directory dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        // 实际写一个临时文件确认可写（Android 11+ 对 Download 根目录有限制）
        final File probe =
            File('${dir.path}${Platform.pathSeparator}.cml_write_test');
        await probe.writeAsString('ok');
        await probe.delete();
        return dir;
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('无法访问存储目录（请检查存储权限）：$lastError');
  }

  /// CSV 字段转义
  static String _escape(String value) {
    final needQuote = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final v = value.replaceAll('"', '""');
    return needQuote ? '"$v"' : v;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
