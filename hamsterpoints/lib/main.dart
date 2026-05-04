import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:table_calendar/table_calendar.dart';
import 'firebase_options.dart';

const List<String> kTaskIcons = [
  '🧹','🧽','🍽️','🛏️','🛁','🚿','🪣','🗑️',
  '📚','✏️','📖','🎒','📝','📐','🔬',
  '🌿','🌻','🌱','🐕','🐱','🐠',
  '🏃','🚴','⚽','🎯','🏊',
  '🎨','🎵','🎸','🎭','🖌️',
  '🛒','🍳','🧁','🍎','💊',
  '🚗','🚲','⭐','💪','🤝','🎁',
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
  ChildColorScheme(Color(0xFFFFF0F8), Color(0xFFFF8FAB)), // rose
  ChildColorScheme(Color(0xFFF0F8FF), Color(0xFF5DADE2)), // bleu
  ChildColorScheme(Color(0xFFF5F0FF), Color(0xFFAF7AC5)), // violet
  ChildColorScheme(Color(0xFFF0FFF4), Color(0xFF52BE80)), // vert
  ChildColorScheme(Color(0xFFFFFBF0), Color(0xFFE67E22)), // orange
  ChildColorScheme(Color(0xFFFFF0F0), Color(0xFFE74C3C)), // rouge
  ChildColorScheme(Color(0xFFF0FBFF), Color(0xFF1ABC9C)), // turquoise
  ChildColorScheme(Color(0xFFFFF8F0), Color(0xFFD4AC0D)), // doré
];

enum RecurrenceType { none, daily, weekdaysOnly, weekly, biweekly, monthly }
enum HamsterStage   { egg, baby, small, medium, large, legend }
enum HamsterMood    { sleeping, sad, neutral, happy, excited }

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
  String name;
  String animal;
  int colorIndex;
  int seedsBalance;
  int lifetimeSeeds;
  String? lastTaskDate;

  ChildProfile({required this.id, required this.name,
      this.animal = '🐹', this.colorIndex = 0,
      this.seedsBalance = 0, this.lifetimeSeeds = 0, this.lastTaskDate});

  HamsterStage get stage {
    if (lifetimeSeeds <  10) return HamsterStage.egg;
    if (lifetimeSeeds <  30) return HamsterStage.baby;
    if (lifetimeSeeds <  70) return HamsterStage.small;
    if (lifetimeSeeds < 150) return HamsterStage.medium;
    if (lifetimeSeeds < 300) return HamsterStage.large;
    return HamsterStage.legend;
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
  final String id; String title; String icon; int rewardSeeds;
  TaskTemplate({required this.id, required this.title,
                required this.icon, required this.rewardSeeds});
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

  ScheduledTask({required this.id, required this.childId, required this.childName,
      required this.title, required this.icon, required this.rewardSeeds,
      required this.date, this.done = false, this.pendingValidation = false});

  Map<String, dynamic> toJson() => {
    'id': id, 'childId': childId, 'childName': childName,
    'title': title, 'icon': icon, 'rewardSeeds': rewardSeeds,
    'date': date.toIso8601String(), 'done': done,
    'pendingValidation': pendingValidation,
  };
  factory ScheduledTask.fromJson(Map<String, dynamic> j) => ScheduledTask(
    id: j['id'] as String, childId: j['childId'] as String,
    childName: j['childName'] as String, title: j['title'] as String,
    icon: j['icon'] as String? ?? '📌',
    rewardSeeds: (j['rewardSeeds'] as num).toInt(),
    date: DateTime.parse(j['date'] as String),
    done: j['done'] as bool? ?? false,
    pendingValidation: j['pendingValidation'] as bool? ?? false,
  );
}

// ══════════════════════════════════════════════════════════════
// APP DATA — sauvegarde dans Firestore
// ══════════════════════════════════════════════════════════════

class AppData {
  static List<ChildProfile>  children       = [];
  static List<RewardItem>    rewards        = [];
  static List<TaskTemplate>  taskTemplates  = [];
  static List<ScheduledTask> scheduledTasks = [];
  static String              parentPin      = '';

  static String uid() => DateTime.now().microsecondsSinceEpoch.toString();

