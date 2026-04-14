class Medicine {
  final String id;
  final String name;
  final String dosage;
  final String time;
  String status;
  final DateTime createdAt;

  Medicine({
    this.id = '',
    required this.name,
    required this.dosage,
    required this.time,
    this.status = "pending",
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "dosage": dosage,
      "time": time,
      "status": status,
      "createdAt": createdAt.toIso8601String(),
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map["id"] ?? "",
      name: map["name"] ?? "",
      dosage: map["dosage"] ?? "",
      time: map["time"] ?? "",
      status: map["status"] ?? "pending",
      createdAt: DateTime.tryParse(map["createdAt"] ?? "") ?? DateTime.now(),
    );
  }
}
