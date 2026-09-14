class Counter {
  final int id;
  final String name;
  bool isActive;

  Counter({required this.id, required this.name, this.isActive = true});

  factory Counter.fromJson(Map<String, dynamic> json) {
    return Counter(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
    };
  }
}