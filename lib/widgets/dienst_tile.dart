import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../util/datum_util.dart';
import '../util/kleuren_palet.dart';

/// Eén rij voor een [Dienst] in een lijst - gedeeld tussen het
/// PDF-uploadscherm (voorbeeld tonen) en het overzichtscherm (eigen
/// diensten bekijken/corrigeren), zodat die twee er niet elk apart een
/// versie van moeten bijhouden.
class DienstTile extends StatelessWidget {
  const DienstTile({super.key, required this.dienst, this.onTap});

  final Dienst dienst;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titel = dienst.isMeerdaags
        ? '${naarWeergaveDatum(dienst.datum)} → '
              '${naarWeergaveDatum(dienst.eindDatum!)}'
        : naarWeergaveDatum(dienst.datum);

    return ListTile(
      dense: true,
      onTap: onTap,
      // De kleur (F10) van dit item zit in het icoon - zo blijft het
      // onderscheid met schoolrooster-items (ander icoon) behouden, en
      // krijgt de rij toch meteen de eigen kleur mee.
      leading: Icon(
        dienst.bron == DienstBron.schoolrooster
            ? Icons.school_outlined
            : Icons.calendar_today,
        color: kleurVanHex(dienst.kleur),
      ),
      title: Text(titel),
      subtitle: Text(dienst.naarTekst()),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    );
  }
}
