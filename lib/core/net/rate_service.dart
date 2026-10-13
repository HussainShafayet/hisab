import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';

/// Today's rate could not be fetched: no internet, a slow answer, or an answer
/// that made no sense. The [message] can be shown as it is.
class RateException extends ValidationException {
  const RateException(super.message);

  @override
  String toString() => message;
}

/// Gold and silver prices, in US dollars for one troy ounce.
class MetalPrices {
  const MetalPrices({required this.goldPerOunce, required this.silverPerOunce});

  final double goldPerOunce;
  final double silverPerOunce;
}

/// Live prices from the internet. The app works without it: this is only used
/// when the person asks for today's rate or price, and they can always type
/// the figure by hand.
abstract class RateService {
  /// How many taka one US dollar costs today.
  Future<double> usdToBdt();

  /// Today's gold and silver prices.
  Future<MetalPrices> metals();
}

/// Grams in a troy ounce.
const gramsPerTroyOunce = 31.1034768;

/// The taka per US dollar in the answer of the exchange rate service
/// (`{"rates": {"BDT": 123.19}}`). Throws a [RateException] if it is not
/// there.
double parseUsdToBdt(Object? json) {
  if (json is Map && json['rates'] is Map) {
    final rate = (json['rates'] as Map)['BDT'];
    if (rate is num && rate > 0) return rate.toDouble();
  }
  throw RateException(
    tr('The rate service gave an answer that cannot be read.'),
  );
}

/// The price in the answer of the metal price service (`{"price": 4161.0}`).
double parseMetalPrice(Object? json) {
  if (json is Map) {
    final price = json['price'];
    if (price is num && price > 0) return price.toDouble();
  }
  throw RateException(
    tr('The rate service gave an answer that cannot be read.'),
  );
}

/// Reads the rates from free services: open.er-api.com for dollars and
/// api.gold-api.com for gold and silver. No account or key is needed.
class HttpRateService implements RateService {
  const HttpRateService({this.timeout = const Duration(seconds: 12)});

  final Duration timeout;

  static const _usdUrl = 'https://open.er-api.com/v6/latest/USD';
  static const _goldUrl = 'https://api.gold-api.com/price/XAU';
  static const _silverUrl = 'https://api.gold-api.com/price/XAG';

  Future<Object?> _get(String url) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) throw const _Failed();
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return jsonDecode(body);
    } on Object {
      throw RateException(
        tr('Could not get today\'s rate. Check your internet and try again.'),
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<double> usdToBdt() async => parseUsdToBdt(await _get(_usdUrl));

  @override
  Future<MetalPrices> metals() async {
    final gold = parseMetalPrice(await _get(_goldUrl));
    final silver = parseMetalPrice(await _get(_silverUrl));
    return MetalPrices(goldPerOunce: gold, silverPerOunce: silver);
  }
}

class _Failed implements Exception {
  const _Failed();
}

/// The rate service of the app. Tests replace it with a fake.
final rateServiceProvider = Provider<RateService>(
  (ref) => const HttpRateService(),
);
