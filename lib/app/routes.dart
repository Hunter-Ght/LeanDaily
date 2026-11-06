import 'package:flutter/widgets.dart';

import '../ui/me/about_pages.dart';
import '../ui/kit/sheet.dart';
import '../ui/sheets/alternatives_sheet.dart';
import '../ui/sheets/android_settings_sheet.dart';
import '../ui/sheets/edit_set_sheet.dart';
import '../ui/sheets/goals_sheet.dart';
import '../ui/sheets/guide_sheet.dart';
import '../ui/sheets/meal_sheet.dart';
import '../ui/sheets/my_gym_sheet.dart';
import '../ui/sheets/muscle_exercises_sheet.dart';
import '../ui/sheets/plan_editor_sheet.dart';
import '../ui/onboarding/onboarding_flow.dart';
import '../ui/sheets/preview_sheet.dart';
import '../ui/sheets/profile_sheet.dart';
import '../ui/sheets/quick_food_sheet.dart';
import '../ui/sheets/template_browser_sheet.dart';
import '../ui/sheets/train_sheet.dart';
import 'app_controller.dart';

export '../ui/sheets/body_log_sheet.dart' show openBodyLog;
export '../ui/training/training_mode.dart' show openTrainingMode;

/// 所有“打开某个页面 / 弹层”的入口都在这里，页面之间只通过它跳转。

Future<void> openTrainSheet(
  BuildContext context, {
  Map<String, dynamic>? preset,
}) => showAppSheet<void>(context, (_) => TrainSheet(preset: preset));
Future<void> openMealSheet(
  BuildContext context, {
  Map<String, dynamic>? preset,
}) => showAppSheet<void>(context, (_) => MealSheet(preset: preset));
Future<void> openEditSet(BuildContext context, Map<String, dynamic> set) =>
    showAppSheet<void>(context, (_) => EditSetSheet(set: set));
Future<void> openGoals(BuildContext context) =>
    showAppSheet<void>(context, (_) => const GoalsSheet());
Future<void> openAndroidSettings(BuildContext context) =>
    showAppSheet<void>(context, (_) => const AndroidSettingsSheet());
Future<void> openPlanEditor(BuildContext context) =>
    showAppSheet<void>(context, (_) => const PlanEditorSheet());

/// 动作示范。`iso` 是从哪一天的计划点进来的（决定显示哪个版本的动作）。
Future<void> openGuide(BuildContext context, String exercise, {String? iso}) =>
    showAppSheet<void>(
      context,
      (_) => GuideSheet(exercise: exercise, iso: iso),
    );

/// 器械被占时换一个练同一块肌肉的动作；选了就返回动作名。
Future<String?> openAlternatives(BuildContext context, String exercise) =>
    showAppSheet<String>(context, (_) => AlternativesSheet(exercise: exercise));

/// 我的健身房：勾选常去的健身房有哪些器械。
Future<void> openMyGym(BuildContext context) =>
    showAppSheet<void>(context, (_) => const MyGymSheet());
Future<void> openDayPreview(BuildContext context, String iso) =>
    showAppSheet<void>(context, (_) => PreviewSheet(iso: iso));
Future<void> openMuscleExercises(BuildContext context, String muscleId) =>
    showAppSheet<void>(
      context,
      (_) => MuscleExercisesSheet(muscleId: muscleId),
    );

Future<void> openProfile(BuildContext context) =>
    showAppSheet<void>(context, (_) => const ProfileSheet());
Future<void> openTemplateBrowser(BuildContext context) =>
    showAppSheet<void>(context, (_) => const TemplateBrowserSheet());
Future<void> openQuickFood(
  BuildContext context, {
  String? date,
  String? meal,
}) =>
    showAppSheet<void>(context, (_) => QuickFoodSheet(date: date, meal: meal));

/// 评估引导。老用户（[upgrade]）从今日页的提示卡进入，不会替换现有计划。
Future<void> openOnboarding(BuildContext context, {bool upgrade = false}) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => OnboardingFlow(upgrade: upgrade),
        transitionDuration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 280,
        ),
        reverseTransitionDuration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
        ),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );

Future<void> _openAboutPage(BuildContext context, Widget page) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => page,
        transitionDuration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 280,
        ),
        reverseTransitionDuration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
Future<void> openPrivacy(BuildContext context) =>
    _openAboutPage(context, const PrivacyPage());
Future<void> openCredits(BuildContext context) =>
    _openAboutPage(context, const CreditsPage());
Future<void> openOpenSourceLicenses(BuildContext context) =>
    _openAboutPage(context, const OpenSourceLicensesPage());
Future<void> openUpdateDetails(BuildContext context) async {
  final app = context.app;
  final info = app.updateInfo;
  if (info == null) return;
  final route = showAppSheet<void>(
    context,
    (_) => UpdateDetailsSheet(info: info),
  );
  await app.markUpdateSeen();
  await route;
}
