import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// ── Data Models ──

class LineItem {
  final String description;
  final double amount;

  const LineItem({required this.description, required this.amount});

  LineItem copyWith({String? description, double? amount}) =>
      LineItem(
        description: description ?? this.description,
        amount: amount ?? this.amount,
      );

  Map<String, dynamic> toJson() =>
      {'description': description, 'amount': amount};

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
      );
}

class ReceiptData {
  final String? merchantName;
  final double? totalAmount;
  final DateTime? date;
  final List<LineItem> lineItems;

  const ReceiptData({
    this.merchantName,
    this.totalAmount,
    this.date,
    this.lineItems = const [],
  });

  ReceiptData copyWith({
    String? merchantName,
    double? totalAmount,
    DateTime? date,
    List<LineItem>? lineItems,
  }) =>
      ReceiptData(
        merchantName: merchantName ?? this.merchantName,
        totalAmount: totalAmount ?? this.totalAmount,
        date: date ?? this.date,
        lineItems: lineItems ?? this.lineItems,
      );
}

class ScannerState {
  final bool isProcessing;
  final ReceiptData? receiptData;
  final String? error;
  final String? imagePath;

  const ScannerState({
    this.isProcessing = false,
    this.receiptData,
    this.error,
    this.imagePath,
  });

  ScannerState copyWith({
    bool? isProcessing,
    ReceiptData? receiptData,
    String? error,
    String? imagePath,
    bool clearReceiptData = false,
    bool clearError = false,
    bool clearImagePath = false,
  }) =>
      ScannerState(
        isProcessing: isProcessing ?? this.isProcessing,
        receiptData:
            clearReceiptData ? null : (receiptData ?? this.receiptData),
        error: clearError ? null : (error ?? this.error),
        imagePath:
            clearImagePath ? null : (imagePath ?? this.imagePath),
      );
}

// ── Receipt Text Parser ──

class ReceiptParser {
  const ReceiptParser._();

  // FIX: tightened amount pattern — bare integers are NOT matched unless
  // they have a decimal part or are directly adjacent to a currency symbol.
  // This eliminates false positives from table numbers, item quantities,
  // phone numbers (10-digit), and year values like 2026.
  static final _pricePattern = RegExp(
    // ₹/Rs./INR then optional space then number
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'|'
    // number with mandatory decimal part (e.g. 249.00, 1,299.50)
    r'\b([\d,]+\.\d{1,2})\b'
    r'|'
    // number then currency symbol
    r'([\d,]+(?:\.\d{1,2})?)\s*(?:Rs\.?|INR|\u20B9)',
    caseSensitive: false,
  );

  static final _totalKeywords = RegExp(
    r'(?:grand\s*total|total\s*amount|total\s*due|net\s*total|'
    r'total|amount\s*due|amount\s*payable|balance\s*due|'
    r'net\s*payable|you\s*pay|paid|subtotal)'
    r'\s*:?\s*',
    caseSensitive: false,
  );

  // Keywords that make a line very likely to be the grand total
  static final _grandTotalKeywords = RegExp(
    r'(?:grand\s*total|total\s*amount|total\s*due|net\s*total|'
    r'amount\s*payable|net\s*payable|you\s*pay)',
    caseSensitive: false,
  );

