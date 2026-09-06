import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'auth_gate.dart';
import 'firebase_options.dart';
import 'theme.dart';

void main() async {
  // Nodig omdat Firebase.initializeApp() al Flutter-bindings gebruikt
  // vóórdat runApp() dat normaal gesproken zelf zou doen.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Laadt de Nederlandse maand-/dagnamen in voor de kalenderweergave
  // (ShiftenScreen, via table_calendar) - zonder dit gooit intl een
  // LocaleDataException zodra er een niet-Engelse locale gebruikt wordt.
  await initializeDateFormatting('nl_BE');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gezinsrooster',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      // Nederlands: vertaalt de ingebouwde Material-teksten (datumkiezer,
      // "Annuleren"/"OK", ...) én zorgt dat de week op maandag begint in
      // showDatePicker / showDateRangePicker.
      locale: const Locale('nl'),
      supportedLocales: const [Locale('nl')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Altijd 24u-notatie (07:00, 17:00, ...) i.p.v. AM/PM - overal in de
      // app waar een tijd getoond/gekozen wordt (bv. showTimePicker in
      // DienstBewerkenScreen), ongeacht de systeeminstelling van het
      // toestel.
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
      // AuthGate beslist zelf of het inlogscherm of het startscherm getoond
      // wordt, op basis van de Firebase-inlogstatus (zie auth_gate.dart).
      home: const AuthGate(),
    );
  }
}
