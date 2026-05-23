class LocalStep {
  final int? id;
  final String date; // 'YYYY-MM-DD'
  final int totalSteps;
  final String source;
  final bool synced;

  const LocalStep({
    this.id,
    required this.date,
    required this.totalSteps,
    required this.source,
    required this.synced,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'date': date,
    'total_steps': totalSteps,
    'source': source,
    'synced': synced ? 1 : 0,
  };

  factory LocalStep.fromMap(Map<String, dynamic> m) => LocalStep(
    id: m['id'] as int?,
    date: m['date'] as String,
    totalSteps: m['total_steps'] as int,
    source: m['source'] as String,
    synced: (m['synced'] as int) == 1,
  );
}
