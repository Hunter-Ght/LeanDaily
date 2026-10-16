import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';

/// The app's non-interactive, accessible wordmark.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 27});

  final double fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '薄肌日课',
    header: true,
    excludeSemantics: true,
    child: Text.rich(
      TextSpan(
        text: '薄肌',
        style: TextStyle(color: context.pal.text),
        children: [
          TextSpan(
            text: '日课',
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
