import 'dart:convert';

import '../core/native.dart';
import '../domain/body.dart';

/// Owns only the two V2 profile keys. Loading never marks onboarding complete.
/// Each operation is serialized and commits its memory snapshot after put.
/// Profile and onboarding are deliberately separate writes: Native has no
/// multi-document transaction, so no API pretends to save both atomically.
class ProfileStore {
  ProfileStore(this.native);

  final Native native;
  static const profileKey = 'fw-profile-v1';
  static const onboardedKey = 'fw-onboarded-v1';
  Profile? _profile;
  bool _onboarded = false;
  Future<void> _lane = Future<void>.value();

  /// Null means no stored profile, distinct from an explicitly saved default.
  Profile? get profile => _profile == null ? null : _copy(_profile!);
  Profile? get value => profile;
  bool get onboarded => _onboarded;

  static Profile _copy(Profile p) => {
    ...p,
    'limits': List<String>.of(p['limits'] as List<String>),
  };

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _lane.then((_) => action());
    // A failed write is reported to its caller, but doesn't poison the lane.
    _lane = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Profile?> load() => _serial(() async {
    final docs = await native.all();
    final raw = docs[profileKey];
    Object? decoded;
    try {
      decoded = raw == null ? null : jsonDecode(raw);
    } on FormatException {
      decoded = null;
    }
    final next = decoded is Map
        ? normalizeProfile(decoded)['profile'] as Profile
        : null;
    _profile = next;
    _onboarded = docs[onboardedKey] == '1';
    return profile;
  });

  Future<Profile> save(Profile raw) {
    // Snapshot before queuing so callers cannot mutate a pending write.
    final next = normalizeProfile(raw)['profile'] as Profile;
    return _serial(() async {
      await native.put(profileKey, jsonEncode(next));
      _profile = next;
      return _copy(next);
    });
  }

  /// Completing and skipping onboarding both persist the same literal "1".
  Future<void> markOnboarded() => _serial(() async {
    await native.put(onboardedKey, '1');
    _onboarded = true;
  });
}
