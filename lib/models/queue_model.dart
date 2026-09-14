import 'queue_status.dart';

class Queue {
  final int id;
  final int counterId;
  final String queueNumber;
  final String customerName;
  QueueStatus status;
  DateTime createdAt;
  DateTime? calledAt;
  DateTime? completedAt;

  Queue({
    required this.id,
    required this.counterId,
    required this.queueNumber,
    required this.customerName,
    required this.status,
    required this.createdAt,
    this.calledAt,
    this.completedAt,
  });

  factory Queue.fromJson(Map<String, dynamic> json) {
    return Queue(
      id: int.tryParse(json['id'].toString()) ?? 0,
      counterId: int.tryParse(json['counter_id'].toString()) ?? 0,
      queueNumber: json['queue_number'] ?? '',
      customerName: json['customer_name'] ?? 'Tamu',
      status: (json['status'] ?? 'waiting').toQueueStatus(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      calledAt: json['called_at'] != null ? DateTime.tryParse(json['called_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'counter_id': counterId,
      'queue_number': queueNumber,
      'customer_name': customerName,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'called_at': calledAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}