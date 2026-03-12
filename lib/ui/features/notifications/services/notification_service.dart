import 'dart:async';
import 'dart:convert';

import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/notification_provider.dart';

/// Service wrapper around [NotificationListenerService] that filters payment
/// notifications, parses them into [PendingTransaction] objects, and persists
/// the pending list to SharedPreferences.
class NotificationService {
  static const _pendingKey = 'pending_notification_transactions';

  /// Supported payment / banking app package names.
  ///
  /// FIX: corrected wrong package IDs for HDFC, Canara, SBI.
  /// Added real package names verified against Play Store listings.
  /// Also added system SMS apps so bank debit/credit SMS alerts are captured
  /// (banks typically send alerts via SMS, not their own app notifications).
  static const supportedPackages = <String>{
    // ── UPI apps ──
    'com.google.android.apps.nbu.paisa.user', // Google Pay
    'com.phonepe.app',                         // PhonePe
    'net.one97.paytm',                         // Paytm
    'in.org.npci.upiapp',                      // BHIM
    'com.amazon.mShop.android.shopping',       // Amazon Pay

    // ── Banking apps (verified package IDs) ──
    'com.csam.icici.bank.imobile',             // ICICI iMobile Pay
    'com.sbi.SBIFreedomPlus',                  // SBI YONO (old)
    'com.sbi.lotusintouch',                    // SBI YONO (new)
    'com.axis.mobile',                         // Axis Mobile
    'com.bankofbaroda.mconnect',               // Bank of Baroda
    'com.msf.kbank.mobile',                    // Kotak Bank
    'com.unionbankofindia.unionbank',          // Union Bank
    'com.infrasofttech.indianbank',            // Indian Bank
    'com.canarabank.mobility',                 // Canara Bank (FIX: was wrong)
    'com.hdfc.hdfcbankmobilebanking',          // HDFC Bank (FIX: was wrong)
    'com.snapwork.hdfc',                       // HDFC PayZapp
    'com.idbi.mPassbook',                      // IDBI Bank
    'com.pnb.mbanking',                        // PNB mBanking
    'com.indusind.mobile',                     // IndusInd Bank
    'com.yesbank.yesmobile',                   // Yes Bank

    // ── System SMS apps ──
    // Bank debit/credit alerts come via SMS, not the bank's own app,
    // so we need to intercept messages from the default SMS handler.
    'com.android.mms',                         // Stock Android SMS
    'com.google.android.apps.messaging',       // Google Messages
    'com.samsung.android.messaging',           // Samsung Messages
    'com.miui.sms',                            // Xiaomi / MIUI SMS
    'com.oneplus.mms',                         // OnePlus Messages
  };

  final SharedPreferences _prefs;
  StreamSubscription<ServiceNotificationEvent>? _subscription;
  final List<PendingTransaction> _pending = [];
  final _pendingController =
      StreamController<List<PendingTransaction>>.broadcast();

  Stream<List<PendingTransaction>> get pendingStream =>
      _pendingController.stream;

  List<PendingTransaction> get pending => List.unmodifiable(_pending);

  NotificationService(this._prefs) {
    _loadPending();
  }

  // ── Permission ──

  Future<bool> isPermissionGranted() async {
    return NotificationListenerService.isPermissionGranted();
  }

  Future<bool> requestPermission() async {
    return NotificationListenerService.requestPermission();
  }

  // ── Lifecycle ──

  /// Start listening for notifications. Returns `true` if the service started.
  Future<bool> initialize() async {
    // If already subscribed, don't double-subscribe.
    if (_subscription != null) return true;

    final granted = await isPermissionGranted();
    if (!granted) return false;

    _subscription = NotificationListenerService.notificationsStream.listen(
      _onNotificationReceived,
      onError: (_) {},     // swallow stream errors so the app doesn't crash
      cancelOnError: false,
    );
    return true;
  }

  /// Stop listening and clean up.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    if (!_pendingController.isClosed) _pendingController.close();
  }

  // ── Notification Processing ──

  void _onNotificationReceived(ServiceNotificationEvent event) {
    final packageName = event.packageName;
    if (packageName == null) return;
    if (!supportedPackages.contains(packageName)) return;

    final title = event.title ?? '';
    final text = event.content ?? '';

    final transaction = NotificationParser.parseNotification(
      packageName,
      title,
      text,
    );
    if (transaction == null) return;

    // Deduplicate: same amount + merchant within 2 minutes
    final isDuplicate = _pending.any((p) {
      return p.amount == transaction.amount &&
          p.merchant == transaction.merchant &&
          transaction.timestamp.difference(p.timestamp).inMinutes.abs() < 2;
    });
    if (isDuplicate) return;

    _pending.insert(0, transaction);
    _persistPending();
    _pendingController.add(List.unmodifiable(_pending));
  }

  // ── CRUD ──

  void dismiss(String id) {
    _pending.removeWhere((t) => t.id == id);
    _persistPending();
    _pendingController.add(List.unmodifiable(_pending));
  }

  void dismissAll() {
    _pending.clear();
    _persistPending();
    _pendingController.add(List.unmodifiable(_pending));
  }

  void markSaved(String id) => dismiss(id);

  // ── Persistence ──

  void _loadPending() {
    final jsonStr = _prefs.getString(_pendingKey);
    if (jsonStr == null || jsonStr.isEmpty) return;
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _pending.addAll(
        list
            .cast<Map<String, dynamic>>()
            .map(PendingTransaction.fromJson)
            .toList(),
      );
      _pendingController.add(List.unmodifiable(_pending));
    } on FormatException {
      _prefs.remove(_pendingKey);
    }
  }

  void _persistPending() {
    final jsonStr = jsonEncode(_pending.map((t) => t.toJson()).toList());
    _prefs.setString(_pendingKey, jsonStr);
  }
}
