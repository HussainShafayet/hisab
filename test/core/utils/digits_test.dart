import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/utils/digits.dart';

void main() {
  test('turns Bengali digits into English ones', () {
    expect(normalizeDigits('০১২৩৪৫৬৭৮৯'), '0123456789');
    expect(normalizeDigits('১,২৫০.৫০'), '1,250.50');
  });

  test('leaves everything else alone', () {
    expect(normalizeDigits('Tk 1200 / bKash ৳'), 'Tk 1200 / bKash ৳');
    expect(normalizeDigits(''), '');
  });

  test('works on a mix of both', () {
    expect(normalizeDigits('১১/10/২০২৬'), '11/10/2026');
  });
}
