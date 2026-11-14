import 'permissions.dart';

class Territory {
  const Territory(this.id, this.name);

  final int id;
  final String name;
}

/// The signed-in field user, from `/auth/me`.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.designation,
    required this.permissions,
    this.mobile,
    this.territories = const [],
  });

  final int id;
  final String name;
  final String email;
  final String? mobile;
  final String role;

  /// Display text only, e.g. "RCM". Never used for access decisions.
  final String designation;
  final Set<String> permissions;
  final List<Territory> territories;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  bool can(String permission) => permissions.contains(permission);

  factory AppUser.fromJson(Map<String, dynamic> j) {
    final role = '${j['role'] ?? ''}';
    final perms = j['permissions'];
    return AppUser(
      id: (j['id'] as num).toInt(),
      name: '${j['name'] ?? ''}',
      email: '${j['email'] ?? ''}',
      mobile: j['mobile'] as String?,
      role: role,
      designation: '${j['designation'] ?? j['role_label'] ?? role}',
      permissions: perms is List ? perms.map((p) => '$p').toSet() : (legacyRolePermissions[role] ?? const <String>{}),
      territories: [
        for (final t in (j['territories'] as List? ?? const []))
          if (t is Map) Territory((t['id'] as num).toInt(), '${t['name']}'),
      ],
    );
  }
}
