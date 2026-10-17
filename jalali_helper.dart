/// تبدیل ساده میلادی به شمسی (جلالی) و بالعکس.
/// الگوریتم استاندارد تبدیل تاریخ جلالی بدون هیچ وابستگی خارجی.
class JalaliHelper {
  /// خروجی: [سال شمسی، ماه شمسی، روز شمسی]
  static List<int> gregorianToJalali(int gy, int gm, int gd) {
    final gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    int jy = gy <= 1600 ? 0 : 979;
    int gy2 = gy <= 1600 ? gy - 621 : gy - 1600;
    int gd2 = gm > 2 ? gy2 + 1 : gy2;
    int days =
        365 * gy2 + (gd2 + 3) ~/ 4 - (gd2 + 99) ~/ 100 + (gd2 + 399) ~/ 400 -
            80 + gdm[gm - 1] + gd;
    jy += 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    final List<int> jm;
    int jd;
    if (days < 186) {
      jm = _jm(days ~/ 31 + 1);
      jd = (days % 31) + 1;
    } else {
      jm = _jm(((days - 186) ~/ 30) + 7);
      jd = ((days - 186) % 30) + 1;
    }
    return [jy, jm is List ? jm[0] : jm, jd];
  }

  static List<int> _jm(int m) => [m];

  /// خروجی: [سال میلادی، ماه میلادی، روز میلادی]
  static List<int> jalaliToGregorian(int jy, int jm, int jd) {
    int gy = jy <= 979 ? 621 : 1600;
    jy -= jy <= 979 ? 0 : 979;
    int days =
        365 * jy + (jy ~/ 33) * 8 + ((jy % 33) + 3) ~/ 4 + 78 + jd +
            (jm < 7 ? (jm - 1) * 31 : (jm - 7) * 30 + 186);
    gy += 400 * (days ~/ 146097);
    days %= 146097;
    if (days > 36524) {
      gy += 100 * (--days ~/ 36524);
      days %= 36524;
      if (days >= 365) days++;
    }
    gy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      gy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    int gd = days + 1;
    const salem = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335];
    const na = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    int gm = 0;
    for (int i = 0; i < 12; i++) {
      final ref = _isLeapGreg(gy) ? salem[i] : na[i];
      if (gd > ref) gm = i + 1;
    }
    final start = _isLeapGreg(gy) ? salem[gm - 1] : na[gm - 1];
    gd -= start;
    return [gy, gm, gd];
  }

  static bool _isLeapGreg(int y) =>
      (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);

  static const _monthNames = [
    "فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
    "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند",
  ];

  static String monthName(int m) =>
      (m >= 1 && m <= 12) ? _monthNames[m - 1] : "نامعلوم";

  static String p2(int n) => n.toString().padLeft(2, "0");

  /// تاریخ امروز به شکل رشته شمسی "۱۴۰۳/۰۵/۱۲" (ارقام لاتین برای مقایسه ساده)
  static String todayJalali() {
    final now = DateTime.now();
    final j = gregorianToJalali(now.year, now.month, now.day);
    return "${j[0]}/${p2(j[1])}/${p2(j[2])}";
  }

  /// تبدیل DateTime به رشته شمسی.
  static String format(DateTime d) {
    final j = gregorianToJalali(d.year, d.month, d.day);
    return "${j[0]}/${p2(j[1])}/${p2(j[2])}";
  }

  /// تبدیل رشته شمسی به DateTime (میلادی) یا null در صورت نامعتبر بودن.
  static DateTime? parse(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split("/");
    if (parts.length != 3) return null;
    final jy = int.tryParse(parts[0]);
    final jm = int.tryParse(parts[1]);
    final jd = int.tryParse(parts[2]);
    if (jy == null || jm == null || jd == null) return null;
    if (jm < 1 || jm > 12 || jd < 1 || jd > 31) return null;
    final g = jalaliToGregorian(jy, jm, jd);
    return DateTime(g[0], g[1], g[2]);
  }
}
