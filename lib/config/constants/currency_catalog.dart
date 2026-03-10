import 'package:flutter/material.dart';

class CurrencyOption {
  final String code;
  final String name;
  final String symbol;
  final IconData icon;

  const CurrencyOption({
    required this.code,
    required this.name,
    required this.symbol,
    required this.icon,
  });
}

const currencyCatalog = <CurrencyOption>[
  CurrencyOption(
    code: 'INR',
    name: 'Indian Rupee',
    symbol: 'Rs.',
    icon: Icons.currency_rupee_rounded,
  ),
  CurrencyOption(
    code: 'USD',
    name: 'US Dollar',
    symbol: r'$',
    icon: Icons.attach_money_rounded,
  ),
  CurrencyOption(
    code: 'EUR',
    name: 'Euro',
    symbol: 'EUR',
    icon: Icons.euro_rounded,
  ),
  CurrencyOption(
    code: 'GBP',
    name: 'British Pound',
    symbol: 'GBP',
    icon: Icons.currency_pound_rounded,
  ),
  CurrencyOption(
    code: 'JPY',
    name: 'Japanese Yen',
    symbol: 'JPY',
    icon: Icons.currency_yen_rounded,
  ),
  CurrencyOption(
    code: 'AUD',
    name: 'Australian Dollar',
    symbol: 'A\$',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'CAD',
    name: 'Canadian Dollar',
    symbol: 'C\$',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'SGD',
    name: 'Singapore Dollar',
    symbol: 'S\$',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'AED',
    name: 'UAE Dirham',
    symbol: 'AED',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'SAR',
    name: 'Saudi Riyal',
    symbol: 'SAR',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'QAR',
    name: 'Qatari Riyal',
    symbol: 'QAR',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'KWD',
    name: 'Kuwaiti Dinar',
    symbol: 'KWD',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'BHD',
    name: 'Bahraini Dinar',
    symbol: 'BHD',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'OMR',
    name: 'Omani Rial',
    symbol: 'OMR',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'CHF',
    name: 'Swiss Franc',
    symbol: 'CHF',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'CNY',
    name: 'Chinese Yuan',
    symbol: 'CNY',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'HKD',
    name: 'Hong Kong Dollar',
    symbol: 'HK\$',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'NZD',
    name: 'New Zealand Dollar',
    symbol: 'NZ\$',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'ZAR',
    name: 'South African Rand',
    symbol: 'ZAR',
    icon: Icons.payments_rounded,
  ),
  CurrencyOption(
    code: 'BRL',
    name: 'Brazilian Real',
    symbol: 'R\$',
    icon: Icons.payments_rounded,
  ),
];

String currencySymbolFor(String code) {
  for (final currency in currencyCatalog) {
    if (currency.code == code) {
      return currency.symbol;
    }
  }
  return 'Rs.';
}

CurrencyOption currencyOptionFor(String code) {
  for (final currency in currencyCatalog) {
    if (currency.code == code) {
      return currency;
    }
  }
  return currencyCatalog.first;
}
