// 应用配置（微信云开发 / 腾讯 CloudBase）
//
// 环境 ID 通过编译参数注入，不写死在仓库里：
//
//   flutter build apk --release --dart-define=TCB_ENV_ID=你的环境ID
//
// 仓库根目录的 build-release.bat 已经把这个参数封装好了，
// 把环境 ID 填进该文件（已被 .gitignore 忽略）后双击即可编译。
//
// 为什么不写死：环境 ID 虽不是密钥，但公开仓库里暴露后，
// 别人可以向你同一个云开发环境发请求（受数据库权限限制）。
//
// 更多配置步骤见 README 第四节。
class AppConfig {
  AppConfig._();

  /// 云开发环境 ID（形如 couplemeallog-d7g4uijac13bbf0a7）
  ///
  /// 编译时通过 --dart-define=TCB_ENV_ID=xxx 注入；
  /// 未注入时保留占位符，App 启动会提示「尚未配置云开发环境」。
  static const String envId = String.fromEnvironment(
    'TCB_ENV_ID',
    defaultValue: '请替换为你的云开发环境ID',
  );

  /// 环境所在地域：ap-shanghai（默认）/ ap-guangzhou / ap-singapore
  static const String region = String.fromEnvironment(
    'TCB_REGION',
    defaultValue: 'ap-shanghai',
  );

  /// 可选：Publishable Key（accessKey）
  ///
  /// 编译参数：--dart-define=TCB_ACCESS_KEY=xxx
  /// 匿名登录不可用时作为兜底凭证；留空则只依赖匿名登录。
  static const String accessKey = String.fromEnvironment(
    'TCB_ACCESS_KEY',
    defaultValue: '',
  );

  /// 集合（数据表）名称
  static const String collectionRoom = 'room'; // 房间
  static const String collectionMember = 'roomMember'; // 房间成员（每设备一条）
  static const String collectionMeal = 'mealRecord'; // 餐食记录
  static const String collectionFood = 'foodLibrary'; // 常用食物库

  /// 图片缩略图（Base64 存数据库，绕开云存储付费权限）
  static const String collectionImage = 'mealImage';

  /// 云存储目录前缀（图片）
  static const String storageDir = 'meal-images';

  /// 是否启用调试日志
  static const bool debug = false;
}
