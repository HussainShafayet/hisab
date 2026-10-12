import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/reports/domain/category_total.dart';
import 'package:hishab/features/reports/domain/pie_slices.dart';

CategoryTotal total(int id, int amount) => CategoryTotal(
  categoryId: id,
  name: 'C$id',
  icon: 'category',
  color: 0xFF000000 + id,
  total: amount,
);

void main() {
  test('is empty when nothing was spent', () {
    expect(buildPieSlices([]), isEmpty);
    expect(buildPieSlices([total(1, 0)]), isEmpty);
  });

  test('keeps every category when there are few', () {
    final slices = buildPieSlices([
      total(1, 500),
      total(2, 300),
      total(3, 200),
    ]);

    expect(slices.map((s) => s.label), ['C1', 'C2', 'C3']);
    expect(slices.map((s) => s.amount), [500, 300, 200]);
    expect(slices.every((s) => !s.isOthers), isTrue);
    expect(slices.first.color, 0xFF000001);
  });

  test('groups the smallest into Others', () {
    final slices = buildPieSlices([
      for (var i = 1; i <= 9; i++) total(i, 1000 - i * 10),
    ], maxSlices: 5);

    expect(slices, hasLength(6));
    expect(slices.last.label, 'Others');
    expect(slices.last.isOthers, isTrue);
    // Categories 6 to 9: 940 + 930 + 920 + 910.
    expect(slices.last.amount, 3700);
    expect(slices.take(5).map((s) => s.label), ['C1', 'C2', 'C3', 'C4', 'C5']);
  });

  test('the slices add up to everything that was spent', () {
    final totals = [for (var i = 1; i <= 10; i++) total(i, i * 111)];
    totals.sort((a, b) => b.total.compareTo(a.total));

    final slices = buildPieSlices(totals, maxSlices: 4);

    expect(
      slices.fold(0, (sum, s) => sum + s.amount),
      totals.fold(0, (sum, c) => sum + c.total),
    );
  });

  test('a single leftover category is shown as itself, not as Others', () {
    final slices = buildPieSlices([
      total(1, 500),
      total(2, 400),
      total(3, 300),
      total(4, 200),
    ], maxSlices: 3);

    expect(slices.map((s) => s.label), ['C1', 'C2', 'C3', 'C4']);
  });

  test('uses the color given for Others', () {
    final slices = buildPieSlices(
      [for (var i = 1; i <= 5; i++) total(i, 100)],
      maxSlices: 2,
      othersColor: 0xFF123456,
    );

    expect(slices.last.color, 0xFF123456);
  });

  test('leaves out categories with nothing spent', () {
    final slices = buildPieSlices([total(1, 500), total(2, 0), total(3, 100)]);

    expect(slices.map((s) => s.label), ['C1', 'C3']);
  });
}
