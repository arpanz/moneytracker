import 'dart:async';
import 'dart:convert';

import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/notification_provider.dart';

class NotificationService {
  static const _pendingKey = 'pending_notification_transactions';

  static const supportedPackages = <String>{
    // UPI apps
    'com.google.android.apps.nbu.paisa.user',
    'com.phonepe.app',
    'net.one97.paytm',
    'in.org.npci.upiapp',
    'com.amazon.mShop.android.shopping',
    // Banking apps
    'com.csam.icici.bank.imobile',
    'com.sbi.SBIFreedomPlus',
    'com.sbi.lotusintouch',
    'com.axis.mobile',
    'com.bankofbaroda.mconnect',
    'com.msf.kbank.mobile',
    'com.unionbankofindia.unionbank',
    'com.infrasofttech.indianbank',
    'com.canarabank.mobility',
    'com.hdfc.hdfcbankmobilebanking',
    'com.snapwork.hdfc',
    'com.idbi.mPassbook',
    'com.pnb.mbanking',
    'com.indusind.mobile',
    'com.yesbank.yesmobile',
    // System SMS apps
    'com.android.mms',
    'com.google.android.apps.messaging',
    'com.samsung.android.messaging',
    'com.miui.sms',
    'com.oneplus.mms',
  };

  final SharedPreferences _prefs;
  StreamSubscription<ServiceNotificationEvent>? _subscription;
  final List<PendingTransaction> _pending = [];

  // FIX: controller is kept open for the lifetime of the provider.
  // It is NEVER closed by stop() or initialize() — only by _destroy()
  // which is called from ref.onDispose when Riverpod tears down the provider.
  final StreamController<List<PendingTransaction>> _pendingController =
      StreamController<List<PendingTransaction>>.broadcast();

  Stream<List<PendingTransaction>> get pendingStream =>
      _pendingController.stream;

  List<PendingTransaction> get pending => List.unmodifiable(_pending);

  NotificationService(this._prefs) {
    _loadPending();
  }

  // ── Permission ──

  Future<bool> isPermissionGranted() =>
      NotificationListenerService.isPermissionGranted();

  Future<bool> requestPermission() =>
      NotificationListenerService.requestPermission();

  // ── Lifecycle ──

  /// Start (or resume) listening. Safe to call multiple times.
  Future<bool> initialize() async {
    // Already subscribed — nothing to do.
    if (_subscription != null) return true;

    final granted = await isPermissionGranted();
    if (!granted) return false;

    _subscription = NotificationListenerService.notificationsStream.listen(
      _onNotificationReceived,
      onError: (_) {},
      cancelOnError: false,
    );
    return true;
  }

  /// Cancel the stream subscription but keep the controller alive.
  /// Call this when the user toggles the feature off — the service instance
  /// stays valid and initialize() can be called again later.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Full teardown — only called by Riverpod's ref.onDispose.
  /// After this the instance must not be used again.
  void _destroy() {
    _subscription?.cancel();
    _subscription = null;
    if (!_pendingController.isClosed) _pendingController.close();
  }

  /// Exposed so the provider can wire it to ref.onDispose.
  void dispose() => _destroy();

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

    final isDuplicate = _pending.any((p) {
      return p.amount == transaction.amount &&
          p.merchant == transaction.merchant &&
          transaction.timestamp.difference(p.timestamp).inMinutes.abs() < 2;
    });
    if (isDuplicate) return;

    _pending.insert(0, transaction);
    _persistPending();
    if (!_pendingController.isClosed) {
      _pendingController.add(List.unmodifiable(_pending));
    }
  }

  // ── CRUD ──

  void dismiss(String id) {
    _pending.removeWhere((t) => t.id == id);
    _persistPending();
    if (!_pendingController.isClosed) {
      _pendingController.add(List.unmodifiable(_pending));
    }
  }

  void dismissAll() {
    _pending.clear();
    _persistPending();
    if (!_pendingController.isClosed) {
      _pendingController.add(List.unmodifiable(_pending));
    }
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
      if (!_pendingController.isClosed) {
        _pendingController.add(List.unmodifiable(_pending));
      }
    } on FormatException {
      _prefs.remove(_pendingKey);
    }
  }

  void _persistPending() {
    final jsonStr = jsonEncode(_pending.map((t) => t.toJson()).toList());
    _prefs.setString(_pendingKey, jsonStr);
  }
}
