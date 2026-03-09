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
  static const supportedPackages = <String>{
    // UPI apps
    'com.google.android.apps.nbu.paisa.user', // Google Pay
    'com.phonepe.app', // PhonePe
    'net.one97.paytm', // Paytm
    'in.org.npci.upiapp', // BHIM
    // Banking apps
    'com.csam.icici.bank.imobile', // ICICI iMobile
    'com.sbi.SBIFreedomPlus', // SBI YONO
    'com.axis.mobile', // Axis Mobile
    'com.bankofbaroda.mconnect', // BOB
    'com.msf.kbank.mobile', // Kotak
    'com.unionbankofindia.unionbank', // Union Bank
    'com.infrasofttech.indianbank', // Indian Bank
    'com.canaaboretum', // Canara Bank
    'com.lcode.hdfc', // HDFC
    'com.snapwork.hdfc', // HDFC PayZapp
  };

  final SharedPreferences _prefs;
  StreamSubscription<ServiceNotificationEvent>? _subscription;
  final List<PendingTransaction> _pending = [];
  final _pendingController =
      StreamController<List<PendingTransaction>>.broadcast();

  /// Stream of pending transactions for UI consumption.
  Stream<List<PendingTransaction>> get pendingStream =>
      _pendingController.stream;

  /// Current pending list snapshot.
  List<PendingTransaction> get pending => List.unmodifiable(_pending);

  NotificationService(this._prefs) {
    _loadPending();
  }

  // ── Permission ──

  /// Check if the notification listener permission has been granted.
  Future<bool> isPermissionGranted() async {
    return NotificationListenerService.isPermissionGranted();
  }

  /// Open the system settings page to grant notification listener permission.
  Future<bool> requestPermission() async {
    return NotificationListenerService.requestPermission();
  }

  // ── Lifecycle ──

  /// Start listening for notifications. Returns `true` if the service started.
  Future<bool> initialize() async {
    final granted = await isPermissionGranted();
    if (!granted) return false;

    _subscription = NotificationListenerService.notificationsStream.listen(
      _onNotificationReceived,
    );
    return true;
  }

  /// Stop listening and clean up.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _pendingController.close();
  }

  // ── Notification Processing ──

  void _onNotificationReceived(ServiceNotificationEvent event) {
    final packageName = event.packageName;
    if (packageName == null) return;

    // Only process notifications from supported apps
    if (!supportedPackages.contains(packageName)) return;

    final title = event.title ?? '';
    final text = event.content ?? '';

    // Combine title and text for parsing
    final fullText = '$title\n$text';

    final transaction = NotificationParser.parseNotification(
      packageName,
      title,
      text,
    );

    if (transaction == null) return;

    // Avoid duplicates: check if we already have a pending transaction
    // with the same amount and merchant within the last 2 minutes
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

  // ── CRUD for pending list ──

  /// Dismiss a single pending transaction by id.
  void dismiss(String id) {
    _pending.removeWhere((t) => t.id == id);
    _persistPending();
    _pendingController.add(List.unmodifiable(_pending));
  }

  /// Dismiss all pending transactions.
  void dismissAll() {
    _pending.clear();
    _persistPending();
    _pendingController.add(List.unmodifiable(_pending));
  }

  /// Mark a pending transaction as saved (removes it from pending).
  void markSaved(String id) {
    dismiss(id);
  }

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
      // Corrupted data -- start fresh
      _prefs.remove(_pendingKey);
    }
  }

  void _persistPending() {
    final jsonStr = jsonEncode(_pending.map((t) => t.toJson()).toList());
    _prefs.setString(_pendingKey, jsonStr);
  }
}
