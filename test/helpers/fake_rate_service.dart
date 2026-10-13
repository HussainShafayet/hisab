import 'package:hishab/core/net/rate_service.dart';

const _offline = RateException(
  "Could not get today's rate. Check your internet and try again.",
);

/// A rate service that gives fixed rates, or fails, and counts the calls.
class FakeRateService implements RateService {
  FakeRateService({
    this.bdtPerUsd = 120,
    this.gold = 4000,
    this.silver = 60,
    this.fails = false,
  });

  double bdtPerUsd;
  double gold;
  double silver;
  bool fails;
  int calls = 0;

  @override
  Future<double> usdToBdt() async {
    calls++;
    if (fails) {
      throw _offline;
    }
    return bdtPerUsd;
  }

  @override
  Future<MetalPrices> metals() async {
    calls++;
    if (fails) {
      throw _offline;
    }
    return MetalPrices(goldPerOunce: gold, silverPerOunce: silver);
  }
}
