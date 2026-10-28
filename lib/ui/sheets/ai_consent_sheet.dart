import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../config/ai_provider.dart';
import '../../data/ai_consent.dart';
import '../../l10n/app_messages.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/form.dart';
import '../kit/grouped.dart';
import '../kit/sheet.dart';

/// Disclosure can be scrolled while cancel/agree remain accessible on small
/// screens and with larger text. Opening or reading this sheet grants nothing.
class AiConsentSheet extends StatelessWidget {
  const AiConsentSheet({super.key, required this.settings});
  final Map<String, dynamic> settings;

  @override
  Widget build(BuildContext context) => AppSheet(
    title: 'AI 照片授权',
    cancelLabel: '✕',
    padding: const EdgeInsets.all(16),
    footer: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormButton(
            '同意并识别',
            filled: true,
            onTap: () => SheetController.of(context).close(true),
          ),
          const SizedBox(height: 8),
          FormButton(
            '取消',
            plain: true,
            onTap: () => SheetController.of(context).close(false),
          ),
        ],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LText(
          '发送照片给 AI 服务？',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.pal.text,
          ),
        ),
        const SizedBox(height: 16),
        LText(
          '接收服务：${aiProviderName(settings)}\n接收地址：${AiConsent.destination(settings)}',
          style: TextStyle(
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: context.pal.text,
          ),
        ),
        const SizedBox(height: 12),
        LText(
          '发送内容：本次选择的吃前和吃后照片（如有）、餐次、补充说明（最多 300 字）和营养估算指令。API Key 用于认证；服务商还会收到 IP 地址。照片可能包含人物或位置等个人信息，请先裁剪或移除。',
          style: TextStyle(fontSize: 15, height: 1.4, color: context.pal.text),
        ),
        const SizedBox(height: 12),
        const LText('不会发送身体资料、测量数据或训练记录。'),
        const SizedBox(height: 12),
        const LText('每次上传前都会询问。取消不会发送；手动记餐无需 AI。授权相机或相册不代表同意发送给 AI。'),
        const SizedBox(height: 16),
        LText(
          AppMessages.of(context).text(aiProviderDisclosure(settings)),
          style: TextStyle(fontSize: 15, height: 1.4, color: context.pal.text),
        ),
        const SizedBox(height: 16),
        if (aiDataPolicyUrl(settings) != null)
          GroupCard(
            children: [
              GroupRow(
                label: aiDataPolicyLabel(settings),
                onTap: () async {
                  final app = context.app;
                  try {
                    await app.native.openUrl(aiDataPolicyUrl(settings)!);
                  } on Object catch (e) {
                    app.toast.show(AppController.message(e));
                  }
                },
              ),
            ],
          ),
      ],
    ),
  );
}
