// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'firebase_options.dart';

// ══════════════════════════════════════════════════════════════
// CONSTANTES
// ══════════════════════════════════════════════════════════════

const List<String> kTaskIcons = [
  '🧹','🧽','🍽️','🛏️','🛁','🚿','🪣','🗑️',
  '📚','✏️','📖','🎒','📝','📐','🔬',
  '🌿','🌻','🌱','🐕','🐱','🐠',
  '🏃','🚴','⚽','🎯','🏊',
  '🎨','🎵','🎸','🎭','🖌️',
  '🛒','🍳','🧁','🍎','💊','🚗','🚲','⭐','💪','🤝','🎁',
  '⚠️','🚫','❌','💣','👎','😤','🙅','📵','💢','🔇',
];

const List<String> kChildAnimals = [
  '🐹','🐱','🐶','🐰','🐻','🦊','🐼','🐨','🐸','🦄','🐯','🦁',
];

class ChildColorScheme {
  final Color bg;
  final Color accent;
  const ChildColorScheme(this.bg, this.accent);
}

const List<ChildColorScheme> kChildColorSchemes = [
  ChildColorScheme(Color(0xFFFFF0F8), Color(0xFFFF8FAB)),
  ChildColorScheme(Color(0xFFF0F8FF), Color(0xFF5DADE2)),
  ChildColorScheme(Color(0xFFF5F0FF), Color(0xFFAF7AC5)),
  ChildColorScheme(Color(0xFFF0FFF4), Color(0xFF52BE80)),
  ChildColorScheme(Color(0xFFFFFBF0), Color(0xFFE67E22)),
  ChildColorScheme(Color(0xFFFFF0F0), Color(0xFFE74C3C)),
  ChildColorScheme(Color(0xFFF0FBFF), Color(0xFF1ABC9C)),
  ChildColorScheme(Color(0xFFFFF8F0), Color(0xFFD4AC0D)),
];

enum RecurrenceType { none, daily, weekdaysOnly, weekly, biweekly, monthly }

// 8 stades — l'animal choisi dès le début, pas d'œuf ni de poussin
enum HamsterStage { minuscule, bebe, petit, moyen, grand, vaillant, champion, legendaire }

enum HamsterMood { sleeping, sad, neutral, happy, excited }

class AppPalette {
  static const Color parentBg   = Color(0xFFF7F2E8);
  static const Color green      = Color(0xFF7BA05B);
  static const Color softGreen  = Color(0xFFDDE8CF);
  static const Color brown      = Color(0xFF6F5B46);
  static const Color kawaiiMint = Color(0xFF7DCEA0);
}

// ══════════════════════════════════════════════════════════════
// MODÈLES
// ══════════════════════════════════════════════════════════════

class ChildProfile {
  final String id;
  String name, animal;
  int colorIndex, seedsBalance, lifetimeSeeds;
  String? lastTaskDate;

  ChildProfile({required this.id, required this.name,
      this.animal = '🐹', this.colorIndex = 0,
      this.seedsBalance = 0, this.lifetimeSeeds = 0, this.lastTaskDate});

  HamsterStage get stage {
    if (lifetimeSeeds <  10)  return HamsterStage.minuscule;
    if (lifetimeSeeds <  30)  return HamsterStage.bebe;
    if (lifetimeSeeds <  70)  return HamsterStage.petit;
    if (lifetimeSeeds < 150)  return HamsterStage.moyen;
    if (lifetimeSeeds < 300)  return HamsterStage.grand;
    if (lifetimeSeeds < 500)  return HamsterStage.vaillant;
    if (lifetimeSeeds < 800)  return HamsterStage.champion;
    return HamsterStage.legendaire;
  }

  HamsterMood get mood {
    if (lastTaskDate == null) return HamsterMood.sleeping;
    final last = DateTime.tryParse(lastTaskDate!);
    if (last == null) return HamsterMood.neutral;
    final days = DateTime.now().difference(last).inDays;
    if (days == 0) return HamsterMood.excited;
    if (days <= 1) return HamsterMood.happy;
    if (days <= 3) return HamsterMood.neutral;
    if (days <= 7) return HamsterMood.sad;
    return HamsterMood.sleeping;
  }

  ChildColorScheme get colorScheme =>
      kChildColorSchemes[colorIndex.clamp(0, kChildColorSchemes.length - 1)];

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'animal': animal, 'colorIndex': colorIndex,
    'seedsBalance': seedsBalance, 'lifetimeSeeds': lifetimeSeeds,
    'lastTaskDate': lastTaskDate,
  };
  factory ChildProfile.fromJson(Map<String, dynamic> j) => ChildProfile(
    id: j['id'] as String, name: j['name'] as String,
    animal: j['animal'] as String? ?? '🐹',
    colorIndex: (j['colorIndex'] as num? ?? 0).toInt(),
    seedsBalance:  (j['seedsBalance']  as num? ?? 0).toInt(),
    lifetimeSeeds: (j['lifetimeSeeds'] as num? ?? 0).toInt(),
    lastTaskDate:  j['lastTaskDate']   as String?,
  );
}

class RewardItem {
  final String id; String title; int costSeeds;
  RewardItem({required this.id, required this.title, required this.costSeeds});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'costSeeds': costSeeds};
  factory RewardItem.fromJson(Map<String, dynamic> j) =>
      RewardItem(id: j['id'] as String, title: j['title'] as String,
                 costSeeds: (j['costSeeds'] as num).toInt());
}

class TaskTemplate {
  final String id; String title, icon; int rewardSeeds;
  TaskTemplate({required this.id, required this.title, required this.icon, required this.rewardSeeds});
  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'icon': icon, 'rewardSeeds': rewardSeeds};
  factory TaskTemplate.fromJson(Map<String, dynamic> j) => TaskTemplate(
    id: j['id'] as String, title: j['title'] as String,
    icon: j['icon'] as String? ?? '📌',
    rewardSeeds: (j['rewardSeeds'] as num).toInt(),
  );
}

class ScheduledTask {
  final String id;
  String childId, childName, title, icon;
  int rewardSeeds;
  DateTime date;
  bool done, pendingValidation;
  String? photoBase64;

  ScheduledTask({required this.id, required this.childId, required this.childName,
      required this.title, required this.icon, required this.rewardSeeds,
      required this.date, this.done = false, this.pendingValidation = false,
      this.photoBase64});

  Map<String, dynamic> toJson() => {
    'id': id, 'childId': childId, 'childName': childName,
    'title': title, 'icon': icon, 'rewardSeeds': rewardSeeds,
    'date': date.toIso8601String(), 'done': done,
    'pendingValidation': pendingValidation,
    if (photoBase64 != null) 'photoBase64': photoBase64,
  };
  factory ScheduledTask.fromJson(Map<String, dynamic> j) => ScheduledTask(
    id: j['id'] as String, childId: j['childId'] as String,
    childName: j['childName'] as String, title: j['title'] as String,
    icon: j['icon'] as String? ?? '📌',
    rewardSeeds: (j['rewardSeeds'] as num).toInt(),
    date: DateTime.parse(j['date'] as String),
    done: j['done'] as bool? ?? false,
    pendingValidation: j['pendingValidation'] as bool? ?? false,
    photoBase64: j['photoBase64'] as String?,
  );
}

// ══════════════════════════════════════════════════════════════
// APP DATA
// ══════════════════════════════════════════════════════════════

class AppData {
  static List<ChildProfile>  children       = [];
  static List<RewardItem>    rewards        = [];
  static List<TaskTemplate>  taskTemplates  = [];
  static List<ScheduledTask> scheduledTasks = [];
  static String parentPin      = '';
  static bool   moneyEnabled   = false;
  static double moneyPerSeed   = 0.10;
  static String currencySymbol = '€';
  static bool   photoProofEnabled    = false;
  static bool   childCalendarEnabled = true;

  // ── Code famille ─────────────────────────────────────────
  static String familyCode = '';
  static const _codeStorageKey = 'hp_family_code';

  static String? getStoredCode() => html.window.localStorage[_codeStorageKey];
  static void    storeCode(String code) => html.window.localStorage[_codeStorageKey] = code;
  static void    clearStoredCode() => html.window.localStorage.remove(_codeStorageKey);

  static String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  static String? getCodeFromUrl() {
    final href = html.window.location.href;
    return Uri.parse(href).queryParameters['code'];
  }

  // Called when parent logs in with Google
  static Future<void> initAsParent() async {
    final user = FirebaseAuth.instance.currentUser!;
    final codeRef = FirebaseDatabase.instance.ref('parentFamilyCodes/${user.uid}');
    final snap = await codeRef.get();
    if (snap.exists && snap.value != null) {
      familyCode = snap.value as String;
    } else {
      familyCode = generateCode();
      // Migrate old data from users/${uid} if it exists
      final oldSnap = await FirebaseDatabase.instance.ref('users/${user.uid}').get();
      if (oldSnap.exists && oldSnap.value != null) {
        await FirebaseDatabase.instance.ref('families/$familyCode').set(oldSnap.value);
      }
      await codeRef.set(familyCode);
    }
    storeCode(familyCode);
    await load();
  }

