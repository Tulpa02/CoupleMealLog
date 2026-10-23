# 情侣餐记 CoupleMealLog（微信云开发 / 腾讯 CloudBase）

> **原生 Flutter 安卓 App**：情侣两人共享餐食记录、互相查看每日饮食与营养摄入。
> 功能对标 OpenNutriTracker，并增加「双人共享房间」能力。
>
> **技术栈**：Flutter + Dart + **微信云开发 / 腾讯 CloudBase**（文档型数据库 + 云存储）
> **免注册**：以安卓设备唯一标识（deviceId）作为身份，用 6 位房间密钥加入房间。
> 不含任何 WebView、网页或 PWA 方案，最终产物是可直接安装的 **APK**。

---

## 一、功能一览

| 模块 | 功能 |
| --- | --- |
| 身份 | **免注册**：以本机 `deviceId`（Android ID + 机型指纹哈希）作为身份，昵称保存在本机 |
| 共享房间 | 启动即「房间选择页」：**创建房间**（昵称 → 自动生成 6 位数字房间密钥）或 **加入房间**（昵称 + 6 位密钥）；房间最多 2 人；可退出房间 |
| 餐食记录 | 日期、餐次（早/午/晚/加餐）、食物名称、份量、热量、蛋白质、碳水、脂肪；拍照 / 相册选图上传云存储；新增、编辑、删除**本设备**记录 |
| 权限 | 同房间两人记录互相可见；**只能编辑 / 删除本设备创建的记录**（界面按 deviceId 判断 + 服务层再校验 + 数据库安全规则兜底） |
| 时间线 | 按日期倒序、按天分组展示两人全部餐食，显示当日合计 |
| 日历 + 统计 | 自绘月历（有记录日期打点），点击日期查看当天记录；两人各自的热量/蛋白质/碳水/脂肪合计 |
| 常用食物 | 保存常吃食物（`foodLibrary` 集合，仅本设备可见），记录时一键填充 |
| **内置食材库** | **离线内置 90+ 常见食材 / 菜品**（主食、肉蛋、蔬菜、水果、坚果、家常菜），按「每 100g」营养值换算：搜索食材 → 输入克数 → 自动填入热量与三大营养素 |
| **图片大图** | 点击列表缩略图进入**全屏查看**：双指缩放、双击放大、拖动，带 Hero 过渡动画；编辑页也有「查看」按钮 |
| CSV 导出 | 导出全部记录为 CSV 到 `Download/CoupleMealLog/` |
| 离线缓存 | 已加载记录写本地缓存，离线可查看；设置页可清理 |

---

## 二、项目结构

```
CoupleMealLog/
├── pubspec.yaml                        # cloudbase_flutter / device_info_plus / image_picker / path_provider / shared_preferences
├── lib/
│   ├── main.dart                       # 入口：TcbService.init() → RoomGate
│   ├── app.dart                        # 主题 + 根节点（无登录页）
│   ├── core/
│   │   ├── app_config.dart             # ★ 环境 ID、集合名、云存储目录
│   │   └── device_service.dart         # ★ 设备唯一 ID + 昵称本地存储
│   ├── models/models.dart              # Room / MealEntry / FoodPreset（云开发文档字段）
│   ├── data/
│   │   ├── food_item.dart              # ★ 内置食材数据模型（每 100g 营养值 + 克数换算）
│   │   └── food_database.dart          # ★ 内置食材库（90+ 条，离线可用，可自行追加）
│   ├── services/
│   │   ├── tcb_service.dart            # ★ 云开发初始化、数据库/存储封装、错误翻译
│   │   ├── room_service.dart           # ★ room + roomMember 集合：创建/加入/退出
│   │   ├── meal_service.dart           # ★ mealRecord 集合：增删改查 + 图片链接
│   │   ├── food_preset_service.dart    # ★ foodLibrary 集合
│   │   ├── image_service.dart          # ★ 拍照/相册 + 云存储上传/删除
│   │   ├── cache_service.dart          # 本地缓存
│   │   └── csv_export_service.dart     # CSV 导出
│   ├── screens/                        # 房间选择、首页、时间线、日历、设置、新增餐食、食材库、常用食物
│   ├── widgets/                        # 餐食卡片、营养汇总
│   └── utils/date_utils.dart
├── android/                            # 安卓工程（Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0）
└── test/widget_test.dart
```

---

## 三、环境准备

