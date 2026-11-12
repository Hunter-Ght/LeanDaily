import 'package:flutter/widgets.dart';

import '../domain/units.dart';
import '../ui/kit/units_scope.dart';
import 'app_messages.dart';

/// Explicit display boundary for legacy canonical content and messages. Input
/// controllers and stored values remain untouched. Use Text for user prose.
class LText extends StatelessWidget {
  const LText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.localize = true,
  }) : span = null;
  const LText.rich(
    InlineSpan this.span, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.localize = true,
  }) : data = null;
  final bool localize;
  final String? data;
  final InlineSpan? span;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  static InlineSpan translateSpan(
    InlineSpan span,
    AppMessages messages, [
    Units units = Units.metric,
  ]) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: span.text == null
          ? null
          : units.localizeText(messages.text(span.text!)),
      children: span.children
          ?.map((s) => translateSpan(s, messages, units))
          .toList(),
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel == null
          ? null
          : messages.text(span.semanticsLabel!),
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = AppMessages.of(context);
    final units = context.units;
    final label = semanticsLabel == null
        ? null
        : messages.text(semanticsLabel!);
    if (span != null) {
      return Text.rich(
        localize ? translateSpan(span!, messages, units) : span!,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: label,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return Text(
      localize ? units.localizeText(messages.text(data!)) : data!,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: label,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
