// 新增 / 编辑餐食记录页面
//
// 功能：
// - 选择记录日期、餐类型；
// - 手动录入：食物名称、份量、热量、蛋白质、碳水、脂肪；
// - 从常用食物库一键填充营养数据；
// - 拍照 / 相册选图，图片上传到云开发云存储；
// - 保存时可选「同时存入常用食物」。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/meal_type.dart';
import '../../models/models.dart';
import '../../services/food_preset_service.dart';
import '../../services/image_service.dart';
import '../../services/meal_service.dart';
import '../../services/tcb_service.dart';
import '../../utils/date_utils.dart';
import 'food_search_screen.dart';
import 'image_viewer_screen.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({
    super.key,
    required this.roomId,
    required this.deviceId,
    required this.nickname,
    this.existing,
    this.initialDate,
  });

  final String roomId; // 房间 objectId
  final String deviceId; // 本机设备 ID（身份凭证）
  final String nickname; // 本机昵称
  final MealEntry? existing; // 非空表示编辑模式
  final String? initialDate; // 预览某天时新增，默认当天

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _portionCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();

  late String _date;
  late MealType _type;
  late bool _remember; // 同时存入常用食物

  // 图片相关
  File? _localImage; // 新选择的本地图片
  String? _imageUrl; // 已上传图片地址（编辑时可能已有）
  String? _imageFileId; // 已上传图片对应的云存储 fileID
  bool _removeImage = false; // 编辑时删除原图片

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.date ?? widget.initialDate ?? DateUtilsX.today();
    _type = e?.type ?? MealType.guessFromNow();
    _remember = e == null; // 编辑时默认不重复加入食物库
    if (e != null) {
      _nameCtrl.text = e.foodName;
      _portionCtrl.text = e.portion;
      _kcalCtrl.text = NumFmt.input(e.calories);
      _proteinCtrl.text = NumFmt.input(e.protein);
      _carbsCtrl.text = NumFmt.input(e.carbs);
      _fatCtrl.text = NumFmt.input(e.fat);
      _imageUrl = e.imageUrl;
      _imageFileId = e.imageFileId;
      // 编辑时如果没有可用链接但有 fileID，异步换一个新链接用于预览
      if ((_imageUrl == null || !_imageUrl!.startsWith('http')) &&
          _imageFileId != null) {
        _refreshImageUrl();
      }
    }
  }

  /// 用 fileID 换取一次可访问链接（用于编辑页预览）
  Future<void> _refreshImageUrl() async {
    try {
      final url = await TcbService.getTempFileURL(_imageFileId!);
      if (mounted) setState(() => _imageUrl = url);
    } catch (e) {
      debugPrint('预览图片链接获取失败：$e');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _portionCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  // ===================== 日期 =====================

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateUtilsX.parse(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: '选择记录日期',
    );
    if (picked != null) {
      setState(() => _date = DateUtilsX.format(picked));
    }
  }

  // ===================== 图片 =====================

  /// 选择图片来源
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (_localImage != null || _imageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('移除图片', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      if (source == 'remove') {
        setState(() {
          _localImage = null;
          _imageUrl = null;
          _removeImage = true;
        });
        return;
      }
      final file = source == 'camera'
          ? await ImageService.instance.takePhoto()
          : await ImageService.instance.pickFromGallery();
      if (file == null) {
        // 用户取消，或者相机被系统拒绝（Android 上声明了 CAMERA 权限
        // 却没授予时，系统相机会直接失败并返回空）
        if (mounted) {
          showToast(
            context,
            source == 'camera' ? '没有拿到照片：请检查系统设置里是否允许「情侣餐记」使用相机' : '没有选择照片',
          );
        }
        return;
      }
      setState(() {
        _localImage = file;
        _removeImage = false;
      });
    } catch (e) {
      if (mounted) showToast(context, '无法获取图片：$e', isError: true);
    }
  }

  /// 全屏预览当前图片（本地文件优先，其次网络链接）
  Future<void> _openPreview() async {
    if (_localImage != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageViewerScreen(
            imageFile: _localImage,
            title: '预览图片',
          ),
        ),
      );
      return;
    }
    final url = _imageUrl;
    if (url == null || !url.startsWith('http')) {
      if (mounted) showToast(context, '图片还没加载好，稍后再试');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(imageUrl: url, title: '预览图片'),
      ),
    );
  }

  // ===================== 食材库 / 常用食物填充 =====================
  /// 打开内置食材库，选中后自动填入名称、份量与营养数据
  Future<void> _openFoodDatabase() async {
    final picked = await Navigator.of(context).push<FoodPickResult>(
      MaterialPageRoute(builder: (_) => const FoodSearchScreen()),
    );
    if (picked == null || !mounted) return;

    // 已经填了别的食物名称时先确认是否覆盖
    if (_nameCtrl.text.trim().isNotEmpty &&
        _nameCtrl.text.trim() != picked.name) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('覆盖当前内容？'),
          content: Text('将用「${picked.name}」的营养数据覆盖当前填写的食物信息。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('覆盖')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _nameCtrl.text = picked.name;
      _portionCtrl.text = picked.portion;
      _kcalCtrl.text = NumFmt.input(picked.calories);
      _proteinCtrl.text = NumFmt.input(picked.protein);
      _carbsCtrl.text = NumFmt.input(picked.carbs);
      _fatCtrl.text = NumFmt.input(picked.fat);
    });
    if (mounted) showToast(context, '已按「${picked.name}」换算营养数据');
  }

  Future<void> _showPresetPicker() async {
    final selected = await showModalBottomSheet<FoodPreset>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PresetPickerSheet(deviceId: widget.deviceId),
    );
    if (selected == null || !mounted) return;

    // 如果已经填写了名称，先确认是否覆盖
    if (_nameCtrl.text.trim().isNotEmpty &&
        _nameCtrl.text.trim() != selected.name) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('覆盖当前内容？'),
          content: Text('将用「${selected.name}」的营养数据覆盖当前填写的食物信息。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('覆盖')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _nameCtrl.text = selected.name;
      if (selected.portion.isNotEmpty) _portionCtrl.text = selected.portion;
      _kcalCtrl.text = NumFmt.input(selected.calories);
      _proteinCtrl.text = NumFmt.input(selected.protein);
      _carbsCtrl.text = NumFmt.input(selected.carbs);
      _fatCtrl.text = NumFmt.input(selected.fat);
    });
    if (mounted) showToast(context, '已填充「${selected.name}」的营养数据');
  }

  /// 保存记录的同时存入常用食物库
  Future<void> _saveAsPreset() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    await FoodPresetService.instance.add(
      deviceId: widget.deviceId,
      name: _nameCtrl.text.trim(),
      portion: _portionCtrl.text.trim(),
      calories: NumFmt.parse(_kcalCtrl.text),
      protein: NumFmt.parse(_proteinCtrl.text),
      carbs: NumFmt.parse(_carbsCtrl.text),
      fat: NumFmt.parse(_fatCtrl.text),
    );
  }

  // ===================== 保存 =====================

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      // 1. 处理图片：有新图片则上传到云开发云存储；删除图片则清理云端文件
      var url = _removeImage ? null : _imageUrl;
      var fileId = _removeImage ? null : _imageFileId;
      if (_localImage != null) {
        // uploadMealImage 返回的是 (fileID, 临时访问链接)，注意顺序
        final (newFileId, newUrl) = await ImageService.instance.uploadMealImage(
          roomId: widget.roomId,
          deviceId: widget.deviceId,
          file: _localImage!,
        );
        // 编辑时替换了旧图片 → 删除旧文件
        if (_imageFileId != null && _imageFileId != newFileId) {
          await ImageService.instance.deleteImage(_imageFileId);
        }
        url = newUrl;
        fileId = newFileId;
      } else if (_removeImage) {
        await ImageService.instance.deleteImage(_imageFileId);
      }

      // 2. 组装数据
      final draft = MealEntry(
        objectId: widget.existing?.objectId ?? '',
        roomId: widget.roomId,
        deviceId: widget.deviceId,
        nickname: widget.nickname,
        date: _date,
        time: _isEdit ? widget.existing!.time : DateUtilsX.nowTime(),
        type: _type,
        foodName: _nameCtrl.text.trim(),
        portion: _portionCtrl.text.trim(),
        calories: NumFmt.parse(_kcalCtrl.text),
        protein: NumFmt.parse(_proteinCtrl.text),
        carbs: NumFmt.parse(_carbsCtrl.text),
        fat: NumFmt.parse(_fatCtrl.text),
        imageUpdatedAt:
            fileId == null ? null : DateTime.now().millisecondsSinceEpoch,
        // 注意：imageUrl 只是「当前这一次」的临时链接，读取时会重新换取；
        // 真正持久化的是 imageFileId。
        imageUrl: url,
        imageFileId: fileId,
      );

      // 3. 写入云开发集合 mealRecord
      if (_isEdit) {
        await MealService.instance.updateMeal(
          updated: draft,
          deviceId: widget.deviceId,
        );
      } else {
        await MealService.instance.addMeal(
          roomId: widget.roomId,
          deviceId: widget.deviceId,
          nickname: widget.nickname,
          draft: draft,
        );
      }

      // 4. 可选：同时存入常用食物
      if (_remember) await _saveAsPreset();

      if (mounted) {
        showToast(context, _isEdit ? '已保存修改' : '已添加记录');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ===================== UI =====================

  /// 数字输入框
  Widget _numField(String label, TextEditingController ctrl, String unit) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(labelText: label, suffixText: unit),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return '请输入$label';
        if (double.tryParse(v.trim()) == null) return '$label格式错误';
        return null;
      },
    );
  }

  /// 图片预览区域
  Widget _buildImageArea() {
    Widget? image;
    if (_localImage != null) {
      image = Image.file(_localImage!, fit: BoxFit.cover, cacheWidth: 1200);
    } else if (_imageUrl != null &&
        _imageUrl!.startsWith('http') &&
        !_removeImage) {
      image = Image.network(
        _imageUrl!,
        fit: BoxFit.cover,
        // 按显示区域解码，降低内存占用
        cacheWidth: 1200,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }

    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: image != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _openPreview,
                          icon: const Icon(Icons.zoom_out_map, size: 16),
                          label: const Text('查看'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('更换'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 32, color: Theme.of(context).hintColor),
                  const SizedBox(height: 8),
                  Text('拍照 / 从相册选择图片（可选）',
                      style: TextStyle(color: Theme.of(context).hintColor)),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑餐食记录' : '新增餐食记录'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 日期选择
              InkWell(
                onTap: _saving ? null : _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '记录日期',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text('$_date  (${DateUtilsX.label(_date)})'),
                ),
              ),
              const SizedBox(height: 12),

              // 餐类型选择
              Text('餐次', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<MealType>(
                segments: [
                  for (final t in MealType.values)
                    ButtonSegment(
                      value: t,
                      label: Text(t.label),
                      icon: Icon(t.icon, size: 18),
                    ),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged:
                    _saving ? null : (v) => setState(() => _type = v.first),
              ),
              const SizedBox(height: 16),

              // 图片
              _buildImageArea(),
              const SizedBox(height: 16),

              // 食物名称 + 从常用食物填充
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: '食物名称',
                        hintText: '如：番茄炒蛋',
                        counterText: '',
                        prefixIcon: Icon(Icons.restaurant_menu),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '请输入食物名称' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton.tonalIcon(
                      onPressed: _saving ? null : _openFoodDatabase,
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('食材库'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _showPresetPicker,
                    icon: const Icon(Icons.bookmark_outline, size: 18),
                    label: const Text('从常用食物填充'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portionCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '食用份量',
                  hintText: '如：1 碗 / 200g',
                  prefixIcon: Icon(Icons.scale_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // 营养数据
              Row(
                children: [
                  Expanded(child: _numField('热量', _kcalCtrl, 'kcal')),
                  const SizedBox(width: 8),
                  Expanded(child: _numField('蛋白质', _proteinCtrl, 'g')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _numField('碳水', _carbsCtrl, 'g')),
                  const SizedBox(width: 8),
                  Expanded(child: _numField('脂肪', _fatCtrl, 'g')),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '提示：先填写份量再填热量与三大营养素，或从常用食物一键填充。',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 8),

              // 同时加入常用食物
              CheckboxListTile(
                value: _remember,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _remember = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('同时加入「常用食物」'),
                subtitle: const Text('下次可一键填充相同营养数据'),
              ),
              const SizedBox(height: 8),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isEdit ? '保存修改' : '保存记录'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// 常用食物选择弹窗（从云开发集合 foodLibrary 读取本设备的数据）
class _PresetPickerSheet extends StatefulWidget {
  const _PresetPickerSheet({required this.deviceId});

  final String deviceId;

  @override
  State<_PresetPickerSheet> createState() => _PresetPickerSheetState();
}

class _PresetPickerSheetState extends State<_PresetPickerSheet> {
  List<FoodPreset> _list = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Text('选择常用食物', style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          Expanded(child: _buildBody(controller)),
        ],
      ),
    );
  }

  Widget _buildBody(ScrollController controller) {
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
        child: Text('常用食物库还是空的\n可在「常用食物」页面添加'),
      );
    }
    return ListView.separated(
      controller: controller,
      itemCount: _list.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = _list[i];
        return ListTile(
          leading: const Icon(Icons.fastfood_outlined),
          title: Text(p.name),
          subtitle: Text(
            '${p.portion.isEmpty ? '' : '${p.portion} · '}'
            '${NumFmt.kcal(p.calories)} kcal · '
            '蛋${NumFmt.one(p.protein)} 碳${NumFmt.one(p.carbs)} '
            '脂${NumFmt.one(p.fat)}',
          ),
          onTap: () => Navigator.pop(context, p),
        );
      },
    );
  }
}
