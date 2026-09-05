/// Formatteert een datum als ISO-tekst ("2026-07-04"), het formaat waarin
/// [Dienst.datum] opgeslagen wordt (zie models/dienst.dart). Gedeeld tussen
/// de verschillende RoosterParser-implementaties zodat dit niet in elke
/// parser opnieuw geschreven moet worden.
String naarIsoDatum(DateTime datum) {
  final j = datum.year.toString().padLeft(4, '0');
  final m = datum.month.toString().padLeft(2, '0');
  final d = datum.day.toString().padLeft(2, '0');
  return '$j-$m-$d';
}
