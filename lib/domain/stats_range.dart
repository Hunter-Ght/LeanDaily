import 'calendar.dart' as calendar;

/// 进度页的时间范围：近 4 周 / 近 12 周 / 全部记录。
enum StatsRange { weeks4, weeks12, all }

/// 范围换算后的具体窗口：[from, to] 含两端，[days] 为天数，[weeks] 至少 4。
class RangeWindow {
  const RangeWindow(this.from, this.to, this.days);
  final String from, to;
  final int days;
  int get weeks => (days / 7).ceil();
  bool contains(String iso) =>
      iso.compareTo(from) >= 0 && iso.compareTo(to) <= 0;
}

/// [firstDate] 为最早一次训练日期（仅「全部」用到）；窗口至少 28 天。
RangeWindow rangeWindow(StatsRange range, String today, {String? firstDate}) {
  final days = switch (range) {
    StatsRange.weeks4 => 28,
    StatsRange.weeks12 => 84,
    StatsRange.all =>
      firstDate == null || firstDate.compareTo(today) > 0
          ? 28
          : (calendar.daysApart(firstDate, today) + 1).clamp(28, 100000),
  };
  return RangeWindow(calendar.shiftDate(today, -(days - 1)), today, days);
}
