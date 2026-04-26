import 'package:flutter_dexcom_follow/app/glucose_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FEATURE: mmol formatting uses 1 decimal place', () {
    expect(formatMmol(5.04), '5.0');
    expect(formatMmol(5.05), '5.0'); // toStringAsFixed rounds ties consistently
    expect(formatMmol(5.06), '5.1');
  });
}
