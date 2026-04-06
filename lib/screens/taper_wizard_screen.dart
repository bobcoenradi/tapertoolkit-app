import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/taper_plan_model.dart';
import '../models/journal_entry_model.dart';
import '../services/firestore_service.dart';

class TaperWizardScreen extends StatefulWidget {
  const TaperWizardScreen({super.key});

  @override
  State<TaperWizardScreen> createState() => _TaperWizardScreenState();
}

class _TaperWizardScreenState extends State<TaperWizardScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _saving = false;

  // Step 1
  final _medCtrl = TextEditingController();

  // Step 2
  final _startDoseCtrl = TextEditingController();
  final _targetDoseCtrl = TextEditingController(text: '0');

  // Step 3
  bool _crossTaper = false;
  final _crossMedCtrl = TextEditingController();
  final _crossTargetCtrl = TextEditingController(text: '0');

  // Step 4 — interval = pillsPerScript; aimEndDate is computed
  int _pillsPerScript = 28;
  final List<int> _pillOptions = [14, 28, 30];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _medCtrl.dispose();
    _startDoseCtrl.dispose();
    _targetDoseCtrl.dispose();
    _crossMedCtrl.dispose();
    _crossTargetCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 4) {
      if (!_validateCurrent()) return;
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _step++);
    } else {
      _generatePlan();
    }
  }

  void _prev() {
    if (_step > 0) {
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _step--);
    }
  }

  bool _validateCurrent() {
    switch (_step) {
      case 0:
        if (_medCtrl.text.trim().isEmpty) {
          _snack('Please enter your medication name');
          return false;
        }
      case 1:
        final s = double.tryParse(_startDoseCtrl.text);
        if (s == null || s <= 0) {
          _snack('Please enter a valid starting dose');
          return false;
        }
      default:
        break;
    }
    return true;
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));

  // ─── Computed preview ────────────────────────────────────────────────────

  double get _startDose => double.tryParse(_startDoseCtrl.text) ?? 0;
  double get _targetDose => double.tryParse(_targetDoseCtrl.text) ?? 0;

  List<double> get _previewSteps =>
      TaperPlan.generateSteps(_startDose, _targetDose);

  // The interval IS the pills per script — one bottle = one interval
  int get _intervalDays => _pillsPerScript;

  // Aimed end date is fully computed: today + (numTransitions × interval)
  DateTime get _computedEndDate {
    final steps = _previewSteps;
    final totalDays = (steps.length - 1) * _pillsPerScript;
    return DateTime.now().add(Duration(days: totalDays));
  }

  Future<void> _generatePlan() async {
    setState(() => _saving = true);
    try {
      final steps = _previewSteps;
      final interval = _intervalDays;
      final now = DateTime.now();

      final plan = TaperPlan(
        id: '',
        uid: '',          // Firestore service fills actual uid on save
        medicationName: _medCtrl.text.trim(),
        startDose: _startDose,
        targetDose: _targetDose,
        pillsPerScript: _pillsPerScript,
        startDate: DateTime(now.year, now.month, now.day),
        aimEndDate: _computedEndDate,
        intervalDays: interval,   // = pillsPerScript
        crossTaper: _crossTaper,
        crossTaperMed: _crossTaper ? _crossMedCtrl.text.trim() : null,
        crossTaperTargetDose: _crossTaper
            ? double.tryParse(_crossTargetCtrl.text)
            : null,
      );

      await FirestoreService.saveTaperPlan(plan);

      // Auto-generate order reminders for the next 6 dose changes
      final medName = _medCtrl.text.trim();
      for (int i = 1; i < steps.length && i <= 6; i++) {
        final changeDate = now.add(Duration(days: i * interval));
        final orderDate = changeDate.subtract(const Duration(days: 7));
        await FirestoreService.saveMedReminder(MedReminder(
          id: '',
          uid: '',
          name: 'Order ${steps[i]}mg $medName',
          dosage: 'Dose changes ${DateFormat('d MMM').format(changeDate)} — order by ${DateFormat('d MMM').format(orderDate)}',
          ordered: false,
          refillNeededBy: orderDate,
          status: 'needed',
        ));
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Error saving plan. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Guided Taper Wizard', style: AppTextStyles.h4()),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
                _buildStep5(),
              ],
            ),
          ),
          _buildNavButtons(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const labels = ['Medication', 'Dosing', 'Cross Taper', 'Timeline', 'Review'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(5, (i) {
          final done = i < _step;
          final active = i == _step;
          return Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: done || active ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(labels[i],
                    style: AppTextStyles.caption(
                      color: active ? AppColors.primary : AppColors.textLight,
                    ).copyWith(fontWeight: active ? FontWeight.w600 : FontWeight.normal),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _prev,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Back', style: AppTextStyles.label(color: AppColors.textMid)),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saving ? null : _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _step == 4 ? 'Generate My Taper Plan' : 'Continue',
                        style: AppTextStyles.label(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step pages ──────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.gradientCard(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Maudsley Deprescribing Guidelines', style: AppTextStyles.label(color: AppColors.primary)),
            ]),
            const SizedBox(height: 8),
            Text(
              'This wizard uses the Maudsley Deprescribing Guidelines to generate a personalised taper schedule.\n\n'
              'This app is NOT a replacement for medical advice. Always discuss your taper plan with a healthcare professional before making any changes to your medication.',
              style: AppTextStyles.body(),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        Text("What's your medication?", style: AppTextStyles.h3()),
        const SizedBox(height: 6),
        Text('Enter the medication you are currently tapering.',
            style: AppTextStyles.body()),
        const SizedBox(height: 16),
        TextField(
          controller: _medCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Medication name (e.g. Sertraline)'),
        ),
      ]),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your dosing', style: AppTextStyles.h3()),
        const SizedBox(height: 6),
        Text('Enter your current dose and where you want to end up.',
            style: AppTextStyles.body()),
        const SizedBox(height: 24),
        Text('Starting dose (mg)', style: AppTextStyles.label()),
        const SizedBox(height: 8),
        TextField(
          controller: _startDoseCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'e.g. 50'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('Target dose (mg)', style: AppTextStyles.label()),
        const SizedBox(height: 4),
        Text('Usually 0 — complete discontinuation.',
            style: AppTextStyles.bodySmall()),
        const SizedBox(height: 8),
        TextField(
          controller: _targetDoseCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '0'),
          onChanged: (_) => setState(() {}),
        ),
        if (_startDose > 0) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppDecorations.card(),
            child: Row(children: [
              const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Text(
                '${_previewSteps.length - 1} reduction steps at ~10% each',
                style: AppTextStyles.label(color: AppColors.textDark),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Cross taper', style: AppTextStyles.h3()),
        const SizedBox(height: 6),
        Text(
          'A cross taper means switching from one medication to another while overlapping schedules to minimise withdrawal.',
          style: AppTextStyles.body(),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.card(),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('I am cross tapering', style: AppTextStyles.label(color: AppColors.textDark)),
              Text('Switching to another medication', style: AppTextStyles.bodySmall()),
            ])),
            Switch(
              value: _crossTaper,
              onChanged: (v) => setState(() => _crossTaper = v),
              activeColor: AppColors.primary,
            ),
          ]),
        ),
        if (_crossTaper) ...[
          const SizedBox(height: 20),
          Text('New medication name', style: AppTextStyles.label()),
          const SizedBox(height: 8),
          TextField(
            controller: _crossMedCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'e.g. Fluoxetine'),
          ),
          const SizedBox(height: 16),
          Text('Target dose of new medication (mg)', style: AppTextStyles.label()),
          const SizedBox(height: 8),
          TextField(
            controller: _crossTargetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'e.g. 20'),
          ),
        ] else ...[
          const SizedBox(height: 24),
          Text('Not cross tapering — I am discontinuing.',
              style: AppTextStyles.body(color: AppColors.textLight)),
        ],
      ]),
    );
  }

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Timeline & supply', style: AppTextStyles.h3()),
        const SizedBox(height: 6),
        Text('Help us calculate your step interval and script ordering reminders.',
            style: AppTextStyles.body()),
        const SizedBox(height: 24),

        // Pills per script
        Text('Tablets per prescription', style: AppTextStyles.label()),
        const SizedBox(height: 4),
        Text('How many tablets are in one prescription?', style: AppTextStyles.bodySmall()),
        const SizedBox(height: 10),
        Row(children: [
          ..._pillOptions.map((p) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _pillsPerScript = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _pillsPerScript == p ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _pillsPerScript == p ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text('$p',
                    style: AppTextStyles.label(
                      color: _pillsPerScript == p ? Colors.white : AppColors.textMid,
                    )),
              ),
            ),
          )),
          // Custom
          GestureDetector(
            onTap: _enterCustomPills,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: !_pillOptions.contains(_pillsPerScript) ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: !_pillOptions.contains(_pillsPerScript) ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                !_pillOptions.contains(_pillsPerScript) ? '$_pillsPerScript' : 'Other',
                style: AppTextStyles.label(
                  color: !_pillOptions.contains(_pillsPerScript) ? Colors.white : AppColors.textMid,
                ),
              ),
            ),
          ),
        ]),

        if (_startDose > 0) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppDecorations.gradientCard(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your plan at a glance', style: AppTextStyles.label(color: AppColors.textDark)),
              const SizedBox(height: 8),
              _previewRow('Steps', '${_previewSteps.length - 1} reductions'),
              _previewRow('Interval', '$_intervalDays days per step'),
              _previewRow('Est. end', DateFormat('MMM yyyy').format(_computedEndDate)),
              _previewRow('Script covers', '$_pillsPerScript days'),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _previewRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text('$label:  ', style: AppTextStyles.bodySmall(color: AppColors.textLight)),
      Text(value, style: AppTextStyles.label(color: AppColors.textDark)),
    ]),
  );

  Widget _buildStep5() {
    if (_startDose <= 0) {
      return Center(child: Text('Please go back and enter your starting dose.',
          style: AppTextStyles.body()));
    }
    final steps = _previewSteps;
    final interval = _intervalDays;
    final now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Review your plan', style: AppTextStyles.h3()),
        const SizedBox(height: 6),
        Text('Discuss this schedule with your doctor before starting.',
            style: AppTextStyles.body()),
        const SizedBox(height: 20),

        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.gradientCard(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_medCtrl.text.trim(), style: AppTextStyles.h4()),
            const SizedBox(height: 12),
            _summaryRow(Icons.medication_outlined, '${steps.first}mg → ${steps.last}mg'),
            _summaryRow(Icons.stacked_bar_chart, '${steps.length - 1} steps at ~10% reduction'),
            _summaryRow(Icons.timer_outlined, '$interval days per step'),
            _summaryRow(Icons.calendar_today_outlined,
                'Est. complete ${DateFormat('MMMM yyyy').format(_computedEndDate)}'),
            _summaryRow(Icons.local_pharmacy_outlined, '$_pillsPerScript tablets per script'),
            if (_crossTaper && _crossMedCtrl.text.isNotEmpty)
              _summaryRow(Icons.swap_horiz, 'Cross tapering to ${_crossMedCtrl.text.trim()}'),
          ]),
        ),
        const SizedBox(height: 20),

        // All steps
        Text('All steps (${steps.length - 1} reductions)', style: AppTextStyles.h4()),
        const SizedBox(height: 10),
        ...steps.asMap().entries.map((e) {
          final date = now.add(Duration(days: e.key * interval));
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: AppDecorations.card(),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: e.key == 0 ? AppColors.primary : AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${e.key + 1}',
                      style: AppTextStyles.caption(
                          color: e.key == 0 ? Colors.white : AppColors.primary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('${e.value}mg', style: AppTextStyles.label(color: AppColors.textDark))),
              Text(e.key == 0 ? 'Today' : DateFormat('d MMM yyyy').format(date),
                  style: AppTextStyles.bodySmall()),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _summaryRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: AppTextStyles.body(color: AppColors.textDark))),
    ]),
  );

  // ─── Pickers ─────────────────────────────────────────────────────────────

  Future<void> _enterCustomPills() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Custom amount', style: AppTextStyles.h4()),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Tablets per script'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: AppTextStyles.label(color: AppColors.textLight))),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null && v > 0) setState(() => _pillsPerScript = v);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0),
            child: Text('OK', style: AppTextStyles.label(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
