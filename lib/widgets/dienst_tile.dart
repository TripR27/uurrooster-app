import 'package:flutter/material.dart';

import '../models/dienst.dart';
import '../util/datum_util.dart';

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
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: const Icon(Icons.calendar_today),
      title: Text(naarWeergaveDatum(dienst.datum)),
      subtitle: Text(dienst.naarTekst()),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    );
  }
}
