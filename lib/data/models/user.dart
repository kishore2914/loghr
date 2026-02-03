enum UserRole {
  employee,
  admin,
}

class User {
  final String id;
  final String fullName;
  final String? email; // Added back, populated from Auth
  final String? employeeId;
  final UserRole role;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final String? avatarUrl;

  User({
    required this.id,
    required this.fullName,
    this.email,
    this.employeeId,
    required this.role,
    required this.isActive,
    this.lastLogin,
    required this.createdAt,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle role parsing - check for admin roles (admin, super_admin, hr_manager, manager)
    // Based on schema: 'super_admin', 'admin', 'hr_manager', 'manager', 'employee'
    final roleString = (json['role'] as String?)?.toLowerCase().trim() ?? 'employee';
    final isAdmin = roleString == 'admin' || 
                    roleString == 'super_admin' || 
                    roleString == 'hr_manager' || 
                    roleString == 'manager';
    
    return User(
      // Use user_id (foreign key to auth.users) as the main identifier
      // This matches the RLS policies which check user_id = auth.uid()
      id: json['user_id'] as String? ?? json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?, // Can be in DB now
      employeeId: json['employee_id'] as String?,
      role: isAdmin ? UserRole.admin : UserRole.employee,
      isActive: json['is_active'] as bool? ?? true,
      lastLogin: json['last_login_at'] != null 
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      avatarUrl: json['avatar_url'] as String?,
    );
  }
  
  User copyWith({
    String? email,
    String? avatarUrl,
  }) {
    return User(
      id: id,
      fullName: fullName,
      email: email ?? this.email,
      employeeId: employeeId,
      role: role,
      isActive: isActive,
      lastLogin: lastLogin,
      createdAt: createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'employee_id': employeeId,
      'role': role == UserRole.admin ? 'admin' : 'employee',
      'is_active': isActive,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'avatar_url': avatarUrl,
    };
  }
  
  // Convenience getters 
  String get name => fullName;
  String? get phone => null; 
  String? get department => null; 
  String? get position => null;
}
