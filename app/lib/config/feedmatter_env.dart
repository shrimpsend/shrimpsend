import 'feedmatter_env.secrets.dart';

/// FeedMatter 客户端配置。
/// apiKey / apiSecret / baseUrl 默认值来自 gitignored [feedmatter_env.secrets.dart]；
/// 亦可用 `--dart-define=FM_CN_*`、`FM_INTL_*` 覆盖。
class FeedmatterEnv {
  FeedmatterEnv._();

  static const cnApiKey = String.fromEnvironment(
    'FM_CN_API_KEY',
    defaultValue: FeedmatterSecrets.cnApiKey,
  );

  static const cnApiSecret = String.fromEnvironment(
    'FM_CN_API_SECRET',
    defaultValue: FeedmatterSecrets.cnApiSecret,
  );

  static const cnBaseUrl = String.fromEnvironment(
    'FM_CN_BASE_URL',
    defaultValue: FeedmatterSecrets.cnBaseUrl,
  );

  static const intlApiKey = String.fromEnvironment(
    'FM_INTL_API_KEY',
    defaultValue: FeedmatterSecrets.intlApiKey,
  );

  static const intlApiSecret = String.fromEnvironment(
    'FM_INTL_API_SECRET',
    defaultValue: FeedmatterSecrets.intlApiSecret,
  );

  static const intlBaseUrl = String.fromEnvironment(
    'FM_INTL_BASE_URL',
    defaultValue: FeedmatterSecrets.intlBaseUrl,
  );
}
