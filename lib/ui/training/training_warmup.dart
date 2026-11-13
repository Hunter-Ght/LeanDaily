import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:leandaily/l10n/app_messages.dart';

import '../../domain/warmup.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../kit/exercise_demo.dart';
import '../kit/exercise_thumb.dart';
import '../kit/pressable.dart';

/// 热身「跟着做」：逐项倒计时，倒计时走完或点「下一项」进入下一项，最后一项结束后调用 [onDone]。
/// 自己持有一个每秒走一次的计时器，页面离开或退出时必须 [dispose]。
class WarmupFollow extends ChangeNotifier {
  WarmupFollow({
    required this.count,
    required this.onDone,
    this.onStep,
    this.seconds = warmupSeconds,
  }) : remaining = seconds {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }
  final int count, seconds;
  final VoidCallback onDone;

  /// 进入下一项时（不含最后完成）。
  final VoidCallback? onStep;
  int index = 0;
  int remaining;
  Timer? _timer;
  bool _disposed = false;

  bool get isLast => index >= count - 1;

  void _tick() {
    if (_disposed) return;
    remaining--;
    if (remaining <= 0) {
      next();
    } else {
      notifyListeners();
    }
  }

  void next() {
    if (_disposed) return;
    if (isLast) {
      _timer?.cancel();
      onDone();
      return;
    }
    index++;
    remaining = seconds;
    onStep?.call();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// 热身列表里的一行：序号 + 缩略图（有示范时，可点开看要点）+ 名字 + 一行做法。
class WarmupRow extends StatelessWidget {
  const WarmupRow({
    super.key,
    required this.index,
    required this.name,
    required this.onOpen,
  });
  final int index;
  final String name;

  /// 有示范时点整行打开动作要点。
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final demo = warmupHasDemo(name);
    final how = warmupHowTo(name);
    final row = Container(
      constraints: const BoxConstraints(minHeight: 64),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${index + 1}',
              style: AppText.num(p, 24, color: p.secondary),
            ),
          ),
          if (demo) ...[
            ExerciseThumb(ex: {'name': name}, size: 52, radius: 12),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(
                  name,
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
                if (how != null) ...[
                  const SizedBox(height: 2),
                  LText(
                    how,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: p.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (demo)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '›',
                style: TextStyle(fontSize: 22, color: p.secondary),
              ),
            ),
        ],
      ),
    );
    if (!demo) return row;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text('$name · 动作要点'),
      excludeSemantics: true,
      child: Pressable(
        scale: MediaQuery.disableAnimationsOf(context) ? 1 : .98,
        onTap: onOpen,
        child: row,
      ),
    );
  }
}

/// 中性的软按钮（不是橙色主按钮），用在热身列表里的「跟着做」。
class WarmupSoftButton extends StatelessWidget {
  const WarmupSoftButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Semantics(
      button: true,
      label: AppMessages.of(context).text(label),
      excludeSemantics: true,
      child: Pressable(
        scale: MediaQuery.disableAnimationsOf(context) ? 1 : .97,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.fill2,
            borderRadius: BorderRadius.circular(18),
          ),
          child: LText(
            label,
            style: TextStyle(
              color: p.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// 跟做模式的主体：第几项、名字、大倒计时、示范或做法、下一项预告。
class WarmupFollowView extends StatelessWidget {
  const WarmupFollowView({
    super.key,
    required this.follow,
    required this.items,
    required this.onOpen,
  });
  final WarmupFollow follow;
  final List<String> items;
  final void Function(String name) onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final i = follow.index.clamp(0, items.length - 1);
    final name = items[i];
    final how = warmupHowTo(name);
    final demo = warmupHasDemo(name);
    final next = i + 1 < items.length ? items[i + 1] : null;
    final progress = follow.remaining / follow.seconds;
    // 矮屏把示范压矮一些，保证倒计时和按钮都在一屏内。
    final demoHeight = (MediaQuery.sizeOf(context).height - 540)
        .clamp(120.0, 240.0)
        .toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          LText(
            '第 ${i + 1}/${items.length} 项',
            style: TextStyle(fontSize: 13, color: p.secondary),
          ),
          const SizedBox(height: 4),
          LText(name, style: AppText.display(p, size: 30)),
          const SizedBox(height: 14),
          Semantics(
            label: AppMessages.of(context)
                .text('剩余 ${_clock(follow.remaining)}'),
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _clock(follow.remaining),
                key: const ValueKey('warm-follow-clock'),
                style: AppText.num(p, 84, color: p.tint),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LayoutBuilder(
                builder: (_, box) => Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: p.fill2)),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: box.maxWidth * math.max(0, progress),
                      child: ColoredBox(color: p.tint),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (demo)
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                height: demoHeight,
                child: ColoredBox(
                  color: p.studio,
                  child: LayoutBuilder(
                    builder: (_, box) {
                      final side = math.max(demoHeight, box.maxWidth);
                      return OverflowBox(
                        maxWidth: side,
                        maxHeight: side,
                        child: ExerciseDemo(ex: {'name': name}, size: side),
                      );
                    },
                  ),
                ),
              ),
            ),
          if (how != null) ...[
            SizedBox(height: demo ? 12 : 4),
            LText(
              how,
              style: TextStyle(
                fontSize: demo ? 15 : 20,
                height: 1.35,
                fontWeight: demo ? FontWeight.w400 : FontWeight.w600,
                color: demo ? p.secondary : p.text,
              ),
            ),
          ],
          if (demo)
            Align(
              alignment: Alignment.centerLeft,
              child: Pressable(
                scale: .97,
                onTap: () => onOpen(name),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.centerLeft,
                  child: LText(
                    '动作要点 ›',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: p.tint,
                    ),
                  ),
                ),
              ),
            ),
          if (next != null) ...[
            const SizedBox(height: 8),
            LText('接下来：$next', style: AppText.hint(p)),
          ],
        ],
      ),
    );
  }
}
