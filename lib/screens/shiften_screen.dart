import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/dienst.dart';
import '../models/gebruiker.dart';
import '../services/dienst_service.dart';
import '../theme.dart';
import '../util/datum_util.dart';
import '../widgets/dienst_tile.dart';
import 'dienst_bewerken_screen.dart';
import 'dienst_toevoegen_screen.dart';

/// Scherm met de eigen shiften van de ingelogde gebruiker: een kalender
/// (maand per maand, zie [TableCalendar]) met een bolletje op elke dag
/// waarop iets staat. Tik een dag aan om de shiften/afspraken van die dag
/// eronder te zien, en van daaruit te corrigeren/verwijderen (zie
/// PROJECT_SPEC.md sectie 1 - PDF-import mag nooit de enige manier zijn
/// waarop een shift ontstaat of verandert).
///
/// Vroeger stond dit als platte lijst rechtstreeks op [HomeScreen] (in
/// `_EigenRooster`); dat scherm toont nu enkel nog 2 knoppen, waarvan deze
/// kalender er ("Shiften bekijken") één is - zie PROJECT_SPEC.md sectie 13.
class ShiftenScreen extends StatefulWidget {
  const ShiftenScreen({super.key, required this.profiel});

  final Gebruiker profiel;

  @override
  State<ShiftenScreen> createState() => _ShiftenScreenState();
}

class _ShiftenScreenState extends State<ShiftenScreen> {
  late DateTime _gefocusteDag;
  late DateTime _geselecteerdeDag;

  @override
  void initState() {
    super.initState();
    final vandaag = DateTime.now();
    _gefocusteDag = vandaag;
    _geselecteerdeDag = DateTime(vandaag.year, vandaag.month, vandaag.day);
  }

  /// Groepeert een platte lijst diensten per dag (zonder tijdscomponent),
  /// zodat [TableCalendar] per dag kan opzoeken of er iets op staat.
  Map<DateTime, List<Dienst>> _groepeerPerDag(List<Dienst> diensten) {
    final perDag = <DateTime, List<Dienst>>{};
    for (final dienst in diensten) {
      final dag = vanIsoDatum(dienst.datum);
      perDag.putIfAbsent(dag, () => []).add(dienst);
    }
    return perDag;
  }

  List<Dienst> _opDag(Map<DateTime, List<Dienst>> perDag, DateTime dag) {
    return perDag[DateTime(dag.year, dag.month, dag.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mijn shiften')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DienstToevoegenScreen(
                profiel: widget.profiel,
                initieleDatum: _geselecteerdeDag,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Toevoegen'),
      ),
      body: StreamBuilder<List<Dienst>>(
        stream: DienstService.eigenDiensten(widget.profiel.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kon shiften niet laden: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }

          final perDag = _groepeerPerDag(snapshot.data ?? []);
          final vanGeselecteerdeDag = _opDag(perDag, _geselecteerdeDag);

          return Column(
            children: [
              TableCalendar<Dienst>(
                locale: 'nl_BE',
                firstDay: DateTime(_gefocusteDag.year - 1),
                lastDay: DateTime(_gefocusteDag.year + 2),
                focusedDay: _gefocusteDag,
                selectedDayPredicate: (dag) =>
                    DateUtils.isSameDay(dag, _geselecteerdeDag),
                eventLoader: (dag) => _opDag(perDag, dag),
                onDaySelected: (geselecteerd, gefocust) {
                  setState(() {
                    _geselecteerdeDag = DateTime(
                      geselecteerd.year,
                      geselecteerd.month,
                      geselecteerd.day,
                    );
                    _gefocusteDag = gefocust;
                  });
                },
                onPageChanged: (gefocust) {
                  _gefocusteDag = gefocust;
                },
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppKleuren.bosgroen.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: AppKleuren.bosgroen,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: AppKleuren.terracotta,
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: const TextStyle(color: AppKleuren.inkt),
                  outsideDaysVisible: false,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: vanGeselecteerdeDag.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Niets op ${naarWeergaveDatum(naarIsoDatum(_geselecteerdeDag))}. '
                            'Tik op "Toevoegen" om er iets op te zetten.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: vanGeselecteerdeDag.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, i) => DienstTile(
                          dienst: vanGeselecteerdeDag[i],
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DienstBewerkenScreen(
                                  dienst: vanGeselecteerdeDag[i],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