  static int get pendingCount =>
      scheduledTasks.where((t) => t.pendingValidation && !t.done).length;

  static DatabaseReference get _ref {
    final user = FirebaseAuth.instance.currentUser!;
    return FirebaseDatabase.instance.ref('users/${user.uid}');
  }

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
    if (FirebaseAuth.instance.currentUser == null) return;
    await _ref.set({
      'children':       children.map((e) => e.toJson()).toList(),
      'rewards':        rewards.map((e) => e.toJson()).toList(),
      'taskTemplates':  taskTemplates.map((e) => e.toJson()).toList(),
      'scheduledTasks': scheduledTasks.map((e) => e.toJson()).toList(),
      'parentPin':      parentPin,
    });
  }

  static Future<void> load() async {
    if (FirebaseAuth.instance.currentUser == null) return;
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
      parentPin      = data['parentPin'] as String? ?? '';
    } catch (_) {}
  }

  static void clear() {
    children = []; rewards = []; taskTemplates = [];
    scheduledTasks = []; parentPin = '';
  }
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
      home: const AuthGateScreen(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AUTH GATE — vérifie si connecté
// ══════════════════════════════════════════════════════════════

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) return const _AppLoader();
        return const LoginScreen();
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// APP LOADER — charge les données puis affiche l'app
// ══════════════════════════════════════════════════════════════

class _AppLoader extends StatefulWidget {
  const _AppLoader();
  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppData.load().then((_) {
      if (mounted) setState(() => _loaded = true);
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Erreur de chargement', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() { _error = null; _loaded = false; });
              AppData.load().then((_) {
                if (mounted) setState(() => _loaded = true);
              });
            },
            child: const Text('Réessayer'),
          ),
        ])),
      );
    }
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Chargement...'),
        ])),
      );
    }
    return const AppGateScreen();
  }
}