  // Called when joining with a family code (child device)
  static Future<bool> initWithCode(String code) async {
    final snap = await FirebaseDatabase.instance.ref('families/$code').get();
    if (!snap.exists) return false;
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    familyCode = code.trim().toUpperCase();
    storeCode(familyCode);
    await load();
    return true;
  }

  // Called on startup if localStorage has a code
  static Future<bool> initFromStorage() async {
    final code = getStoredCode();
    if (code == null || code.isEmpty) return false;
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    familyCode = code;
    await load();
    return true;
  }

  static String uid() => DateTime.now().microsecondsSinceEpoch.toString();

  static int get pendingCount =>
      scheduledTasks.where((t) => t.pendingValidation && !t.done).length;

  static DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('families/$familyCode');

  static List<DateTime> generateDates(
      DateTime start, DateTime? end, RecurrenceType type) {
    if (type == RecurrenceType.none || end == null) return [start];
    final dates = <DateTime>[];
    var current = start;
    final limit = end.isBefore(start) ? start : end;
    while (!current.isAfter(limit)) {
      final isWeekend = current.weekday == DateTime.saturday ||
                        current.weekday == DateTime.sunday;
      if (type != RecurrenceType.weekdaysOnly || !isWeekend) dates.add(current);
      if (type == RecurrenceType.monthly) {
        current = DateTime(current.year, current.month + 1, current.day);
      } else if (type == RecurrenceType.biweekly) {
        current = current.add(const Duration(days: 14));
      } else if (type == RecurrenceType.weekly) {
        current = current.add(const Duration(days: 7));
      } else {
        current = current.add(const Duration(days: 1));
      }
    }
    return dates;
  }

  static Future<void> save() async {
    if (familyCode.isEmpty) return;
    await _ref.set({
      'children':             children.map((e) => e.toJson()).toList(),
      'rewards':              rewards.map((e) => e.toJson()).toList(),
      'taskTemplates':        taskTemplates.map((e) => e.toJson()).toList(),
      'scheduledTasks':       scheduledTasks.map((e) => e.toJson()).toList(),
      'parentPin':            parentPin,
      'moneyEnabled':         moneyEnabled,
      'moneyPerSeed':         moneyPerSeed,
      'currencySymbol':       currencySymbol,
      'photoProofEnabled':    photoProofEnabled,
      'childCalendarEnabled': childCalendarEnabled,
    });
  }

  static Future<void> load() async {
    if (familyCode.isEmpty) return;
    final snapshot = await _ref.get();
    if (!snapshot.exists || snapshot.value == null) return;
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    try {
      Map<String, dynamic> asMap(dynamic e) => Map<String, dynamic>.from(e as Map);
      List<T> asList<T>(String key, T Function(Map<String, dynamic>) f) =>
          (data[key] as List? ?? []).map((e) => f(asMap(e))).toList();
      children       = asList('children',       ChildProfile.fromJson);
      rewards        = asList('rewards',        RewardItem.fromJson);
      taskTemplates  = asList('taskTemplates',  TaskTemplate.fromJson);
      scheduledTasks = asList('scheduledTasks', ScheduledTask.fromJson);
      parentPin            = data['parentPin']            as String? ?? '';
      moneyEnabled         = data['moneyEnabled']         as bool?   ?? false;
      moneyPerSeed         = (data['moneyPerSeed']        as num?    ?? 0.10).toDouble();
      currencySymbol       = data['currencySymbol']       as String? ?? '€';
      photoProofEnabled    = data['photoProofEnabled']    as bool?   ?? false;
      childCalendarEnabled = data['childCalendarEnabled'] as bool?   ?? true;
    } catch (_) {}
  }

  static void clear() {
    children = []; rewards = []; taskTemplates = [];
    scheduledTasks = []; parentPin = '';
    moneyEnabled = false; moneyPerSeed = 0.10; currencySymbol = '€';
    photoProofEnabled = false; childCalendarEnabled = true;
    familyCode = '';
    clearStoredCode();
  }
}

// ══════════════════════════════════════════════════════════════
// PHOTO PICKER (web uniquement)
// ══════════════════════════════════════════════════════════════

Future<String?> pickImageAsBase64() {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';

  input.onChange.listen((_) {
    final file = input.files?.first;
    if (file == null) { if (!completer.isCompleted) completer.complete(null); return; }
    final reader = html.FileReader();
    reader.onLoad.listen((_) {
      final dataUrl = reader.result as String;
      final img = html.ImageElement();
      img.onLoad.listen((_) {
        const maxDim = 500;
        int w = img.naturalWidth, h = img.naturalHeight;
        if (w == 0 || h == 0) { if (!completer.isCompleted) completer.complete(dataUrl); return; }
        if (w > maxDim || h > maxDim) {
          if (w >= h) { h = (h * maxDim ~/ w); w = maxDim; }
          else        { w = (w * maxDim ~/ h); h = maxDim; }
        }
        final canvas = html.CanvasElement();
        canvas.width = w; canvas.height = h;
        canvas.context2D.drawImageScaled(img, 0, 0, w, h);
        if (!completer.isCompleted) completer.complete(canvas.toDataUrl('image/jpeg', 0.75));
      });
      img.src = dataUrl;
    });
    reader.readAsDataUrl(file);
  });

  input.click();
  return completer.future;
}

// ══════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const HamsterPointsApp());
}

class HamsterPointsApp extends StatelessWidget {
  const HamsterPointsApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HamsterPoints',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppPalette.parentBg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppPalette.green),
      ),
      home: const _StartupScreen(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STARTUP — détecte code stocké / URL et route vers le bon écran
// ══════════════════════════════════════════════════════════════

class _StartupScreen extends StatefulWidget {
  const _StartupScreen();
  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // 1. Code dans l'URL (?code=XXXX) — partage par QR
      final urlCode = AppData.getCodeFromUrl();
      if (urlCode != null && urlCode.isNotEmpty) {
        final ok = await AppData.initWithCode(urlCode);
        if (ok && mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const AppGateScreen()));
          return;
        }
      }
      // 2. Code en localStorage (visite précédente)
      final ok = await AppData.initFromStorage();
      if (ok && mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const AppGateScreen()));
        return;
      }
    } catch (_) {
      // En cas d'erreur (ex: règles Firebase pas encore mises à jour), on continue
    }
    // 4. Rien ou erreur → écran d'accueil
    if (mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('🐹', style: TextStyle(fontSize: 60)),
        SizedBox(height: 16),
        CircularProgressIndicator(),
      ])));
}

// ══════════════════════════════════════════════════════════════
// WELCOME SCREEN — première ouverture (pas de code stocké)
// ══════════════════════════════════════════════════════════════

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading      = false;
  bool _isSignUp     = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (_isSignUp) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email, password: password);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email, password: password);
      }
      await AppData.initAsParent();
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const AppGateScreen()));
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error = switch (e.code) {
          'user-not-found'   => 'Aucun compte avec cet email.',
          'wrong-password'   => 'Mot de passe incorrect.',
          'email-already-in-use' => 'Cet email est déjà utilisé.',
          'weak-password'    => 'Mot de passe trop court (6 caractères min).',
          'invalid-email'    => 'Email invalide.',
          _                  => e.message ?? 'Erreur inconnue.',
        };
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.parentBg,
      body: Center(child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🐹', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 12),
          const Text('HamsterPoints',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Gérez les tâches et récompenses de votre famille !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 36),

          // ── Formulaire parent ──────────────────────────
          Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_isSignUp ? '👤 Créer un compte parent' : '🔑 Connexion parent',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(_isSignUp ? 'Créer mon compte' : 'Se connecter',
                      style: const TextStyle(fontSize: 16)),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() { _isSignUp = !_isSignUp; _error = null; }),
                child: Text(_isSignUp
                    ? 'J\'ai déjà un compte → Se connecter'
                    : 'Pas encore de compte → Créer un compte'),
              ),
            ]),
          )),

          const SizedBox(height: 20),

          // ── Rejoindre (enfant) ─────────────────────────
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const _JoinFamilyScreen())),
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Rejoindre une famille (enfant)',
                  style: TextStyle(fontSize: 15)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
        ]),
      ))),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// JOIN FAMILY SCREEN — enfant entre le code famille
// ══════════════════════════════════════════════════════════════

