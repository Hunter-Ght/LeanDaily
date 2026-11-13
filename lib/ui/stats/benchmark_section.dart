import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../app/routes.dart';
import '../../domain/benchmarks.dart';
import '../../l10n/app_messages.dart';
import '../../l10n/localized_text.dart';
import '../../theme/theme.dart';
import '../course/benchmark_rows.dart';
import '../kit/pressable.dart';

/// 进度页的小测试：最近一次，和与第一次的对比。没有测试记录时整块不显示。
class BenchmarkSection extends StatelessWidget {
  const BenchmarkSection({super.key});

  /// 有没有测试记录（进度页据此决定要不要放这一块）。
  static bool has(AppController app) =>
      benchmarkRows(app.benchmarkEntries).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final p = context.pal, app = context.app;
    final rows = benchmarkRows(app.benchmarkEntries);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('benchmark-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: LText('小测试', style: AppText.title(p))),
            Semantics(
              button: true,
              label: AppMessages.of(context).text('再测一次'),
              child: Pressable(
                onTap: () => openBenchmarkSheet(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Center(
                    widthFactor: 1,
                    child: LText(
                      '再测一次',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        BenchmarkRows(rows: rows, dates: true),
      ],
    );
  }
}
