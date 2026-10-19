import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';

Future<bool> ensureAiConsent(BuildContext context, AppState state) async {
  if (state.hasAiConsent) return true;
  final info = state.disclosure;
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('AI 数据分享许可'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.ready
                ? '接收方：${info.operatorName}（应用运营方）及 ${info.providerName}（AI 服务提供方）。'
                : '服务信息尚未配置完整，当前不能提交分析。',
          ),
          const SizedBox(height: 12),
          const Text(
            '为检索资料和生成回答，我们会发送你提交的问题。追问、重试或根据行动反馈调整时，还会发送相关历史问答及你提交的行动、反馈。语音录音不会发送至分析接口。',
          ),
          const SizedBox(height: 12),
          const Text(
            '请勿提交密码、身份证号等敏感信息。拒绝不影响查看本机记录；可在“回答与服务设置”撤回许可。数据保存和删除规则请查看政策。',
          ),
          if (info.ready) ...[
            TextButton(
              onPressed: () =>
                  openConsentPolicy(dialogContext, info.privacyUrl),
              child: const Text('隐私政策'),
            ),
            TextButton(
              onPressed: () =>
                  openConsentPolicy(dialogContext, info.providerPrivacyUrl),
              child: const Text('AI 服务商隐私政策'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('不同意'),
        ),
        FilledButton(
          key: const Key('accept-ai-sharing'),
          onPressed: info.ready
              ? () => Navigator.pop(dialogContext, true)
              : null,
          child: const Text('同意并继续分析'),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return false;
  try {
    await state.acceptAiConsent();
    return context.mounted;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
    return false;
  }
}

Future<void> openConsentPolicy(BuildContext context, String url) async {
  try {
    if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {}
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('政策暂时无法打开，请稍后再试。')));
  }
}
