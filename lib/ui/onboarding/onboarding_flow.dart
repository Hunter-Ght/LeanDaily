import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../domain/body.dart';
import '../../domain/templates.dart';
import '../../theme/theme.dart';
import 'body_fat_step.dart';
import 'diagnosis_step.dart';
import 'onboarding_widgets.dart';
import 'plan_step.dart';
import 'profile_steps.dart';

/// Full-screen assessment, shared by installation, upgrade and reassessment.
/// All edits stay local until the final save. Upgrade never activates a template.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.upgrade});
  final bool upgrade;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with TickerProviderStateMixin {
  late Profile _profile;
  late int _step;
  late final PageController _pages;
  late final AnimationController _travel = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  String? _selected;
  bool _saving = false;
  bool _initialized = false;
  bool _programmatic = false;
  int _dragOrigin = 0;
  int get _firstStep => 0;
  bool get _canContinue => _step != 1 || _valid;
  bool get _valid {
    final method = _profile['bodyFatMethod'];
    final fat = _profile['bodyFatPct'] as num?;
    if (method == 'manual' &&
        fat != null &&
        (!fat.isFinite || fat < 3 || fat > 60)) {
      return false;
    }
    if (method == 'navy') {
      for (final field in [
        'waistCm',
        'neckCm',
        if (_profile['sex'] == 'female') 'hipCm',
      ]) {
        final n = _profile[field] as num?;
        if (n != null && (!n.isFinite || n < 20 || n > 200)) return false;
      }
    }
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _profile = normalizeProfile(context.app.profile)['profile'] as Profile;
    if (context.app.profile == null) _profile['venue'] = null;
    final savedGoal = context.app.targetPrefs['goalBodyFat'];
    if (savedGoal is num) _profile['goalBodyFatPct'] = savedGoal;
    _step = widget.upgrade ? 1 : 0;
    _dragOrigin = _step;
    _pages = PageController(initialPage: _step);
    _travel.addListener(() {
      if (_pages.hasClients) _pages.jumpTo(_travel.value);
    });
  }

  @override
  void dispose() {
    _travel.dispose();
    _exit.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _change(String field, Object? value) {
    setState(() {
      _profile = {..._profile, field: value};
      _selected = null;
    });
  }

  void _go(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (step < _firstStep ||
        step > 3 ||
        _saving ||
        (step > _step && !_canContinue)) {
      return;
    }
    _travel.stop();
    final width = _pages.position.viewportDimension;
    _programmatic = true;
    _dragOrigin = step;
    _travel.value = _pages.offset;
    _travel
        .animateWith(
          SpringSimulation(_onboardingSpring, _pages.offset, step * width, 0),
        )
        .then((_) => _programmatic = false);
  }

  Future<void> _skip() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.upgrade) {
      final app = context.app;
      setState(() => _saving = true);
      try {
        await app.skipOnboarding();
        if (mounted) Navigator.of(context).pop();
      } on Object {
        if (!mounted) return;
        setState(() => _saving = false);
        app.toast.show('保存失败，请重试');
      }
    } else {
      setState(() {
        _profile = {
          ...normalizeProfile(null)['profile'] as Profile,
          'venue': null,
        };
        _selected = null;
      });
      _go(3);
    }
  }

  Future<void> _finish({bool recommended = false}) async {
    if (_saving || !_valid) return;
    final app = context.app;
    final effectiveProfile = {
      ..._profile,
      'venue': _profile['venue'] ?? 'bodyweight',
    };
    final id = recommended || (!widget.upgrade && _selected == null)
        ? recommend(
                effectiveProfile,
                buildTargets(effectiveProfile),
              ).first['templateId']
              as String
        : _selected;
    setState(() => _saving = true);
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      if (MediaQuery.disableAnimationsOf(context)) {
        _exit.value = 1;
      } else {
        await _exit.forward();
      }
      final targets = buildTargets(effectiveProfile);
      await app.completeOnboarding(
        profile: effectiveProfile,
        templateId: id,
        goalBodyFat: targets['goalBodyFat'] as num,
      );
      app.toast.show(
        widget.upgrade ? (id == null ? '目标已更新' : '计划已添加') : '计划已建好',
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on Object {
      if (!mounted) return;
      await _exit.reverse();
      if (!mounted) return;
      setState(() => _saving = false);
      app.toast.show('保存失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PopScope(
      canPop: !_saving && _step == _firstStep,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && !_saving) _go(_step - 1);
      },
      child: ColoredBox(
        color: p.bg,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(_exit),
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 1,
                  end: .96,
                ).animate(CurvedAnimation(parent: _exit, curve: Curves.easeIn)),
                child: AbsorbPointer(
                  absorbing: _saving,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: _step > _firstStep
                                  ? OnboardingButton(
                                      label: '上一步',
                                      onTap: () => _go(_step - 1),
                                    )
                                  : const SizedBox(height: 44),
                            ),
                            Expanded(
                              child: Center(
                                child: AnimatedBuilder(
                                  animation: _pages,
                                  builder: (context, _) {
                                    final page =
                                        _pages.hasClients &&
                                            _pages.position.hasContentDimensions
                                        ? _pages.page ?? _step.toDouble()
                                        : _step.toDouble();
                                    return Semantics(
                                      label: '第 ${_step + 1} 步，共 4 步',
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (var i = 0; i < 4; i++)
                                            Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              width:
                                                  6 +
                                                  16 *
                                                      (1 - (page - i).abs())
                                                          .clamp(0, 1),
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: (page - i).abs() < .5
                                                    ? p.tint
                                                    : p.fill,
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: OnboardingButton(
                                label: '跳过',
                                onTap: _skip,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Listener(
                          onPointerDown: (_) {
                            _travel.stop();
                            _programmatic = false;
                            _dragOrigin = (_pages.page ?? _step.toDouble())
                                .round();
                          },
                          child: PageView(
                            controller: _pages,
                            pageSnapping: false,
                            physics: _OnboardingPhysics(
                              first: _firstStep,
                              limit: () => _canContinue ? 3 : _step,
                              origin: () => _dragOrigin,
                              programmatic: () => _programmatic,
                            ),
                            onPageChanged: (step) =>
                                setState(() => _step = step),
                            children: [
                              IdentityStep(
                                profile: _profile,
                                onChanged: _change,
                              ),
                              BodyFatStep(
                                profile: _profile,
                                onChanged: _change,
                              ),
                              DiagnosisStep(
                                profile: _profile,
                                onGoalChanged: (v) =>
                                    _change('goalBodyFatPct', v),
                              ),
                              PlanStep(
                                onProfileChanged: _change,
                                profile: _profile,
                                upgrade: widget.upgrade,
                                selected:
                                    _selected ??
                                    (widget.upgrade
                                        ? null
                                        : recommend(
                                                {
                                                  ..._profile,
                                                  'venue':
                                                      _profile['venue'] ??
                                                      'bodyweight',
                                                },
                                                buildTargets(_profile),
                                              ).first['templateId']
                                              as String),
                                onSelected: (id) =>
                                    setState(() => _selected = id),
                                onConfirm: _finish,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [p.bg.withValues(alpha: 0), p.bg, p.bg],
                            stops: const [0, .12, 1],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_canContinue)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '请填写有效范围内的数值',
                                  style: AppText.hint(p)
                                      .copyWith(color: p.tint),
                                ),
                              ),
                            OnboardingButton(
                              label: _saving
                                  ? '正在保存…'
                                  : _step == 3
                                  ? (widget.upgrade
                                        ? (_selected == null
                                              ? '保留计划，完成评估'
                                              : '另外添加，完成评估')
                                        : '开始')
                                  : '继续',
                              primary: true,
                              onTap: !_canContinue || _saving
                                  ? null
                                  : _step == 3
                                  ? _finish
                                  : () => _go(_step + 1),
                            ),
                            if (_step == 1) ...[
                              const SizedBox(height: 6),
                              OnboardingButton(
                                label: '用默认设置，直接开始',
                                onTap: _canContinue && !_saving
                                    ? () =>
                                          _finish(recommended: !widget.upgrade)
                                    : null,
                              ),
                            ],
                            if (_step == 3 && !widget.upgrade) ...[
                              const SizedBox(height: 10),
                              OnboardingButton(
                                label: '稍后再选，先用推荐的',
                                textOnly: true,
                                onTap: () => _finish(recommended: true),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// SPEC: response .32, damping ratio 1, mass 1. Shared by drag and button travel.
final _onboardingSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: math.pow(2 * math.pi / .32, 2).toDouble(),
  ratio: 1,
);

class _OnboardingPhysics extends ScrollPhysics {
  const _OnboardingPhysics({
    required this.first,
    required this.limit,
    required this.origin,
    required this.programmatic,
    super.parent,
  });
  final int first;
  final int Function() limit;
  int get last => limit();
  final int Function() origin;
  final bool Function() programmatic;
  @override
  SpringDescription get spring => _onboardingSpring;
  @override
  _OnboardingPhysics applyTo(ScrollPhysics? ancestor) => _OnboardingPhysics(
    first: first,
    limit: limit,
    origin: origin,
    programmatic: programmatic,
    parent: buildParent(ancestor),
  );
  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (programmatic()) return null;
    final width = position.viewportDimension;
    final base = origin().clamp(first, last);
    // Web date paging: project(v, .99), threshold min(width * .32, 150).
    final projected =
        position.pixels - base * width + velocity / 1000 * .99 / (1 - .99);
    final threshold = math.min(width * .32, 150);
    final target =
        (base + (projected.abs() > threshold ? (projected > 0 ? 1 : -1) : 0))
            .clamp(first, last) *
        width;
    final tolerance = toleranceFor(position);
    if ((target - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final min = first * position.viewportDimension;
    final max = last * position.viewportDimension;
    if (value < min && value < position.pixels) {
      return value - math.min(min, position.pixels);
    }
    if (value > max && value > position.pixels) {
      return value - math.max(max, position.pixels);
    }
    return super.applyBoundaryConditions(position, value);
  }
}
