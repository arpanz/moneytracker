import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../config/constants/app_constants.dart';
import '../services/notification_service.dart';

// ── Data Models ──────────────────────────────────────────────────────────────

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

// ── Notification Parser ───────────────────────────────────────────────────────

class NotificationParser {
  const NotificationParser._();

  // ── App metadata ─────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────────────────
  // BALANCE STRIP
  //
  // Must be stripped BEFORE amount parsing. Covers every real-world variant:
  //   Bal:, Bal., Balance:, Avl Bal, Avl.Bal, Avl Bal-, Avl Bal INR,
  //   Clr Bal, Ledger Bal, Mini Stmt, Available Balance, Opening Bal
  // ─────────────────────────────────────────────────────────────────────────
  static final _balancePattern = RegExp(
    r'(?:'
    r'(?:Avl\.?\s*|Available\s+|Clr\.?\s*|Ledger\s+|Opening\s+)?'
    r'Bal(?:ance)?'
    r'|Mini\s+Stmt'
    r')'
    r'[:\-\.\s]*'
    r'(?:Rs\.?|INR|\u20B9)?\s*'
    r'[\d,]+(?:\.\d{1,2})?',
    caseSensitive: false,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // AMOUNT PATTERNS
  //
  // Priority order — most specific first:
  //   1. Currency symbol/code prefix:  ₹1,500  /  Rs.1500  /  INR 1500
  //   2. Currency suffix:              1500.00 INR
  //   3. Bare decimal (last resort):   1500.00
  // ─────────────────────────────────────────────────────────────────────────
  static final _amountWithPrefix = RegExp(
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final _amountWithSuffix = RegExp(
    r'([\d,]+\.\d{1,2})\s*(?:Rs\.?|INR|\u20B9)',
    caseSensitive: false,
  );
  static final _amountBareDecimal = RegExp(
    r'\b([\d,]{1,10}\.\d{2})\b',
  );

  // ─────────────────────────────────────────────────────────────────────────
  // COMMON STOP-WORD SET (used as regex alternation in terminators)
  //
  // When extracting a merchant name we stop at any of these tokens to avoid
  // pulling in noise like "using BHIM UPI", "Ref No 123", "on 19Sep24" etc.
  // ─────────────────────────────────────────────────────────────────────────
  static const _stopWords =
      r'on|via|using|through|ref(?:no|erence)?|txn|upi|imps|neft|rtgs|by|at|for|from|to';

  // Merchant name character class: letters, digits, spaces, common punctuation
  // but NOT @ (UPI VPA) — we stop before a VPA so we don't capture it.
  static const _mChar = r"[A-Za-z0-9 &'.\-]";

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 1 — UPI APP-SPECIFIC (GPay / PhonePe / Paytm / BHIM)
  // ─────────────────────────────────────────────────────────────────────────

  // ── GPay ──────────────────────────────────────────────────────────────────
  // "You paid ₹500 to Swiggy on Google Pay"
  // "Paid ₹500 to merchant@okicici on ..."
  static final _gpayPaid = RegExp(
    r'(?:you\s+)?paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'\s+to\s+($_mChar{1,50}?)(?=\s*(?:@|\s+on|\s*$))',
    caseSensitive: false,
  );
  // "Received ₹500 from Rahul Kumar on Google Pay"
  static final _gpayReceived = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'\s+from\s+($_mChar{1,50}?)(?=\s*(?:@|\s+on|\s*$))',
    caseSensitive: false,
  );

  // ── PhonePe ───────────────────────────────────────────────────────────────
  // "Sent ₹500 to NAME on PhonePe"
  // "paid ₹500 to NAME via PhonePe"
  static final _phonepePaid = RegExp(
    r'(?:paid|sent)\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'\s+to\s+($_mChar{1,50}?)(?=\s*(?:@|\s+on|\s+via|\s*$))',
    caseSensitive: false,
  );
  // "received ₹500 from NAME on/via PhonePe"
  static final _phonepeReceived = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'\s+from\s+($_mChar{1,50}?)(?=\s*(?:@|\s+on|\s+via|\s*$))',
    caseSensitive: false,
  );

