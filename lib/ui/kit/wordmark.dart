import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';
import '../../l10n/app_messages.dart';

/// The app's non-interactive, accessible wordmark.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 27});

  final double fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: AppMessages.of(context).text('薄肌日课'),
    header: true,
    excludeSemantics: true,
    child: AppMessages.of(context).code == 'en'
        ? Text(
            'LeanDaily',
            style: TextStyle(
              color: context.pal.text,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          )
        : Text.rich(
            TextSpan(
              text: '薄肌',
              style: TextStyle(color: context.pal.text),
              children: [
                TextSpan(
                  text: AppMessages.of(context).code == 'zh_Hant' ? '日課' : '日课',
                  style: TextStyle(color: context.pal.tint),
                ),
              ],
            ),
            style: TextStyle(
              fontFamily: 'Wordmark',
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
              letterSpacing: 1,
              height: 1.2,
            ),
          ),
  );
}
