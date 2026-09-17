import 'queue_status.dart';

typedef QueueModel = Queue;

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
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      counterId: json['counter_id'] is int
          ? json['counter_id']
          : int.tryParse(json['counter_id']?.toString() ?? '0') ?? 0,
      queueNumber: json['queue_number']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Pelanggan',
      status: (json['status']?.toString() ?? 'waiting').toQueueStatus(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      calledAt: json['called_at'] != null
          ? DateTime.tryParse(json['called_at'].toString())?.toLocal()
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())?.toLocal()
          : null,
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
