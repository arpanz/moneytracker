import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../services/notification_service.dart';

// ── Data Models ─────────────────────────────────────────────────────────────

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

// ── Notification Parser ────────────────────────────────────────────────────────

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
    'com.miui.messaging': 'SMS',
    'com.oneplus.mms': 'SMS',
    'com.coloros.mms': 'SMS',
    'com.messaging.android': 'SMS',
    'com.vivo.mms': 'SMS',
    'com.asus.mms': 'SMS',
    'com.realme.mms': 'SMS',
    'com.transsion.message': 'SMS',
  };

  static const _appIcons = <String, String>{
    'com.google.android.apps.nbu.paisa.user': 'gpay',
    'com.phonepe.app': 'phonepe',
    'net.one97.paytm': 'paytm',
    'in.org.npci.upiapp': 'bhim',
    'com.amazon.mShop.android.shopping': 'amazonpay',
  };

  // ── Amount ──
  static final _amountStrict = RegExp(
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'|'
    r'([\d,]+\.\d{1,2})\s*(?:Rs\.?|INR|\u20B9)?'
    r'|'
    r'\b([\d,]+\.\d{2})\b',
    caseSensitive: false,
  );

  static final _balancePattern = RegExp(
    r'(?:Bal(?:ance)?|Avl\.?\s*Bal)\.?\s*:?\s*(?:Rs\.?|INR|\u20B9)?\s*[\d,]+(?:\.\d{1,2})?',
    caseSensitive: false,
  );

  // ── UPI / Payment app patterns ────────────────────────────────────────────────

  // GPay: "You paid ₹500 to Swiggy on..."
  static final _gpayPaid = RegExp(
    r'(?:you\s+)?paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );
  // GPay: "Received ₹500 from Rahul on..."
  static final _gpayReceived = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+from\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );

  // PhonePe: "paid ₹500 to NAME on/via"
  static final _phonepePaid = RegExp(
    r'paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+(.+?)(?:\s+on|\s+via|\s*$)',
    caseSensitive: false,
  );
  // PhonePe: "received ₹500 from NAME on/via"
  static final _phonepeReceived = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+from\s+(.+?)(?:\s+on|\s+via|\s*$)',
    caseSensitive: false,
  );

  // Paytm title: "Received ₹1000 from NAME"
  static final _paytmReceivedTitle = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+from\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );
  // Paytm body: "₹1000 received from NAME"
  static final _paytmReceivedBody = RegExp(
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+received\s+from\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );
  // Paytm paid: "paid ₹500 to NAME"
  static final _paytmPaid = RegExp(
    r'paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+(.+?)(?:\s+on|\s*$)',
    caseSensitive: false,
  );

  // ── BHIM UPI patterns ────────────────────────────────────────────────────────────
  //
  // BHIM notification formats observed:
  //
  // Debit:
  //   Title: "₹500 Paid"  OR  "Transaction Successful"
  //   Body:  "Transaction successful. Paid ₹500 to Swiggy using BHIM UPI."
  //          "You paid ₹500 to merchant@upi using BHIM"
  //
  // Credit:
  //   Title: "Money Received"  OR  "₹1,000 Received"
  //   Body:  "₹1,000 received from Rahul Kumar via BHIM UPI. Ref No: 123456789"
  //          "Received ₹1,000 from rahul@upi"

  // Paid ₹X to NAME [using/via BHIM ...]
  static final _bhimPaid = RegExp(
    r'paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+([\w\s@.&-]{1,50}?)'
    r'(?:\s+using|\s+via|\s+through|\s+on|\s+ref|\s*\.\s*|\s*$)',
    caseSensitive: false,
  );
  // You paid ₹X to NAME
  static final _bhimYouPaid = RegExp(
    r'you\s+paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+to\s+([\w\s@.&-]{1,50}?)'
    r'(?:\s+using|\s+via|\s+through|\s+on|\s+ref|\s*\.\s*|\s*$)',
    caseSensitive: false,
  );
  // ₹X received from NAME [via/using BHIM ...]
  static final _bhimReceived = RegExp(
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+received\s+from\s+([\w\s@.&-]{1,50}?)'
    r'(?:\s+via|\s+using|\s+through|\s+on|\s+ref|\s*\.\s*|\s*$)',
    caseSensitive: false,
  );
  // received ₹X from NAME
  static final _bhimReceivedAlt = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+from\s+([\w\s@.&-]{1,50}?)'
    r'(?:\s+via|\s+using|\s+through|\s+on|\s+ref|\s*\.\s*|\s*$)',
    caseSensitive: false,
  );
  // Title-only amount: "₹500 Paid" or "₹1,000 Received"
  static final _bhimTitleAmount = RegExp(
    r'^(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+(paid|received)$',
    caseSensitive: false,
  );

  // ── Generic fallbacks ─────────────────────────────────────────────────────────────
  //
  // FIX: Added 'using', 'via', 'upi', 'ref' as terminators so BHIM/Amazon
  // notifications don't accidentally consume the app-name suffix as the
  // merchant name or swallow extra text into the amount group.

  static final _genericReceived = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'(?:\s+from\s+([\w\s]+?))?'
    r'(?:\s+on|\s+via|\s+using|\s+upi|\s+ref|\s*$)',
    caseSensitive: false,
  );
  static final _genericPaid = RegExp(
    r'(?:paid|sent)\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'(?:\s+to\s+([\w\s]+?))?'
    r'(?:\s+on|\s+via|\s+using|\s+upi|\s+ref|\s*$)',
    caseSensitive: false,
  );

  // ── Bank SMS patterns ────────────────────────────────────────────────────────────────

  static final _bankCredited = RegExp(
    r'credited\s+(?:with\s+|by\s+)?(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'|'
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+(?:has\s+been\s+)?credited'
    r'|'
    r'deposited\s+(?:in\s+your\s+)?(?:[\w\s]+?\s+)?(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'|'
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+deposited',
    caseSensitive: false,
  );

  static final _bankDebited = RegExp(
    r'debited\s+(?:with\s+|by\s+)?(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'|'
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+(?:has\s+been\s+)?debited'
    r'|'
    r'withdrawn\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // ── Merchant patterns ──────────────────────────────────────────────────────────────

  static final _merchantKeyword = RegExp(
    r"(?:at|to|from|towards)\s+([A-Za-z][\w\s&.'-]{1,40}?)(?:\s+on|\s+ref|\s+txn|\s+via|\s+using|\s*\.|\s*$)",
    caseSensitive: false,
  );
  static final _merchantFrom = RegExp(
    r'from\s+([A-Za-z][\w\s]{1,30}?)(?:\s+on|\s+via|\s+using|\s*$)',
    caseSensitive: false,
  );
  static final _merchantSender = RegExp(r'-\s*([A-Z][A-Z0-9]{1,15})\s*$');
  static final _merchantInfo = RegExp(
    r'Info:\s*([A-Za-z][\w\s&.-]{1,40}?)(?:\s*\.|\s*$)',
    caseSensitive: false,
  );

  // ── Entry point ──────────────────────────────────────────────────────────────

  static PendingTransaction? parseNotification(
    String packageName,
    String title,
    String text,
  ) {
    final rawFull = '$title $text'.trim();
    if (rawFull.isEmpty) return null;

    // Strip balance segment so it can't pollute amount extraction
    final fullText = rawFull.replaceAll(_balancePattern, '').trim();

    final appName = _appNames[packageName] ?? packageName;
    final appIcon = _appIcons[packageName];

    double? amount;
    String? merchant;
    bool? isDebit;

    // 1. App-specific patterns
    if (packageName == 'com.google.android.apps.nbu.paisa.user') {
      final r = _tryGpayPatterns(fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    } else if (packageName == 'com.phonepe.app') {
      final r = _tryPhonepePatterns(fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    } else if (packageName == 'net.one97.paytm') {
      final r = _tryPaytmPatterns(fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    } else if (packageName == 'in.org.npci.upiapp') {
      final r = _tryBhimPatterns(title, fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    }

    // 2. Bank SMS patterns
    if (amount == null) {
      final r = _tryBankPatterns(fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    }

    // 3. Generic UPI fallback (covers Amazon Pay, lesser-known UPI apps, SMS)
    if (amount == null) {
      final r = _tryGenericUpiPatterns(fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    }

    // 4. Last resort: grab any currency amount
    if (amount == null) {
      final match = _amountStrict.firstMatch(fullText);
      if (match != null) {
        final raw = match.group(1) ?? match.group(2) ?? match.group(3);
        if (raw != null) amount = double.tryParse(raw.replaceAll(',', ''));
      }
    }

    if (amount == null || amount <= 0) return null;

    // Merchant extraction: keyword → title "from NAME" → trailing sender → Info:
    if (merchant == null) {
      final m1 = _merchantKeyword.firstMatch(fullText);
      if (m1 != null) {
        merchant = m1.group(1)?.trim();
      } else {
        final m2 = _merchantFrom.firstMatch(title);
        if (m2 != null) {
          merchant = m2.group(1)?.trim();
        } else {
          final m3 = _merchantSender.firstMatch(rawFull);
          if (m3 != null) {
            merchant = m3.group(1)?.trim();
          } else {
            final m4 = _merchantInfo.firstMatch(fullText);
            if (m4 != null) merchant = m4.group(1)?.trim();
          }
        }
      }
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
      rawText: rawFull,
    );
  }

  // ── GPay ──
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

  // ── PhonePe ──
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

  // ── Paytm ──
  static _ParseResult? _tryPaytmPatterns(String text) {
    final recvTitle = _paytmReceivedTitle.firstMatch(text);
    if (recvTitle != null) {
      final a = double.tryParse(recvTitle.group(1)!.replaceAll(',', ''));
      if (a != null) return _ParseResult(amount: a, merchant: recvTitle.group(2)?.trim(), isDebit: false);
    }
    final recvBody = _paytmReceivedBody.firstMatch(text);
    if (recvBody != null) {
      final a = double.tryParse(recvBody.group(1)!.replaceAll(',', ''));
      if (a != null) return _ParseResult(amount: a, merchant: recvBody.group(2)?.trim(), isDebit: false);
    }
    final paid = _paytmPaid.firstMatch(text);
    if (paid != null) {
      final a = double.tryParse(paid.group(1)!.replaceAll(',', ''));
      if (a != null) return _ParseResult(amount: a, merchant: paid.group(2)?.trim(), isDebit: true);
    }
    return null;
  }

  // ── BHIM UPI ──
  //
  // Tries patterns in priority order:
  //   1. "You paid ₹X to NAME using BHIM"   → debit
  //   2. "paid ₹X to NAME using BHIM"        → debit
  //   3. "₹X received from NAME via BHIM"    → credit
  //   4. "received ₹X from NAME"             → credit
  //   5. Title "₹X Paid" + body for merchant  → debit  (title-only fallback)
  //   6. Title "₹X Received"                 → credit (title-only fallback)
  static _ParseResult? _tryBhimPatterns(String title, String text) {
    // 1 & 2 — debit with merchant
    for (final re in [_bhimYouPaid, _bhimPaid]) {
      final m = re.firstMatch(text);
      if (m != null) {
        final a = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (a != null) return _ParseResult(amount: a, merchant: m.group(2)?.trim(), isDebit: true);
      }
    }
    // 3 & 4 — credit with merchant
    for (final re in [_bhimReceived, _bhimReceivedAlt]) {
      final m = re.firstMatch(text);
      if (m != null) {
        final a = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (a != null) return _ParseResult(amount: a, merchant: m.group(2)?.trim(), isDebit: false);
      }
    }
    // 5 & 6 — title-only amount (e.g. "₹500 Paid" title, body has merchant)
    final titleMatch = _bhimTitleAmount.firstMatch(title.trim());
    if (titleMatch != null) {
      final a = double.tryParse(titleMatch.group(1)!.replaceAll(',', ''));
      final verb = titleMatch.group(2)?.toLowerCase();
      if (a != null && verb != null) {
        // Try to pull merchant from body text
        final mBody = _merchantKeyword.firstMatch(text);
        return _ParseResult(
          amount: a,
          merchant: mBody?.group(1)?.trim(),
          isDebit: verb == 'paid',
        );
      }
    }
    return null;
  }

  // ── Generic UPI ──
  static _ParseResult? _tryGenericUpiPatterns(String text) {
    final recv = _genericReceived.firstMatch(text);
    if (recv != null) {
      final a = double.tryParse(recv.group(1)!.replaceAll(',', ''));
      if (a != null) return _ParseResult(amount: a, merchant: recv.group(2)?.trim(), isDebit: false);
    }
    final paid = _genericPaid.firstMatch(text);
    if (paid != null) {
      final a = double.tryParse(paid.group(1)!.replaceAll(',', ''));
      if (a != null) return _ParseResult(amount: a, merchant: paid.group(2)?.trim(), isDebit: true);
    }
    return null;
  }

  // ── Bank SMS ──
  static _ParseResult? _tryBankPatterns(String text) {
    final credit = _bankCredited.firstMatch(text);
    if (credit != null) {
      final raw = credit.group(1) ?? credit.group(2) ?? credit.group(3) ?? credit.group(4);
      if (raw != null) {
        final a = double.tryParse(raw.replaceAll(',', ''));
        if (a != null) {
          final m = _merchantKeyword.firstMatch(text);
          return _ParseResult(amount: a, merchant: m?.group(1)?.trim(), isDebit: false);
        }
      }
    }
    final debit = _bankDebited.firstMatch(text);
    if (debit != null) {
      final raw = debit.group(1) ?? debit.group(2) ?? debit.group(3);
      if (raw != null) {
        final a = double.tryParse(raw.replaceAll(',', ''));
        if (a != null) {
          final m = _merchantKeyword.firstMatch(text);
          return _ParseResult(amount: a, merchant: m?.group(1)?.trim(), isDebit: true);
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

// ── State Notifier ────────────────────────────────────────────────────────────────

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

// ── Providers ───────────────────────────────────────────────────────────────────

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

Future<void> initializeIfEnabled(WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final wasEnabled =
      prefs.getBool(AppConstants.prefNotificationListener) ?? false;
  if (!wasEnabled) return;

  final service = ref.read(notificationServiceProvider);
  final isFirstAfterGrant = service.consumeFirstLaunchAfterGrant();

  try {
    final started = await service.initialize(delayForBind: isFirstAfterGrant);
    if (started) {
      ref.read(isListeningProvider.notifier).state = true;
    } else {
      await prefs.setBool(AppConstants.prefNotificationListener, false);
      ref.read(isListeningProvider.notifier).state = false;
    }
  } catch (_) {
    await prefs.setBool(AppConstants.prefNotificationListener, false);
    ref.read(isListeningProvider.notifier).state = false;
  }
}

Future<bool> startListening(WidgetRef ref) async {
  final service = ref.read(notificationServiceProvider);
  try {
    final granted = await service.isPermissionGranted();
    if (!granted) {
      final result = await service.requestPermission();
      if (!result) return false;
      service.markFirstLaunchAfterGrant();
    }
    final started = await service.initialize(delayForBind: !granted);
    if (started) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(AppConstants.prefNotificationListener, true);
      ref.read(isListeningProvider.notifier).state = true;
    }
    return started;
  } catch (_) {
    return false;
  }
}

void stopListening(WidgetRef ref) {
  final service = ref.read(notificationServiceProvider);
  service.stop();
  final prefs = ref.read(sharedPreferencesProvider);
  prefs.setBool(AppConstants.prefNotificationListener, false);
  ref.read(isListeningProvider.notifier).state = false;
}