class _JoinFamilyScreen extends StatefulWidget {
  const _JoinFamilyScreen();
  @override
  State<_JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<_JoinFamilyScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _join() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    final ok = await AppData.initWithCode(code);
    if (!mounted) return;
    if (ok) {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const AppGateScreen()),
          (_) => false);
    } else {
      setState(() { _loading = false; _error = 'Code introuvable. Vérifie avec tes parents.'; });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.parentBg,
      appBar: AppBar(title: const Text('Rejoindre une famille'),
          backgroundColor: AppPalette.softGreen),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🐹', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 24),
          const Text('Entre le code famille\ndonné par tes parents',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Code famille (ex: ABCD1234)',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _join,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Rejoindre', style: TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CUSTOM PIN KEYPAD (no OS keyboard — works on iOS PWA)
// ══════════════════════════════════════════════════════════════

class _PinDialog extends StatefulWidget {
  final void Function(bool ok) onResult;
  const _PinDialog({required this.onResult});
  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _entered = '';

  void _press(String digit) {
    if (_entered.length >= 8) return;
    setState(() => _entered += digit);
  }

  void _delete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  void _confirm() => widget.onResult(_entered == AppData.parentPin);

  Widget _key(String label, {VoidCallback? onTap, Color? color, IconData? icon}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: color ?? Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 24, color: Colors.grey.shade700)
                    : Text(label,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dots = List.generate(
      _entered.length,
      (_) => const Text('●', style: TextStyle(fontSize: 20, letterSpacing: 4)),
    );

    return AlertDialog(
      title: const Text('🔒 Code parent', textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: _entered.isEmpty
                ? Text('Entrez votre code',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 15))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dots,
                  ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            _key('1', onTap: () => _press('1')),
            _key('2', onTap: () => _press('2')),
            _key('3', onTap: () => _press('3')),
          ]),
          Row(children: [
            _key('4', onTap: () => _press('4')),
            _key('5', onTap: () => _press('5')),
            _key('6', onTap: () => _press('6')),
          ]),
          Row(children: [
            _key('7', onTap: () => _press('7')),
            _key('8', onTap: () => _press('8')),
            _key('9', onTap: () => _press('9')),
          ]),
          Row(children: [
            _key('', icon: Icons.backspace_outlined, onTap: _delete,
                color: Colors.red.shade50),
            _key('0', onTap: () => _press('0')),
            _key('', icon: Icons.check_circle_outline, onTap: _confirm,
                color: Colors.green.shade50),
          ]),
          const SizedBox(height: 8),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => widget.onResult(false),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// GATE SCREEN
// ══════════════════════════════════════════════════════════════

class AppGateScreen extends StatefulWidget {
  const AppGateScreen({super.key});
  @override
  State<AppGateScreen> createState() => _AppGateScreenState();
}

class _AppGateScreenState extends State<AppGateScreen> {
  void _refresh() => setState(() {});

  Future<bool> _checkPin(BuildContext context) async {
    if (AppData.parentPin.isEmpty) return true;
    bool? result;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PinDialog(
        onResult: (ok) { result = ok; Navigator.pop(ctx); },
      ),
    );
    if (result != true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code incorrect.')));
    }
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final pending = AppData.pendingCount;
    return Scaffold(
      backgroundColor: AppPalette.parentBg,
      appBar: AppBar(
        title: const Text('🐹 HamsterPoints', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppPalette.softGreen,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _gateButton(
            label: 'Parent 🌿',
            sub: pending > 0
                ? '$pending tâche${pending > 1 ? "s" : ""} en attente de validation ⚠️'
                : 'Gérer les tâches et récompenses',
            color: AppPalette.green,
            badge: pending,
            onTap: () async {
              final ok = await _checkPin(context);
              if (!ok || !context.mounted) return;
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ParentHomeScreen(onRefresh: _refresh)));
              _refresh();
            },
          ),
          const SizedBox(height: 24),
          if (AppData.children.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Aucun enfant ajouté.\nConnecte-toi en mode Parent → Réglages.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Qui es-tu ?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                   color: AppPalette.brown)),
            ),
            ...AppData.children.map((child) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _gateButton(
                label: child.name,
                sub: '${child.seedsBalance} graines 🌱',
                color: child.colorScheme.accent,
                avatar: child.animal,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ChildModeScreen(childId: child.id))),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _gateButton({
    required String label, required String sub,
    required Color color, required VoidCallback onTap, int badge = 0, String? avatar,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              CircleAvatar(
                radius: 28, backgroundColor: color,
                child: avatar != null
                    ? Text(avatar, style: const TextStyle(fontSize: 26))
                    : Text(label[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 22,
                                               fontWeight: FontWeight.bold)),
              ),
              if (badge > 0) Positioned(right: -4, top: -4,
                child: Container(padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('$badge', style: const TextStyle(color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(sub, style: TextStyle(
                  color: badge > 0 ? Colors.orange.shade700 : Colors.grey.shade600,
                  fontSize: 13)),
            ])),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PARENT HOME
// ══════════════════════════════════════════════════════════════

class ParentHomeScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const ParentHomeScreen({super.key, required this.onRefresh});
  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _tab = 0;
  void _refresh() { setState(() {}); widget.onRefresh(); }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ParentCalendarScreen(onRefresh: _refresh),
      ParentRewardsScreen(onRefresh: _refresh),
      ParentSettingsScreen(onRefresh: _refresh),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Mode Parent 🌿'), backgroundColor: AppPalette.softGreen),
      body: tabs[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendrier'),
          NavigationDestination(icon: Icon(Icons.card_giftcard),  label: 'Récompenses'),
          NavigationDestination(icon: Icon(Icons.settings),       label: 'Réglages'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PARENT CALENDAR
// ══════════════════════════════════════════════════════════════

class ParentCalendarScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const ParentCalendarScreen({super.key, required this.onRefresh});
  @override
  State<ParentCalendarScreen> createState() => _ParentCalendarScreenState();
}

class _ParentCalendarScreenState extends State<ParentCalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay  = DateTime.now();
  int  _childIdx = 0, _taskIdx = 0;
  String? _filterChildId;
  RecurrenceType _recurrence = RecurrenceType.none;
  DateTime? _endDate;

  List<ScheduledTask> _tasksForDay(DateTime day, {String? childId}) =>
      AppData.scheduledTasks.where((t) {
        final match = t.date.year == day.year && t.date.month == day.month && t.date.day == day.day;
        return match && (childId == null || t.childId == childId);
      }).toList();


  String _recLabel(RecurrenceType t) => switch (t) {
    RecurrenceType.none         => 'Une seule fois',
    RecurrenceType.daily        => 'Tous les jours',
    RecurrenceType.weekdaysOnly => 'Lun → Ven',
    RecurrenceType.weekly       => 'Toutes les semaines',
    RecurrenceType.biweekly     => 'Toutes les 2 semaines',
    RecurrenceType.monthly      => 'Tous les mois',
  };

  Future<void> _assign() async {
    if (AppData.children.isEmpty || AppData.taskTemplates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajoute des enfants et des tâches dans Réglages.')));
      return;
    }
    if (_recurrence != RecurrenceType.none && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choisis une date de fin.')));
      return;
    }
    final child = AppData.children[_childIdx.clamp(0, AppData.children.length - 1)];
    final task  = AppData.taskTemplates[_taskIdx.clamp(0, AppData.taskTemplates.length - 1)];
    final dates = AppData.generateDates(_selectedDay, _endDate, _recurrence);
    for (final date in dates) {
      AppData.scheduledTasks.add(ScheduledTask(
        id: AppData.uid(), childId: child.id, childName: child.name,
        title: task.title, icon: task.icon, rewardSeeds: task.rewardSeeds, date: date,
      ));
    }
    await AppData.save();
    setState(() {});
    widget.onRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(dates.length > 1 ? '${dates.length} tâches créées ✅' : 'Tâche attribuée ✅')));
    }
  }

  Future<void> _refuse(ScheduledTask task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la tâche ?'),
        content: Text('Refuser "${task.title}" de ${task.childName} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    setState(() => AppData.scheduledTasks.remove(task));
    await AppData.save();
    widget.onRefresh();
  }

  Future<void> _validate(ScheduledTask task) async {
    final idx = AppData.children.indexWhere((c) => c.id == task.childId);
    if (idx == -1) return;
    final child = AppData.children[idx];
    setState(() {
      task.done = true; task.pendingValidation = false; task.photoBase64 = null;
      child.seedsBalance  += task.rewardSeeds;
      if (task.rewardSeeds > 0) child.lifetimeSeeds += task.rewardSeeds;
      child.lastTaskDate = DateTime.now().toIso8601String();
    });
    await AppData.save();
    widget.onRefresh();
  }

  Future<void> _delete(ScheduledTask task) async {
    setState(() => AppData.scheduledTasks.remove(task));
    await AppData.save();
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final dayTasks = _tasksForDay(_selectedDay, childId: _filterChildId);
    final hasData  = AppData.children.isNotEmpty && AppData.taskTemplates.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (AppData.children.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('Tous', null),
              ...AppData.children.map((c) => _chip(c.name, c.id)),
            ]),
          ),
        const SizedBox(height: 8),
        Card(child: Padding(
          padding: const EdgeInsets.all(6),
          child: TableCalendar(
            firstDay: DateTime.utc(2020), lastDay: DateTime.utc(2035),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            onDaySelected: (sel, foc) => setState(() { _selectedDay = sel; _focusedDay = foc; }),
            eventLoader: (day) => _tasksForDay(day, childId: _filterChildId),
            rowHeight: 36,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false, titleCentered: true,
              headerPadding: EdgeInsets.symmetric(vertical: 2),
              titleTextStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(Icons.chevron_left, size: 18),
              rightChevronIcon: Icon(Icons.chevron_right, size: 18),
              leftChevronPadding: EdgeInsets.zero, rightChevronPadding: EdgeInsets.zero,
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              weekendStyle: const TextStyle(fontSize: 10, color: Colors.redAccent),
            ),
            calendarStyle: const CalendarStyle(
              cellMargin: EdgeInsets.all(1),
              defaultTextStyle: TextStyle(fontSize: 11),
              weekendTextStyle: TextStyle(fontSize: 11, color: Colors.redAccent),
              selectedTextStyle: TextStyle(fontSize: 11, color: Colors.white),
              todayTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              outsideDaysVisible: false, markersMaxCount: 0,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (ctx, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: events.cast<ScheduledTask>().take(4).map((t) =>
                        Text(t.icon.isEmpty ? '·' : t.icon,
                             style: const TextStyle(fontSize: 7))).toList(),
                  ),
                );
              },
            ),
          ),
        )),
        const SizedBox(height: 10),
        ExpansionTile(
          title: const Text('➕ Attribuer une tâche',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          children: [
            if (!hasData)
              const Padding(padding: EdgeInsets.all(12),
                child: Text('Va dans Réglages pour ajouter des enfants et des tâches.',
                    style: TextStyle(color: Colors.deepOrange)))
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  DropdownButtonFormField<int>(
                    initialValue: _childIdx.clamp(0, AppData.children.length - 1),
                    decoration: const InputDecoration(labelText: 'Enfant', isDense: true),
                    items: List.generate(AppData.children.length, (i) =>
                        DropdownMenuItem(value: i, child: Text(AppData.children[i].name))),
                    onChanged: (v) => setState(() => _childIdx = v!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _taskIdx.clamp(0, AppData.taskTemplates.length - 1),
                    decoration: const InputDecoration(labelText: 'Tâche', isDense: true),
                    items: List.generate(AppData.taskTemplates.length, (i) {
                      final t = AppData.taskTemplates[i];
                      return DropdownMenuItem(value: i,
                          child: Text('${t.icon} ${t.title} (${t.rewardSeeds} 🌱)'));
                    }),
                    onChanged: (v) => setState(() => _taskIdx = v!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<RecurrenceType>(
                    initialValue: _recurrence,
                    decoration: const InputDecoration(labelText: 'Récurrence', isDense: true),
                    items: RecurrenceType.values.map((r) =>
                        DropdownMenuItem(value: r, child: Text(_recLabel(r)))).toList(),
                    onChanged: (v) => setState(() {
                      _recurrence = v!;
                      if (v == RecurrenceType.none) _endDate = null;
                    }),
                  ),
                  if (_recurrence != RecurrenceType.none) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? _selectedDay.add(const Duration(days: 7)),
                          firstDate: _selectedDay, lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _endDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text(_endDate == null
                          ? 'Choisir la date de fin'
                          : 'Fin : ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(onPressed: _assign,
                      icon: const Icon(Icons.add), label: const Text('Attribuer')),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Tâches du ${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (dayTasks.isEmpty)
          Text('Aucune tâche ce jour.',
              style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic))
        else
          ...dayTasks.map((t) => _taskTile(t)),
      ],
    );
  }

  Widget _chip(String label, String? childId) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _filterChildId == childId,
      onSelected: (_) => setState(() => _filterChildId = childId),
    ),
  );

  Widget _taskTile(ScheduledTask t) {
    final borderColor = t.done ? Colors.green.shade200
        : t.pendingValidation ? Colors.orange.shade300 : Colors.grey.shade200;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 1.5)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          dense: true,
          leading: Text(t.icon.isEmpty ? '📌' : t.icon, style: const TextStyle(fontSize: 20)),
          title: Text(t.title, style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            t.done ? '✅ Validé · ${t.childName}'
                : t.pendingValidation ? '⏳ En attente · ${t.childName}' : t.childName,
            style: TextStyle(fontSize: 11,
                color: t.pendingValidation && !t.done ? Colors.orange.shade700 : null),
          ),
          trailing: t.done
              ? Text('${t.rewardSeeds} 🌱',
                  style: TextStyle(fontSize: 12, color: t.rewardSeeds < 0 ? Colors.red : null))
              : t.pendingValidation
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                          onPressed: () => _validate(t), tooltip: 'Valider'),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _delete(t), tooltip: 'Supprimer'),
                    ]),
        ),
        if (t.pendingValidation && !t.done) ...[
          if (t.photoBase64 != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(t.photoBase64!.split(',').last),
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red)),
                  onPressed: () => _refuse(t),
                  child: const Text('Refuser'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: () => _validate(t),
                  child: const Text('Valider'),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PARENT REWARDS
// ══════════════════════════════════════════════════════════════

class ParentRewardsScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const ParentRewardsScreen({super.key, required this.onRefresh});
  @override
  State<ParentRewardsScreen> createState() => _ParentRewardsScreenState();
}

