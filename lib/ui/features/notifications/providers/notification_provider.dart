import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../services/notification_service.dart';

// ── Data Models ──

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

class NotificationParser {
  const NotificationParser._();

  static const _appNames = <String, String>{
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'com.phonepe.app': 'PhonePe',
    'net.one97.paytm': 'Paytm',
    'in.org.npci.upiapp': 'BHIM',
    'com.amazon.mShop.android.shopping': 'Amazon Pay',
    'com.csam.icici.bank.imobile': 'ICICI Bank',
    'com.sbi.SBIFreedomPlus': 'SBI YONO',
    'com.sbi.lotusintouch': 'SBI YONO',
    'com.axis.mobile': 'Axis Bank',
    'com.bankofbaroda.mconnect': 'Bank of Baroda',
    'com.msf.kbank.mobile': 'Kotak Bank',
    'com.unionbankofindia.unionbank': 'Union Bank',
    'com.infrasofttech.indianbank': 'Indian Bank',
    'com.canarabank.mobility': 'Canara Bank',
    'com.hdfc.hdfcbankmobilebanking': 'HDFC Bank',
    'com.snapwork.hdfc': 'HDFC PayZapp',
    'com.idbi.mPassbook': 'IDBI Bank',
    'com.pnb.mbanking': 'PNB',
    'com.indusind.mobile': 'IndusInd Bank',
    'com.yesbank.yesmobile': 'Yes Bank',
    'com.android.mms': 'SMS',
    'com.google.android.apps.messaging': 'SMS',
    'com.samsung.android.messaging': 'SMS',
    'com.miui.sms': 'SMS',
    'com.oneplus.mms': 'SMS',
  };

  static const _appIcons = <String, String>{
    'com.google.android.apps.nbu.paisa.user': 'gpay',
    'com.phonepe.app': 'phonepe',
    'net.one97.paytm': 'paytm',
    'in.org.npci.upiapp': 'bhim',
    'com.amazon.mShop.android.shopping': 'amazonpay',
  };

  // ── Amount patterns ──
  // FIX: tightened so bare integers only match when adjacent to a currency
  // symbol or have a decimal part — prevents quantities, barcodes, years from
  // being picked up as amounts.
  static final _amountPatternStrict = RegExp(
    // currency-symbol then number (with or without decimals)
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'|'
    // number then currency symbol
    r'([\d,]+\.\d{1,2})\s*(?:Rs\.?|INR|\u20B9)?'
    r'|'
    // number with decimal followed by nothing (bare price like 249.00)
    r'\b([\d,]+\.\d{2})\b',
    caseSensitive: false,
  );

  // Kept for generic amount extraction only when strict fails
  static final _amountPatternLoose = RegExp(
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'|'
    r'([\d,]+(?:\.\d{1,2})?)\s*(?:Rs\.?|INR|\u20B9)',
    caseSensitive: false,
  );

  // ── UPI app-specific patterns ──

