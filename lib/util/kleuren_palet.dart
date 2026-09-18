import 'package:flutter/material.dart';

/// Vast kleurenpalet, bewust beperkt tot een tiental basiskleuren i.p.v.
/// een vrije kleurkiezer - gebruikt voor het eigen bolletje in het
/// gezamenlijke overzicht (F9) én voor losse items in de persoonlijke
/// agenda (F10). Elke kleur staat hier als hex-string (zo wordt ze ook in
/// Firestore opgeslagen, bv. op `Gebruiker.kleur`/`Dienst.kleur`) samen met
/// een Nederlandse naam voor in de kleurkiezer.
const List<(String naam, String hex)> kleurenPalet = [
  ('Terracotta', '#E0704F'),
  ('Bosgroen', '#1F6F5C'),
  ('Blauw', '#3B6EA5'),
  ('Paars', '#7A5CA6'),
  ('Roze', '#D8698B'),
  ('Geel', '#D9A441'),
  ('Turquoise', '#2E9C9C'),
  ('Rood', '#C0453A'),
  ('Bruin', '#8A5A3B'),
  ('Grijs', '#6B7280'),
];

/// Standaardkleur zolang er nog niks gekozen is (bv. `Gebruiker.kleur` of
/// `Dienst.kleur` is nog `null`).
const String kleurStandaardHex = '#6B7280';

/// Zet een hex-string ("#E0704F") om naar een [Color] - valt terug op
/// [kleurStandaardHex] bij `null` of een niet te lezen waarde (bv. een
/// corrupt document), zodat een scherm nooit crasht op een kleurveld.
Color kleurVanHex(String? hex) {
  final waarde = int.tryParse((hex ?? kleurStandaardHex).replaceFirst('#', ''), radix: 16);
  if (waarde == null) return kleurVanHex(kleurStandaardHex);
  return Color(0xFF000000 | waarde);
}
