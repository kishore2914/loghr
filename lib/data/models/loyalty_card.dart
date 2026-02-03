class LoyaltyCard {
  final String id;
  final String cardNumber;
  final int points;
  final String employeeName;
  final String designation;
  final String role; // Added role field
  final String companyName;
  final String? logoUrl;
  final String employeeId;

  LoyaltyCard({
    required this.id,
    required this.cardNumber,
    required this.points,
    required this.employeeName,
    required this.designation,
    required this.role,
    required this.companyName,
    required this.employeeId,
    this.logoUrl,
  });

  factory LoyaltyCard.fromJson(Map<String, dynamic> cardData, Map<String, dynamic> employeeData, Map<String, dynamic>? orgData) {
    return LoyaltyCard(
      id: cardData['id'] as String? ?? '',
      cardNumber: cardData['card_number'] as String? ?? '0000000000000000',
      points: cardData['points_earned'] as int? ?? 0,
      employeeName: employeeData['full_name'] as String? ?? 'Employee',
      designation: employeeData['designation'] as String? ?? 'Team Member',
      role: employeeData['role'] as String? ?? employeeData['designation'] as String? ?? 'Employee', // Fallback to designation
      companyName: orgData?['name'] as String? ?? 'LogHR',
      logoUrl: orgData?['logo_url'] as String?,
      employeeId: employeeData['id'] as String? ?? '',
    );
  }

  String get formattedCardNumber {
    if (cardNumber.length != 16) return cardNumber;
    return '${cardNumber.substring(0, 4)} ${cardNumber.substring(4, 8)} ${cardNumber.substring(8, 12)} ${cardNumber.substring(12, 16)}';
  }
}

class LoyaltyTransaction {
  final String id;
  final int points;
  final String type;
  final String? description;
  final DateTime createdAt;

  LoyaltyTransaction({
    required this.id,
    required this.points,
    required this.type,
    this.description,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: json['id'] as String,
      points: json['points'] as int,
      type: json['transaction_type'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