| 工具 | 要求 |
| --- | --- |
| Flutter | 3.24+（推荐 3.29+ / 3.47，Dart ≥ 3.4） |
| Android SDK | Platform 34+、Build-Tools 34+ |
| JDK | 17 或 21 |
| 腾讯云账号 | 用**微信扫码**登录 [云开发控制台](https://tcb.cloud.tencent.com/dev) 即可（需实名） |

```bat
flutter doctor -v
:: 必须确认 Android toolchain 为 ✓
:: 若提示 Some Android licenses not accepted，先执行：
::   flutter doctor --android-licenses   （一路输入 y）
```

---

## 四、云开发配置步骤（必做）

### 1. 创建环境

1. 打开 [腾讯云开发平台](https://tcb.cloud.tencent.com/dev)，微信扫码登录；
2. 首次使用按提示开通（个人开发版有免费额度）；
3. **新建环境** → 计费方式选「按量计费 / 开发版」，**地域选「上海」**（文档型数据库的安全规则目前仅上海地域支持），拿到**环境 ID**（形如 `cloud1-xxxxxxxxxxxx`）。

### 2. 开启匿名登录

控制台 → **身份认证 / 登录方式** → 开启「**匿名登录**」。
App 启动时会自动调用 `signInAnonymously()`，安全规则里用 `auth.openid` 判断“是不是本人”。

### 3. 创建 4 个集合

控制台 → **数据库 → 云数据库（文档型）**，新建以下集合（字段首次写入会自动创建，无需手动建字段）：

| 集合 | 字段 | 说明 |
| --- | --- | --- |
| **room** | `roomCode`、`creatorDeviceId`、`createdAt`（旧版还有 `memberList`/`memberNames`） | 房间主体，只有创建者会写 |
| **roomMember** | `roomId`、`roomCode`、`deviceId`、`nickname`、`createdAt` | **房间成员，每个设备一条** |
| **mealRecord** | `roomId`、`deviceId`、`nickname`、`date`、`time`、`mealType`、`foodName`、`portion`、`calorie`、`protein`、`carb`、`fat`、`imageFileId`、`imageUpdatedAt`、`createdAt`、`updateTime` | 餐食记录 |
| **foodLibrary** | `deviceId`、`foodName`、`portion`、`calorie`、`protein`、`carb`、`fat`、`createdAt` | 常用食物（仅本设备） |

> `_id`、`_openid` 由云开发自动维护，不用创建。
>
> **为什么要有 roomMember**：云开发基础权限只能做到「修改本人创建的数据」，
> 而伴侣加入房间时要去改“对方创建的”房间文档，会被拒绝（表现为“加入失败”）。
> 改为每个设备写自己的成员文档后，加入 / 退出 / 改昵称都只碰自己的数据，权限天然通过。

**建议索引**：`room.roomCode`、`roomMember.roomId + deviceId`、`mealRecord.roomId + date`、`foodLibrary.deviceId`。

### 4. 设置权限

> ⚠️ 实测部分环境（`flexdb` 版云数据库）**不接受 `get(database.xxx.${...})`** 这类跨文档规则，
> 保存时会报 `rule invalid`。所以提供两套方案，**先用方案一跑通**，有余力再升级到方案二。

#### 方案一（推荐先用）：控制台基础权限，一条规则都不用写

数据库 → 选择集合 → **权限设置** → 选下面的预设：

| 集合 | 选择的权限 |
| --- | --- |
| `room` | 读取全部数据，修改本人数据 |
| `roomMember` | 读取全部数据，修改本人数据 |
| `mealRecord` | 读取全部数据，修改本人数据 |
| `foodLibrary` | 读取和修改本人数据 |

这样设置后：

- 两人能正常创建/加入房间、互相看到记录；
- “只能改自己的记录”由 App 按 `deviceId` 在服务层校验（`meal_service.dart` / `food_preset_service.dart` 里都有归属判断）；
- “最多 2 人”由 App 保证（加入前统计成员数，写入后回查，若超员立即撤回自己）。

缺点：拿到环境 ID 的技术用户理论上能读到其他房间的数据。对“情侣自用”够用。

#### 方案二（可选，严格隔离）：自定义安全规则

如果控制台接受下面语法（先小范围试，保存成功才用），可以做文档级隔离：

**roomMember**
```json
{
  "read": "auth.openid != null",
  "create": "auth.openid != null",
  "update": "doc._openid == auth.openid",
  "delete": "doc._openid == auth.openid"
}
```

**mealRecord**（需要引擎支持 `get()` 跨文档引用）
```json
{
  "read": "auth.openid in get(`database.room.${doc.roomId}`).memberList",
  "write": "auth.openid in get(`database.room.${doc.roomId}`).memberList"
}
```

> 若提示 `rule invalid`，说明当前环境不支持，请回到方案一。
> 更进一步的“服务端强制只能改自己的记录”可参考第五节（记录 `ownerOpenid` / 使用 `doc._openid`）。

### 5. 云存储权限

控制台 → **云存储 → 权限设置** → 选「**所有用户可读，仅创建者可读写**」（两人要互相看图片）。
若也报 `rule invalid`，选最宽松的「所有用户可读写」即可（图片本身不敏感）。

### 6. 配置环境 ID（编译参数注入，不写死在代码里）

仓库里的 `lib/core/app_config.dart` 使用 `String.fromEnvironment` 读取，默认为占位符：

```dart
static const String envId = String.fromEnvironment(
  'TCB_ENV_ID',
  defaultValue: '请替换为你的云开发环境ID',
);
```

所以编译时必须带上你的环境 ID：

```powershell
flutter build apk --release --dart-define=TCB_ENV_ID=你的环境ID
```

**推荐做法**：把 `build-release.example.bat` 复制一份为 `build-release.bat`，
填上自己的环境 ID 后双击即可（该文件已被 `.gitignore` 忽略，不会提交到仓库）。

> 为什么这么设计：环境 ID 虽不是密钥，但公开仓库里暴露后，别人能向你同一环境发请求。
> 用编译参数注入可以做到「代码公开、环境私有」。

---

## 五、权限加强方案（可选，严格隔离）

当前实现：**房间维度由安全规则 `get(database.room.${doc.roomId}).memberList` 保证**；
“只能改自己的记录”由 deviceId 在 App 层判断。

如果需要连“改自己的”都由服务端强制，可在 room 里保存每个成员的 **openid**（登录后通过 `app.auth` 获取当前用户 ID），
把 mealRecord 规则写成：

```json
{
  "read": "auth.openid in get(`database.room.${doc.roomId}`).memberOpenids",
  "create": "auth.openid in get(`database.room.${doc.roomId}`).memberOpenids",
  "update": "doc.ownerOpenid == auth.openid",
  "delete": "doc.ownerOpenid == auth.openid"
}
```

并给每条 mealRecord 写入 `ownerOpenid`（`_openid` 本身就是创建者 openid，也可直接用 `doc._openid == auth.openid` 判断）。
本项目为了保持“免注册 + deviceId 身份”的需求，默认使用 deviceId 方案；两者可以同时存在。

---

## 六、编译生成安卓 APK

**方式一（推荐）**：复制 `build-release.example.bat` 为 `build-release.bat`，填好环境 ID 后双击。

**方式二（命令行）**：

```bat
cd /d D:\DevTools\CoupleMealLog
flutter pub get
flutter build apk --release --dart-define=TCB_ENV_ID=你的环境ID
:: 产物：build\app\outputs\flutter-apk\app-release.apk

:: 按 CPU 架构拆分（体积更小）
flutter build apk --release --dart-define=TCB_ENV_ID=你的环境ID --split-per-abi

:: 安装到手机（USB 调试已开启）
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

> 忘了加 `--dart-define` 也能编译通过，但 App 启动会提示「尚未配置云开发环境」。

也可以把 `app-release.apk` 用微信/数据线传到手机，点击安装（允许“安装未知来源应用”）。

正式签名请参考 `android/app/build.gradle.kts` 中的注释与上一版 README 的 keystore 配置（`android/key.properties`）。

### 常见问题

| 现象 | 处理 |
| --- | --- |
| 启动页提示「尚未配置云开发环境」 | `lib/core/app_config.dart` 没填 `envId` |
| 提示「云开发凭证缺失」/ `MISSING_CREDENTIALS` | 控制台没开**匿名登录**（身份认证 → 登录方式），或在 `app_config.dart` 填 `accessKey` |
| 请求报 `permission denied` / `DATABASE_PERMISSION_DENIED` | 检查第四节的集合权限；确认已开启匿名登录 |
| 提示「集合不存在」 | 控制台没建 room / **roomMember** / mealRecord / foodLibrary 四个集合 |
| 加入房间提示「加入失败」 | 多半是没建 `roomMember` 集合（见第四节第 3 步） |
| **拍了照但记录里没有图片** | 已修复：清单里【不能】声明 `CAMERA` 权限，否则系统相机会拒绝并把结果返回空。见下方说明 |
| 图片上传成功但列表不显示 | 云存储权限没放开（选「所有用户可读」）；链接过期会进页面自动重换 |
| **自己能看到图片，伴侣看不到（反之亦然）** | **云存储权限**：默认是「仅创建者可读写」，每台设备的匿名 openid 不同，所以对方取不到下载链接。改成「**所有用户可读，仅创建者可写**」即可 |
| 伴侣看不到我的记录 | 两台设备是否在同一个房间（设置页看 6 位密钥是否一致） |
| 网络超时 | 环境地域需为「上海」；检查手机网络 |

> **关于「对方看不到我的图片」**（最常见问题）：
> 云开发控制台 → **云存储 → 权限设置** → 选「**所有用户可读，仅创建者可读写**」（如果没有这一项，选「所有用户可读，仅创建者可写」或最宽松的「所有用户可读写」）。
> 原因：图片下载链接是按**请求者身份**签发的，两台手机的匿名 openid 不同，
> 在「仅创建者可读写」下，对方拿不到签名链接，App 就只能显示占位图标。
> App 内长按该占位图标会给出同样提示。

> **关于相机权限**：`android/app/src/main/AndroidManifest.xml` 里**不要**写
> `<uses-permission android:name="android.permission.CAMERA"/>`。
> `image_picker` 用的是系统相机（`ACTION_IMAGE_CAPTURE`），
> 一旦清单声明了 CAMERA 却没有在运行时申请，系统会直接拒绝拍照并返回空，
> 表现就是「点了拍照、保存后没有图片」。本项目已移除该声明，保留 `uses-feature` 即可。

---

## 六-2、内置食材库怎么用 / 怎么扩充

1. 记一餐 → 点右上角「**食材库**」；
2. 搜索食材（如「米饭」「鸡胸肉」），或按分类筛选；
3. 点进条目 → 输入实际克数（默认填常见份量，如「1 碗 ≈ 150g」）；
4. 底部实时显示换算后的热量/蛋白质/碳水/脂肪 → 点「填入」，自动回填到表单。

数据都在 `lib/data/food_database.dart`，格式：

```dart
FoodItem('米饭（熟）', '主食', 116, 2.6, 25.9, 0.3, '1 碗', 150),
//       名称      分类    kcal/100g 蛋白  碳水  脂肪  份量名  份量克数
```

追加一行即可扩充，无需改动其他代码，也不联网。

---

## 七、迁移记录（Firebase → LeanCloud → 微信云开发）

| Firebase | LeanCloud（已弃用：国内版 2026-01-12 起停止注册、2027-01-12 停服） | 现在（微信云开发） |
| --- | --- | --- |
| Firebase Auth 邮箱密码 | 删除登录页，deviceId 身份 | 匿名登录 + deviceId 身份 |
| Firestore `rooms/{code}` | `Room` 表 | `room` 集合 |
| Firestore 子集合 meals | `MealRecord` 表 | `mealRecord` 集合 |
| Firestore foodPresets | `FoodLibrary` 表 | `foodLibrary` 集合 |
| Firebase Storage | `_File` | 云存储 fileID + 临时下载链接 |
| 安全规则（Firestore Rules） | 表权限 + ACL | **安全规则（支持 `get(database.…)` 跨文档校验）** |
| 实时监听 `snapshots()` | 无 | 无（进页面拉取 + 下拉刷新） |

> 为什么换：LeanCloud 官方公告国内版于 2026-01-12 停止新用户注册与新建应用，并将在 2027-01-12 全面停服；
> 旧的 `cloudbase_core/cloudbase_database/cloudbase_storage` Flutter 包停留在 2020 年、不支持 Dart 3，
> 因此本项目使用官方新版 **`cloudbase_flutter`（Dart 3 兼容）**。

---

## 八、依赖清单

```yaml
dependencies:
  cloudbase_flutter: ^1.2.2     # 腾讯云开发新版 Flutter SDK（数据库 / 存储 / 匿名登录）
  device_info_plus: ^13.3.0     # 设备唯一标识
  image_picker: ^1.1.2          # 拍照 / 相册
  path_provider: ^2.1.4         # CSV 导出目录
  shared_preferences: ^2.3.2    # 本地缓存 / deviceId / 昵称
```

---

## 九、验证状态

- `flutter pub get` 已在 Flutter 3.47.7 / Dart 3.13.5 下解析成功；
- 代码结构检查（所有 import 路径、云开发 API 名称与参数）已通过脚本核对；
- `flutter analyze` / Gradle 打包需在你本机执行（当前构建环境沙箱禁止创建子进程），如报错请把完整信息发回。
