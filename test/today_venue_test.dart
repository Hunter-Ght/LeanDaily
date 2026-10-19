import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leandaily/ui/kit/app_icon.dart';
import 'package:leandaily/ui/today/today_model.dart';
import 'package:leandaily/ui/today/venue_controls.dart';

import 'support/harness.dart';
import 'today_four_test.dart' show fourProfile;
import 'today_page_test.dart' show settle, todayTest;

Future<void> pick(WidgetTester t, String label) async {
  await t.tap(find.byType(VenueChip));
  await settle(t);
  expect(find.text('今天在哪练'), findsOneWidget);
  await t.tap(find.text(label).last);
  await settle(t);
}

void main() {
  setUpAll(Harness.setUpAll);
  for (final venue in [null, 'bodyweight', 'dumbbell', 'gym', 'both']) {
    todayTest('venue visibility $venue', (t) async {
      final h = await Harness.pump(
        t,
        seed: (n) {
          if (venue != null) {
            n.docs['fw-profile-v1'] = jsonEncode({
              ...fourProfile(),
              'venue': venue,
            });
          }
        },
      );
      expect(TodayModel(h.controller).workout['hasGym'], isTrue);
      // 场地选了什么都保留切换：进入主界面后随时可以改。
      expect(find.byType(VenueChip), findsOneWidget);
    });
  }
  todayTest('wide layout uses same venue menu without premature weekly hint', (
    t,
  ) async {
    final h = await Harness.pump(t, empty: true, size: const Size(1000, 852));
    await pick(t, '健身房');
    expect(h.controller.dayStates[h.controller.today]['venue'], 'gym');
    expect(find.text('以后每周五都在健身房练？'), findsNothing);
    await pick(t, '健身房');
    expect(find.text('以后每周五都在健身房练？'), findsNothing);
    await h.controller.setProfile({...fourProfile(), 'venue': 'dumbbell'});
    await settle(t);
    expect(find.byType(VenueChip), findsOneWidget);
  });
  todayTest('rest and home-only workout do not expose venue', (t) async {
    final h = await Harness.pump(t, empty: true);
    await h.controller.patchDayState(h.controller.today, {'override': 'rest'});
    await settle(t);
    expect(find.byType(VenueChip), findsNothing);
    final p = jsonDecode(jsonEncode(h.controller.plan)) as Map<String, dynamic>;
    for (final w in (p['workouts'] as Map).values) {
      (w as Map).remove('gym');
    }
    await h.controller.updatePlan(p);
    await h.controller.patchDayState(h.controller.today, {'override': null});
    await settle(t);
    expect(find.byType(VenueChip), findsNothing);
  });
  todayTest('menu selection clears swaps and started and persists venue', (
    t,
  ) async {
    final h = await Harness.pump(t, empty: true);
    await h.controller.patchDayState(h.controller.today, {
      'started': true,
      'swaps': {'old': 'new'},
    });
    await settle(t);
    await pick(t, '健身房');
    expect(
      h.controller.dayStates[h.controller.today],
      containsPair('venue', 'gym'),
    );
    expect(h.controller.dayStates[h.controller.today]['started'], isFalse);
    expect(h.controller.dayStates[h.controller.today]['swaps'], isEmpty);
    expect(
      jsonDecode(h.native.docs['fw-plan-day-v1']!)[h.controller.today]['venue'],
      'gym',
    );
  });
  todayTest('existing training requires confirmation and retains sets', (
    t,
  ) async {
    final h = await Harness.pump(t);
    final sets = jsonEncode(h.controller.repo.day(h.controller.today)['sets']);
    await pick(t, '健身房');
    expect(find.text('改成健身房版？'), findsOneWidget);
    expect(h.controller.dayStates[h.controller.today]?['venue'], isNot('gym'));
    await t.tap(find.text('取消'));
    await settle(t);
    expect(h.controller.dayStates[h.controller.today]?['venue'], isNot('gym'));
    await pick(t, '健身房');
    await t.tap(find.text('切换'));
    await settle(t);
    expect(h.controller.dayStates[h.controller.today]['venue'], 'gym');
    expect(jsonEncode(h.controller.repo.day(h.controller.today)['sets']), sets);
  });
  for (final home in [false, true]) {
    todayTest('remember weekly venue persists and home clears default $home', (
      t,
    ) async {
      final h = await Harness.pump(t, empty: true);
      if (home) await h.controller.setWeekdayVenue(5, 'gym');
      await h.controller.patchDayState('2026-10-09', {
        'venue': home ? 'home' : 'gym',
      });
      await settle(t);
      await pick(t, home ? '居家' : '健身房');
      expect(find.text('以后每周五都在${home ? '居家' : '健身房'}练？'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('好'));
      await settle(t);
      expect((h.controller.plan['venues'] as Map)['5'], home ? isNull : 'gym');
      expect(
        jsonDecode(h.native.docs['fw-plan-v1']!)['venues']['5'],
        home ? isNull : 'gym',
      );
      expect(
        h.controller.shouldAskVenueDefault(
          h.controller.today,
          home ? 'home' : 'gym',
        ),
        isFalse,
      );
    });
  }
  todayTest('declining weekly hint persists and does not ask again', (t) async {
    final h = await Harness.pump(t, empty: true);
    await h.controller.patchDayState('2026-10-09', {'venue': 'gym'});
    await settle(t);
    await pick(t, '健身房');
    await t.tap(find.bySemanticsLabel('不用'));
    await settle(t);
    expect(h.controller.venueHintDeclined, contains(5));
    final docs = await h.native.all();
    expect(docs.values.any((s) => s.contains('"venueDeclined":[5]')), isTrue);
    await pick(t, '居家');
    await pick(t, '健身房');
    expect(find.text('以后每周五都在健身房练？'), findsNothing);
  });
  for (final dark in [false, true]) {
    todayTest('venue screenshots $dark', (t) async {
      final h = await Harness.pump(t, dark: dark, size: const Size(393, 852));
      final mode = dark ? 'dark' : 'light';
      expect(t.getSize(find.byType(VenueChip)).width, lessThan(110));
      expect(
        t.getSize(find.byType(VenueChip)).height,
        greaterThanOrEqualTo(44),
      );
      await h.shot(t, 'r-venue-today-chip-$mode');
      await t.tap(find.byType(VenueChip));
      await settle(t);
      final checked = t
          .widgetList<AppIcon>(find.byType(AppIcon))
          .where((i) => i.name == 'check');
      expect(checked, isNotEmpty);
      await h.shot(t, 'r-venue-menu-$mode');
      await t.tap(find.text('取消'));
      await settle(t);
      await h.controller.patchDayState('2026-10-09', {'venue': 'gym'});
      await pick(t, '健身房');
      await t.tap(find.text('切换'));
      await settle(t);
      await h.shot(t, 'r-venue-ask-$mode');
      await t.tap(find.bySemanticsLabel('不用'));
      await settle(t);
      await h.controller.setProfile({...fourProfile(), 'venue': 'gym'});
      await settle(t);
      expect(find.byType(VenueChip), findsOneWidget);
    });
  }
}
