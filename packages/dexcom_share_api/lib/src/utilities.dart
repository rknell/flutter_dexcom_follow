int? extractNumber(String str) {
  final match = RegExp(r"\d+").firstMatch(str);
  if (match == null) return null;
  return int.tryParse(match.group(0)!);
}

// http://www.bcchildrens.ca/endocrinology-diabetes-site/documents/glucoseunits.pdf
// [BG (mmol/L) * 18] = BG (mg/dL)
//
// Return the normalized mmol/L
double mgdlToMmol(int mgdl) {
  final value = mgdl / 18.0;
  return double.parse(value.toStringAsFixed(2));
}