  static final List<RegExp> _datePatterns = [
    RegExp(r'(?<!\d)(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})(?!\d)'),
    RegExp(r'(?<!\d)(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})(?!\d)'),
    RegExp(
      r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{4})',
      caseSensitive: false,
    ),
    RegExp(
      r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{1,2}),?\s+(\d{4})',
      caseSensitive: false,
    ),
  ];

  // FIX: time pattern — used to skip DD/MM matches that are actually times
  static final _timePattern =
      RegExp(r'\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?', caseSensitive: false);

  static const _monthNames = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
    'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
    'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static ReceiptData parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return const ReceiptData();

    return ReceiptData(
      merchantName: _extractMerchant(lines),
      totalAmount: _extractTotal(lines),
      date: _extractDate(rawText),
      lineItems: _extractLineItems(lines),
    );
  }

  // FIX: scan up to 6 lines (not 3) and skip decoration/address lines.
  // Decoration lines: all dashes, all stars, or look like addresses
  // (contain digits + street keywords like "road", "nagar", "st", "ave").
  static String? _extractMerchant(List<String> lines) {
    final addressPattern = RegExp(
      r'\b(?:road|rd|street|st|ave|avenue|nagar|colony|lane|ln|floor|fl|'  
      r'shop|no\.|#|gst|gstin|cin|ph|tel|mob|www|http)\b',
      caseSensitive: false,
    );
    final decorPattern = RegExp(r'^[\-=\*\_\~\s]+$');

    for (final line in lines.take(6)) {
      if (decorPattern.hasMatch(line)) continue;
      if (addressPattern.hasMatch(line)) continue;
      // Must have at least 3 alphabetic characters
      final letters = line.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      if (letters.length >= 3) return line;
    }
    return null;
  }

  // FIX: two-pass with priority.
  // Pass 1: prefer lines matching "grand total" / "amount payable" keywords.
  // Pass 2: fallback to any total keyword.
  // Pass 3: last resort — largest amount with minimum threshold of 1.0.
  static double? _extractTotal(List<String> lines) {
    // Pass 1: strong total keywords
    for (final line in lines) {
      if (_grandTotalKeywords.hasMatch(line)) {
        final amount = _extractAmountFromLine(line);
        if (amount != null && amount > 1.0) return amount;
      }
    }
    // Pass 2: any total keyword
    for (final line in lines) {
      if (_totalKeywords.hasMatch(line)) {
        final amount = _extractAmountFromLine(line);
        if (amount != null && amount > 1.0) return amount;
      }
    }
    // Pass 3: largest amount (minimum 1.0 to skip quantities)
    double? largest;
    for (final line in lines) {
      // Skip lines that look like tax/discount lines with very small amounts
      final amount = _extractAmountFromLine(line);
      if (amount != null && amount > 1.0) {
        if (largest == null || amount > largest) largest = amount;
      }
    }
    return largest;
  }

  static double? _extractAmountFromLine(String line) {
    final matches = _pricePattern.allMatches(line);
    double? best;
    for (final match in matches) {
      final raw = match.group(1) ?? match.group(2) ?? match.group(3);
      if (raw == null) continue;
      final value = double.tryParse(raw.replaceAll(',', ''));
      if (value != null && value > 0) {
        if (best == null || value > best) best = value;
      }
    }
    return best;
  }

  // FIX: strip time-pattern matches from text before trying DD/MM/YYYY
  // so that a timestamp like "12:30" isn't mistaken for day 12, month 30.
  static DateTime? _extractDate(String rawText) {
    // Remove time strings to avoid DD/MM false matches
    final textNoTime = rawText.replaceAll(_timePattern, '');

    // Pattern 0: DD/MM/YYYY or DD-MM-YYYY
    final m1 = _datePatterns[0].firstMatch(textNoTime);
    if (m1 != null) {
      final d = int.tryParse(m1.group(1)!);
      final mon = int.tryParse(m1.group(2)!);
      final y = int.tryParse(m1.group(3)!);
      if (d != null && mon != null && y != null &&
          mon >= 1 && mon <= 12 && d >= 1 && d <= 31 &&
          y >= 2000 && y <= 2100) {
        return DateTime(y, mon, d);
      }
    }
    // Pattern 1: YYYY-MM-DD
    final m2 = _datePatterns[1].firstMatch(textNoTime);
    if (m2 != null) {
      final y = int.tryParse(m2.group(1)!);
      final mon = int.tryParse(m2.group(2)!);
      final d = int.tryParse(m2.group(3)!);
      if (y != null && mon != null && d != null &&
          mon >= 1 && mon <= 12 && d >= 1 && d <= 31 &&
          y >= 2000 && y <= 2100) {
        return DateTime(y, mon, d);
      }
    }
    // Pattern 2: DD Mon YYYY
    final m3 = _datePatterns[2].firstMatch(rawText);
    if (m3 != null) {
      final d = int.tryParse(m3.group(1)!);
      final month = _monthNames[m3.group(2)!.toLowerCase().substring(0, 3)];
      final y = int.tryParse(m3.group(3)!);
      if (d != null && month != null && y != null) return DateTime(y, month, d);
    }
    // Pattern 3: Mon DD, YYYY
    final m4 = _datePatterns[3].firstMatch(rawText);
    if (m4 != null) {
      final month = _monthNames[m4.group(1)!.toLowerCase().substring(0, 3)];
      final d = int.tryParse(m4.group(2)!);
      final y = int.tryParse(m4.group(3)!);
      if (month != null && d != null && y != null) return DateTime(y, month, d);
    }
    return null;
  }

  static List<LineItem> _extractLineItems(List<String> lines) {
    final items = <LineItem>[];
    final start = lines.length > 6 ? 3 : 0;
    final end = lines.length > 6 ? lines.length - 3 : lines.length;

    // FIX: also skip lines that are single digits (quantities) or look like
    // phone numbers (10+ consecutive digits)
    final quantityOrPhonePattern = RegExp(r'^\d{1,2}$|\d{10,}');

    for (var i = start; i < end; i++) {
      final line = lines[i];
      if (_totalKeywords.hasMatch(line)) continue;
      if (quantityOrPhonePattern.hasMatch(line)) continue;
      if (RegExp(
        r'(?:tax|gst|cgst|sgst|igst|cess|discount|change|cash|card|upi|'
        r'tip|service\s*charge|delivery|platform\s*fee)',
        caseSensitive: false,
      ).hasMatch(line)) continue;

      final amount = _extractAmountFromLine(line);
      if (amount != null && amount > 0) {
        var desc = line
            .replaceAll(_pricePattern, '')
            .replaceAll(RegExp(r'[\s]{2,}'), ' ')
            .replaceAll(RegExp(r'^[\s\-:x×*]+|[\s\-:x×*]+$'), '')
            .trim();
        if (desc.length >= 2) {
          items.add(LineItem(description: desc, amount: amount));
        }
      }
    }
    return items;
  }
}

