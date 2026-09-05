import 'dart:typed_data';

import '../models/dienst.dart';

/// Elk rooster-PDF-formaat (zie PROJECT_SPEC.md sectie 6) krijgt zijn eigen
/// klasse die dit implementeert. De rest van de app moet nooit weten hoe
/// een specifiek PDF-formaat er precies uitziet - enkel dat er ergens een
/// lijst Diensten uitkomt.
abstract class RoosterParser {
  List<Dienst> parse(
    Uint8List pdfBytes, {
    required String gebruikerId,
    required String gebruikerNaam,
  });
}
