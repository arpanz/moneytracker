import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/notification_provider.dart';

class NotificationService {
  static const _pendingKey = 'pending_notification_transactions';
  static const _firstLaunchAfterGrantKey = 'notif_first_launch_after_grant';

  /// All packages whose notifications are scanned for transaction data.
  ///
  /// UPI / payment apps:
  ///   GPay, PhonePe, Paytm, BHIM, Amazon Pay
  /// Bank apps (major Indian banks):
  ///   ICICI, SBI YONO (two variants), Axis, BoB, Kotak, Union, Indian,
  ///   Canara, HDFC (two variants), IDBI, PNB, IndusInd, Yes Bank
  /// SMS / messaging apps (covers stock Android + major OEM skins):
  ///   AOSP MMS, Google Messages, Samsung Messages, MIUI Messages,
  ///   MIUI v2 Messages, OnePlus/OxygenOS MMS, ColorOS MMS,
  ///   Motorola Messages, Vivo Messages, Asus Messages,
  ///   Realme Messages, Transsion (Tecno/Infinix) Messages
  static const supportedPackages = <String>{
    // ── UPI / payment ──────────────────────────────────────────────────────
    'com.google.android.apps.nbu.paisa.user',
    'com.phonepe.app',
    'net.one97.paytm',
    'in.org.npci.upiapp',
    'com.amazon.mShop.android.shopping',
    // ── Bank apps ──────────────────────────────────────────────────────────
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
    // ── SMS / messaging ────────────────────────────────────────────────────
    'com.android.mms',                    // AOSP
    'com.google.android.apps.messaging',  // Google Messages
    'com.samsung.android.messaging',      // Samsung
    'com.miui.sms',                       // MIUI (older)
    'com.miui.messaging',                 // MIUI (newer)
    'com.oneplus.mms',                    // OxygenOS
    'com.coloros.mms',                    // ColorOS (OnePlus/Oppo)
    'com.messaging.android',              // Motorola
    'com.vivo.mms',                       // Vivo
    'com.asus.mms',                       // Asus
    'com.realme.mms',                     // Realme
    'com.transsion.message',              // Tecno / Infinix
  };

  final SharedPreferences _prefs;
  StreamSubscription<ServiceNotificationEvent>? _subscription;
  final List<PendingTransaction> _pending = [];

  final StreamController<List<PendingTransaction>> _pendingController =
      StreamController<List<PendingTransaction>>.broadcast();

  Stream<List<PendingTransaction>> get pendingStream =>
      _pendingController.stream;
  List<PendingTransaction> get pending => List.unmodifiable(_pending);

  NotificationService(this._prefs) {
    _loadPending();
  }

  Future<bool> isPermissionGranted() =>
      NotificationListenerService.isPermissionGranted();

  Future<bool> requestPermission() =>
      NotificationListenerService.requestPermission();

  void markFirstLaunchAfterGrant() =>
      _prefs.setBool(_firstLaunchAfterGrantKey, true);

  bool _consumeFirstLaunchAfterGrant() {
    final val = _prefs.getBool(_firstLaunchAfterGrantKey) ?? false;
    if (val) _prefs.remove(_firstLaunchAfterGrantKey);
    return val;
  }

  Future<bool> initialize({bool delayForBind = false}) async {
    if (_subscription != null) return true;
    try {
      final granted = await isPermissionGranted();
      if (!granted) return false;
      if (delayForBind) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
      _subscription = NotificationListenerService.notificationsStream.listen(
        _onNotificationReceived,
        onError: (e) => dev.log('[NotifService] stream error: $e', name: 'Cheddar'),
        cancelOnError: false,
      );
      dev.log('[NotifService] listener subscribed', name: 'Cheddar');
      return true;
    } on PlatformException catch (e) {
      dev.log('[NotifService] PlatformException on init: $e', name: 'Cheddar');
      _subscription = null;
      return false;
    } catch (e) {
      dev.log('[NotifService] unexpected error on init: $e', name: 'Cheddar');
      _subscription = null;
      return false;
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    dev.log('[NotifService] listener stopped', name: 'Cheddar');
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    if (!_pendingController.isClosed) _pendingController.close();
  }

  void _onNotificationReceived(ServiceNotificationEvent event) {
    final pkg = event.packageName ?? 'unknown';
    final title = event.title ?? '';
    final text = event.content ?? '';

    // DEBUG: log every single notification so we can see what's arriving
    dev.log(
      '[NotifService] PKG=$pkg | TITLE=$title | TEXT=$text',
      name: 'Cheddar',
    );

    if (!supportedPackages.contains(pkg)) {
      // Not a supported app — logged above, skip processing
      return;
    }

    final transaction = NotificationParser.parseNotification(pkg, title, text);

    if (transaction == null) {
      dev.log(
        '[NotifService] PARSE FAILED for supported pkg=$pkg | "$title" | "$text"',
        name: 'Cheddar',
      );
      return;
    }

    final isDuplicate = _pending.any((p) =>
        p.amount == transaction.amount &&
        p.merchant == transaction.merchant &&
        transaction.timestamp.difference(p.timestamp).inMinutes.abs() < 2);
    if (isDuplicate) {
      dev.log('[NotifService] duplicate skipped: ${transaction.amount}', name: 'Cheddar');
      return;
    }

    dev.log(
      '[NotifService] SAVED: ${transaction.isDebit ? 'DEBIT' : 'CREDIT'} '
      '${transaction.amount} from ${transaction.merchant ?? 'unknown'}',
      name: 'Cheddar',
    );

    _pending.insert(0, transaction);
    _persistPending();
    if (!_pendingController.isClosed) {
      _pendingController.add(List.unmodifiable(_pending));
    }
  }

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

  bool get isFirstLaunchAfterGrant =>
      _prefs.getBool(_firstLaunchAfterGrantKey) ?? false;
  bool consumeFirstLaunchAfterGrant() => _consumeFirstLaunchAfterGrant();
}
