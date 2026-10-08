import 'dart:convert';

class AiDisclosure {
  final String operatorName,
      providerName,
      privacyUrl,
      providerPrivacyUrl,
      version;
  const AiDisclosure({
    this.operatorName = const String.fromEnvironment('AI_OPERATOR_NAME'),
    this.providerName = const String.fromEnvironment('AI_PROVIDER_NAME'),
    this.privacyUrl = const String.fromEnvironment('PRIVACY_POLICY_URL'),
    this.providerPrivacyUrl = const String.fromEnvironment(
      'AI_PROVIDER_PRIVACY_URL',
    ),
    this.version = '1',
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
