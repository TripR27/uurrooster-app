/// Formatteert een datum als ISO-tekst ("2026-07-04"), het formaat waarin
/// [Dienst.datum] opgeslagen wordt (zie models/dienst.dart) - handig om te
/// sorteren als tekst, maar niet om aan een gebruiker te tonen.
String naarIsoDatum(DateTime datum) {
  final j = datum.year.toString().padLeft(4, '0');
  final m = datum.month.toString().padLeft(2, '0');
  final d = datum.day.toString().padLeft(2, '0');
  return '$j-$m-$d';
}

/// Het omgekeerde van [naarIsoDatum].
DateTime vanIsoDatum(String iso) {
  final delen = iso.split('-');
  return DateTime(int.parse(delen[0]), int.parse(delen[1]), int.parse(delen[2]));
}

/// Formatteert een ISO-datum ("2026-07-04") als "04-07-2026", voor op het
/// scherm - mama en Amy hebben niks aan ISO-notatie.
String naarWeergaveDatum(String isoDatum) {
  final delen = isoDatum.split('-');
  return '${delen[2]}-${delen[1]}-${delen[0]}';
}
