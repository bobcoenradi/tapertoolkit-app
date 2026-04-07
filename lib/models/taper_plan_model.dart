class TaperPlan {
  final String id;
  final String uid;
  final String medicationName;
  final double startDose;
  final double targetDose;
  final int pillsPerScript;
  final DateTime startDate;
  final DateTime aimEndDate;
  final int intervalDays;
  final String status; // 'active' | 'hold' | 'complete'
  final int holdAtStepIndex;
  final bool crossTaper;
  final String? crossTaperMed;
  final double? crossTaperTargetDose;
  /// When set, overrides the computed step list entirely.
  final List<double>? customSteps;

  const TaperPlan({
    required this.id,
    required this.uid,
    required this.medicationName,
    required this.startDose,
    this.targetDose = 0.0,
    required this.pillsPerScript,
    required this.startDate,
    required this.aimEndDate,
    required this.intervalDays,
    this.status = 'active',
    this.holdAtStepIndex = 0,
    this.crossTaper = false,
    this.crossTaperMed,
    this.crossTaperTargetDose,
    this.customSteps,
  });

  // ─── Step generation ────────────────────────────────────────────────────────

  /// All dose values from startDose down to targetDose, each rounded to 0.1 mg.
  List<double> get steps => customSteps ?? generateSteps(startDose, targetDose);

  static List<double> generateSteps(double start, [double target = 0.0]) {
    final list = <double>[_r(start)];
    double current = _r(start);
    while (current > target) {
      double next = _r(current - current * 0.1);
      // If 10% rounds to nothing, use minimum 0.1 mg step
      if (next >= current) next = _r(current - 0.1);
      if (next <= target) {
        list.add(target);
        break;
      }
      list.add(next);
      current = next;
    }
    return list;
  }

  static double _r(double v) => (v * 10).round() / 10.0;

  // ─── Computed state ─────────────────────────────────────────────────────────

  int get currentStepIndex {
    if (status == 'hold' || status == 'complete') return holdAtStepIndex;
    final days = DateTime.now().difference(startDate).inDays;
    final computed = (days / intervalDays).floor();
    return computed.clamp(0, steps.length - 1);
  }

  double get currentDose => steps[currentStepIndex];

  DateTime stepDate(int index) =>
      startDate.add(Duration(days: index * intervalDays));

  DateTime? get nextStepDate {
    if (status != 'active') return null;
    final next = currentStepIndex + 1;
    if (next >= steps.length) return null;
    return stepDate(next);
  }

  double? get nextDose {
    final next = currentStepIndex + 1;
    if (next >= steps.length) return null;
    return steps[next];
  }

  double get progressFraction =>
      steps.length <= 1 ? 1.0 : currentStepIndex / (steps.length - 1);

  /// Days until current script runs out (based on pillsPerScript & intervalDays).
  int get daysUntilReorder {
    final stepStart = stepDate(currentStepIndex);
    final daysOnStep = DateTime.now().difference(stepStart).inDays;
    return pillsPerScript - daysOnStep;
  }

  // ─── Serialisation ──────────────────────────────────────────────────────────

  factory TaperPlan.fromMap(Map<String, dynamic> m, String id) => TaperPlan(
        id: id,
        uid: m['uid'] ?? '',
        medicationName: m['medicationName'] ?? '',
        startDose: (m['startDose'] as num?)?.toDouble() ?? 0,
        targetDose: (m['targetDose'] as num?)?.toDouble() ?? 0,
        pillsPerScript: (m['pillsPerScript'] as num?)?.toInt() ?? 28,
        startDate: DateTime.tryParse(m['startDate'] ?? '') ?? DateTime.now(),
        aimEndDate: DateTime.tryParse(m['aimEndDate'] ?? '') ?? DateTime.now().add(const Duration(days: 365)),
        intervalDays: (m['intervalDays'] as num?)?.toInt() ?? 14,
        status: m['status'] ?? 'active',
        holdAtStepIndex: (m['holdAtStepIndex'] as num?)?.toInt() ?? 0,
        crossTaper: m['crossTaper'] == true,
        crossTaperMed: m['crossTaperMed'],
        crossTaperTargetDose: (m['crossTaperTargetDose'] as num?)?.toDouble(),
        customSteps: (m['customSteps'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'medicationName': medicationName,
        'startDose': startDose,
        'targetDose': targetDose,
        'pillsPerScript': pillsPerScript,
        'startDate': startDate.toIso8601String(),
        'aimEndDate': aimEndDate.toIso8601String(),
        'intervalDays': intervalDays,
        'status': status,
        'holdAtStepIndex': holdAtStepIndex,
        'crossTaper': crossTaper,
        if (crossTaperMed != null) 'crossTaperMed': crossTaperMed,
        if (crossTaperTargetDose != null) 'crossTaperTargetDose': crossTaperTargetDose,
        if (customSteps != null) 'customSteps': customSteps,
      };

  TaperPlan copyWith({String? status, int? holdAtStepIndex, List<double>? customSteps, bool clearCustomSteps = false}) => TaperPlan(
        id: id,
        uid: uid,
        medicationName: medicationName,
        startDose: startDose,
        targetDose: targetDose,
        pillsPerScript: pillsPerScript,
        startDate: startDate,
        aimEndDate: aimEndDate,
        intervalDays: intervalDays,
        status: status ?? this.status,
        holdAtStepIndex: holdAtStepIndex ?? this.holdAtStepIndex,
        crossTaper: crossTaper,
        crossTaperMed: crossTaperMed,
        crossTaperTargetDose: crossTaperTargetDose,
        customSteps: clearCustomSteps ? null : (customSteps ?? this.customSteps),
      );
}
