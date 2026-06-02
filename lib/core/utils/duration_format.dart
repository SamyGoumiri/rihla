String formatTripDuration(Duration d) {
  if (d.isNegative) return '< 1 min';
  if (d.inMinutes < 1) return '< 1 min';

  if (d.inHours < 1) {
    return '${d.inMinutes} min';
  }

  if (d.inHours < 24) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  final days = d.inDays;
  final hours = d.inHours.remainder(24);
  if (hours == 0) {
    return '${days}j';
  }
  return '${days}j ${hours.toString().padLeft(2, '0')}h';
}