// ── State Notifier ──

class ScannerNotifier extends StateNotifier<ScannerState> {
  ScannerNotifier() : super(const ScannerState());

  Future<void> processImage(String imagePath) async {
    state = state.copyWith(
      isProcessing: true,
      clearError: true,
      clearReceiptData: true,
      imagePath: imagePath,
    );

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      try {
        final recognizedText = await textRecognizer.processImage(inputImage);
        final rawText = recognizedText.text;

        if (rawText.trim().isEmpty) {
          state = state.copyWith(
            isProcessing: false,
            error: 'No text found in the image. Try a clearer photo.',
          );
          return;
        }

        state = state.copyWith(
          isProcessing: false,
          receiptData: ReceiptParser.parse(rawText),
        );
      } finally {
        textRecognizer.close();
      }
    } on Exception catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to process receipt: '
            '${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<String?> saveReceiptImage(String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(p.join(appDir.path, 'receipts'));
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ext = p.extension(sourcePath).isNotEmpty
          ? p.extension(sourcePath)
          : '.jpg';
      final destPath = p.join(receiptsDir.path, 'receipt_$ts$ext');
      await File(sourcePath).copy(destPath);
      return destPath;
    } on Exception {
      return null;
    }
  }

  void updateReceiptData(ReceiptData data) =>
      state = state.copyWith(receiptData: data);

  void reset() => state = const ScannerState();
}

// ── Providers ──

final scannerStateProvider =
    StateNotifierProvider.autoDispose<ScannerNotifier, ScannerState>(
  (ref) => ScannerNotifier(),
);
