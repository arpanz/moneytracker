import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// ── Data Models ──

/// A single line item parsed from a receipt.
class LineItem {
  final String description;
  final double amount;

  const LineItem({required this.description, required this.amount});

  LineItem copyWith({String? description, double? amount}) {
    return LineItem(
      description: description ?? this.description,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'amount': amount,
      };

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
      );
}

/// Structured data extracted from a receipt image.
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
  }) {
    return ReceiptData(
      merchantName: merchantName ?? this.merchantName,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      lineItems: lineItems ?? this.lineItems,
    );
  }
}

/// Immutable state for the scanner feature.
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
  }) {
    return ScannerState(
      isProcessing: isProcessing ?? this.isProcessing,
      receiptData: clearReceiptData ? null : (receiptData ?? this.receiptData),
      error: clearError ? null : (error ?? this.error),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
    );
  }
}

// ── Receipt Text Parser ──

/// Stateless utility that extracts structured data from raw OCR text.
class ReceiptParser {
  const ReceiptParser._();

  /// Currency amount patterns: Rs., Rs, INR, $, USD, numbers after total keywords.
  static final _amountPattern = RegExp(
    r'(?:Rs\.?|INR|\$|USD)?\s*(\d{1,3}(?:[,.]\d{2,3})*(?:\.\d{1,2})?)'
    r'|'
    r'(\d{1,3}(?:[,.]\d{2,3})*(?:\.\d{1,2})?)\s*(?:Rs\.?|INR|\$|USD)?',
    caseSensitive: false,
  );

  /// Keywords that typically precede the total amount on a receipt.
  static final _totalKeywords = RegExp(
    r'(?:grand\s*total|total\s*amount|total\s*due|net\s*total|total|amount\s*due|'
    r'amount\s*payable|balance\s*due|net\s*payable|you\s*pay|paid)'
    r'\s*:?\s*',
    caseSensitive: false,
  );

