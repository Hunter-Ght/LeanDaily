/// Calendar arithmetic uses UTC dates to avoid DST changing day distances.
const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
const monthRows = 6;
typedef Marks = ({bool train, bool meal}) Function(String iso);
DateTime _date(String iso) => DateTime.parse('${iso}T00:00:00Z');
String _iso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String shiftDate(String iso, int days) =>
    _iso(_date(iso).add(Duration(days: days)));
int daysApart(String a, String b) => _date(b).difference(_date(a)).inDays;
String mondayOf(String iso) => shiftDate(iso, 1 - _date(iso).weekday);
String monthStart(String iso) => '${iso.substring(0, 8)}01';
String monthTitle(String iso) => '${_date(iso).year}年${_date(iso).month}月';
int monthsApart(String a, String b) =>
    (_date(b).year - _date(a).year) * 12 + _date(b).month - _date(a).month;
String shiftMonth(String iso, int n) =>
    _iso(DateTime.utc(_date(iso).year, _date(iso).month + n));

class DayCell {
  const DayCell({
    required this.iso,
    required this.num,
    required this.future,
    required this.today,
    required this.out,
    required this.train,
    required this.meal,
  });
  final String iso;
  final int num;
  final bool future, today, out, train, meal;
  Map<String, dynamic> toJson() => {
    'iso': iso,
    'num': num,
    'future': future,
    'today': today,
    'out': out,
    'train': train,
    'meal': meal,
  };
}

DayCell _cell(String iso, String today, Marks? marks, [String? month]) {
  final mk = marks?.call(iso);
  return DayCell(
    iso: iso,
    num: _date(iso).day,
    future: today.isNotEmpty && iso.compareTo(today) > 0,
    today: iso == today,
    out: month != null && iso.substring(0, 7) != month.substring(0, 7),
    train: mk?.train ?? false,
    meal: mk?.meal ?? false,
  );
}

List<DayCell> weekDays(String iso, String today, [Marks? marks]) =>
    List.generate(7, (i) => _cell(shiftDate(mondayOf(iso), i), today, marks));

class MonthGrid {
  const MonthGrid({
    required this.month,
    required this.title,
    required this.rows,
  });
  final String month, title;
  final List<List<DayCell>> rows;
  Map<String, dynamic> toJson() => {
    'month': month,
    'title': title,
    'rows': rows.map((r) => r.map((c) => c.toJson()).toList()).toList(),
  };
}

MonthGrid monthGrid(String month, String today, [Marks? marks]) {
  final first = monthStart(month), start = mondayOf(monthStart(month));
  return MonthGrid(
    month: first,
    title: monthTitle(first),
    rows: List.generate(
      monthRows,
      (r) => List.generate(
        7,
        (c) => _cell(shiftDate(start, r * 7 + c), today, marks, first),
      ),
    ),
  );
}

int rowOf(MonthGrid g, String iso) => g.rows
    .indexWhere((r) => r.any((c) => c.iso == iso))
    .clamp(0, monthRows - 1);
String? stepWeek(String iso, int dir, String today) {
  final next = shiftDate(iso, dir * 7);
  if (today.isEmpty || next.compareTo(today) <= 0) return next;
  return mondayOf(next).compareTo(today) <= 0 ? today : null;
}

String? stepMonth(String iso, int dir, String today) {
  final target = shiftMonth(iso, dir), t = _date(shiftMonth(iso, dir));
  final last = DateTime.utc(t.year, t.month + 1, 0).day;
  final next = _iso(
    DateTime.utc(t.year, t.month, _date(iso).day.clamp(1, last)),
  );
  if (today.isEmpty || next.compareTo(today) <= 0) return next;
  return target.compareTo(today) <= 0 ? today : null;
}
