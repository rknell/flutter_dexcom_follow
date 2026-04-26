import 'package:intl/intl.dart';
import 'package:dexcom_share_api/dexcom_share_api.dart';

import 'alarm_settings.dart';

String formatMmol(double mmol) {
  return mmol.toStringAsFixed(1);
}

String formatMgdl(int mgdl) {
  return mgdl.toString();
}

String formatGlucoseEntry(GlucoseEntry entry, GlucoseUnit unit) {
  return switch (unit) {
    GlucoseUnit.mmol => formatMmol(entry.mmol),
    GlucoseUnit.mgdl => formatMgdl(entry.mgdl),
  };
}

String formatGlucoseMmol(double mmol, GlucoseUnit unit) {
  return switch (unit) {
    GlucoseUnit.mmol => formatMmol(mmol),
    GlucoseUnit.mgdl => formatMgdl((mmol * 18).round()),
  };
}

double glucoseDisplayValueFromMmol(double mmol, GlucoseUnit unit) {
  return switch (unit) {
    GlucoseUnit.mmol => mmol,
    GlucoseUnit.mgdl => mmol * 18,
  };
}

String formatLocalTimeFromIsoUtc(String isoUtc) {
  final utc = DateTime.parse(isoUtc);
  final local = utc.toLocal();
  return DateFormat.Hm().format(local);
}
