import 'package:timeago/timeago.dart' as timeago;

/// Locution française personnalisée pour timeago :
/// - "il y a 1 h" au lieu de "il y a environ une heure"
/// - "il y a 5 mn" au lieu de "il y a 5 minutes"
class TimeagoFrShort implements timeago.LookupMessages {
  @override
  String prefixAgo() => 'il y a';
  @override
  String prefixFromNow() => 'dans';
  @override
  String suffixAgo() => '';
  @override
  String suffixFromNow() => '';
  @override
  String lessThanOneMinute(int seconds) => 'à l\'instant';
  @override
  String aboutAMinute(int minutes) => '1 mn';
  @override
  String minutes(int minutes) => '$minutes mn';
  @override
  String aboutAnHour(int minutes) => '1 h';
  @override
  String hours(int hours) => '$hours h';
  @override
  String aDay(int hours) => '1 j';
  @override
  String days(int days) => '$days j';
  @override
  String aboutAMonth(int days) => '1 mois';
  @override
  String months(int months) => '$months mois';
  @override
  String aboutAYear(int years) => '1 an';
  @override
  String years(int years) => '$years an';
  @override
  String wordSeparator() => ' ';
}

/// Enregistre la locale française courte pour timeago.
void registerTimeagoFrShort() {
  timeago.setLocaleMessages('fr', TimeagoFrShort());
}