class _ParentRewardsScreenState extends State<ParentRewardsScreen> {
  int _childIdx = 0;

  Future<void> _redeem(ChildProfile child, RewardItem reward) async {
    if (child.seedsBalance < reward.costSeeds) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${child.name} n\'a pas assez de graines !')));
      return;
    }
    setState(() => child.seedsBalance -= reward.costSeeds);
    await AppData.save();
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    if (AppData.children.isEmpty) return const Center(child: Text('Aucun enfant.'));
    final idx   = _childIdx.clamp(0, AppData.children.length - 1);
    final child = AppData.children[idx];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<int>(
          initialValue: idx,
          items: List.generate(AppData.children.length, (i) =>
              DropdownMenuItem(value: i, child: Text(AppData.children[i].name))),
          onChanged: (v) => setState(() => _childIdx = v!),
        ),
        const SizedBox(height: 16),
        Card(color: AppPalette.softGreen, child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            const Text('🌱', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${child.seedsBalance} graines',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                                         color: AppPalette.brown)),
              Text('${child.lifetimeSeeds} gagnées au total',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ]),
        )),
        const SizedBox(height: 20),
        if (AppData.rewards.isEmpty)
          Text('Aucune récompense. Ajoute-en dans Réglages.',
              style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic))
        else ...[
          const Text('Récompenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...AppData.rewards.map((r) => Card(child: ListTile(
            leading: const Text('🎁', style: TextStyle(fontSize: 26)),
            title: Text(r.title), subtitle: Text('${r.costSeeds} graines'),
            trailing: ElevatedButton(
              onPressed: child.seedsBalance >= r.costSeeds ? () => _redeem(child, r) : null,
              child: const Text('Échanger'),
            ),
          ))),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PARENT SETTINGS — MENU
// ══════════════════════════════════════════════════════════════

class ParentSettingsScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const ParentSettingsScreen({super.key, required this.onRefresh});
  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  Future<void> _go(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    setState(() {}); widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ListView(children: [
      _tile(Icons.people_outline, 'Enfants',
          '${AppData.children.length} enfant(s) configuré(s)',
          () => _go(_ChildrenSettingsScreen(onRefresh: widget.onRefresh))),
      _tile(Icons.task_alt, 'Tâches',
          '${AppData.taskTemplates.length} tâche(s) définie(s)',
          () => _go(_TasksSettingsScreen(onRefresh: widget.onRefresh))),
      _tile(Icons.card_giftcard_outlined, 'Récompenses',
          '${AppData.rewards.length} récompense(s) définie(s)',
          () => _go(_RewardsSettingsScreen(onRefresh: widget.onRefresh))),
      _tile(Icons.lock_outline, 'Code PIN',
          AppData.parentPin.isEmpty ? 'Non défini — accès libre' : 'Code défini ●●●●',
          () => _go(_PinSettingsScreen(onRefresh: widget.onRefresh))),
      _tile(Icons.monetization_on_outlined, 'Valeur des graines',
          AppData.moneyEnabled
              ? 'Activé — 1 graine = ${AppData.moneyPerSeed} ${AppData.currencySymbol}'
              : 'Désactivé',
          () => _go(_MoneySettingsScreen(onRefresh: widget.onRefresh))),
      const Divider(height: 1),
      _tile(Icons.account_circle_outlined, 'Compte', user?.email ?? '',
          () => _go(_AccountSettingsScreen(onRefresh: widget.onRefresh))),
    ]);
  }

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: AppPalette.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      );
}