// ══════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ══════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final provider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(provider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.parentBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🐹', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              const Text('HamsterPoints',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Connecte-toi pour accéder à tes données\net les synchroniser entre tes appareils.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 48),
              if (_loading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Text('G',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                                       color: Color(0xFF4285F4))),
                  label: const Text('Continuer avec Google',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    elevation: 2,
                  ),
                ),
            ],
          ),
        ),
      ),
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
    final ctrl = TextEditingController();
    bool? result;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🔒 Code parent'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Code PIN'),
          onSubmitted: (_) {
            result = ctrl.text == AppData.parentPin;
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () { result = false; Navigator.pop(ctx); },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () { result = ctrl.text == AppData.parentPin; Navigator.pop(ctx); },
            child: const Text('Entrer'),
          ),
        ],
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
        title: const Text('🐹 HamsterPoints',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
              child: Text(
                'Aucun enfant ajouté.\nConnecte-toi en mode Parent → Réglages.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
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
    required Color color, required VoidCallback onTap, int badge = 0,
    String? avatar,
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
              if (badge > 0) Positioned(
                right: -4, top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 11,
                                             fontWeight: FontWeight.bold)),
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
      appBar: AppBar(
        title: const Text('Mode Parent 🌿'),
        backgroundColor: AppPalette.softGreen,
      ),
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
  int  _childIdx    = 0;
  int  _taskIdx     = 0;
  String? _filterChildId;
  RecurrenceType _recurrence = RecurrenceType.none;
  DateTime? _endDate;

  List<ScheduledTask> _tasksForDay(DateTime day, {String? childId}) =>
      AppData.scheduledTasks.where((t) {
        final dayMatch = t.date.year == day.year &&
            t.date.month == day.month && t.date.day == day.day;
        return dayMatch && (childId == null || t.childId == childId);
      }).toList();

  List<ScheduledTask> get _pending =>
      AppData.scheduledTasks.where((t) => t.pendingValidation && !t.done).toList();

  String _recurrenceLabel(RecurrenceType t) => switch (t) {
    RecurrenceType.none         => 'Une seule fois',
    RecurrenceType.daily        => 'Tous les jours',
    RecurrenceType.weekdaysOnly => 'Lun → Ven (sans week-end)',
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
        title: task.title, icon: task.icon,
        rewardSeeds: task.rewardSeeds, date: date,
      ));
    }
    await AppData.save();
    setState(() {});
    widget.onRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(dates.length > 1
              ? '${dates.length} tâches créées ✅' : 'Tâche attribuée ✅')));
    }
  }

  Future<void> _validate(ScheduledTask task) async {
    final idx = AppData.children.indexWhere((c) => c.id == task.childId);
    if (idx == -1) return;
    final child = AppData.children[idx];
    setState(() {
      task.done = true;
      task.pendingValidation = false;
      child.seedsBalance  += task.rewardSeeds;
      child.lifetimeSeeds += task.rewardSeeds;
      child.lastTaskDate   = DateTime.now().toIso8601String();
    });
    await AppData.save();
    widget.onRefresh();
  }

  Future<void> _delete(ScheduledTask task) async {
    setState(() => AppData.scheduledTasks.remove(task));
    await AppData.save();
    widget.onRefresh();
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _selectedDay.add(const Duration(days: 7)),
      firstDate: _selectedDay,
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dayTasks = _tasksForDay(_selectedDay, childId: _filterChildId);
    final pending  = _pending;
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

        Card(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: TableCalendar(
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2035),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
              onDaySelected: (sel, foc) =>
                  setState(() { _selectedDay = sel; _focusedDay = foc; }),
              eventLoader: (day) => _tasksForDay(day, childId: _filterChildId),
              rowHeight: 36,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false, titleCentered: true,
                headerPadding: EdgeInsets.symmetric(vertical: 2),
                titleTextStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                leftChevronIcon:  Icon(Icons.chevron_left,  size: 18),
                rightChevronIcon: Icon(Icons.chevron_right, size: 18),
                leftChevronPadding: EdgeInsets.zero,
                rightChevronPadding: EdgeInsets.zero,
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
                outsideDaysVisible: false,
                markersMaxCount: 0,
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (ctx, day, events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  final tasks = events.cast<ScheduledTask>();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: tasks.take(4).map((t) =>
                        Text(t.icon.isEmpty ? '·' : t.icon,
                             style: const TextStyle(fontSize: 7))).toList(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        if (pending.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('⚠️ ${pending.length} tâche${pending.length > 1 ? "s" : ""} à valider',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              const SizedBox(height: 6),
              ...pending.map((t) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(t.icon.isEmpty ? '📌' : t.icon,
                              style: const TextStyle(fontSize: 20)),
                title: Text(t.title, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${t.childName} · ${t.date.day}/${t.date.month}',
                               style: const TextStyle(fontSize: 11)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => _validate(t),
                  child: const Text('Valider', style: TextStyle(fontSize: 12)),
                ),
              )),
            ]),
          ),

        ExpansionTile(
          title: const Text('➕ Attribuer une tâche',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          children: [
            if (!hasData)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Va dans Réglages pour ajouter des enfants et des tâches.',
                            style: TextStyle(color: Colors.deepOrange)),
              )
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
                    items: RecurrenceType.values.map((r) => DropdownMenuItem(
                        value: r, child: Text(_recurrenceLabel(r)))).toList(),
                    onChanged: (v) => setState(() {
                      _recurrence = v!;
                      if (v == RecurrenceType.none) _endDate = null;
                    }),
                  ),
                  if (_recurrence != RecurrenceType.none) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text(_endDate == null
                          ? 'Choisir la date de fin'
                          : 'Fin : ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _assign,
                    icon: const Icon(Icons.add),
                    label: const Text('Attribuer'),
                  ),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 10),

        Text('Tâches du ${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (dayTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Aucune tâche ce jour.',
                style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
          )
        else
          ...dayTasks.map((t) => _taskTile(t)),
      ],
    );
  }

  Widget _chip(String label, String? childId) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: _filterChildId == childId,
        onSelected: (_) => setState(() => _filterChildId = childId),
      ),
    );
  }

  Widget _taskTile(ScheduledTask t) {
    final borderColor = t.done
        ? Colors.green.shade200
        : t.pendingValidation
            ? Colors.orange.shade300
            : Colors.grey.shade200;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: ListTile(
        dense: true,
        leading: Text(t.icon.isEmpty ? '📌' : t.icon, style: const TextStyle(fontSize: 20)),
        title: Text(t.title, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          t.done ? '✅ Validé · ${t.childName}'
              : t.pendingValidation ? '⏳ En attente · ${t.childName}'
              : t.childName,
          style: TextStyle(fontSize: 11,
              color: t.pendingValidation && !t.done ? Colors.orange.shade700 : null),
        ),
        trailing: t.done
            ? Text('${t.rewardSeeds} 🌱', style: const TextStyle(fontSize: 12))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                  onPressed: () => _validate(t), tooltip: 'Valider',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _delete(t), tooltip: 'Supprimer',
                ),
              ]),
      ),
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
    if (AppData.children.isEmpty) {
      return const Center(child: Text('Aucun enfant. Va dans Réglages.'));
    }
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
        Card(
          color: AppPalette.softGreen,
          child: Padding(
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
          ),
        ),
        const SizedBox(height: 20),
        if (AppData.rewards.isEmpty)
          Text('Aucune récompense. Ajoute-en dans Réglages.',
              style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic))
        else ...[
          const Text('Récompenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...AppData.rewards.map((r) => Card(
            child: ListTile(
              leading: const Text('🎁', style: TextStyle(fontSize: 26)),
              title: Text(r.title),
              subtitle: Text('${r.costSeeds} graines'),
              trailing: ElevatedButton(
                onPressed: child.seedsBalance >= r.costSeeds ? () => _redeem(child, r) : null,
                child: const Text('Échanger'),
              ),
            ),
          )),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PARENT SETTINGS
