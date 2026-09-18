import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/gebruiker.dart';
import 'gebruiker_service.dart';

/// Stuurt de beheerder(s) een pushmelding via de OneSignal REST-API
/// wanneer iemand zelf iets invult (F11, zie PROJECT_SPEC.md) - een
/// PDF-import, het schoolrooster ophalen, of handmatig iets toevoegen
/// (niet wanneer de beheerder vanuit het gezamenlijke overzicht iets voor
/// een ander toevoegt, F3 - dat weet de beheerder al).
///
/// App-ID + REST-key komen uit `.env`/`.env.android`
/// (`--dart-define-from-file`), net als de Firebase-config - nooit
/// hardcoded of gecommit.
class MeldingService {
  MeldingService._();

  static const _appId = String.fromEnvironment('onesignalAppId');
  static const _restApiKey = String.fromEnvironment('onesignalRestApiKey');

  /// Wie een melding moet krijgen over een actie van [acteur] - pure
  /// functie, apart testbaar zonder Firestore: alle beheerders met
  /// `wilMeldingen == true`, maar enkel als de acteur zelf de bijhorende
  /// schakelaar aan heeft staan (`meldingenBulkAan` voor een PDF-/
  /// schoolrooster-import, `meldingenSingleAan` voor handmatig iets
  /// toevoegen - F12). Nooit de acteur zelf (je hoeft geen melding over je
  /// eigen actie te krijgen).
  static List<Gebruiker> bepaalOntvangers(
    List<Gebruiker> gezinsleden,
    Gebruiker acteur, {
    required bool isBulk,
  }) {
    final acteurStuurtMeldingen = isBulk
        ? acteur.meldingenBulkAan
        : acteur.meldingenSingleAan;
    if (!acteurStuurtMeldingen) return const [];
    return gezinsleden
        .where(
          (g) => g.isBeheerder && g.wilMeldingen && g.uid != acteur.uid,
        )
        .toList();
  }

  /// Zoekt de ontvangers op en stuurt hen [tekst] als pushmelding. [isBulk]
  /// onderscheidt een PDF-/schoolrooster-import (`meldingenBulkAan`) van
  /// handmatig iets toevoegen (`meldingenSingleAan`) - zie
  /// [bepaalOntvangers]. Faalt dit (geen internet, OneSignal down, geen
  /// App-ID/REST-key ingesteld, ...), dan wordt dat enkel genegeerd - de
  /// dienst zelf is dan al opgeslagen, een melding is nooit een kritiek pad.
  static Future<void> stuurMelding({
    required Gebruiker acteur,
    required String tekst,
    required bool isBulk,
  }) async {
    if (_appId.isEmpty || _restApiKey.isEmpty) return;
    try {
      final gezinsleden = await GebruikerService.zichtbareGebruikers(
        acteur.uid,
      );
      final ontvangers = bepaalOntvangers(
        gezinsleden,
        acteur,
        isBulk: isBulk,
      );
      if (ontvangers.isEmpty) return;

      await http.post(
        Uri.parse('https://api.onesignal.com/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_aliases': {
            'external_id': ontvangers.map((g) => g.uid).toList(),
          },
          'target_channel': 'push',
          'headings': {'en': "Mama's rooster app"},
          'contents': {'en': tekst},
        }),
      );
    } catch (_) {
      // Negeren - zie hierboven.
    }
  }
}
