import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

// Remplace ces valeurs avec ta config Firebase.
// Firebase Console → Paramètres du projet → Tes applications → Web → Config

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('Seule la plateforme web est supportée.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'REMPLACE_MOI',
    authDomain:        'REMPLACE_MOI',
    projectId:         'REMPLACE_MOI',
    storageBucket:     'REMPLACE_MOI',
    messagingSenderId: 'REMPLACE_MOI',
    appId:             'REMPLACE_MOI',
  );
}
