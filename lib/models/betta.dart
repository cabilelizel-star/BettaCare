class Betta {
  final String id;
  final String name;
  final String variety;
  final String color;
  final String age;
  final String dateAdded;
  final String healthStatus;
  final String imageUrl;
  final String tankTemperature;
  final String phLevel;
  final String waterQuality;
  final String lastFed;
  final String lastWaterChange;
  final String nextScheduledCare;
  final String notes;

  const Betta({
    required this.id,
    required this.name,
    required this.variety,
    required this.color,
    required this.age,
    required this.dateAdded,
    required this.healthStatus,
    required this.imageUrl,
    required this.tankTemperature,
    required this.phLevel,
    required this.waterQuality,
    required this.lastFed,
    required this.lastWaterChange,
    required this.nextScheduledCare,
    required this.notes,
  });

  Betta copyWith({
    String? id,
    String? name,
    String? variety,
    String? color,
    String? age,
    String? dateAdded,
    String? healthStatus,
    String? imageUrl,
    String? tankTemperature,
    String? phLevel,
    String? waterQuality,
    String? lastFed,
    String? lastWaterChange,
    String? nextScheduledCare,
    String? notes,
  }) {
    return Betta(
      id: id ?? this.id,
      name: name ?? this.name,
      variety: variety ?? this.variety,
      color: color ?? this.color,
      age: age ?? this.age,
      dateAdded: dateAdded ?? this.dateAdded,
      healthStatus: healthStatus ?? this.healthStatus,
      imageUrl: imageUrl ?? this.imageUrl,
      tankTemperature: tankTemperature ?? this.tankTemperature,
      phLevel: phLevel ?? this.phLevel,
      waterQuality: waterQuality ?? this.waterQuality,
      lastFed: lastFed ?? this.lastFed,
      lastWaterChange: lastWaterChange ?? this.lastWaterChange,
      nextScheduledCare: nextScheduledCare ?? this.nextScheduledCare,
      notes: notes ?? this.notes,
    );
  }

  static const sampleBetta = Betta(
    id: 'b1',
    name: 'Finley',
    variety: 'Halfmoon Betta',
    color: 'Royal Sapphire & Magenta',
    age: '10 Months',
    dateAdded: 'Jan 15, 2024',
    healthStatus: 'Healthy',
    imageUrl: 'assets/images/betta-logo.jpg',
    tankTemperature: '26.5°C',
    phLevel: '7.2',
    waterQuality: 'Optimal',
    lastFed: 'Today, 8:00 AM',
    lastWaterChange: '3 days ago',
    nextScheduledCare: 'Feeding at 6:00 PM',
    notes: 'Vibrant blue fins with active swimming behavior. Loves micro pellets.',
  );
}
