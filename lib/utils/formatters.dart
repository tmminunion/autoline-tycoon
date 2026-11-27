class Formatters {
  static String money(double value) {
    if (value < 0) return '-\$${money(-value).substring(1)}';
    if (value < 1000) {
      return '\$${value.toStringAsFixed(value < 10 ? 1 : 0)}';
    }
    const suffixes = ['K', 'M', 'B', 'T', 'Qa', 'Qi'];
    var scaled = value;
    var index = -1;
    while (scaled >= 1000 && index < suffixes.length - 1) {
      scaled /= 1000;
      index++;
    }
    return '\$${scaled.toStringAsFixed(2)}${suffixes[index]}';
  }

  static String rate(double unitsPerMin) {
    if (unitsPerMin >= 100) {
      return '${unitsPerMin.toStringAsFixed(0)} u/m';
    }
    return '${unitsPerMin.toStringAsFixed(1)} u/m';
  }

  static String duration(int seconds) {
    if (seconds < 60) return '${seconds}d';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ${seconds % 60}d';
    final hours = minutes ~/ 60;
    return '${hours}j ${minutes % 60}m';
  }
}