// ══════════════════════════════════════════════════════════════

class ParentSettingsScreen extends StatefulWidget {
  final VoidCallback onRefresh;
  const ParentSettingsScreen({super.key, required this.onRefresh});
  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  final _taskCtrl       = TextEditingController();
  final _taskPtsCtrl    = TextEditingController(text: '5');
  final _rewardCtrl     = TextEditingController();
  final _rewardCostCtrl = TextEditingController(text: '20');
  String _icon = '📌';

  @override
  void dispose() {
    _taskCtrl.dispose(); _taskPtsCtrl.dispose();
    _rewardCtrl.dispose(); _rewardCostCtrl.dispose();
    super.dispose();
  }

  Future<void> _showChildDialog({ChildProfile? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedAnimal = existing?.animal ?? kChildAnimals[0];
    int selectedColor = existing?.colorIndex ?? 0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existing == null ? 'Ajouter un enfant' : 'Modifier le profil'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                autofocus: existing == null,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Animal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: kChildAnimals.map((a) {
                  final isSelected = selectedAnimal == a;
                  final accent = kChildColorSchemes[selectedColor].accent;
                  return GestureDetector(
                    onTap: () => setS(() => selectedAnimal = a),
                    child: Container(
                      width: 48, height: 48,
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
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Couleur de la page', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: kChildColorSchemes.asMap().entries.map((e) {
                  final isSelected = selectedColor == e.key;
                  return GestureDetector(
                    onTap: () => setS(() => selectedColor = e.key),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: e.value.accent,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black87, width: 3)
                            : Border.all(color: Colors.transparent, width: 3),
                        boxShadow: isSelected
                            ? [BoxShadow(color: e.value.accent.withValues(alpha: 0.5), blurRadius: 8)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                setState(() {
                  if (existing == null) {
                    AppData.children.add(ChildProfile(
                      id: AppData.uid(), name: name,
                      animal: selectedAnimal, colorIndex: selectedColor,
                    ));
                  } else {
                    existing.name = name;
                    existing.animal = selectedAnimal;
                    existing.colorIndex = selectedColor;
                  }
                });
                await AppData.save();
                widget.onRefresh();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTask() async {
    final title = _taskCtrl.text.trim();
    final pts   = int.tryParse(_taskPtsCtrl.text) ?? 0;
    if (title.isEmpty || pts <= 0) return;
    setState(() => AppData.taskTemplates.add(
        TaskTemplate(id: AppData.uid(), title: title, icon: _icon, rewardSeeds: pts)));
    _taskCtrl.clear(); _taskPtsCtrl.text = '5';
    await AppData.save();
  }

  Future<void> _addReward() async {
    final title = _rewardCtrl.text.trim();
    final cost  = int.tryParse(_rewardCostCtrl.text) ?? 0;
    if (title.isEmpty || cost <= 0) return;
    setState(() => AppData.rewards.add(
        RewardItem(id: AppData.uid(), title: title, costSeeds: cost)));
    _rewardCtrl.clear(); _rewardCostCtrl.text = '20';
    await AppData.save();
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Choisir une icône',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kTaskIcons.map((ico) => GestureDetector(
              onTap: () { setState(() => _icon = ico); Navigator.pop(ctx); },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _icon == ico ? AppPalette.softGreen : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(ico, style: const TextStyle(fontSize: 22))),
              ),
            )).toList(),
          ),
        ]),
      ),
    );
  }

  Future<void> _showPinDialog() async {
    final ctrl1 = TextEditingController();
    final ctrl2 = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔒 Code PIN parent'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (AppData.parentPin.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Code actuel défini. Entre un nouveau code pour le changer.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
          TextField(controller: ctrl1, obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nouveau code (4 chiffres min)')),
          const SizedBox(height: 8),
          TextField(controller: ctrl2, obscureText: true,
              keyboardType: TextInputType.number,
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

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
            'Tes données restent sauvegardées dans le cloud.\nTu pourras te reconnecter à tout moment.'),
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
    if (confirm == true) {
      AppData.clear();
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Compte ────────────────────────────────────────
        _header('👤 Compte'),
        ListTile(
          leading: const Icon(Icons.account_circle, size: 36, color: AppPalette.green),
          title: Text(user?.displayName ?? user?.email ?? 'Connecté'),
          subtitle: Text(user?.email ?? ''),
          trailing: TextButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Déconnecter'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ),
        const Divider(height: 32),

        // ── PIN ───────────────────────────────────────────
        _header('🔒 Code PIN parent'),
        ListTile(
          title: Text(AppData.parentPin.isEmpty ? 'Aucun code défini' : '● ● ● ●'),
          subtitle: Text(AppData.parentPin.isEmpty
              ? 'Accès parent libre' : 'Accès parent protégé'),
          trailing: ElevatedButton(
            onPressed: _showPinDialog,
            child: Text(AppData.parentPin.isEmpty ? 'Définir' : 'Modifier'),
          ),
        ),
        const Divider(height: 32),

        // ── Enfants ───────────────────────────────────────
        _header('👨‍👩‍👧 Enfants'),
        const SizedBox(height: 4),
        ElevatedButton.icon(
          onPressed: () => _showChildDialog(),
          icon: const Icon(Icons.person_add),
          label: const Text('Ajouter un enfant'),
        ),
        const SizedBox(height: 8),
        ...AppData.children.map((c) => ListTile(
          leading: Text(c.animal, style: const TextStyle(fontSize: 26)),
          title: Text(c.name),
          subtitle: Text('${c.seedsBalance} graines · ${c.lifetimeSeeds} au total'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
              tooltip: 'Modifier',
              onPressed: () async {
                await _showChildDialog(existing: c);
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Supprimer',
              onPressed: () async {
                setState(() => AppData.children.remove(c));
                await AppData.save(); widget.onRefresh();
              },
            ),
          ]),
        )),
        const Divider(height: 32),

        // ── Tâches ────────────────────────────────────────
        _header('✅ Tâches'),
        Row(children: [
          GestureDetector(
            onTap: _showIconPicker,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: AppPalette.softGreen, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(_icon, style: const TextStyle(fontSize: 26))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _taskCtrl,
              decoration: const InputDecoration(labelText: 'Nom de la tâche'))),
          const SizedBox(width: 8),
          SizedBox(width: 70, child: TextField(controller: _taskPtsCtrl,
              decoration: const InputDecoration(labelText: 'Graines'),
              keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _addTask, child: const Text('+')),
        ]),
        const SizedBox(height: 8),
        ...AppData.taskTemplates.map((t) => ListTile(
          leading: Text(t.icon, style: const TextStyle(fontSize: 22)),
          title: Text(t.title),
          subtitle: Text('${t.rewardSeeds} graines'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              setState(() => AppData.taskTemplates.remove(t));
              await AppData.save();
            },
          ),
        )),
        const Divider(height: 32),

        // ── Récompenses ───────────────────────────────────
        _header('🎁 Récompenses'),
        Row(children: [
          Expanded(child: TextField(controller: _rewardCtrl,
              decoration: const InputDecoration(labelText: 'Nom de la récompense'))),
          const SizedBox(width: 8),
          SizedBox(width: 80, child: TextField(controller: _rewardCostCtrl,
              decoration: const InputDecoration(labelText: 'Coût'),
              keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _addReward, child: const Text('+')),
        ]),
        const SizedBox(height: 8),
        ...AppData.rewards.map((r) => ListTile(
          title: Text(r.title),
          subtitle: Text('${r.costSeeds} graines'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              setState(() => AppData.rewards.remove(r));
              await AppData.save();
            },
          ),
        )),
      ],
    );
  }

  Widget _header(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
  );
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

  Future<void> _markPending(ScheduledTask task) async {
    setState(() => task.pendingValidation = true);
    await AppData.save();
  }

  List<ScheduledTask> _tasksForDay(String childId, DateTime day) =>
      AppData.scheduledTasks.where((t) =>
        t.childId == childId &&
        t.date.year == day.year && t.date.month == day.month && t.date.day == day.day
      ).toList();

  @override
  Widget build(BuildContext context) {
    final child = _child;
    if (child == null) {
      return const Scaffold(body: Center(child: Text('Profil introuvable 😢')));
    }
    final scheme = child.colorScheme;
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
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Text(child.animal, style: const TextStyle(fontSize: 20)),
                  text: 'Mon compagnon'),
              const Tab(icon: Icon(Icons.calendar_month), text: 'Mon calendrier'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _hamsterTab(child),
          _calendarTab(child),
        ]),
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
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _calendarTab(ChildProfile child) {
    final scheme = child.colorScheme;
    final dayTasks = _tasksForDay(child.id, _calDay);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: TableCalendar(
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2035),
              focusedDay: _calFocus,
              selectedDayPredicate: (d) => isSameDay(_calDay, d),
              onDaySelected: (sel, foc) =>
                  setState(() { _calDay = sel; _calFocus = foc; }),
              eventLoader: (day) => _tasksForDay(child.id, day),
              rowHeight: 36,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false, titleCentered: true,
                headerPadding: EdgeInsets.symmetric(vertical: 2),
                titleTextStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                leftChevronIcon:  Icon(Icons.chevron_left,  size: 18),
                rightChevronIcon: Icon(Icons.chevron_right, size: 18),
                leftChevronPadding: EdgeInsets.zero,
                rightChevronPadding: EdgeInsets.zero,
              ),
              calendarStyle: CalendarStyle(
                cellMargin: const EdgeInsets.all(1),
                defaultTextStyle: const TextStyle(fontSize: 11),
                weekendTextStyle: const TextStyle(fontSize: 11, color: Colors.redAccent),
                selectedDecoration: BoxDecoration(color: scheme.accent, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(
                    color: scheme.accent.withValues(alpha: 0.4), shape: BoxShape.circle),
                outsideDaysVisible: false,
                markersMaxCount: 0,
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (ctx, day, events) {
                  if (events.isEmpty) return const SizedBox.shrink();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: events.cast<ScheduledTask>().take(4).map((t) =>
                        Text(t.icon.isEmpty ? '·' : t.icon,
                             style: const TextStyle(fontSize: 7))).toList(),
                  );
                },
              ),
            ),
          ),
        ),
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
        child: Text(_moodMessage(child.mood, child.name),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: _moodColor(child.mood),
                             fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 8),
      Text(_stageLabel(child.stage),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.purple.shade300,
                           fontStyle: FontStyle.italic)),
    ]);
  }

  Widget _hamsterStack(ChildProfile child) {
    const z = 200.0;
    final s = _stageSize(child.stage);
    final m = child.mood;
    final sparkle = m == HamsterMood.excited || m == HamsterMood.happy;
    final crown   = child.stage.index >= HamsterStage.large.index;
    final rainbow = child.stage == HamsterStage.legend;

    return SizedBox(width: z, height: z, child: Stack(alignment: Alignment.center, children: [
      Container(
        width: s + 50, height: s + 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [_stageGlow(child.stage).withValues(alpha: 0.35), Colors.transparent]),
        ),
      ),
      if (rainbow) ...[
        Container(
          width: s + 60, height: s + 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(colors: [
              Colors.red, Colors.orange, Colors.yellow,
              Colors.green, Colors.blue, Colors.purple, Colors.red,
            ]),
          ),
        ),
        Container(
          width: s + 48, height: s + 48,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.9)),
        ),
      ],
      Text(_stageEmoji(child.stage, child.animal), style: TextStyle(fontSize: s)),
      if (crown) Positioned(
        top: (z - s) / 2 - 26,
        child: Text('👑', style: TextStyle(fontSize: s * 0.35)),
      ),
      Positioned(
        right: (z - s) / 2 - 18, bottom: (z - s) / 2 - 18,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.accent.withValues(alpha: 0.85), scheme.accent.withValues(alpha: 0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(
            color: scheme.accent.withValues(alpha: 0.3),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🌱', style: TextStyle(fontSize: 36)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${child.seedsBalance} graines',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                                     color: Colors.white)),
          Text('${child.lifetimeSeeds} gagnées au total 🏆',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
        ]),
      ]),
    );
  }

  Widget _taskList(List<ScheduledTask> tasks, ChildProfile child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Mes tâches 📋',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (tasks.isEmpty)
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Text('Aucune tâche pour le moment 🎉',
              style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
        )
      else
        ...tasks.take(20).map((t) => _kawaiiTaskTile(t, child)),
    ]);
  }

  Widget _kawaiiTaskTile(ScheduledTask t, ChildProfile child) {
    final scheme  = child.colorScheme;
    final now     = DateTime.now();
    final isPast  = !t.date.isAfter(DateTime(now.year, now.month, now.day));
    final canMark = !t.done && !t.pendingValidation && isPast;

    final borderColor = t.done
        ? AppPalette.kawaiiMint
        : t.pendingValidation
            ? Colors.orange.shade300
            : scheme.accent.withValues(alpha: 0.4);

    final statusText = t.done
        ? 'Validée ✅'
        : t.pendingValidation
            ? 'En attente de validation... ⏳'
            : '${t.rewardSeeds} graines 🌱 · ${t.date.day}/${t.date.month}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
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
            color: t.done ? Colors.grey.shade400 : Colors.black87,
          )),
          Text(statusText, style: TextStyle(
            fontSize: 12,
            color: t.pendingValidation && !t.done
                ? Colors.orange.shade700 : Colors.grey.shade500,
          )),
        ])),
        if (canMark)
          GestureDetector(
            onTap: () => _markPending(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: scheme.accent, borderRadius: BorderRadius.circular(20)),
              child: const Text('J\'ai fini ! 🙋',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
      ]),
    );
  }

  String _stageEmoji(HamsterStage s, String animal) => switch (s) {
    HamsterStage.egg    => '🥚',
    HamsterStage.baby   => '🐣',
    HamsterStage.small  => animal,
    HamsterStage.medium => animal,
    HamsterStage.large  => animal,
    HamsterStage.legend => animal,
  };

  double _stageSize(HamsterStage s) => switch (s) {
    HamsterStage.egg    => 55,
    HamsterStage.baby   => 65,
    HamsterStage.small  => 75,
    HamsterStage.medium => 85,
    HamsterStage.large  => 95,
    HamsterStage.legend => 105,
  };

  Color _stageGlow(HamsterStage s) => switch (s) {
    HamsterStage.egg    => Colors.lightBlue,
    HamsterStage.baby   => Colors.pink,
    HamsterStage.small  => Colors.orange,
    HamsterStage.medium => Colors.purple,
    HamsterStage.large  => Colors.amber,
    HamsterStage.legend => Colors.deepPurple,
  };

  String _stageLabel(HamsterStage s) => switch (s) {
    HamsterStage.egg    => '✨ Encore un œuf... fais des tâches pour le faire éclore !',
    HamsterStage.baby   => '🌸 Bébé — tu commences bien !',
    HamsterStage.small  => '🌟 Petit compagnon — tu grandis !',
    HamsterStage.medium => '⚡ Junior — tu es en pleine forme !',
    HamsterStage.large  => '👑 Grand compagnon — champion des tâches !',
    HamsterStage.legend => '🌈 Compagnon légendaire — tu es incroyable !',
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
