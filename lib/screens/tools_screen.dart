import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/taper_plan_model.dart';
import '../models/taper_schedule_model.dart';
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

  // Classic calculator
  final _startDoseCtrl = TextEditingController();
  final _targetDoseCtrl = TextEditingController(text: '0');
  double _primaryPercent = 10;
  bool _useHyperbolic = false;
  double _switchAtDose = 5;
  double _secondaryPercent = 5;
  int _intervalDays = 14;
  List<TaperStep> _schedule = [];
  bool _scheduleVisible = false;

  List<Map<String, dynamic>> _doseLog = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _startDoseCtrl.dispose();
    _targetDoseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final plan = await FirestoreService.fetchActiveTaperPlan();
    final log  = await FirestoreService.fetchDoseLog();
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _doseLog = log;
      _loadingPlan = false;
    });
  }

  Future<void> _openWizard() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TaperWizardScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _toggleHold() async {
    if (_plan == null) return;
    final isHold = _plan!.status == 'hold';
    final newStatus = isHold ? 'active' : 'hold';
    final stepIdx = isHold ? _plan!.holdAtStepIndex : _plan!.currentStepIndex;
    await FirestoreService.updateTaperPlanStatus(_plan!.id, newStatus, stepIdx);
    _load();
  }

  void _computeSchedule() {
    final startDose = double.tryParse(_startDoseCtrl.text);
    final targetDose = double.tryParse(_targetDoseCtrl.text) ?? 0;
    if (startDose == null || startDose <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid starting dose'),
            backgroundColor: AppColors.danger),
      );
      return;
    }
    final params = TaperScheduleParams(
      startDose: startDose,
      targetDose: targetDose,
      primaryPercent: _primaryPercent,
      switchAtDose: _useHyperbolic ? _switchAtDose : null,
      secondaryPercent: _useHyperbolic ? _secondaryPercent : null,
      intervalDays: _intervalDays,
    );
    setState(() {
      _schedule = params.compute();
      _scheduleVisible = true;
    });
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
              SliverToBoxAdapter(child: _plan != null
                  ? _buildActivePlan(_plan!)
                  : _buildEmptyPlan()),
              SliverToBoxAdapter(child: _buildProgressChart()),
              SliverToBoxAdapter(child: _buildCalculatorSection()),
              if (_scheduleVisible) SliverToBoxAdapter(child: _buildScheduleTable()),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Text('Tools', style: AppTextStyles.h2()),
  );

  // ─── Empty state ────────────────────────────────────────────────────────

  Widget _buildEmptyPlan() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: AppDecorations.gradientCard(),
        padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 20),
          Text(
            'Create a personalised taper schedule based on the Maudsley Deprescribing Guidelines. Track your progress, set dose reminders, and stay on track.',
            style: AppTextStyles.body(color: AppColors.textMid),
          ),
          const SizedBox(height: 20),
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
      ),
    );
  }

  // ─── Active plan overview ─────────────────────────────────────────────

  Widget _buildActivePlan(TaperPlan plan) {
    final steps = plan.steps;
    final totalSteps = steps.length - 1;
    final doneSteps = plan.currentStepIndex;
    final progress = plan.progressFraction;
    final isHold = plan.status == 'hold';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(children: [

        // Main overview card
        Container(
          decoration: AppDecorations.gradientCard(),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plan.medicationName, style: AppTextStyles.h3()),
                const SizedBox(height: 2),
                Text('${plan.startDose}mg → ${plan.targetDose}mg',
                    style: AppTextStyles.body()),
              ])),
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

            // Current dose display
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CURRENT DOSE',
                    style: AppTextStyles.caption(color: AppColors.primary).copyWith(letterSpacing: 0.8)),
                Text('${plan.currentDose}mg',
                    style: AppTextStyles.h1(color: AppColors.textDark)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('STEP',
                    style: AppTextStyles.caption(color: AppColors.textLight).copyWith(letterSpacing: 0.8)),
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
                  const Icon(Icons.arrow_downward_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Next reduction', style: AppTextStyles.caption(color: AppColors.primary)
                        .copyWith(letterSpacing: 0.5)),
                    Text('${plan.nextDose}mg on ${DateFormat('d MMM yyyy').format(plan.nextStepDate!)}',
                        style: AppTextStyles.label(color: AppColors.textDark)),
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
                  const Icon(Icons.pause_circle_outline_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Taper paused at ${plan.currentDose}mg. Your dose will not change until you resume.',
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
                style: AppTextStyles.label(color: isHold ? AppColors.success : AppColors.warning),
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
              onPressed: _openWizard,
              icon: const Icon(Icons.list_alt_rounded, size: 18, color: AppColors.primary),
              label: Text('Full Schedule', style: AppTextStyles.label(color: AppColors.primary)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),

        // Upcoming steps preview
        const SizedBox(height: 20),
        _buildUpcomingSteps(plan),
      ]),
    );
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

  // ─── Progress chart ──────────────────────────────────────────────────────

  Widget _buildProgressChart() {
    final hasData = _doseLog.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: AppDecorations.card(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Dose History', style: AppTextStyles.h4()),
            if (hasData)
              Text('${(_doseLog.last['dose'] as num).toStringAsFixed(1)}mg',
                  style: AppTextStyles.h3(color: AppColors.primary)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: hasData
                ? LineChart(_buildChartData())
                : Center(child: Text('Log your first dose to see progress',
                    style: AppTextStyles.body())),
          ),
        ]),
      ),
    );
  }

  LineChartData _buildChartData() {
    final spots = _doseLog.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), (e.value['dose'] as num).toDouble())).toList();
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [LineChartBarData(
        spots: spots, isCurved: true, color: AppColors.primary, barWidth: 2,
        dotData: FlDotData(show: true,
            getDotPainter: (_, __, ___, ____) =>
                FlDotCirclePainter(radius: 3, color: AppColors.primary,
                    strokeWidth: 0, strokeColor: Colors.transparent)),
        belowBarData: BarAreaData(show: true,
            color: AppColors.primary.withValues(alpha: 0.08)),
      )],
    );
  }

  // ─── Calculator ──────────────────────────────────────────────────────────

  Widget _buildCalculatorSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: AppDecorations.card(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Taper Calculator', style: AppTextStyles.h4()),
          const SizedBox(height: 4),
          Text('Explore a custom reduction schedule', style: AppTextStyles.body()),
          const SizedBox(height: 20),

          Text('Starting dose (mg)', style: AppTextStyles.label()),
          const SizedBox(height: 6),
          _inputField(_startDoseCtrl, 'e.g. 20'),
          const SizedBox(height: 14),

          Text('Target dose (mg)', style: AppTextStyles.label()),
          const SizedBox(height: 6),
          _inputField(_targetDoseCtrl, '0'),
          const SizedBox(height: 14),

          Text('Reduction: ${_primaryPercent.round()}% per step', style: AppTextStyles.label()),
          Slider(value: _primaryPercent, min: 2, max: 25, divisions: 23,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _primaryPercent = v)),

          Text('Interval: $_intervalDays days between steps', style: AppTextStyles.label()),
          Slider(value: _intervalDays.toDouble(), min: 7, max: 28, divisions: 21,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _intervalDays = v.round())),

          Row(children: [
            Switch(value: _useHyperbolic, onChanged: (v) => setState(() => _useHyperbolic = v),
                activeColor: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Hyperbolic taper (switch to finer % below threshold)',
                style: AppTextStyles.body())),
          ]),
          if (_useHyperbolic) ...[
            const SizedBox(height: 8),
            Text('Switch below: ${_switchAtDose.toStringAsFixed(1)}mg', style: AppTextStyles.label()),
            Slider(value: _switchAtDose, min: 1, max: 20, divisions: 38,
                activeColor: AppColors.primaryLight,
                onChanged: (v) => setState(() => _switchAtDose = v)),
            Text('Fine reduction: ${_secondaryPercent.round()}%', style: AppTextStyles.label()),
            Slider(value: _secondaryPercent, min: 1, max: 10, divisions: 9,
                activeColor: AppColors.primaryLight,
                onChanged: (v) => setState(() => _secondaryPercent = v)),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _computeSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Calculate Schedule', style: AppTextStyles.label(color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint) => Container(
    decoration: AppDecorations.inputField(),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body(color: AppColors.textLight),
        border: InputBorder.none,
        fillColor: Colors.transparent,
        filled: true,
      ),
      style: AppTextStyles.body(color: AppColors.textDark),
    ),
  );

  Widget _buildScheduleTable() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: AppDecorations.card(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your Taper Schedule', style: AppTextStyles.h4()),
          const SizedBox(height: 4),
          Text('${_schedule.length} steps total', style: AppTextStyles.body()),
          const SizedBox(height: 12),
          Row(children: [
            _th('Step', flex: 1), _th('Dose', flex: 2),
            _th('Reduction', flex: 3), _th('Day', flex: 2),
          ]),
          const Divider(color: AppColors.border),
          ..._schedule.take(20).map((step) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              _td('${step.stepNumber}', flex: 1),
              _td('${step.dose}mg', flex: 2),
              _td('-${step.reductionMg}mg (${step.reductionPercent.round()}%)', flex: 3),
              _td('Day ${(step.stepNumber - 1) * _intervalDays + 1}', flex: 2),
            ]),
          )),
          if (_schedule.length > 20)
            Padding(padding: const EdgeInsets.only(top: 6),
                child: Text('+ ${_schedule.length - 20} more steps…',
                    style: AppTextStyles.body())),
        ]),
      ),
    );
  }

  Widget _th(String t, {required int flex}) =>
      Expanded(flex: flex, child: Text(t, style: AppTextStyles.caption(color: AppColors.textLight)
          .copyWith(letterSpacing: 0.4)));

  Widget _td(String t, {required int flex}) =>
      Expanded(flex: flex, child: Text(t, style: AppTextStyles.body(color: AppColors.textDark)));
}
