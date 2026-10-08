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
      scrollable: true,
      title: const Text('AI 数据分享许可'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            info.ready
                ? '接收方：${info.operatorName}（分析服务运营方）及 ${info.providerName}（AI 服务提供方）。'
                : 'AI 服务接收方及隐私政策尚未配置完整，暂不能提交分析。',
          ),
          const SizedBox(height: 16),
          const Text(
            '发送内容：你提交的问题与补充信息；追问、重试或根据行动反馈调整时，还会发送相关历史问答，以及你提交的行动与反馈。',
          ),
          const SizedBox(height: 12),
          const Text('用途：检索参考资料、理解上下文并生成回答。语音识别后的文字经你提交才会发送，本客户端不向分析接口发送录音。'),
          const SizedBox(height: 12),
          const Text(
            '请勿提交身份证号、银行卡号、密码等敏感信息。保存、删除及服务商处理规则详见下方政策。拒绝不影响查看本机记录；可在“回答与服务设置”撤回许可。',
          ),
          if (info.ready) ...[
            TextButton(
              onPressed: () => _openPolicy(dialogContext, info.privacyUrl),
              child: const Text('查看隐私政策'),
            ),
            TextButton(
              onPressed: () =>
                  _openPolicy(dialogContext, info.providerPrivacyUrl),
              child: const Text('查看 AI 服务商隐私政策'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('暂不使用'),
        ),
        FilledButton(
          onPressed: info.ready
              ? () => Navigator.pop(dialogContext, true)
              : null,
          child: const Text('同意并继续'),
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

Future<void> _openPolicy(BuildContext context, String url) async {
  try {
    if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {}
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('政策链接暂时无法打开，请稍后再试。')));
  }
}
