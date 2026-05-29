import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_config.dart';

bool get _firebaseSupported =>
    kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

final appConfigProvider = StreamProvider<AppConfig>((ref) {
  if (!_firebaseSupported) return Stream.value(const AppConfig());
  return FirebaseFirestore.instance
      .collection('config')
      .doc('global')
      .snapshots()
      .map((snap) => snap.exists
          ? AppConfig.fromFirestore(snap)
          : const AppConfig());
});