  /// Common date format patterns found on Indian and international receipts.
  static final List<RegExp> _datePatterns = [
    // DD/MM/YYYY or DD-MM-YYYY
    RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})'),
    // YYYY/MM/DD or YYYY-MM-DD
    RegExp(r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})'),
    // DD Mon YYYY (e.g., 15 Mar 2026)
    RegExp(
      r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)'
      r'\w*\s+(\d{4})',
      caseSensitive: false,
    ),
    // Mon DD, YYYY (e.g., Mar 15, 2026)
    RegExp(
      r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)'
      r'\w*\s+(\d{1,2}),?\s+(\d{4})',
      caseSensitive: false,
    ),
  ];

  static const _monthNames = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
    'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
    'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Parse the full OCR text into structured [ReceiptData].
  static ReceiptData parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const ReceiptData();
    }

    final merchantName = _extractMerchant(lines);
    final totalAmount = _extractTotal(lines);
    final date = _extractDate(rawText);
    final lineItems = _extractLineItems(lines);

    return ReceiptData(
      merchantName: merchantName,
      totalAmount: totalAmount,
      date: date,
      lineItems: lineItems,
    );
  }

  /// Merchant name is typically in the first few non-numeric lines.
  static String? _extractMerchant(List<String> lines) {
    for (final line in lines.take(3)) {
      // Skip lines that are mostly numbers or very short
      final stripped = line.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      if (stripped.length >= 3) {
        return line;
      }
    }
    return null;
  }

  /// Look for total amount using keyword matching first, then largest amount.
  static double? _extractTotal(List<String> lines) {
    // First pass: look for lines with total keywords
    for (final line in lines) {
      if (_totalKeywords.hasMatch(line)) {
        final amount = _extractAmountFromLine(line);
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }

    // Second pass: find the largest amount (likely the total)
    double? largest;
    for (final line in lines) {
      final amount = _extractAmountFromLine(line);
      if (amount != null && amount > 0) {
        if (largest == null || amount > largest) {
          largest = amount;
        }
      }
    }
    return largest;
  }

  /// Extract a numeric amount from a single line of text.
  static double? _extractAmountFromLine(String line) {
    final matches = _amountPattern.allMatches(line);
    double? best;
    for (final match in matches) {
      final raw = (match.group(1) ?? match.group(2));
      if (raw == null) continue;
      final cleaned = raw.replaceAll(',', '');
      final value = double.tryParse(cleaned);
      if (value != null && value > 0) {
        if (best == null || value > best) best = value;
      }
    }
    return best;
  }

  /// Try each date pattern against the full text.
  static DateTime? _extractDate(String text) {
    // Pattern 1: DD/MM/YYYY
    final m1 = _datePatterns[0].firstMatch(text);
    if (m1 != null) {
      final d = int.tryParse(m1.group(1)!);
      final m = int.tryParse(m1.group(2)!);
      final y = int.tryParse(m1.group(3)!);
      if (d != null && m != null && y != null && m >= 1 && m <= 12) {
        return DateTime(y, m, d);
      }
    }

    // Pattern 2: YYYY-MM-DD
    final m2 = _datePatterns[1].firstMatch(text);
    if (m2 != null) {
      final y = int.tryParse(m2.group(1)!);
      final m = int.tryParse(m2.group(2)!);
      final d = int.tryParse(m2.group(3)!);
      if (y != null && m != null && d != null && m >= 1 && m <= 12) {
        return DateTime(y, m, d);
      }
    }

    // Pattern 3: DD Mon YYYY
    final m3 = _datePatterns[2].firstMatch(text);
    if (m3 != null) {
      final d = int.tryParse(m3.group(1)!);
      final month = _monthNames[m3.group(2)!.toLowerCase().substring(0, 3)];
      final y = int.tryParse(m3.group(3)!);
      if (d != null && month != null && y != null) {
        return DateTime(y, month, d);
      }
    }

    // Pattern 4: Mon DD, YYYY
    final m4 = _datePatterns[3].firstMatch(text);
    if (m4 != null) {
      final month = _monthNames[m4.group(1)!.toLowerCase().substring(0, 3)];
      final d = int.tryParse(m4.group(2)!);
      final y = int.tryParse(m4.group(3)!);
      if (month != null && d != null && y != null) {
        return DateTime(y, month, d);
      }
    }

    return null;
  }

  /// Extract line items: lines containing both descriptive text and a number.
  static List<LineItem> _extractLineItems(List<String> lines) {
    final items = <LineItem>[];
    // Skip header lines (first 3) and footer lines (last 3)
    final start = lines.length > 6 ? 3 : 0;
    final end = lines.length > 6 ? lines.length - 3 : lines.length;

    for (var i = start; i < end; i++) {
      final line = lines[i];
      // Skip total/subtotal lines
      if (_totalKeywords.hasMatch(line)) continue;
      // Skip lines with common non-item keywords
      if (RegExp(r'(?:tax|gst|cgst|sgst|discount|change|cash|card|upi)',
              caseSensitive: false)
          .hasMatch(line)) {
        continue;
      }

      final amount = _extractAmountFromLine(line);
      if (amount != null && amount > 0) {
        // Remove the numeric part to get the description
        var desc = line
            .replaceAll(_amountPattern, '')
            .replaceAll(RegExp(r'[\s]{2,}'), ' ')
            .replaceAll(RegExp(r'^[\s\-:]+|[\s\-:]+$'), '')
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

  /// Process an image file through ML Kit text recognition and parse results.
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

        final receiptData = ReceiptParser.parse(rawText);
        state = state.copyWith(
          isProcessing: false,
          receiptData: receiptData,
        );
      } finally {
        textRecognizer.close();
      }
    } on Exception catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Failed to process receipt: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  /// Copy the captured/picked image to the app's documents directory for
  /// permanent storage alongside the transaction record.
  Future<String?> saveReceiptImage(String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(p.join(appDir.path, 'receipts'));
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = p.extension(sourcePath).isNotEmpty
          ? p.extension(sourcePath)
          : '.jpg';
      final destPath = p.join(receiptsDir.path, 'receipt_$timestamp$extension');

      await File(sourcePath).copy(destPath);
      return destPath;
    } on Exception {
      return null;
    }
  }

  /// Update the parsed receipt data (e.g. user edits a field in the bottom sheet).
  void updateReceiptData(ReceiptData data) {
    state = state.copyWith(receiptData: data);
  }

  /// Clear all scanner state to start fresh.
  void reset() {
    state = const ScannerState();
  }
}

// ── Providers ──

final scannerStateProvider =
    StateNotifierProvider.autoDispose<ScannerNotifier, ScannerState>(
  (ref) => ScannerNotifier(),
);
