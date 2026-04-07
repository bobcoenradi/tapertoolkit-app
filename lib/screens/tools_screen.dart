import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/taper_plan_model.dart';
import '../services/firestore_service.dart';
import 'taper_wizard_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  TaperPlan? _plan;
  bool _loadingPlan = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plan = await FirestoreService.fetchActiveTaperPlan();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loadingPlan = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPlan = false);
    }
  }

  Future<void> _openWizard() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TaperWizardScreen()),
    );
    if (created == true) _load();
  }

  void _showFullSchedule(TaperPlan plan) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _FullScheduleSheet(plan: plan, onSaved: _load),
    );
  }

  Future<void> _toggleHold() async {
    if (_plan == null) return;
    final isHold = _plan!.status == 'hold';
    final newStatus = isHold ? 'active' : 'hold';
    final stepIdx = isHold ? _plan!.holdAtStepIndex : _plan!.currentStepIndex;
    await FirestoreService.updateTaperPlanStatus(_plan!.id, newStatus, stepIdx);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_loadingPlan)
              const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )),
              )
            else ...[
              SliverToBoxAdapter(child: _buildToolsSection()),
              SliverToBoxAdapter(child: _buildProgressChart()),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
    child: Text('Tools', style: AppTextStyles.h2()),
  );

  // ─── Tool cards section ──────────────────────────────────────────────────

  Widget _buildToolsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('My Tools', style: AppTextStyles.h4()),
        const SizedBox(height: 12),
        // Taper Wizard tool card
        _plan != null ? _buildActivePlan(_plan!) : _buildEmptyWizardCard(),
        // Future tool cards can be added here
      ]),
    );
  }

  // ─── Empty / no plan state ───────────────────────────────────────────────

  Widget _buildEmptyWizardCard() {
    return Container(
      decoration: AppDecorations.gradientCard(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.route_outlined, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Guided Taper Wizard', style: AppTextStyles.h4()),
            Text('No active taper plan', style: AppTextStyles.body()),
          ])),
        ]),
        const SizedBox(height: 16),
        Text(
          'Create a personalised taper schedule based on the Maudsley Deprescribing Guidelines. '
          'Track your progress, set dose reminders, and stay on track.',
          style: AppTextStyles.body(color: AppColors.textMid),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _openWizard,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Start My Taper', style: AppTextStyles.label(color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  // ─── Active plan overview ────────────────────────────────────────────────

  Widget _buildActivePlan(TaperPlan plan) {
    final steps = plan.steps;
    final totalSteps = steps.length - 1;
    final doneSteps = plan.currentStepIndex;
    final progress = plan.progressFraction;
    final isHold = plan.status == 'hold';

    return Column(children: [

      // Tool card header
      Container(
        decoration: AppDecorations.gradientCard(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Card label row
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.route_outlined, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Guided Taper Wizard', style: AppTextStyles.label(color: AppColors.primary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isHold
                    ? AppColors.warning.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(isHold ? 'On Hold' : 'Active',
                  style: AppTextStyles.caption(
                    color: isHold ? AppColors.warning : AppColors.primary,
                  ).copyWith(fontWeight: FontWeight.w600)),
            ),
          ]),

          const SizedBox(height: 16),

          // Medication name
          Text(plan.medicationName, style: AppTextStyles.h3()),
          Text('${plan.startDose}mg → ${plan.targetDose}mg',
              style: AppTextStyles.body()),

          const SizedBox(height: 16),

          // Current dose display
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CURRENT DOSE',
                  style: AppTextStyles.caption(color: AppColors.primary)
                      .copyWith(letterSpacing: 0.8)),
              Text('${plan.currentDose}mg',
                  style: AppTextStyles.h1(color: AppColors.textDark)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('STEP',
                  style: AppTextStyles.caption(color: AppColors.textLight)
                      .copyWith(letterSpacing: 0.8)),
              Text('${doneSteps + 1} / ${totalSteps + 1}',
                  style: AppTextStyles.h3(color: AppColors.textDark)),
            ]),
          ]),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.5),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text('${(progress * 100).round()}% complete',
              style: AppTextStyles.caption(color: AppColors.textMid)),

          // Next step
          if (!isHold && plan.nextStepDate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.arrow_downward_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Next reduction',
                      style: AppTextStyles.caption(color: AppColors.primary)
                          .copyWith(letterSpacing: 0.5)),
                  Text(
                    '${plan.nextDose}mg on ${DateFormat('d MMM yyyy').format(plan.nextStepDate!)}',
                    style: AppTextStyles.label(color: AppColors.textDark),
                  ),
                ]),
              ]),
            ),
          ],

          if (isHold) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.pause_circle_outline_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Taper paused at ${plan.currentDose}mg. '
                    'Your dose will not change until you resume.',
                    style: AppTextStyles.body(color: AppColors.textMid),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),

      const SizedBox(height: 12),

      // Actions row
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _toggleHold,
            icon: Icon(
              isHold ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 18,
              color: isHold ? AppColors.success : AppColors.warning,
            ),
            label: Text(
              isHold ? 'Resume Taper' : 'Put on Hold',
              style: AppTextStyles.label(
                  color: isHold ? AppColors.success : AppColors.warning),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: isHold ? AppColors.success : AppColors.warning),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showFullSchedule(plan),
            icon: const Icon(Icons.list_alt_rounded,
                size: 18, color: AppColors.primary),
            label: Text('Full Schedule',
                style: AppTextStyles.label(color: AppColors.primary)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),

      const SizedBox(height: 16),
      _buildUpcomingSteps(plan),
    ]);
  }

  Widget _buildUpcomingSteps(TaperPlan plan) {
    final steps = plan.steps;
    final startIdx = plan.currentStepIndex;
    final preview = <MapEntry<int, double>>[];
    for (int i = startIdx; i < steps.length && preview.length < 4; i++) {
      preview.add(MapEntry(i, steps[i]));
    }

    return Container(
      decoration: AppDecorations.card(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Upcoming steps', style: AppTextStyles.h4()),
        const SizedBox(height: 12),
        ...preview.map((e) {
          final isCurrent = e.key == startIdx;
          final date = plan.stepDate(e.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.primary : AppColors.border,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('${e.value}mg',
                  style: AppTextStyles.label(
                      color: isCurrent ? AppColors.primary : AppColors.textDark))),
              Text(
                isCurrent ? 'Now' : DateFormat('d MMM yyyy').format(date),
                style: AppTextStyles.bodySmall(),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ─── Dose history chart ──────────────────────────────────────────────────

  Widget _buildProgressChart() {
    final plan = _plan;
    if (plan == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Container(
          decoration: AppDecorations.card(),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dose History', style: AppTextStyles.h4()),
            const SizedBox(height: 16),
            Center(child: Text('Create a taper plan to see your schedule',
                style: AppTextStyles.body())),
          ]),
        ),
      );
    }

    final steps = plan.steps;
    final origin = plan.startDate;
    final today = DateTime.now();

    // Build spots: x = days since plan start, y = dose
    // Split into past (solid) and future (dashed) at today
    final List<FlSpot> pastSpots = [];
    final List<FlSpot> futureSpots = [];

    for (int i = 0; i < steps.length; i++) {
      final date = plan.stepDate(i);
      final x = date.difference(origin).inDays.toDouble();
      final y = steps[i];
      if (!date.isAfter(today)) {
        pastSpots.add(FlSpot(x, y));
      } else {
        futureSpots.add(FlSpot(x, y));
      }
    }

    // Bridge: connect past line to future line at today's current dose
    if (pastSpots.isNotEmpty && futureSpots.isNotEmpty) {
      futureSpots.insert(0, pastSpots.last);
    } else if (pastSpots.isEmpty) {
      // Plan hasn't started yet — treat everything as future
      futureSpots.addAll(steps.asMap().entries.map((e) {
        final x = plan.stepDate(e.key).difference(origin).inDays.toDouble();
        return FlSpot(x, e.value);
      }));
    }

    final maxY = (plan.startDose * 1.1).ceilToDouble();
    final endDate = plan.stepDate(steps.length - 1);
    final totalDays = endDate.difference(origin).inDays.toDouble();

    // Collect month-boundary x values for x-axis labels
    final labelPoints = <double, String>{};
    DateTime cursor = DateTime(origin.year, origin.month, 1).add(const Duration(days: 32));
    cursor = DateTime(cursor.year, cursor.month, 1);
    while (!cursor.isAfter(endDate)) {
      final x = cursor.difference(origin).inDays.toDouble();
      labelPoints[x] = DateFormat('MMM yy').format(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    // Always show start label
    labelPoints[0.0] = DateFormat('MMM yy').format(origin);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: AppDecorations.card(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Dose History', style: AppTextStyles.h4()),
            Text('${plan.currentDose}mg', style: AppTextStyles.h3(color: AppColors.primary)),
          ]),
          const SizedBox(height: 8),
          // Legend
          Row(children: [
            _legendDot(AppColors.primary, solid: true),
            const SizedBox(width: 6),
            Text('Past', style: AppTextStyles.bodySmall()),
            const SizedBox(width: 16),
            _legendDot(AppColors.primary.withValues(alpha: 0.5), solid: false),
            const SizedBox(width: 6),
            Text('Scheduled', style: AppTextStyles.bodySmall()),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: totalDays,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxY / 4,
                      getTitlesWidget: (v, _) => Text(
                        v == 0 ? '0' : '${v.round()}mg',
                        style: AppTextStyles.bodySmall(),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        // Find the nearest label within 3 days
                        String? label;
                        for (final entry in labelPoints.entries) {
                          if ((entry.key - value).abs() < 3) {
                            label = entry.value;
                            break;
                          }
                        }
                        if (label == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(label, style: AppTextStyles.bodySmall()),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Past — solid line
                  if (pastSpots.length > 1)
                    LineChartBarData(
                      spots: pastSpots,
                      isCurved: false,
                      color: AppColors.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.primary,
                          strokeWidth: 0,
                          strokeColor: Colors.transparent,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  // Future — dashed line
                  if (futureSpots.length > 1)
                    LineChartBarData(
                      spots: futureSpots,
                      isCurved: false,
                      color: AppColors.primary.withValues(alpha: 0.5),
                      barWidth: 2,
                      dashArray: [6, 4],
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.primary.withValues(alpha: 0.5),
                          strokeWidth: 0,
                          strokeColor: Colors.transparent,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.04),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _legendDot(Color color, {required bool solid}) => Row(children: [
    SizedBox(
      width: 24, height: 12,
      child: CustomPaint(painter: _LegendLinePainter(color: color, solid: solid)),
    ),
  ]);
}   // end _ToolsScreenState

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool solid;
  const _LegendLinePainter({required this.color, required this.solid});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    if (!solid) {
      // Draw dashed
      const dashW = 4.0, gapW = 3.0;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, size.height / 2),
            Offset((x + dashW).clamp(0, size.width), size.height / 2), paint);
        x += dashW + gapW;
      }
    } else {
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_LegendLinePainter old) => old.color != color || old.solid != solid;
}

// ─── Full Schedule Sheet ──────────────────────────────────────────────────────

class _FullScheduleSheet extends StatefulWidget {
  final TaperPlan plan;
  final VoidCallback onSaved;
  const _FullScheduleSheet({required this.plan, required this.onSaved});

  @override
  State<_FullScheduleSheet> createState() => _FullScheduleSheetState();
}

class _FullScheduleSheetState extends State<_FullScheduleSheet> {
  late List<double> _steps;
  double _reductionPct = 10.0; // default 10% per step
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _steps = List<double>.from(widget.plan.steps);
  }

  static double _r(double v) => (v * 10).round() / 10.0;

  /// Adjusts the global taper speed: regenerates all steps after the current one
  /// using the new reduction percentage, leaving past steps untouched.
  void _adjustSpeed(double delta) {
    final newPct = (_reductionPct + delta).clamp(2.5, 25.0);
    if (newPct == _reductionPct) return;

    final target = widget.plan.targetDose;
    final currentIdx = widget.plan.currentStepIndex;
    final currentDose = _steps.isNotEmpty ? _steps[currentIdx.clamp(0, _steps.length - 1)] : widget.plan.currentDose;

    // Keep steps up to and including current; regenerate everything after
    final head = _steps.sublist(0, currentIdx.clamp(0, _steps.length) + 1).toList();
    double prev = currentDose;
    while (prev > target) {
      double next = _r(prev - prev * (newPct / 100));
      if (next >= prev) next = _r(prev - 0.1);
      if (next <= target) {
        head.add(target);
        break;
      }
      head.add(next);
      prev = next;
    }

    setState(() {
      _reductionPct = newPct;
      _steps = head;
    });
  }

  void _adjust(int index, double delta) {
    final target = widget.plan.targetDose;
    final current = _steps[index];
    final newVal = _r(current + delta);

    // Don't allow going below target
    if (newVal < target) return;

    setState(() {
      // If this step hits or passes the target, truncate everything after it
      if (newVal <= target) {
        _steps = [..._steps.sublist(0, index), target];
        return;
      }

      // Update this step
      _steps[index] = newVal;

      // Regenerate all downstream steps from newVal using 10% reductions
      final head = _steps.sublist(0, index + 1).toList();
      double prev = newVal;
      while (prev > target) {
        double next = _r(prev - prev * 0.1);
        if (next >= prev) next = _r(prev - 0.1); // min 0.1mg step
        if (next <= target) {
          head.add(target);
          break;
        }
        head.add(next);
        prev = next;
      }
      _steps = head;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await FirestoreService.updateTaperPlanSteps(widget.plan.id, _steps);
    setState(() => _saving = false);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scrollCtrl) => Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Full Schedule', style: AppTextStyles.h3()),
                Text('${_steps.length - 1} reductions  •  ${plan.medicationName}',
                    style: AppTextStyles.body(color: AppColors.textMid)),
              ])),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Save', style: AppTextStyles.label(color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 12),
            // Global speed control
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TAPER SPEED', style: AppTextStyles.caption(color: AppColors.primary).copyWith(letterSpacing: 0.8)),
                    Text('${_reductionPct.toStringAsFixed(1).replaceAll('.0', '')}% reduction per step',
                        style: AppTextStyles.label(color: AppColors.textDark)),
                  ]),
                ),
                _stepBtn(Icons.remove, _reductionPct <= 2.5 ? null : () => _adjustSpeed(-2.5)),
                const SizedBox(width: 4),
                _stepBtn(Icons.add, _reductionPct >= 25.0 ? null : () => _adjustSpeed(2.5)),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Adjust speed to change the whole schedule, or tap ± on individual doses.',
                style: AppTextStyles.bodySmall()),
          ]),
        ),

        const Divider(height: 1, color: AppColors.border),

        // Step list
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            itemCount: _steps.length,
            itemBuilder: (ctx, i) {
              final date = plan.startDate.add(Duration(days: i * plan.intervalDays));
              final isCurrent = i == plan.currentStepIndex;
              final isPast = i < plan.currentStepIndex;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.primarySoft : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent ? AppColors.primary : const Color(0xFFE8DDD0),
                  ),
                ),
                child: Row(children: [
                  // Step badge
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.primary
                          : isPast ? AppColors.border
                          : AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text('${i + 1}',
                        style: AppTextStyles.caption(
                            color: isCurrent ? Colors.white
                                : isPast ? AppColors.textLight
                                : AppColors.primary).copyWith(fontSize: 10))),
                  ),
                  const SizedBox(width: 10),

                  // Date
                  SizedBox(
                    width: 80,
                    child: Text(
                      i == 0 ? 'Start' : DateFormat('d MMM yy').format(date),
                      style: AppTextStyles.bodySmall(
                          color: isPast ? AppColors.textLight : AppColors.textMid),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Dose with +/-
                  if (isPast)
                    Expanded(child: Text('${_steps[i]}mg',
                        style: AppTextStyles.label(color: AppColors.textLight)))
                  else ...[
                    _stepBtn(Icons.remove, isPast ? null : () => _adjust(i, -0.1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('${_steps[i]}mg',
                          style: AppTextStyles.label(
                              color: isCurrent ? AppColors.primary : AppColors.textDark)),
                    ),
                    _stepBtn(Icons.add, isPast ? null : () => _adjust(i, 0.1)),
                  ],

                  const Spacer(),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Now', style: AppTextStyles.caption(color: Colors.white)),
                    ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.all(6), // larger tap area
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.border.withValues(alpha: 0.3) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap == null ? AppColors.border : AppColors.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Icon(icon, size: 16,
            color: onTap == null ? AppColors.textLight : AppColors.primary),
      ),
    ),
  );
}
