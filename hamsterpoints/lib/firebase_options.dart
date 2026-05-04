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
    apiKey: 'AIzaSyCqoahu1PVKpTJ35hhDTVo7f56gyAoRkS8',
    authDomain: 'hamsterpoints.firebaseapp.com',
    databaseURL: 'https://hamsterpoints-default-rtdb.europe-west1.firebasedatabase.app',
    projectId: 'hamsterpoints',
    storageBucket: 'hamsterpoints.firebasestorage.app',
    messagingSenderId: '475939580686',
    appId: '1:475939580686:web:d65f05bad7afe838ea855f',
  );
}