// ══════════════════════════════════════════════════════════════
// SOUS-ÉCRAN : ENFANTS
// ══════════════════════════════════════════════════════════════

class _ChildrenSettingsScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const _ChildrenSettingsScreen({required this.onRefresh});
  @override
  State<_ChildrenSettingsScreen> createState() => _ChildrenSettingsScreenState();
}

class _ChildrenSettingsScreenState extends State<_ChildrenSettingsScreen> {
  Future<void> _showChildDialog({ChildProfile? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedAnimal = existing?.animal ?? kChildAnimals[0];
    int selectedColor = existing?.colorIndex ?? 0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text(existing == null ? 'Ajouter un enfant' : 'Modifier le profil'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, autofocus: existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Prénom')),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft,
              child: Text('Animal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8,
            children: kChildAnimals.map((a) {
              final isSelected = selectedAnimal == a;
              final accent = kChildColorSchemes[selectedColor].accent;
              return GestureDetector(
                onTap: () => setS(() => selectedAnimal = a),
                child: Container(width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withValues(alpha: 0.2) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected ? Border.all(color: accent, width: 2.5) : null,
                  ),
                  child: Center(child: Text(a, style: const TextStyle(fontSize: 28))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft,
              child: Text('Couleur de la page',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10,
            children: kChildColorSchemes.asMap().entries.map((e) {
              final isSelected = selectedColor == e.key;
              return GestureDetector(
                onTap: () => setS(() => selectedColor = e.key),
                child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: e.value.accent, shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.black87, width: 3)
                        : Border.all(color: Colors.transparent, width: 3),
                    boxShadow: isSelected
                        ? [BoxShadow(color: e.value.accent.withValues(alpha: 0.5), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
              );
            }).toList(),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() {
                if (existing == null) {
                  AppData.children.add(ChildProfile(id: AppData.uid(), name: name,
                      animal: selectedAnimal, colorIndex: selectedColor));
                } else {
                  existing.name = name; existing.animal = selectedAnimal;
                  existing.colorIndex = selectedColor;
                }
              });
              await AppData.save(); widget.onRefresh();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enfants'), backgroundColor: AppPalette.softGreen),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ElevatedButton.icon(
          onPressed: () async { await _showChildDialog(); setState(() {}); },
          icon: const Icon(Icons.person_add), label: const Text('Ajouter un enfant'),
        ),
        const SizedBox(height: 12),
        if (AppData.children.isEmpty)
          Padding(padding: const EdgeInsets.all(24),
            child: Text('Aucun enfant ajouté.', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)))
        else
          ...AppData.children.map((c) => Card(child: ListTile(
            leading: Text(c.animal, style: const TextStyle(fontSize: 26)),
            title: Text(c.name),
            subtitle: Text('${c.seedsBalance} graines · ${c.lifetimeSeeds} au total'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                tooltip: 'Modifier',
                onPressed: () async { await _showChildDialog(existing: c); setState(() {}); }),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Supprimer',
                onPressed: () async {
                  setState(() => AppData.children.remove(c));
                  await AppData.save(); widget.onRefresh();
                }),
            ]),
          ))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SOUS-ÉCRAN : TÂCHES
// ══════════════════════════════════════════════════════════════

class _TasksSettingsScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const _TasksSettingsScreen({required this.onRefresh});
  @override
  State<_TasksSettingsScreen> createState() => _TasksSettingsScreenState();
}

class _TasksSettingsScreenState extends State<_TasksSettingsScreen> {
  Future<void> _showTaskDialog({TaskTemplate? existing}) async {
    bool isPenalty = existing != null && existing.rewardSeeds < 0;
    String selectedIcon = existing?.icon ?? '📌';
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final seedsCtrl = TextEditingController(
        text: (existing?.rewardSeeds.abs() ?? 5).toString());

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text(existing == null ? 'Ajouter une tâche' : 'Modifier la tâche'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Icône', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                                         color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          SizedBox(height: 200, child: SingleChildScrollView(
            child: Wrap(spacing: 6, runSpacing: 6,
              children: kTaskIcons.map((ico) => GestureDetector(
                onTap: () => setS(() => selectedIcon = ico),
                child: Container(width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: selectedIcon == ico ? AppPalette.softGreen : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: selectedIcon == ico
                        ? Border.all(color: AppPalette.green, width: 2) : null,
                  ),
                  child: Center(child: Text(ico, style: const TextStyle(fontSize: 18))),
                ),
              )).toList(),
            ),
          )),
          const SizedBox(height: 12),
          // Reward / Penalty toggle
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => setS(() => isPenalty = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !isPenalty ? AppPalette.softGreen : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: !isPenalty ? Border.all(color: AppPalette.green, width: 2) : null,
                ),
                child: const Column(children: [
                  Text('✅', style: TextStyle(fontSize: 20)),
                  Text('Récompense', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () => setS(() => isPenalty = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isPenalty ? Colors.red.shade100 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: isPenalty ? Border.all(color: Colors.red, width: 2) : null,
                ),
                child: const Column(children: [
                  Text('⚠️', style: TextStyle(fontSize: 20)),
                  Text('Pénalité', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: 12),
          TextField(controller: titleCtrl, autofocus: existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nom de la tâche', isDense: true)),
          const SizedBox(height: 8),
          TextField(
            controller: seedsCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Nombre de graines',
              prefixText: isPenalty ? '− ' : '+ ',
              isDense: true,
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final abs   = int.tryParse(seedsCtrl.text) ?? 0;
              if (title.isEmpty || abs <= 0) return;
              final seeds = isPenalty ? -abs : abs;
              setState(() {
                if (existing == null) {
                  AppData.taskTemplates.add(TaskTemplate(id: AppData.uid(),
                      title: title, icon: selectedIcon, rewardSeeds: seeds));
                } else {
                  existing.title = title; existing.icon = selectedIcon;
                  existing.rewardSeeds = seeds;
                }
              });
              await AppData.save(); widget.onRefresh();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tâches'), backgroundColor: AppPalette.softGreen),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Options pour les enfants',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        SwitchListTile(
          title: const Text('Preuve en photo'),
          subtitle: Text(AppData.photoProofEnabled
              ? 'Les enfants peuvent joindre une photo'
              : 'Option désactivée'),
          value: AppData.photoProofEnabled,
          onChanged: (v) async { setState(() => AppData.photoProofEnabled = v); await AppData.save(); },
        ),
        SwitchListTile(
          title: const Text('Afficher le calendrier'),
          subtitle: Text(AppData.childCalendarEnabled
              ? 'Les enfants voient l\'onglet calendrier'
              : 'Calendrier masqué pour les enfants'),
          value: AppData.childCalendarEnabled,
          onChanged: (v) async {
            setState(() => AppData.childCalendarEnabled = v); await AppData.save();
          },
        ),
        const Divider(height: 24),
        ElevatedButton.icon(
          onPressed: () async { await _showTaskDialog(); setState(() {}); },
          icon: const Icon(Icons.add), label: const Text('Ajouter une tâche'),
        ),
        const SizedBox(height: 8),
        if (AppData.taskTemplates.isEmpty)
          Padding(padding: const EdgeInsets.all(24),
            child: Text('Aucune tâche définie.', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)))
        else
          ...AppData.taskTemplates.map((t) => Card(child: ListTile(
            leading: Text(t.icon, style: const TextStyle(fontSize: 22)),
            title: Text(t.title),
            subtitle: Text(
              '${t.rewardSeeds > 0 ? '+' : ''}${t.rewardSeeds} graine${t.rewardSeeds.abs() > 1 ? 's' : ''}',
              style: TextStyle(color: t.rewardSeeds < 0 ? Colors.red : Colors.grey.shade600,
                  fontWeight: t.rewardSeeds < 0 ? FontWeight.w600 : FontWeight.normal),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  tooltip: 'Modifier',
                  onPressed: () async { await _showTaskDialog(existing: t); setState(() {}); }),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Supprimer',
                  onPressed: () async {
                    setState(() => AppData.taskTemplates.remove(t));
                    await AppData.save(); widget.onRefresh();
                  }),
            ]),
          ))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SOUS-ÉCRAN : RÉCOMPENSES
// ══════════════════════════════════════════════════════════════

class _RewardsSettingsScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const _RewardsSettingsScreen({required this.onRefresh});
  @override
  State<_RewardsSettingsScreen> createState() => _RewardsSettingsScreenState();
}

class _RewardsSettingsScreenState extends State<_RewardsSettingsScreen> {
  Future<void> _showRewardDialog({RewardItem? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final costCtrl  = TextEditingController(text: existing?.costSeeds.toString() ?? '20');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Ajouter une récompense' : 'Modifier la récompense'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, autofocus: existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nom de la récompense', isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: costCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Coût en graines', isDense: true)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final cost  = int.tryParse(costCtrl.text) ?? 0;
              if (title.isEmpty || cost <= 0) return;
              setState(() {
                if (existing == null) {
                  AppData.rewards.add(RewardItem(id: AppData.uid(), title: title, costSeeds: cost));
                } else { existing.title = title; existing.costSeeds = cost; }
              });
              await AppData.save(); widget.onRefresh();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Récompenses'), backgroundColor: AppPalette.softGreen),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ElevatedButton.icon(
          onPressed: () async { await _showRewardDialog(); setState(() {}); },
          icon: const Icon(Icons.add), label: const Text('Ajouter une récompense'),
        ),
        const SizedBox(height: 8),
        if (AppData.rewards.isEmpty)
          Padding(padding: const EdgeInsets.all(24),
            child: Text('Aucune récompense définie.', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)))
        else
          ...AppData.rewards.map((r) => Card(child: ListTile(
            leading: const Text('🎁', style: TextStyle(fontSize: 24)),
            title: Text(r.title), subtitle: Text('${r.costSeeds} graines'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  tooltip: 'Modifier',
                  onPressed: () async { await _showRewardDialog(existing: r); setState(() {}); }),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Supprimer',
                  onPressed: () async {
                    setState(() => AppData.rewards.remove(r));
                    await AppData.save(); widget.onRefresh();
                  }),
            ]),
          ))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SOUS-ÉCRAN : CODE PIN
// ══════════════════════════════════════════════════════════════

class _PinSettingsScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const _PinSettingsScreen({required this.onRefresh});
  @override
  State<_PinSettingsScreen> createState() => _PinSettingsScreenState();
}

class _PinSettingsScreenState extends State<_PinSettingsScreen> {
  Future<void> _showPinDialog() async {
    final ctrl1 = TextEditingController(), ctrl2 = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔒 Code PIN parent'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (AppData.parentPin.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Text('Code actuel défini. Entre un nouveau code pour le changer.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          TextField(controller: ctrl1, obscureText: true, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nouveau code (4 chiffres min)')),
          const SizedBox(height: 8),
          TextField(controller: ctrl2, obscureText: true, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Confirmer le code')),
        ]),
        actions: [
          if (AppData.parentPin.isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                setState(() => AppData.parentPin = '');
                await AppData.save();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Supprimer le code'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl1.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le code doit avoir au moins 4 chiffres.')));
                return;
              }
              if (ctrl1.text != ctrl2.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Les codes ne correspondent pas.')));
                return;
              }
              setState(() => AppData.parentPin = ctrl1.text);
              await AppData.save();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Code PIN'), backgroundColor: AppPalette.softGreen),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: ListTile(
          leading: const Icon(Icons.lock_outline, color: AppPalette.green),
          title: Text(AppData.parentPin.isEmpty ? 'Aucun code défini' : '● ● ● ●'),
          subtitle: Text(AppData.parentPin.isEmpty
              ? 'L\'accès parent est libre' : 'L\'accès parent est protégé'),
          trailing: ElevatedButton(
            onPressed: () async { await _showPinDialog(); setState(() {}); },
            child: Text(AppData.parentPin.isEmpty ? 'Définir' : 'Modifier'),
          ),
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SOUS-ÉCRAN : VALEUR DES GRAINES
// ══════════════════════════════════════════════════════════════

class _MoneySettingsScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const _MoneySettingsScreen({required this.onRefresh});
  @override
  State<_MoneySettingsScreen> createState() => _MoneySettingsScreenState();
}

class _MoneySettingsScreenState extends State<_MoneySettingsScreen> {
  late final TextEditingController _rateCtrl;
  late final TextEditingController _symbolCtrl;

  @override
  void initState() {
    super.initState();
    _rateCtrl   = TextEditingController(text: AppData.moneyPerSeed.toString());
    _symbolCtrl = TextEditingController(text: AppData.currencySymbol);
  }

  @override
  void dispose() { _rateCtrl.dispose(); _symbolCtrl.dispose(); super.dispose(); }

  Future<void> _saveRate() async {
    final rate   = double.tryParse(_rateCtrl.text.trim().replaceAll(',', '.'));
    final symbol = _symbolCtrl.text.trim();
    if (rate == null || rate <= 0 || symbol.isEmpty) return;
    setState(() { AppData.moneyPerSeed = rate; AppData.currencySymbol = symbol; });
    final messenger = ScaffoldMessenger.of(context);
    await AppData.save(); widget.onRefresh();
    if (mounted) messenger.showSnackBar(const SnackBar(content: Text('Taux enregistré ✅')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Valeur des graines'), backgroundColor: AppPalette.softGreen),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SwitchListTile(
          title: const Text('Afficher la valeur en argent'),
          subtitle: Text(AppData.moneyEnabled
              ? 'Affiché sur le profil de chaque enfant'
              : 'Les enfants voient seulement les graines'),
          value: AppData.moneyEnabled,
          onChanged: (v) async {
            setState(() => AppData.moneyEnabled = v);
            await AppData.save(); widget.onRefresh();
          },
        ),
        if (AppData.moneyEnabled) ...[
          const Divider(height: 24),
          const Text('Taux de conversion',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Padding(padding: EdgeInsets.only(bottom: 10),
                child: Text('1 graine = ', style: TextStyle(fontSize: 15))),
            SizedBox(width: 90, child: TextField(controller: _rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montant', isDense: true))),
            const SizedBox(width: 8),
            SizedBox(width: 60, child: TextField(controller: _symbolCtrl,
                decoration: const InputDecoration(labelText: 'Devise', isDense: true))),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _saveRate, child: const Text('OK')),
          ]),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SOUS-ÉCRAN : COMPTE
// ══════════════════════════════════════════════════════════════

class _AccountSettingsScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const _AccountSettingsScreen({required this.onRefresh});
  @override
  State<_AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<_AccountSettingsScreen> {
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Tes données restent sauvegardées dans le cloud.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final navigator = Navigator.of(context);
    AppData.clear();
    await FirebaseAuth.instance.signOut();
    navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()), (_) => false);
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final code = AppData.familyCode;
    final qrUrl = 'https://nvalmalette-max.github.io/Hamsterpoints/?code=$code';

    return Scaffold(
      appBar: AppBar(title: const Text('Compte'), backgroundColor: AppPalette.softGreen),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (user != null && user.email != null)
          Card(child: ListTile(
            leading: const Icon(Icons.account_circle, size: 40, color: AppPalette.green),
            title: Text(user.displayName ?? user.email!,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(user.email!),
          )),
        const SizedBox(height: 24),

        // ── Code famille ──────────────────────────────────
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Code famille', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Partagez ce code ou ce QR avec les appareils de vos enfants.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppPalette.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(code,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                        letterSpacing: 4, color: AppPalette.brown)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: qrUrl,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copié !')));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copier le code'),
              ),
            ),
          ]),
        )),
        const SizedBox(height: 24),

