import 'package:intl/intl.dart';

String formatMmol(double mmol) {
  return mmol.toStringAsFixed(1);
}

String formatLocalTimeFromIsoUtc(String isoUtc) {
  final utc = DateTime.parse(isoUtc);
  final local = utc.toLocal();
  return DateFormat.Hm().format(local);
}

