/// Belarus public holidays — port of `src/lib/belarus/holidays.ts`.
///
/// Used by the budget planner to adjust salary/advance pay dates when they
/// fall on a weekend or public holiday (shift to last working day before).

class BYHoliday {
  const BYHoliday({required this.date, required this.name});

  /// ISO date (YYYY-MM-DD).
  final String date;
  final String name;
}

const _fixed = [
  (md: '01-01', name: 'Новы год'),
  (md: '01-02', name: 'Працяг навагодніх'),
  (md: '01-07', name: 'Раство Хрыстова (праваслаўнае)'),
  (md: '03-08', name: 'Дзень жанчын'),
  (md: '05-01', name: 'Свята працы'),
  (md: '05-09', name: 'Дзень Перамогі'),
  (md: '07-03', name: 'Дзень Незалежнасці РБ'),
  (md: '11-07', name: 'Дзень Кастрычніцкай рэвалюцыі'),
  (md: '12-25', name: 'Раство Хрыстова (каталіцкае)'),
];

/// Orthodox Easter (Meeus Julian algorithm) returned as a Gregorian date.
///
/// The algorithm yields the Julian-calendar Easter date, which is then shifted
/// by the Julian→Gregorian offset (13 days for 1900–2099, computed generally
/// below) to give the civil Gregorian date used by the Belarus calendar.
DateTime _orthodoxEaster(int year) {
  final a = year % 4;
  final b = year % 7;
  final c = year % 19;
  final d = (19 * c + 15) % 30;
  final e = (2 * a + 4 * b - d + 34) % 7;
  final month = (d + e + 114) ~/ 31; // 3 = March, 4 = April
  final day = ((d + e + 114) % 31) + 1;
  final julian = DateTime.utc(year, month, day);
  final offsetDays = year ~/ 100 - year ~/ 400 - 2;
  return julian.add(Duration(days: offsetDays));
}

List<BYHoliday> getBYHolidays(int year) {
  final list = <BYHoliday>[
    for (final h in _fixed)
      BYHoliday(date: '$year-${h.md}', name: h.name),
  ];
  final easter = _orthodoxEaster(year);
  final radonitsa = easter.add(const Duration(days: 9));
  final mm = radonitsa.month.toString().padLeft(2, '0');
  final dd = radonitsa.day.toString().padLeft(2, '0');
  list.add(BYHoliday(date: '$year-$mm-$dd', name: 'Радаўніца'));
  list.sort((a, b) => a.date.compareTo(b.date));
  return list;
}

/// Returns the holiday info if [iso] (`YYYY-MM-DD`) falls on a Belarus
/// public holiday, or `null` otherwise.
BYHoliday? isBYHoliday(String iso) {
  final year = int.tryParse(iso.substring(0, 4));
  if (year == null) return null;
  final holidays = getBYHolidays(year);
  for (final h in holidays) {
    if (h.date == iso) return h;
  }
  return null;
}
