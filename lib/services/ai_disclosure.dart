import 'dart:convert';

class AiDisclosure {
  final String operatorName,
      providerName,
      privacyUrl,
      providerPrivacyUrl,
      version;
  const AiDisclosure({
    this.operatorName = const String.fromEnvironment(
      'AI_OPERATOR_NAME',
      defaultValue: 'BinGess',
    ),
    this.providerName = const String.fromEnvironment(
      'AI_PROVIDER_NAME',
      defaultValue: '北京春田知韵科技有限公司（扣子）',
    ),
    this.privacyUrl = const String.fromEnvironment(
      'PRIVACY_POLICY_URL',
      defaultValue:
          'https://lucky-geranium-802.notion.site/3f3407f7a7018059b2bdf49578e173d0',
    ),
    this.providerPrivacyUrl = const String.fromEnvironment(
      'AI_PROVIDER_PRIVACY_URL',
      defaultValue: 'https://docs.coze.cn/guides_privacy',
    ),
    this.version = '2',
  });
  bool get ready =>
      operatorName.trim().isNotEmpty &&
      providerName.trim().isNotEmpty &&
      [privacyUrl, providerPrivacyUrl].every((value) {
        final uri = Uri.tryParse(value);
        return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.host != 'example.com';
      });
  String get signature => jsonEncode([
    version,
    operatorName,
    providerName,
    privacyUrl,
    providerPrivacyUrl,
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://vygttv9jhw.coze.site',
    ),
  ]);
}
