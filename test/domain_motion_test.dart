import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/domain/guide.dart';
import 'package:leandaily/domain/motion.dart';
import 'package:leandaily/domain/motion_library.dart';

double dist(P a, P b) => (a - b).length;

void main() {
  for (final MapEntry(:key, value: spec) in motionLibrary.entries) {
    group(key, () {
      test('关键帧有序、首尾循环衔接、标注都能找到', () {
        expect(LIB.containsKey(key), isTrue);
        expect(spec.keys.first.t, 0);
        for (var i = 1; i < spec.keys.length; i++) {
          expect(spec.keys[i].t, greaterThan(spec.keys[i - 1].t));
        }
        final a = sampleMotion(spec, 0),
            b = sampleMotion(spec, spec.period - 1e-6);
        for (final j in a.joints.keys) {
          expect(dist(a.joints[j]!, b.joints[j]!), lessThan(.05), reason: j);
        }
        final parts = a.parts.map((e) => e.id).toSet();
        for (final m in spec.marks) {
          expect(parts, contains(m.part));
        }
        for (final g in spec.guides.where((g) => g.j1 != null)) {
          expect(a.joints.keys, containsAll([g.j1, g.j2]));
        }
        for (final prop in spec.props) {
          expect(a.joints.keys, contains(prop.at));
        }
      });
      test('全程骨长不变、没有 NaN、人在取景框内', () {
        for (var t = 0.0; t < spec.period; t += .05) {
          final pose = sampleMotion(spec, t);
          expect(pose.load, inInclusiveRange(0, 1));
          for (final part in pose.parts) {
            for (final q in [part.a, part.b, ...part.poly]) {
              expect(q.x.isFinite && q.y.isFinite, isTrue);
              expect(q.x, inInclusiveRange(spec.bounds[0], spec.bounds[2]));
              expect(q.y, inInclusiveRange(spec.bounds[1], spec.bounds[3]));
            }
            final len = dist(part.a, part.b);
            final want = switch (part.id.substring(0, part.id.length - 1)) {
              'thigh' when spec.view == MotionView.side => Body.thigh,
              'shin' when spec.view == MotionView.side => Body.shin,
              'uarm' => Body.upperArm,
              'farm' => Body.forearm,
              _ => null,
            };
            if (want != null) expect(len, closeTo(want, .05), reason: part.id);
          }
        }
      });
    });
  }

  test('深蹲：脚踩地不动，底部大腿接近水平', () {
    final bottom = sampleMotion(squatMotion, 2.6);
    for (var t = 0.0; t < squatMotion.period; t += .1) {
      expect(
        dist(sampleMotion(squatMotion, t).joints['ankle']!, const P(0, 8)),
        lessThan(.01),
      );
    }
    final hip = bottom.joints['hip']!, knee = bottom.joints['kneeN']!;
    expect((hip.y - knee.y).abs(), lessThan(10));
    expect(bottom.phase, phaseHold);
  });

  test('俯卧撑：全程肩—髋—踝一直线，手撑在原地', () {
    for (var t = 0.0; t < pushupMotion.period; t += .05) {
      final pose = sampleMotion(pushupMotion, t);
      final a = pose.joints['ankle']!,
          h = pose.joints['hip']!,
          s = pose.joints['shoulder']!;
      final u = (s - a).unit;
      final off = ((h - a).x * u.y - (h - a).y * u.x).abs();
      expect(off, lessThan(.5), reason: 't=$t');
      expect(
        dist(pose.joints['wristN']!, const P(128, 4)),
        lessThan(1.5),
        reason: 't=$t',
      );
    }
    final bottom = sampleMotion(pushupMotion, 2.2).joints['shoulder']!;
    expect(bottom.y, lessThan(24));
  });

  test('侧平举：顶端手不高于肩，也不耸肩', () {
    for (var t = 0.0; t < lateralRaiseMotion.period; t += .05) {
      final pose = sampleMotion(lateralRaiseMotion, t);
      for (final s in ['L', 'R']) {
        expect(
          pose.joints['wrist$s']!.y,
          lessThanOrEqualTo(pose.joints['shoulder$s']!.y + 2),
        );
        expect(pose.joints['shoulder$s']!.y, 145);
      }
    }
    final top = sampleMotion(lateralRaiseMotion, 1.9);
    expect(top.joints['wristL']!.y, greaterThan(138));
    expect(top.load, closeTo(1, .01));
  });

  test('减少动态效果时停在发力最大的姿势', () {
    expect(squatMotion.peakTime, 2.8);
    expect(lateralRaiseMotion.peakTime, 1.6);
  });
}
