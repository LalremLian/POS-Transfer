import 'package:intl/intl.dart';

abstract class AppDateUtils {
  AppDateUtils._();

  static final _dateFmt = DateFormat('d MMM yyyy');
  static final _timeFmt = DateFormat('HH:mm');
  static final _dateTimeFmt = DateFormat('d MMM yyyy, HH:mm');

  static String formatDate(DateTime dt) => _dateFmt.format(dt.toLocal());
  static String formatTime(DateTime dt) => _timeFmt.format(dt.toLocal());
  static String formatDateTime(DateTime dt) => _dateTimeFmt.format(dt.toLocal());

  /// Returns a human-readable elapsed duration, e.g. "2m 34s" or "5h 12m".
  static String formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) {
      final s = d.inSeconds.remainder(60);
      return '${d.inMinutes}m ${s}s';
    }
    final m = d.inMinutes.remainder(60);
    return '${d.inHours}h ${m}m';
  }

  /// Returns estimated time remaining, e.g. "About 3 minutes".
  static String formatEta(int remainingBytes, double bytesPerSecond) {
    if (bytesPerSecond <= 0 || remainingBytes <= 0) return 'Calculating…';
    final seconds = (remainingBytes / bytesPerSecond).round();
    if (seconds < 10) return 'Almost done';
    if (seconds < 60) return 'About ${seconds}s remaining';
    if (seconds < 3600) {
      return 'About ${(seconds / 60).ceil()}m remaining';
    }
    return 'About ${(seconds / 3600).ceil()}h remaining';
  }
}
