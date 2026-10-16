/// Explicit opt-in to the app's progression rules. Null options retain Web parity.
class ProgressOptions {
  const ProgressOptions({
    this.experience,
    this.stage,
    this.age,
    this.venue,
    this.deloadActive = false,
  });

  final String? experience, stage, venue;
  final int? age;
  final bool deloadActive;
  String get level => experience ?? 'some';
  bool get youth => stage == 'youth' || (age != null && age! < 18);
  int get repConfirms => level == 'new' ? 1 : 2;
  int get capConfirms => level == 'trained' ? 3 : 2;

  ProgressOptions forDeload(bool active) => ProgressOptions(
    experience: experience,
    stage: stage,
    age: age,
    venue: venue,
    deloadActive: active,
  );
}

/// Equipment increments, in kg. Explicit user increments take precedence.
num loadStep(Map<String, dynamic> ex, num weight, ProgressOptions options) {
  final name = '${ex['name']} ${ex['gear'] ?? ''}';
  if (name.contains('哑铃')) return weight < 10 ? 1 : 2;
  return weight < 20 ? 1.25 : 2.5;
}

bool adjustableLoad(Map<String, dynamic> ex, ProgressOptions options) {
  final name = '${ex['name']} ${ex['gear'] ?? ''}';
  if (name.contains('哑铃')) {
    return options.venue == 'gym' || options.venue == 'both';
  }
  return ex['machine'] == true ||
      ['杠铃', '器械', '绳索', '龙门架', '史密斯'].any(name.contains);
}
