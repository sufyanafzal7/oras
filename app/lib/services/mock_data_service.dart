import '../models/procedure.dart';

/// Stand-in for the Flask backend until Phase 5.
/// Swap each method body for a real http call later —
/// keep the same method signatures so screens don't change.
class MockDataService {
  static Future<Map<String, dynamic>> fetchDashboardSummary() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'totalProcedures': 142,
      'totalHoursProcessed': 284,
      'phasePrecision': 12.4,
      'efficiencyDelta': 88.2,
      'bloodLossIndex': 'Low Risk',
      'instrumentUptime': 94.8,
    };
  }

  static Future<List<Procedure>> fetchRecentProcedures() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Procedure(
        id: 'A-2',
        title: 'Cholecystectomy Phase A-2',
        surgeonName: 'Dr. Aris Thorne',
        date: DateTime(2026, 6, 20),
        status: ProcedureStatus.completed,
      ),
      Procedure(
        id: 'D-9',
        title: 'Gastric Bypass Delta-9',
        surgeonName: 'Dr. Elena Vance',
        date: DateTime(2026, 6, 19),
        status: ProcedureStatus.analyzing,
      ),
      Procedure(
        id: 'S-4',
        title: 'Appendectomy Stream-4',
        surgeonName: 'Dr. Julian Kovic',
        date: DateTime(2026, 6, 17),
        status: ProcedureStatus.completed,
      ),
    ];
  }
}