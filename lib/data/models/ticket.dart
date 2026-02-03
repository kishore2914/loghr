class Ticket {
  final String id;
  final String ticketId;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final DateTime created;
  final DateTime lastUpdate;

  Ticket({
    required this.id,
    required this.ticketId,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.created,
    required this.lastUpdate,
  });
}

