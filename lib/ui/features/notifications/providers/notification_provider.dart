import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../services/notification_service.dart';

// ── Data Models ──

/// A transaction detected from a payment notification, pending user review.
class PendingTransaction {
  final String id;
  final String appName;
  final String? appIcon;
  final double amount;
  final String? merchant;
  final DateTime timestamp;
  final bool isDebit;
  final String rawText;

  const PendingTransaction({
    required this.id,
    required this.appName,
    this.appIcon,
    required this.amount,
    this.merchant,
    required this.timestamp,
    required this.isDebit,
    required this.rawText,
  });

  PendingTransaction copyWith({
    String? id,
    String? appName,
    String? appIcon,
    double? amount,
    String? merchant,
    DateTime? timestamp,
    bool? isDebit,
    String? rawText,
  }) {
    return PendingTransaction(
      id: id ?? this.id,
      appName: appName ?? this.appName,
      appIcon: appIcon ?? this.appIcon,
      amount: amount ?? this.amount,
      merchant: merchant ?? this.merchant,
      timestamp: timestamp ?? this.timestamp,
      isDebit: isDebit ?? this.isDebit,
      rawText: rawText ?? this.rawText,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'appName': appName,
        'appIcon': appIcon,
        'amount': amount,
        'merchant': merchant,
        'timestamp': timestamp.toIso8601String(),
        'isDebit': isDebit,
        'rawText': rawText,
      };

  factory PendingTransaction.fromJson(Map<String, dynamic> json) {
    return PendingTransaction(
      id: json['id'] as String,
      appName: json['appName'] as String,
      appIcon: json['appIcon'] as String?,
      amount: (json['amount'] as num).toDouble(),
      merchant: json['merchant'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isDebit: json['isDebit'] as bool,
      rawText: json['rawText'] as String,
    );
  }
}

// ── Notification Parser ──

/// Stateless parser that extracts payment information from notification text
/// across common Indian UPI and banking apps.
class NotificationParser {
  const NotificationParser._();

  /// Friendly app name mapping from package names.
  static const _appNames = <String, String>{
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'com.phonepe.app': 'PhonePe',
    'net.one97.paytm': 'Paytm',
    'in.org.npci.upiapp': 'BHIM',
    'com.csam.icici.bank.imobile': 'ICICI Bank',
    'com.sbi.SBIFreedomPlus': 'SBI YONO',
    'com.axis.mobile': 'Axis Bank',
    'com.bankofbaroda.mconnect': 'Bank of Baroda',
    'com.msf.kbank.mobile': 'Kotak Bank',
    'com.unionbankofindia.unionbank': 'Union Bank',
    'com.infrasofttech.indianbank': 'Indian Bank',
    'com.canaaboretum': 'Canara Bank',
    'com.lcode.hdfc': 'HDFC Bank',
    'com.snapwork.hdfc': 'HDFC PayZapp',
  };

  /// App icon identifiers (for mapping to local assets or icon fonts).
  static const _appIcons = <String, String>{
    'com.google.android.apps.nbu.paisa.user': 'gpay',
    'com.phonepe.app': 'phonepe',
    'net.one97.paytm': 'paytm',
    'in.org.npci.upiapp': 'bhim',
  };

  // ── Amount patterns ──

  /// Matches Rs./INR followed by amount, or amount followed by Rs./INR
  static final _amountPattern = RegExp(
    r'(?:Rs\.?|INR|Rupees)\s*([\d,]+(?:\.\d{1,2})?)'
    r'|'
    r'([\d,]+(?:\.\d{1,2})?)\s*(?:Rs\.?|INR|Rupees)',
    caseSensitive: false,
  );

  // ── UPI app patterns ──

  /// Google Pay: "You paid Rs.X to Y" / "Received Rs.X from Y"
  static final _gpayPaid = RegExp(
    r'(?:you\s+)?paid\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );
  static final _gpayReceived = RegExp(
    r'received\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\s+from\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );

  /// PhonePe: "Paid Rs.X to Y" / "Received Rs.X from Y"
  static final _phonepePaid = RegExp(
    r'paid\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+(.+?)(?:\s+on|\s+via|\s*$)',
    caseSensitive: false,
  );
  static final _phonepeReceived = RegExp(
    r'received\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\s+from\s+(.+?)(?:\s+on|\s+via|\s*$)',
    caseSensitive: false,
  );

  /// Paytm: "Paid Rs.X to Y" / "Rs.X received from Y"
  static final _paytmPaid = RegExp(
    r'paid\s+(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );
  static final _paytmReceived = RegExp(
    r'(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\s+received\s+from\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );

  // ── Bank SMS / notification patterns ──

  /// "debited by Rs.X" / "Rs.X debited"
  static final _bankDebited = RegExp(
    r'(?:debited\s+(?:by\s+)?(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?))'
    r'|'
    r'(?:(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\s+(?:has\s+been\s+)?debited)',
    caseSensitive: false,
  );

  /// "credited by Rs.X" / "Rs.X credited"
  static final _bankCredited = RegExp(
    r'(?:credited\s+(?:by\s+)?(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?))'
    r'|'
    r'(?:(?:Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)\s+(?:has\s+been\s+)?credited)',
    caseSensitive: false,
  );

  /// Extract merchant from bank notifications: "at Y" / "to Y" / "from Y"
  static final _merchantPattern = RegExp(
    r"(?:at|to|from|towards)\s+([A-Za-z][\w\s&.'-]{1,40}?)(?:\s+on|\s+ref|\s+txn|\s*\.|\s*$)",
    caseSensitive: false,
  );

  /// Attempt to parse a notification into a [PendingTransaction].
  /// Returns `null` if the notification is not a payment notification.
  static PendingTransaction? parseNotification(
    String packageName,
    String title,
    String text,
  ) {
    final fullText = '$title $text'.trim();
    if (fullText.isEmpty) return null;

    final appName = _appNames[packageName] ?? packageName;
    final appIcon = _appIcons[packageName];

    double? amount;
    String? merchant;
    bool? isDebit;

    // Try UPI app-specific patterns first
    if (packageName == 'com.google.android.apps.nbu.paisa.user') {
      final result = _tryGpayPatterns(fullText);
      if (result != null) {
        amount = result.amount;
        merchant = result.merchant;
        isDebit = result.isDebit;
      }
    } else if (packageName == 'com.phonepe.app') {
      final result = _tryPhonepePatterns(fullText);
      if (result != null) {
        amount = result.amount;
        merchant = result.merchant;
        isDebit = result.isDebit;
      }
    } else if (packageName == 'net.one97.paytm') {
      final result = _tryPaytmPatterns(fullText);
      if (result != null) {
        amount = result.amount;
        merchant = result.merchant;
        isDebit = result.isDebit;
      }
    }

    // Fall back to generic bank patterns
    if (amount == null) {
      final result = _tryBankPatterns(fullText);
      if (result != null) {
        amount = result.amount;
        merchant = result.merchant;
        isDebit = result.isDebit;
      }
    }

    // Last resort: just try to extract an amount
    if (amount == null) {
      final amountMatch = _amountPattern.firstMatch(fullText);
      if (amountMatch != null) {
        final raw = amountMatch.group(1) ?? amountMatch.group(2);
        if (raw != null) {
          amount = double.tryParse(raw.replaceAll(',', ''));
        }
      }
    }

    // If we still have no amount, this isn't a payment notification
    if (amount == null || amount <= 0) return null;

    // Try to extract merchant if not found yet
    if (merchant == null) {
      final mMatch = _merchantPattern.firstMatch(fullText);
      if (mMatch != null) {
        merchant = mMatch.group(1)?.trim();
      }
    }

    // Default to debit if direction unknown
    isDebit ??= true;

    final id = '${DateTime.now().millisecondsSinceEpoch}_${amount.hashCode}';

    return PendingTransaction(
      id: id,
      appName: appName,
      appIcon: appIcon,
      amount: amount,
      merchant: merchant,
      timestamp: DateTime.now(),
      isDebit: isDebit,
      rawText: fullText,
    );
  }

  static _ParseResult? _tryGpayPatterns(String text) {
    final paid = _gpayPaid.firstMatch(text);
    if (paid != null) {
      final amount = double.tryParse(paid.group(1)!.replaceAll(',', ''));
      if (amount != null) {
        return _ParseResult(amount: amount, merchant: paid.group(2)?.trim(), isDebit: true);
      }
    }
    final received = _gpayReceived.firstMatch(text);
    if (received != null) {
      final amount = double.tryParse(received.group(1)!.replaceAll(',', ''));
      if (amount != null) {
        return _ParseResult(amount: amount, merchant: received.group(2)?.trim(), isDebit: false);
      }
    }
    return null;
  }

  static _ParseResult? _tryPhonepePatterns(String text) {
    final paid = _phonepePaid.firstMatch(text);
    if (paid != null) {
      final amount = double.tryParse(paid.group(1)!.replaceAll(',', ''));
      if (amount != null) {
        return _ParseResult(amount: amount, merchant: paid.group(2)?.trim(), isDebit: true);
      }
    }
    final received = _phonepeReceived.firstMatch(text);
    if (received != null) {
      final amount = double.tryParse(received.group(1)!.replaceAll(',', ''));
      if (amount != null) {
        return _ParseResult(amount: amount, merchant: received.group(2)?.trim(), isDebit: false);
      }
    }
    return null;
  }

  static _ParseResult? _tryPaytmPatterns(String text) {
    final paid = _paytmPaid.firstMatch(text);
    if (paid != null) {
      final amount = double.tryParse(paid.group(1)!.replaceAll(',', ''));
      if (amount != null) {
        return _ParseResult(amount: amount, merchant: paid.group(2)?.trim(), isDebit: true);
      }
    }
    final received = _paytmReceived.firstMatch(text);
    if (received != null) {
      final amount = double.tryParse(received.group(1)!.replaceAll(',', ''));
      if (amount != null) {
        return _ParseResult(amount: amount, merchant: received.group(2)?.trim(), isDebit: false);
      }
    }
    return null;
  }

  static _ParseResult? _tryBankPatterns(String text) {
    // Check debit
    final debit = _bankDebited.firstMatch(text);
    if (debit != null) {
      final raw = debit.group(1) ?? debit.group(2);
      if (raw != null) {
        final amount = double.tryParse(raw.replaceAll(',', ''));
        if (amount != null) {
          final mMatch = _merchantPattern.firstMatch(text);
          return _ParseResult(
            amount: amount,
            merchant: mMatch?.group(1)?.trim(),
            isDebit: true,
          );
        }
      }
    }
    // Check credit
    final credit = _bankCredited.firstMatch(text);
    if (credit != null) {
      final raw = credit.group(1) ?? credit.group(2);
      if (raw != null) {
        final amount = double.tryParse(raw.replaceAll(',', ''));
        if (amount != null) {
          final mMatch = _merchantPattern.firstMatch(text);
          return _ParseResult(
            amount: amount,
            merchant: mMatch?.group(1)?.trim(),
            isDebit: false,
          );
        }
      }
    }
    return null;
  }
}

/// Internal parse result holder.
class _ParseResult {
  final double amount;
  final String? merchant;
  final bool isDebit;

  const _ParseResult({
    required this.amount,
    this.merchant,
    required this.isDebit,
  });
}

// ── State Notifier ──

class PendingTransactionNotifier extends StateNotifier<List<PendingTransaction>> {
  final NotificationService _service;

  StreamSubscription<List<PendingTransaction>>? _subscription;

  PendingTransactionNotifier(this._service)
      : super(_service.pending) {
    _subscription = _service.pendingStream.listen((list) {
      state = list;
    });
  }

  void dismiss(String id) {
    _service.dismiss(id);
  }

  void dismissAll() {
    _service.dismissAll();
  }

  void markSaved(String id) {
    _service.markSaved(id);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// ── Providers ──

/// Provides the [NotificationService] singleton, backed by SharedPreferences.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = NotificationService(prefs);
  ref.onDispose(service.dispose);
  return service;
});

/// Whether the notification listener is actively running.
final isListeningProvider = StateProvider<bool>((ref) {
  // Read persisted preference
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefNotificationListener) ?? false;
});

/// Manages the list of pending transactions detected from notifications.
final pendingTransactionsProvider = StateNotifierProvider<
    PendingTransactionNotifier, List<PendingTransaction>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return PendingTransactionNotifier(service);
});

/// Start listening for payment notifications.
Future<bool> startListening(WidgetRef ref) async {
  final service = ref.read(notificationServiceProvider);
  final granted = await service.isPermissionGranted();

  if (!granted) {
    final result = await service.requestPermission();
    if (!result) return false;
  }

  final started = await service.initialize();
  if (started) {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConstants.prefNotificationListener, true);
    ref.read(isListeningProvider.notifier).state = true;
  }
  return started;
}

/// Stop listening for payment notifications.
void stopListening(WidgetRef ref) {
  final service = ref.read(notificationServiceProvider);
  service.dispose();
  final prefs = ref.read(sharedPreferencesProvider);
  prefs.setBool(AppConstants.prefNotificationListener, false);
  ref.read(isListeningProvider.notifier).state = false;
}
