import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../features/lesson_progress/services/lesson_progress_controller.dart';
import '../features/lesson_progress/widgets/lesson_progress_card.dart';
import '../models/models.dart';
import '../utils/time_utils.dart';
import '../widgets/common.dart';
import '../widgets/manual_bell_sheet.dart';
import 'backup_screen.dart';
import 'holidays_screen.dart';
import 'logs_screen.dart';
import 'schedule_hub_screen.dart';
import 'schools_screen.dart';
import 'settings_screen.dart';
import 'sounds_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LessonProgressController? _controller;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    _controller ??= LessonProgressController(app.dayProvider)..start();
    final id = app.selected?.building.id;
    if (id != null) _controller!.setBuilding(id);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _pickBuilding(AppState app) async {
    final refs = await app.schools.allBuildingRefs();
    if (!mounted) return;
    if (refs.isEmpty) {
      _push(const SchoolsScreen());
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(shrinkWrap: true, children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختر المدرسة والمبنى', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final r in refs)
              ListTile(
                leading: Icon(r.building.id == app.selected?.building.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                title: Text(r.title),
                subtitle: r.schoolActive ? null : const Text('المدرسة معطّلة: لا تُجدول أجراسها'),
                onTap: () => Navigator.pop(ctx, r.building.id),
              ),
          ]),
        ),
      ),
    );
    if (picked != null) await app.selectBuilding(picked);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sel = app.selected;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الجرس المدرسي الذكي')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildingCard(app, sel),
                  if (sel == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('ابدأ بإضافة مدرسة ومبنى، ثم أنشئ جدول الأجراس من شاشة «الجدول».'),
                      ),
                    )
                  else ...[
                    LessonProgressCard(controller: _controller!),
                    _nextBellCard(app),
                    _statusCard(app),
                    _bellButtons(app),
                  ],
                  const SizedBox(height: 8),
                  _shortcuts(app),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildingCard(AppState app, BuildingRef? sel) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _pickBuilding(app),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.school, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(sel?.title ?? 'لم يتم اختيار مدرسة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.expand_more),
            ]),
            const SizedBox(height: 8),
            Ticking(
              builder: (c, now) => Text('${arabicDate(now)}   ${formatClock(now)}',
                  style: Theme.of(c).textTheme.bodyLarge),
            ),
            if (app.dayInfo != null) ...[
              const SizedBox(height: 6),
              Chip(
                avatar: Icon(app.dayInfo!.kind == 'normal' ? Icons.check_circle : Icons.event,
                    size: 18),
                label: Text(app.dayInfo!.label),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _nextBellCard(AppState app) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Ticking(
          builder: (c, now) {
            final a = app.nextAlarm(now);
            if (a == null) {
              return const Row(children: [
                Icon(Icons.notifications_off_outlined),
                SizedBox(width: 10),
                Expanded(child: Text('لا يوجد جرس مجدول قادم خلال الأيام القادمة')),
              ]);
            }
            final at = DateTime.parse((a['local'] as String).replaceFirst(' ', 'T'));
            final remaining = at.difference(now);
            final today = at.year == now.year && at.month == now.month && at.day == now.day;
            return Row(children: [
              const Icon(Icons.notifications_active_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الجرس التالي: ${a['label']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${today ? 'اليوم' : weekdayNames[at.weekday]} ${hm(at.hour * 60 + at.minute)}'),
                ]),
              ),
              Text(formatDuration(remaining),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ]);
          },
        ),
      ),
    );
  }

  Widget _statusCard(AppState app) {
    final routeText = switch (app.audioRoute) {
      'wired' => 'متصل بمخرج سلكي (AUX/سماعة) - تقدير تقريبي',
      'bluetooth' => 'متصل ببلوتوث - تقدير تقريبي',
      'speaker' => 'سماعة الهاتف (لا يوجد مخرج خارجي)',
      _ => 'غير معروف',
    };
    final schedOk = app.scheduledCount > 0 && app.exactAllowed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _statusRow(
              schedOk ? Icons.check_circle : Icons.warning_amber_rounded,
              schedOk ? Colors.green.shade700 : Colors.orange.shade800,
              app.scheduledCount < 0
                  ? 'الجدولة: فشلت (راجع السجل والإعدادات)'
                  : app.scheduledCount == 0
                      ? 'الجدولة: لا توجد أجراس مجدولة'
                      : app.exactAllowed
                          ? 'الجدولة: ${app.scheduledCount} جرسًا مجدولًا (دقيقة)'
                          : 'الجدولة: ${app.scheduledCount} جرسًا لكن بدون صلاحية الدقة'),
          const SizedBox(height: 6),
          _statusRow(Icons.volume_up, Colors.blueGrey, 'الصوت: $routeText'),
          if (app.ringing) ...[
            const SizedBox(height: 6),
            _statusRow(Icons.graphic_eq, Colors.red.shade700, 'الجرس يعمل الآن'),
          ],
        ]),
      ),
    );
  }

  Widget _statusRow(IconData i, Color c, String t) => Row(children: [
        Icon(i, color: c, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(t)),
      ]);

  Widget _bellButtons(AppState app) {
    return Column(children: [
      SizedBox(
        height: 72,
        child: FilledButton.icon(
          icon: const Icon(Icons.notifications_active, size: 32),
          label: const Text('تشغيل الجرس', style: TextStyle(fontSize: 22)),
          onPressed: () {
            final now = DateTime.now();
            if (now.difference(_lastTap) < const Duration(seconds: 3)) return; // منع الضغط المتكرر
            _lastTap = now;
            if (app.ringing) {
              showMsg(context, 'يوجد رنين جارٍ. أوقفه أولًا.', error: true);
              return;
            }
            showManualBellSheet(context);
          },
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('إيقاف الرنين الحالي', style: TextStyle(fontSize: 18)),
          onPressed: () async {
            await app.stopBell();
            if (mounted) showMsg(context, 'تم إرسال أمر الإيقاف');
          },
        ),
      ),
    ]);
  }

  Widget _shortcuts(AppState app) {
    final sel = app.selected;
    final items = <(IconData, String, VoidCallback)>[
      (Icons.schedule, 'الجدول', () {
        if (sel == null) {
          showMsg(context, 'اختر مبنى أولًا', error: true);
        } else {
          _push(ScheduleHubScreen(building: sel.building, schoolName: sel.schoolName));
        }
      }),
      (Icons.library_music, 'الأصوات', () => _push(const SoundsScreen())),
      (Icons.beach_access, 'الإجازات', () => _push(const HolidaysScreen())),
      (Icons.business, 'المدارس', () => _push(const SchoolsScreen())),
      (Icons.history, 'السجل', () => _push(const LogsScreen())),
      (Icons.backup, 'النسخ الاحتياطي', () => _push(const BackupScreen())),
      (Icons.settings, 'الإعدادات', () => _push(const SettingsScreen())),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final it in items)
          SizedBox(
            width: 148,
            height: 84,
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: it.$3,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(it.$1, size: 30),
                  const SizedBox(height: 6),
                  Text(it.$2),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}