  static final _gpayPaid = RegExp(
    r'(?:you\s+)?paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );
  static final _gpayReceived = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+from\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );
  static final _phonepePaid = RegExp(
    r'paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+(.+?)(?:\s+on|\s+via|\s*$)',
    caseSensitive: false,
  );
  static final _phonepeReceived = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+from\s+(.+?)(?:\s+on|\s+via|\s*$)',
    caseSensitive: false,
  );
  static final _paytmPaid = RegExp(
    r'paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );
  static final _paytmReceived = RegExp(
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+received\s+from\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );

  // ── Bank SMS patterns ──

  static final _bankDebited = RegExp(
    r'(?:debited\s+(?:by\s+)?(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?))'
    r'|'
    r'(?:(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+(?:has\s+been\s+)?debited)',
    caseSensitive: false,
  );
  static final _bankCredited = RegExp(
    r'(?:credited\s+(?:by\s+)?(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?))'
    r'|'
    r'(?:(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+(?:has\s+been\s+)?credited)',
    caseSensitive: false,
  );
  static final _merchantPattern = RegExp(
    r"(?:at|to|from|towards)\s+([A-Za-z][\w\s&.'-]{1,40}?)(?:\s+on|\s+ref|\s+txn|\s*\.|\s*$)",
    caseSensitive: false,
  );

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

    if (packageName == 'com.google.android.apps.nbu.paisa.user') {
      final r = _tryGpayPatterns(fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    } else if (packageName == 'com.phonepe.app') {
      final r = _tryPhonepePatterns(fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    } else if (packageName == 'net.one97.paytm') {
      final r = _tryPaytmPatterns(fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    }

    if (amount == null) {
      final r = _tryBankPatterns(fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    }

    // Last resort: strict amount pattern (avoids false positives)
    if (amount == null) {
      final match = _amountPatternStrict.firstMatch(fullText);
      if (match != null) {
        final raw = match.group(1) ?? match.group(2) ?? match.group(3);
        if (raw != null) amount = double.tryParse(raw.replaceAll(',', ''));
      }
    }

    if (amount == null || amount <= 0) return null;

    if (merchant == null) {
      final mMatch = _merchantPattern.firstMatch(fullText);
      if (mMatch != null) merchant = mMatch.group(1)?.trim();
    }

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
      final a = double.tryParse(paid.group(1)!.replaceAll(',', ''));
      if (a != null) return _ParseResult(amount: a, merchant: paid.group(2)?.trim(), isDebit: true);
    }
    final recv = _gpayReceived.firstMatch(text);
    if (recv != null) {
      final a = double.tryParse(recv.group(1)!.replaceAll(',', ''));
      if (a != null) return _ParseResult(amount: a, merchant: recv.group(2)?.trim(), isDebit: false);
    }
    return null;
  }

  static _ParseResult? _tryPhonepePatterns(String text) {
    final paid = _phonepePaid.firstMatch(text);
    if (paid != null) {
      final a = double.tryParse(paid.group(1)!.replaceAll(',', ''));
      if (a != null) return _ParseResult(amount: a, merchant: paid.group(2)?.trim(), isDebit: true);
    }
    final recv = _phonepeReceived.firstMatch(text);
    if (recv != null) {
      final a = double.tryParse(recv.group(1)!.replaceAll(',', ''));
      if (a != null) return _ParseResult(amount: a, merchant: recv.group(2)?.trim(), isDebit: false);
    }
    return null;
  }

  static _ParseResult? _tryPaytmPatterns(String text) {
    final paid = _paytmPaid.firstMatch(text);
    if (paid != null) {
      final a = double.tryParse(paid.group(1)!.replaceAll(',', ''));
      if (a != null) return _ParseResult(amount: a, merchant: paid.group(2)?.trim(), isDebit: true);
    }
    final recv = _paytmReceived.firstMatch(text);
    if (recv != null) {
      final a = double.tryParse(recv.group(1)!.replaceAll(',', ''));
      if (a != null) return _ParseResult(amount: a, merchant: recv.group(2)?.trim(), isDebit: false);
    }
    return null;
  }

  static _ParseResult? _tryBankPatterns(String text) {
    final debit = _bankDebited.firstMatch(text);
    if (debit != null) {
      final raw = debit.group(1) ?? debit.group(2);
      if (raw != null) {
        final a = double.tryParse(raw.replaceAll(',', ''));
        if (a != null) {
          final m = _merchantPattern.firstMatch(text);
          return _ParseResult(amount: a, merchant: m?.group(1)?.trim(), isDebit: true);
        }
      }
    }
    final credit = _bankCredited.firstMatch(text);
    if (credit != null) {
      final raw = credit.group(1) ?? credit.group(2);
      if (raw != null) {
        final a = double.tryParse(raw.replaceAll(',', ''));
        if (a != null) {
          final m = _merchantPattern.firstMatch(text);
          return _ParseResult(amount: a, merchant: m?.group(1)?.trim(), isDebit: false);
        }
      }
    }
    return null;
  }
}

class _ParseResult {
  final double amount;
  final String? merchant;
  final bool isDebit;
  const _ParseResult({required this.amount, this.merchant, required this.isDebit});
}

// ── State Notifier ──

class PendingTransactionNotifier
    extends StateNotifier<List<PendingTransaction>> {
  final NotificationService _service;
  StreamSubscription<List<PendingTransaction>>? _subscription;

  PendingTransactionNotifier(this._service) : super(_service.pending) {
    _subscription = _service.pendingStream.listen((list) => state = list);
  }

  void dismiss(String id) => _service.dismiss(id);
  void dismissAll() => _service.dismissAll();
  void markSaved(String id) => _service.markSaved(id);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// ── Providers ──

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = NotificationService(prefs);
  ref.onDispose(service.dispose);
  return service;
});

final isListeningProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefNotificationListener) ?? false;
});

final pendingTransactionsProvider = StateNotifierProvider<
    PendingTransactionNotifier, List<PendingTransaction>>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return PendingTransactionNotifier(service);
});

/// FIX: called on app start to auto-resume listening if it was previously
/// enabled. This is the key function that was missing — the service was never
/// restarted after an app restart even though the pref said enabled=true.
Future<void> initializeIfEnabled(WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final wasEnabled =
      prefs.getBool(AppConstants.prefNotificationListener) ?? false;
  if (!wasEnabled) return;

  final service = ref.read(notificationServiceProvider);
  final started = await service.initialize();
  if (started) {
    ref.read(isListeningProvider.notifier).state = true;
  } else {
    // Permission was revoked — update pref to reflect reality.
    await prefs.setBool(AppConstants.prefNotificationListener, false);
    ref.read(isListeningProvider.notifier).state = false;
  }
}

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

void stopListening(WidgetRef ref) {
  final service = ref.read(notificationServiceProvider);
  service.dispose();
  final prefs = ref.read(sharedPreferencesProvider);
  prefs.setBool(AppConstants.prefNotificationListener, false);
  ref.read(isListeningProvider.notifier).state = false;
}