  // ── Paytm ─────────────────────────────────────────────────────────────────
  // Title: "Received ₹1000 from NAME"
  static final _paytmReceivedTitle = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'\s+from\s+($_mChar{1,50}?)(?=\s*(?:@|\s+on|\s*$))',
    caseSensitive: false,
  );
  // Body: "₹1000 received from NAME"
  static final _paytmReceivedBody = RegExp(
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+received\s+from\s+'
    r'($_mChar{1,50}?)(?=\s*(?:@|\s+on|\s*$))',
    caseSensitive: false,
  );
  // "paid ₹500 to NAME"
  static final _paytmPaid = RegExp(
    r'paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'\s+to\s+($_mChar{1,50}?)(?=\s*(?:@|\s+on|\s*$))',
    caseSensitive: false,
  );

  // ── BHIM UPI ──────────────────────────────────────────────────────────────
  // Observed notification bodies:
  //   "Transaction successful. Paid ₹500 to Swiggy using BHIM UPI."
  //   "You paid ₹500 to merchant@upi using BHIM"
  //   "₹1,000 received from Rahul Kumar via BHIM UPI. Ref No: 123456789"
  //   "Received ₹1,000 from rahul@upi"
  //   Title "₹500 Paid" with merchant in body

  static final _bhimYouPaid = RegExp(
    r'you\s+paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'\s+to\s+($_mChar{1,50}?)(?=\s*(?:@|\s+using|\s+via|\s+on|\s+ref|\s*[.]|\s*$))',
    caseSensitive: false,
  );
  static final _bhimPaid = RegExp(
    r'paid\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'\s+to\s+($_mChar{1,50}?)(?=\s*(?:@|\s+using|\s+via|\s+on|\s+ref|\s*[.]|\s*$))',
    caseSensitive: false,
  );
  static final _bhimReceived = RegExp(
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+received\s+from\s+'
    r'($_mChar{1,50}?)(?=\s*(?:@|\s+via|\s+using|\s+on|\s+ref|\s*[.]|\s*$))',
    caseSensitive: false,
  );
  static final _bhimReceivedAlt = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'\s+from\s+($_mChar{1,50}?)(?=\s*(?:@|\s+via|\s+using|\s+on|\s+ref|\s*[.]|\s*$))',
    caseSensitive: false,
  );
  // Title: "₹500 Paid" / "₹1,000 Received"
  static final _bhimTitleAmount = RegExp(
    r'^(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+(paid|received)\s*$',
    caseSensitive: false,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 2 — BANK SMS (debit/credit/deposited/withdrawn/purchase)
  //
  // Real formats from SBI, HDFC, ICICI, Axis, Kotak:
  //
  // SBI UPI:
  //   "Dear UPI user A/C X9115 debited by 1046.0 on date 19Sep24 trf to FOODAHOLIC Refno 426363"
  // SBI generic:
  //   "Your A/c XX1234 is debited with Rs.5000 on 12-Jan. Avl Bal Rs.12345"
  // HDFC card:
  //   "Used Rs30.00 On HDFCBank Card 1111 At w507455550@ybl by UPI 487713330175 On 23-09"
  //   "HDFC Bank: Rs.1,500 spent on your Credit Card XX1234 at AMAZON on 12-Jan-24."
  // ICICI:
  //   "ICICI Bank Acct XX004 debited by Rs.19,821 on 11-Mar-24; Info:INF*INFT*..."
  //   "ICICI Bk: INR 500.00 debited from Acct XX1234 on 24-Mar for UPI."
  // Axis:
  //   "INR 2000 debited from A/c no. XX3423 on 05-02 at ECS PAY."
  // Kotak:
  //   "Rs 500 has been debited from your Kotak Bank a/c XX1234 for UPI txn."
  // Generic credit:
  //   "Rs.5,000 credited to your A/c XX1234 on 01-Jan."
  // ─────────────────────────────────────────────────────────────────────────

  // ── Debit variants ────────────────────────────────────────────────────────

  // "debited by/with ₹X" — SBI / ICICI style
  static final _bankDebitedBy = RegExp(
    r'debited\s+(?:by|with)\s+(?:Rs\.?|INR|\u20B9)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  // "₹X debited" / "₹X has been debited"
  static final _bankDebitedSuffix = RegExp(
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+(?:has\s+been\s+)?debited',
    caseSensitive: false,
  );
  // "debited from A/c" — already have amount before keyword in Axis style
  // covered by _bankDebitedBy / _bankDebitedSuffix above.

  // "withdrawn ₹X" — ATM
  static final _bankWithdrawn = RegExp(
    r'(?:withdrawn|withdrawal\s+of)\s+(?:Rs\.?|INR|\u20B9)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // "Used Rs X On BANK Card XXXX At MERCHANT" — HDFC card
  static final _bankCardUsed = RegExp(
    r'(?:used|spent|purchase(?:d)?)\s+(?:Rs\.?|INR|\u20B9)?\s*([\d,]+(?:\.\d{1,2})?)'
    r'(?:[\s\S]{0,60}?)\bat\s+($_mChar{1,50}?)(?=\s*(?:@|\s+on|\s+by|\s+ref|\s*$))',
    caseSensitive: false,
  );

  // "₹X spent on ... at MERCHANT" — HDFC credit card style
  static final _bankSpentAt = RegExp(
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+(?:spent|used|charged)'
    r'(?:[\s\S]{0,60}?)\bat\s+($_mChar{1,50}?)(?=\s*(?:@|\s+on|\s*[.]|\s*$))',
    caseSensitive: false,
  );

  // ── Credit variants ───────────────────────────────────────────────────────

  // "credited with/by ₹X" / "₹X credited"
  static final _bankCreditedBy = RegExp(
    r'credited\s+(?:with\s+|by\s+)?(?:Rs\.?|INR|\u20B9)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final _bankCreditedSuffix = RegExp(
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+(?:has\s+been\s+)?credited',
    caseSensitive: false,
  );

  // "deposited ₹X" / "₹X deposited"
  static final _bankDeposited = RegExp(
    r'deposited\s+(?:Rs\.?|INR|\u20B9)?\s*([\d,]+(?:\.\d{1,2})?)'
    r'|'
    r'(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)\s+deposited',
    caseSensitive: false,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 3 — MERCHANT EXTRACTION (post-amount fallback chain)
  //
  // Priority:
  //   1. "trf to MERCHANT" (SBI UPI)
  //   2. "at MERCHANT" (HDFC card / Axis / ATM)
  //   3. "to MERCHANT" (generic UPI debit)
  //   4. "from MERCHANT" (credit)
  //   5. Info: field (ICICI NEFT/IMPS)
  //   6. Trailing sender code "- SBIINB" / "- HDFCBK"
  // ─────────────────────────────────────────────────────────────────────────

  // "trf to NAME" or "transfer to NAME" — SBI UPI style
  static final _merchantTrfTo = RegExp(
    r'trf(?:r?\s+to|er\s+to)?\s+($_mChar{1,50}?)'
    r'(?=\s*(?:@|\s+Ref|\s+ref|\s+on|\s*$))',
    caseSensitive: false,
  );

  // "at NAME" — card swipe / ATM / Axis
  static final _merchantAt = RegExp(
    r'\bat\s+($_mChar{2,50}?)(?=\s*(?:@|\s+on|\s+by|\s+ref|\s+txn|\s*[.,]|\s*$))',
    caseSensitive: false,
  );

  // "to NAME" — UPI debit
  static final _merchantTo = RegExp(
    r'\bto\s+($_mChar{2,50}?)(?=\s*(?:@|\s+on|\s+via|\s+using|\s+ref|\s*[.,]|\s*$))',
    caseSensitive: false,
  );

  // "from NAME" — UPI credit
  static final _merchantFrom = RegExp(
    r'\bfrom\s+($_mChar{2,50}?)(?=\s*(?:@|\s+on|\s+via|\s+using|\s+ref|\s*[.,]|\s*$))',
    caseSensitive: false,
  );

  // "Info: NAME" or "Info:NAME" — ICICI NEFT/IMPS description
  static final _merchantInfo = RegExp(
    r'Info:\s*($_mChar{2,50}?)(?=\s*(?:[/*]|\s*$))',
    caseSensitive: false,
  );

  // Trailing bank/sender code: "... - SBIINB" / "... -HDFCBK"
  static final _merchantSenderCode = RegExp(
    r'(?:^|\s)-\s*([A-Z][A-Z0-9]{2,15})\s*$',
  );

  // ── UPI VPA cleaner — strips @okaxis / @ybl / @upi etc. from merchant ──
  static final _upiVpaSuffix = RegExp(r'@\S+$');

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 4 — GENERIC UPI FALLBACK
  // (covers Amazon Pay, smaller UPI apps, any SMS not matched above)
  //
  // Hard stops at '@' so UPI VPA IDs like "w507455550@ybl" are not
  // mistaken for merchant names.
  // ─────────────────────────────────────────────────────────────────────────

  static final _genericReceived = RegExp(
    r'received\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'(?:\s+from\s+($_mChar{1,50}?))?'
    r'(?=\s*(?:@|\s+on|\s+via|\s+using|\s+upi|\s+ref|\s*$))',
    caseSensitive: false,
  );
  static final _genericPaid = RegExp(
    r'(?:paid|sent)\s+(?:Rs\.?|INR|\u20B9)\s*([\d,]+(?:\.\d{1,2})?)'
    r'(?:\s+to\s+($_mChar{1,50}?))?'
    r'(?=\s*(?:@|\s+on|\s+via|\s+using|\s+upi|\s+ref|\s*$))',
    caseSensitive: false,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // ENTRY POINT
  // ─────────────────────────────────────────────────────────────────────────

  static PendingTransaction? parseNotification(
    String packageName,
    String title,
    String text,
  ) {
    final rawFull = '$title $text'.trim();
    if (rawFull.isEmpty) return null;

    // Strip all balance/summary segments before any parsing
    final fullText = rawFull.replaceAll(_balancePattern, '').trim();

    final appName = _appNames[packageName] ?? packageName;
    final appIcon = _appIcons[packageName];

    double? amount;
    String? merchant;
    bool? isDebit;

    // ── Layer 1: app-specific ──────────────────────────────────────────────
    _ParseResult? r;
    switch (packageName) {
      case 'com.google.android.apps.nbu.paisa.user':
        r = _tryGpay(fullText);
      case 'com.phonepe.app':
        r = _tryPhonePe(fullText);
      case 'net.one97.paytm':
        r = _tryPaytm(fullText);
      case 'in.org.npci.upiapp':
        r = _tryBhim(title, fullText);
    }
    if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }

    // ── Layer 2: bank SMS ──────────────────────────────────────────────────
    if (amount == null) {
      r = _tryBank(fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    }

    // ── Layer 3: generic UPI / SMS fallback ───────────────────────────────
    if (amount == null) {
      r = _tryGeneric(fullText);
      if (r != null) { amount = r.amount; merchant = r.merchant; isDebit = r.isDebit; }
    }

    // ── Layer 4: last-resort amount grab ──────────────────────────────────
    if (amount == null) {
      amount = _extractAmount(fullText);
    }

    if (amount == null || amount <= 0) return null;

    // ── Layer 5: merchant fallback chain (if not yet extracted) ───────────
    if (merchant == null || merchant.isEmpty) {
      merchant = _extractMerchant(fullText, rawFull, isDebit ?? true);
    }

    // Clean merchant: strip UPI VPA suffix, trim whitespace
    if (merchant != null) {
      merchant = merchant.replaceAll(_upiVpaSuffix, '').trim();
      if (merchant.isEmpty) merchant = null;
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

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 1 PARSERS
  // ─────────────────────────────────────────────────────────────────────────

  static _ParseResult? _tryGpay(String text) {
    final paid = _gpayPaid.firstMatch(text);
    if (paid != null) {
      final a = _parseAmt(paid.group(1));
      if (a != null) return _ParseResult(amount: a, merchant: paid.group(2)?.trim(), isDebit: true);
    }
    final recv = _gpayReceived.firstMatch(text);
    if (recv != null) {
      final a = _parseAmt(recv.group(1));
      if (a != null) return _ParseResult(amount: a, merchant: recv.group(2)?.trim(), isDebit: false);
    }
    return null;
  }

  static _ParseResult? _tryPhonePe(String text) {
    final paid = _phonepePaid.firstMatch(text);
    if (paid != null) {
      final a = _parseAmt(paid.group(1));
      if (a != null) return _ParseResult(amount: a, merchant: paid.group(2)?.trim(), isDebit: true);
    }
    final recv = _phonepeReceived.firstMatch(text);
    if (recv != null) {
      final a = _parseAmt(recv.group(1));
      if (a != null) return _ParseResult(amount: a, merchant: recv.group(2)?.trim(), isDebit: false);
    }
    return null;
  }

  static _ParseResult? _tryPaytm(String text) {
    for (final (re, debit) in [
      (_paytmReceivedTitle, false),
      (_paytmReceivedBody, false),
      (_paytmPaid, true),
    ]) {
      final m = re.firstMatch(text);
      if (m != null) {
        final a = _parseAmt(m.group(1));
        if (a != null) return _ParseResult(amount: a, merchant: m.group(2)?.trim(), isDebit: debit);
      }
    }
    return null;
  }

  static _ParseResult? _tryBhim(String title, String text) {
    // Debit
    for (final re in [_bhimYouPaid, _bhimPaid]) {
      final m = re.firstMatch(text);
      if (m != null) {
        final a = _parseAmt(m.group(1));
        if (a != null) return _ParseResult(amount: a, merchant: m.group(2)?.trim(), isDebit: true);
      }
    }
    // Credit
    for (final re in [_bhimReceived, _bhimReceivedAlt]) {
      final m = re.firstMatch(text);
      if (m != null) {
        final a = _parseAmt(m.group(1));
        if (a != null) return _ParseResult(amount: a, merchant: m.group(2)?.trim(), isDebit: false);
      }
    }
    // Title-only: "₹500 Paid" / "₹500 Received"
    final tm = _bhimTitleAmount.firstMatch(title.trim());
    if (tm != null) {
      final a = _parseAmt(tm.group(1));
      final verb = tm.group(2)?.toLowerCase();
      if (a != null && verb != null) {
        final mBody = _merchantAt.firstMatch(text) ?? _merchantTo.firstMatch(text);
        return _ParseResult(amount: a, merchant: mBody?.group(1)?.trim(), isDebit: verb == 'paid');
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 2 — BANK SMS
  // ─────────────────────────────────────────────────────────────────────────

  static _ParseResult? _tryBank(String text) {
    // ── Debit ──
    // 1. Card used/spent at MERCHANT — most specific, try first
    final cardUsed = _bankCardUsed.firstMatch(text);
    if (cardUsed != null) {
      final a = _parseAmt(cardUsed.group(1));
      if (a != null) return _ParseResult(amount: a, merchant: cardUsed.group(2)?.trim(), isDebit: true);
    }
    final spentAt = _bankSpentAt.firstMatch(text);
    if (spentAt != null) {
      final a = _parseAmt(spentAt.group(1));
      if (a != null) return _ParseResult(amount: a, merchant: spentAt.group(2)?.trim(), isDebit: true);
    }

    // 2. "debited by/with ₹X" — SBI / ICICI
    final debitedBy = _bankDebitedBy.firstMatch(text);
    if (debitedBy != null) {
      final a = _parseAmt(debitedBy.group(1));
      if (a != null) {
        // Look for "trf to" merchant first (SBI UPI), then generic merchant
        final m = _merchantTrfTo.firstMatch(text)
            ?? _merchantAt.firstMatch(text)
            ?? _merchantTo.firstMatch(text)
            ?? _merchantInfo.firstMatch(text);
        return _ParseResult(amount: a, merchant: m?.group(1)?.trim(), isDebit: true);
      }
    }

    // 3. "₹X debited"
    final debitedSuffix = _bankDebitedSuffix.firstMatch(text);
    if (debitedSuffix != null) {
      final a = _parseAmt(debitedSuffix.group(1));
      if (a != null) {
        final m = _merchantTrfTo.firstMatch(text)
            ?? _merchantAt.firstMatch(text)
            ?? _merchantTo.firstMatch(text);
        return _ParseResult(amount: a, merchant: m?.group(1)?.trim(), isDebit: true);
      }
    }

    // 4. ATM withdrawal
    final withdrawn = _bankWithdrawn.firstMatch(text);
    if (withdrawn != null) {
      final a = _parseAmt(withdrawn.group(1));
      if (a != null) {
        final m = _merchantAt.firstMatch(text);
        return _ParseResult(amount: a, merchant: m?.group(1)?.trim(), isDebit: true);
      }
    }

    // ── Credit ──
    final creditedBy = _bankCreditedBy.firstMatch(text);
    if (creditedBy != null) {
      final a = _parseAmt(creditedBy.group(1));
      if (a != null) {
        final m = _merchantFrom.firstMatch(text) ?? _merchantInfo.firstMatch(text);
        return _ParseResult(amount: a, merchant: m?.group(1)?.trim(), isDebit: false);
      }
    }
    final creditedSuffix = _bankCreditedSuffix.firstMatch(text);
    if (creditedSuffix != null) {
      final a = _parseAmt(creditedSuffix.group(1));
      if (a != null) {
        final m = _merchantFrom.firstMatch(text) ?? _merchantInfo.firstMatch(text);
        return _ParseResult(amount: a, merchant: m?.group(1)?.trim(), isDebit: false);
      }
    }
    final deposited = _bankDeposited.firstMatch(text);
    if (deposited != null) {
      final a = _parseAmt(deposited.group(1) ?? deposited.group(2));
      if (a != null) {
        final m = _merchantFrom.firstMatch(text);
        return _ParseResult(amount: a, merchant: m?.group(1)?.trim(), isDebit: false);
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 3 — GENERIC UPI / SMS FALLBACK
  // ─────────────────────────────────────────────────────────────────────────

  static _ParseResult? _tryGeneric(String text) {
    final recv = _genericReceived.firstMatch(text);
    if (recv != null) {
      final a = _parseAmt(recv.group(1));
      if (a != null) return _ParseResult(amount: a, merchant: recv.group(2)?.trim(), isDebit: false);
    }
    final paid = _genericPaid.firstMatch(text);
    if (paid != null) {
      final a = _parseAmt(paid.group(1));
      if (a != null) return _ParseResult(amount: a, merchant: paid.group(2)?.trim(), isDebit: true);
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 4 — LAST-RESORT AMOUNT EXTRACTION
  // ─────────────────────────────────────────────────────────────────────────

  static double? _extractAmount(String text) {
    // Try prefix, then suffix, then bare decimal — in that order
    final m1 = _amountWithPrefix.firstMatch(text);
    if (m1 != null) return _parseAmt(m1.group(1));
    final m2 = _amountWithSuffix.firstMatch(text);
    if (m2 != null) return _parseAmt(m2.group(1));
    final m3 = _amountBareDecimal.firstMatch(text);
    if (m3 != null) return _parseAmt(m3.group(1));
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAYER 5 — MERCHANT FALLBACK CHAIN
  // ─────────────────────────────────────────────────────────────────────────

  static String? _extractMerchant(String text, String raw, bool isDebit) {
    // 1. SBI "trf to"
    final trf = _merchantTrfTo.firstMatch(text);
    if (trf != null) return trf.group(1)?.trim();

    // 2. "at MERCHANT" (card/ATM)
    final at = _merchantAt.firstMatch(text);
    if (at != null) return at.group(1)?.trim();

    // 3. Directional — debit → "to NAME", credit → "from NAME"
    if (isDebit) {
      final to = _merchantTo.firstMatch(text);
      if (to != null) return to.group(1)?.trim();
    } else {
      final from = _merchantFrom.firstMatch(text);
      if (from != null) return from.group(1)?.trim();
    }

    // 4. Info: field (ICICI NEFT/IMPS)
    final info = _merchantInfo.firstMatch(text);
    if (info != null) return info.group(1)?.trim();

    // 5. Trailing sender code: "... - SBIINB"
    final sender = _merchantSenderCode.firstMatch(raw);
    if (sender != null) return sender.group(1)?.trim();

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Parse a raw amount string like "1,500.00" or "1500" → double.
  static double? _parseAmt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll(',', ''));
  }
}

class _ParseResult {
  final double amount;
  final String? merchant;
  final bool isDebit;
  const _ParseResult({required this.amount, this.merchant, required this.isDebit});
}

// ── State Notifier ────────────────────────────────────────────────────────────

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

// ── Providers ─────────────────────────────────────────────────────────────────

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
