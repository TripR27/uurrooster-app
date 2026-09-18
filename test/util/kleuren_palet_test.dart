import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uurrooster_app/util/kleuren_palet.dart';

void main() {
  test('kleurenPalet heeft een beperkt aantal unieke kleuren', () {
    expect(kleurenPalet.length, 10);
    final hexen = kleurenPalet.map((k) => k.$2).toSet();
    expect(hexen.length, kleurenPalet.length);
  });

  test('kleurVanHex leest een geldige hex-kleur correct', () {
    expect(kleurVanHex('#E0704F'), const Color(0xFFE0704F));
  });

  test('kleurVanHex valt terug op de standaardkleur bij null', () {
    expect(kleurVanHex(null), kleurVanHex(kleurStandaardHex));
  });

  test('kleurVanHex valt terug op de standaardkleur bij rommel', () {
    expect(kleurVanHex('geen-hex'), kleurVanHex(kleurStandaardHex));
    expect(kleurVanHex(''), kleurVanHex(kleurStandaardHex));
  });
}
