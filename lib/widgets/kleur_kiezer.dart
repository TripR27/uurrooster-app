import 'package:flutter/material.dart';

import '../theme.dart';
import '../util/kleuren_palet.dart';

/// Grid van kleurbolletjes uit `kleurenPalet` - gedeeld tussen "mijn kleur"
/// in het gezamenlijke overzicht (F9) en de kleur per item in de
/// persoonlijke agenda (F10).
class KleurKiezer extends StatelessWidget {
  const KleurKiezer({
    super.key,
    required this.geselecteerdeHex,
    required this.onGekozen,
  });

  final String? geselecteerdeHex;
  final ValueChanged<String> onGekozen;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final (naam, hex) in kleurenPalet)
          _KleurBolletje(
            naam: naam,
            hex: hex,
            geselecteerd: hex == geselecteerdeHex,
            onTap: () => onGekozen(hex),
          ),
      ],
    );
  }
}

class _KleurBolletje extends StatelessWidget {
  const _KleurBolletje({
    required this.naam,
    required this.hex,
    required this.geselecteerd,
    required this.onTap,
  });

  final String naam;
  final String hex;
  final bool geselecteerd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Tooltip(
        message: naam,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kleurVanHex(hex),
            shape: BoxShape.circle,
            border: geselecteerd
                ? Border.all(color: AppKleuren.inkt, width: 3)
                : null,
          ),
          child: geselecteerd
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}

/// Opent een bottom sheet met [KleurKiezer] en geeft de gekozen hex-kleur
/// terug (`null` als er zonder kiezen geannuleerd wordt).
Future<String?> toonKleurKiezer(
  BuildContext context, {
  required String titel,
  String? geselecteerdeHex,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titel,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            KleurKiezer(
              geselecteerdeHex: geselecteerdeHex,
              onGekozen: (hex) => Navigator.of(context).pop(hex),
            ),
          ],
        ),
      ),
    ),
  );
}