        if (user != null)
          ElevatedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MODE ENFANT
// ══════════════════════════════════════════════════════════════

class ChildModeScreen extends StatefulWidget {
  final String childId;
  const ChildModeScreen({super.key, required this.childId});
  @override
  State<ChildModeScreen> createState() => _ChildModeScreenState();
}

class _ChildModeScreenState extends State<ChildModeScreen> with TickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double>    _bounceAnim;
  late final AnimationController _sparkle;
  late final Animation<double>    _sparkleAnim;
  DateTime _calDay   = DateTime.now();
  DateTime _calFocus = DateTime.now();

  ChildProfile? get _child {
    try { return AppData.children.firstWhere((c) => c.id == widget.childId); }
    catch (_) { return null; }
  }

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: -10, end: 10).animate(
        CurvedAnimation(parent: _bounce, curve: Curves.easeInOut));
    _sparkle = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _sparkleAnim = Tween<double>(begin: 0, end: 1).animate(_sparkle);
  }

  @override
  void dispose() { _bounce.dispose(); _sparkle.dispose(); super.dispose(); }

  // ── Déclarer une tâche librement ──────────────────────────

  Future<void> _declareTask(TaskTemplate template, ChildProfile child) async {
    final isPenalty = template.rewardSeeds < 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${template.icon} ${template.title}'),
        content: Text(isPenalty
            ? 'Pénalité de ${template.rewardSeeds} graines. Confirmes-tu ?'
            : 'Super ! Tu as fait cette tâche aujourd\'hui ?\nTon parent validera et tu recevras ${template.rewardSeeds} graines 🌱'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isPenalty ? 'Confirmer' : 'Oui, j\'ai fait ça !'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    String? photo;
    if (AppData.photoProofEnabled && !isPenalty) {
      final result = await _showPhotoProofDialog();
      // null = cancelled dialog entirely → treat as no photo but continue
      photo = (result == null || result.isEmpty) ? null : result;
    }

    final today = DateTime.now();
    final task = ScheduledTask(
      id: AppData.uid(), childId: child.id, childName: child.name,
      title: template.title, icon: template.icon, rewardSeeds: template.rewardSeeds,
      date: DateTime(today.year, today.month, today.day),
      pendingValidation: true, photoBase64: photo,
    );
    setState(() => AppData.scheduledTasks.add(task));
    await AppData.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande envoyée à tes parents ✅')));
    }
  }

  // ── Marquer une tâche planifiée comme faite ──────────────

  Future<void> _confirmAndMark(ScheduledTask task, ChildProfile child) async {
    final isPenalty = task.rewardSeeds < 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${task.icon} ${task.title}'),
        content: Text(isPenalty
            ? 'Pénalité de ${task.rewardSeeds} graines. Confirmes-tu ?'
            : 'Super ! Tu as fait cette tâche ?\nTon parent validera et tu recevras ${task.rewardSeeds} graines 🌱'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isPenalty ? 'Confirmer' : 'Oui, j\'ai fait ça !'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _markPending(task);
  }

  Future<void> _markPending(ScheduledTask task) async {
    String? photo;
    if (AppData.photoProofEnabled) {
      final result = await _showPhotoProofDialog();
      photo = (result == null || result.isEmpty) ? null : result;
    }
    setState(() { task.pendingValidation = true; task.photoBase64 = photo; });
    await AppData.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande envoyée à tes parents ✅')));
    }
  }

  // Returns: null=annulé, ''=sans photo, 'data:...'=avec photo
  Future<String?> _showPhotoProofDialog() async {
    String? capturedPhoto;
    bool cancelled = true, confirmed = false;
    await showDialog<void>(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: const Text('📸 Preuve en photo'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Tu peux ajouter une photo pour montrer que tu as fini !',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (capturedPhoto != null) ...[
            ClipRRect(borderRadius: BorderRadius.circular(12),
              child: Image.memory(base64Decode(capturedPhoto!.split(',').last),
                  height: 140, width: double.infinity, fit: BoxFit.cover)),
            const SizedBox(height: 8),
          ],
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final p = await pickImageAsBase64();
                if (p != null) setS(() => capturedPhoto = p);
              },
              icon: const Icon(Icons.camera_alt),
              label: Text(capturedPhoto == null ? '📷 Choisir une photo' : '🔄 Changer'),
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () { cancelled = true; Navigator.pop(ctx); },
              child: const Text('Annuler')),
          TextButton(onPressed: () { cancelled = false; confirmed = false; Navigator.pop(ctx); },
              child: const Text('Sans photo')),
          if (capturedPhoto != null)
            ElevatedButton(onPressed: () { cancelled = false; confirmed = true; Navigator.pop(ctx); },
                child: const Text('Envoyer ✅')),
        ],
      )),
    );
    if (cancelled) return null;
    if (confirmed && capturedPhoto != null) return capturedPhoto;
    return '';
  }

  List<ScheduledTask> _tasksForDay(String childId, DateTime day) =>
      AppData.scheduledTasks.where((t) =>
        t.childId == childId &&
        t.date.year == day.year && t.date.month == day.month && t.date.day == day.day
      ).toList();

  @override
  Widget build(BuildContext context) {
    final child = _child;
    if (child == null) return const Scaffold(body: Center(child: Text('Profil introuvable 😢')));
    final scheme = child.colorScheme;

    if (!AppData.childCalendarEnabled) {
      return Scaffold(
        backgroundColor: scheme.bg,
        appBar: AppBar(
          title: Text('${child.name} ${child.animal}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: scheme.accent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _hamsterTab(child),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: scheme.bg,
        appBar: AppBar(
          title: Text('${child.name} ${child.animal}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: scheme.accent,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            labelColor: Colors.white, unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Text(child.animal, style: const TextStyle(fontSize: 20)),
                  text: 'Mon compagnon'),
              const Tab(icon: Icon(Icons.calendar_month), text: 'Mon calendrier'),
            ],
          ),
        ),
        body: TabBarView(children: [_hamsterTab(child), _calendarTab(child)]),
      ),
    );
  }

  Widget _hamsterTab(ChildProfile child) {
    final tasks = AppData.scheduledTasks
        .where((t) => t.childId == child.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _hamsterZone(child),
        const SizedBox(height: 28),
        _seedsBadge(child),
        const SizedBox(height: 28),
        _taskList(tasks, child),
        if (AppData.taskTemplates.isNotEmpty) ...[
          const SizedBox(height: 28),
          _declareSection(child),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _declareSection(ChildProfile child) {
    final scheme = child.colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Faire une tâche 🎯',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                           color: scheme.accent)),
      const SizedBox(height: 4),
      Text('Clique sur une tâche que tu as faite !',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      const SizedBox(height: 10),
      ...AppData.taskTemplates.map((t) => _taskTemplateTile(t, child)),
    ]);
  }

  Widget _taskTemplateTile(TaskTemplate t, ChildProfile child) {
    final scheme    = child.colorScheme;
    final isPenalty = t.rewardSeeds < 0;
    return GestureDetector(
      onTap: () => _declareTask(t, child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isPenalty ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPenalty ? Colors.red.shade200 : scheme.accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Text(t.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: isPenalty ? Colors.red.shade700 : Colors.black87)),
            Text(
              '${t.rewardSeeds > 0 ? '+' : ''}${t.rewardSeeds} graine${t.rewardSeeds.abs() > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 12,
                  color: isPenalty ? Colors.red.shade500 : Colors.grey.shade500),
            ),
          ])),
          Icon(isPenalty ? Icons.warning_amber_rounded : Icons.add_circle_outline,
              color: isPenalty ? Colors.red.shade300 : scheme.accent, size: 26),
        ]),
      ),
    );
  }

  Widget _calendarTab(ChildProfile child) {
    final scheme = child.colorScheme;
    final dayTasks = _tasksForDay(child.id, _calDay);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(6),
          child: TableCalendar(
            firstDay: DateTime.utc(2020), lastDay: DateTime.utc(2035),
            focusedDay: _calFocus,
            selectedDayPredicate: (d) => isSameDay(_calDay, d),
            onDaySelected: (sel, foc) => setState(() { _calDay = sel; _calFocus = foc; }),
            eventLoader: (day) => _tasksForDay(child.id, day),
            rowHeight: 36,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false, titleCentered: true,
              headerPadding: EdgeInsets.symmetric(vertical: 2),
              titleTextStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(Icons.chevron_left, size: 18),
              rightChevronIcon: Icon(Icons.chevron_right, size: 18),
              leftChevronPadding: EdgeInsets.zero, rightChevronPadding: EdgeInsets.zero,
            ),
            calendarStyle: CalendarStyle(
              cellMargin: const EdgeInsets.all(1),
              defaultTextStyle: const TextStyle(fontSize: 11),
              weekendTextStyle: const TextStyle(fontSize: 11, color: Colors.redAccent),
              selectedDecoration: BoxDecoration(color: scheme.accent, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(
                  color: scheme.accent.withValues(alpha: 0.4), shape: BoxShape.circle),
              outsideDaysVisible: false, markersMaxCount: 0,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (ctx, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: events.cast<ScheduledTask>().take(4).map((t) =>
                      Text(t.icon.isEmpty ? '·' : t.icon,
                           style: const TextStyle(fontSize: 7))).toList());
              },
            ),
          ),
        )),
        const SizedBox(height: 16),
        Text('Tâches du ${_calDay.day}/${_calDay.month}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (dayTasks.isEmpty)
          Text('Aucune tâche ce jour 🎉',
              style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic))
        else
          ...dayTasks.map((t) => _kawaiiTaskTile(t, child)),
      ],
    );
  }

  Widget _hamsterZone(ChildProfile child) {
    return Column(children: [
      AnimatedBuilder(
        animation: _bounceAnim,
        builder: (context, _) => Transform.translate(
          offset: Offset(0, _bounceAnim.value),
          child: _hamsterStack(child),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _moodColor(child.mood).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: _moodColor(child.mood).withValues(alpha: 0.4)),
        ),
        child: Text(_moodMessage(child.mood, child.name), textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: _moodColor(child.mood),
                             fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 8),
      Text(_stageLabel(child.stage), textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.purple.shade300,
                           fontStyle: FontStyle.italic)),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _stageProgressBar(child),
      ),
    ]);
  }

  Widget _stageProgressBar(ChildProfile child) {
    if (child.stage == HamsterStage.legendaire) {
      return const Text('🌈 Niveau maximum atteint !', textAlign: TextAlign.center,
          style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 13));
    }
    const thresholds = [0, 10, 30, 70, 150, 300, 500, 800];
    final idx = child.stage.index;
    final low  = thresholds[idx];
    final high = idx + 1 < thresholds.length ? thresholds[idx + 1] : low + 1;
    final progress = ((child.lifetimeSeeds - low) / (high - low)).clamp(0.0, 1.0);
    final remaining = high - child.lifetimeSeeds;
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: progress, minHeight: 10,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(_stageGlow(child.stage)),
        ),
      ),
      const SizedBox(height: 4),
      Text('+$remaining graines pour le prochain niveau 🎯', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]);
  }

  Widget _hamsterStack(ChildProfile child) {
    const z = 200.0;
    final s = _stageSize(child.stage);
    final m = child.mood;
    final sparkle = m == HamsterMood.excited || m == HamsterMood.happy;
    final crown   = child.stage.index >= HamsterStage.vaillant.index;
    final rainbow = child.stage == HamsterStage.legendaire;

    return SizedBox(width: z, height: z, child: Stack(alignment: Alignment.center, children: [
      Container(width: s + 50, height: s + 50,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            _stageGlow(child.stage).withValues(alpha: 0.35), Colors.transparent]),
        ),
      ),
      if (rainbow) ...[
        Container(width: s + 60, height: s + 60,
          decoration: const BoxDecoration(shape: BoxShape.circle,
            gradient: SweepGradient(colors: [
              Colors.red, Colors.orange, Colors.yellow,
              Colors.green, Colors.blue, Colors.purple, Colors.red,
            ]),
          ),
        ),
        Container(width: s + 48, height: s + 48,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.9))),
      ],
      Text(child.animal, style: TextStyle(fontSize: s)),
      if (crown) Positioned(top: (z - s) / 2 - 26,
          child: Text('👑', style: TextStyle(fontSize: s * 0.35))),
      Positioned(right: (z - s) / 2 - 18, bottom: (z - s) / 2 - 18,
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          padding: const EdgeInsets.all(4),
          child: Text(_moodEmoji(m), style: const TextStyle(fontSize: 24)),
        ),
      ),
      if (sparkle) ..._sparkles(z),
    ]));
  }

  List<Widget> _sparkles(double z) {
    const offsets = [
      Offset(0.08, 0.10), Offset(0.78, 0.10), Offset(0.05, 0.72),
      Offset(0.80, 0.72), Offset(0.42, 0.00), Offset(0.42, 0.86),
    ];
    return offsets.asMap().entries.map((e) {
      final phase = e.key / offsets.length;
      return AnimatedBuilder(
        animation: _sparkleAnim,
        builder: (context, _) {
          final t = (_sparkleAnim.value + phase) % 1.0;
          final op = sin(t * pi).clamp(0.0, 1.0);
          return Positioned(
            left: e.value.dx * z, top: e.value.dy * z,
            child: Opacity(opacity: op,
              child: Text('✨', style: TextStyle(fontSize: 10.0 + 8.0 * sin(t * pi)))),
          );
        },
      );
    }).toList();
  }

  Widget _seedsBadge(ChildProfile child) {
    final scheme = child.colorScheme;
    final moneyValue = AppData.moneyEnabled ? (child.seedsBalance * AppData.moneyPerSeed) : null;
    final moneyText = moneyValue != null
        ? '💵 ${moneyValue % 1 == 0 ? moneyValue.toInt() : moneyValue.toStringAsFixed(2)} ${AppData.currencySymbol}'
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.accent.withValues(alpha: 0.85), scheme.accent.withValues(alpha: 0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: scheme.accent.withValues(alpha: 0.3),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🌱', style: TextStyle(fontSize: 36)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${child.seedsBalance} graines',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                                     color: Colors.white)),
          if (moneyText != null)
            Text(moneyText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                                                    color: Colors.white)),
          Text('${child.lifetimeSeeds} gagnées au total 🏆',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
        ]),
      ]),
    );
  }

  Widget _taskList(List<ScheduledTask> tasks, ChildProfile child) {
    // Only show scheduled/pending tasks (not instantly declared ones still pending)
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Tâches planifiées 📋', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      ...tasks.take(20).map((t) => _kawaiiTaskTile(t, child)),
    ]);
  }

  Widget _kawaiiTaskTile(ScheduledTask t, ChildProfile child) {
    final scheme    = child.colorScheme;
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final taskDay   = DateTime(t.date.year, t.date.month, t.date.day);
    final isPast    = !taskDay.isAfter(today);
    final canMark   = !t.done && !t.pendingValidation && isPast;
    final isPenalty = t.rewardSeeds < 0;

    final borderColor = t.done
        ? AppPalette.kawaiiMint
        : t.pendingValidation ? Colors.orange.shade300
        : isPenalty ? Colors.red.shade200
        : scheme.accent.withValues(alpha: 0.4);

    final statusText = t.done
        ? (isPenalty ? 'Pénalité appliquée ⚠️' : 'Validée ✅')
        : t.pendingValidation ? 'En attente de validation... ⏳'
        : isPenalty
            ? '${t.rewardSeeds} graines ⚠️ · ${t.date.day}/${t.date.month}'
            : '${t.rewardSeeds} graines 🌱 · ${t.date.day}/${t.date.month}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isPenalty && !t.done ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(children: [
        Text(t.icon.isEmpty ? '📌' : t.icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.title, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold,
            decoration: t.done ? TextDecoration.lineThrough : null,
            color: t.done ? Colors.grey.shade400 : isPenalty ? Colors.red.shade700 : Colors.black87,
          )),
          Text(statusText, style: TextStyle(fontSize: 12,
            color: t.pendingValidation && !t.done ? Colors.orange.shade700
                : isPenalty && !t.done ? Colors.red.shade600 : Colors.grey.shade500,
          )),
        ])),
        if (canMark)
          GestureDetector(
            onTap: () => _confirmAndMark(t, child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: isPenalty ? Colors.red.shade400 : scheme.accent,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(isPenalty ? 'Compris 👍' : 'J\'ai fini ! 🙋',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
      ]),
    );
  }

  // ── Stage helpers ─────────────────────────────────────────

  double _stageSize(HamsterStage s) => switch (s) {
    HamsterStage.minuscule  => 36,
    HamsterStage.bebe       => 48,
    HamsterStage.petit      => 60,
    HamsterStage.moyen      => 70,
    HamsterStage.grand      => 80,
    HamsterStage.vaillant   => 90,
    HamsterStage.champion   => 100,
    HamsterStage.legendaire => 110,
  };

  Color _stageGlow(HamsterStage s) => switch (s) {
    HamsterStage.minuscule  => Colors.lightBlue,
    HamsterStage.bebe       => Colors.pink,
    HamsterStage.petit      => Colors.orange,
    HamsterStage.moyen      => Colors.green,
    HamsterStage.grand      => Colors.purple,
    HamsterStage.vaillant   => Colors.amber,
    HamsterStage.champion   => Colors.deepOrange,
    HamsterStage.legendaire => Colors.deepPurple,
  };

  String _stageLabel(HamsterStage s) => switch (s) {
    HamsterStage.minuscule  => '🌱 Tout nouveau ! Fais des tâches pour grandir !',
    HamsterStage.bebe       => '🌸 Bébé — ton compagnon commence à grandir !',
    HamsterStage.petit      => '🌟 Petit — tu es sur la bonne voie !',
    HamsterStage.moyen      => '⚡ Moyen — ton compagnon est en pleine forme !',
    HamsterStage.grand      => '💪 Grand — bravo, tu es exemplaire !',
    HamsterStage.vaillant   => '🌠 Vaillant — ton compagnon est fier de toi !',
    HamsterStage.champion   => '👑 Champion — tu es une star des tâches !',
    HamsterStage.legendaire => '🌈 Légendaire — tu es absolument incroyable !',
  };

  String _moodEmoji(HamsterMood m) => switch (m) {
    HamsterMood.sleeping => '😴',
    HamsterMood.sad      => '😢',
    HamsterMood.neutral  => '😊',
    HamsterMood.happy    => '😄',
    HamsterMood.excited  => '🤩',
  };

  Color _moodColor(HamsterMood m) => switch (m) {
    HamsterMood.sleeping => Colors.blueGrey,
    HamsterMood.sad      => Colors.indigo,
    HamsterMood.neutral  => Colors.teal,
    HamsterMood.happy    => Colors.green,
    HamsterMood.excited  => Colors.deepOrange,
  };

  String _moodMessage(HamsterMood m, String name) => switch (m) {
    HamsterMood.sleeping => 'Ton compagnon s\'ennuie... fais une tâche pour le réveiller !',
    HamsterMood.sad      => 'Ton compagnon est un peu triste. Il t\'attend ! 🥺',
    HamsterMood.neutral  => 'Ton compagnon est content et se repose 🌿',
    HamsterMood.happy    => 'Bravo $name ! Ton compagnon est heureux ! 🎉',
    HamsterMood.excited  => 'Waouh ! Ton compagnon est super content ! 🌟',
  };
}
