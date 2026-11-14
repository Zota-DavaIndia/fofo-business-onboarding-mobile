import 'package:flutter_test/flutter_test.dart';
import 'package:fofo_onboarding/core/auth/permissions.dart';
import 'package:fofo_onboarding/core/auth/user.dart';

void main() {
  test('permissions from the backend win over the role', () {
    final u = AppUser.fromJson({
      'id': 7,
      'name': 'Arjun Kumar',
      'email': 'arjun@example.com',
      'role': 'rcm',
      'role_label': 'RCM',
      'permissions': ['leads.view'],
    });
    expect(u.permissions, {Perm.leadsView});
    expect(u.can(Perm.paymentsRecord), isFalse);
    expect(u.designation, 'RCM');
    expect(u.firstName, 'Arjun');
  });

  test('falls back to role defaults while permissions are missing', () {
    final u = AppUser.fromJson({'id': 1, 'name': 'A', 'email': 'a@example.com', 'role': 'rcm'});
    expect(u.can(Perm.visitsManage), isTrue);
    expect(u.can(Perm.leadsAssign), isFalse);
  });

  test('unknown role without permissions gets nothing', () {
    final u = AppUser.fromJson({'id': 1, 'name': 'A', 'email': 'a@example.com', 'role': 'asm'});
    expect(u.permissions, isEmpty);
  });

  test('designation prefers the designation field', () {
    final u = AppUser.fromJson({
      'id': 1,
      'name': 'A',
      'email': 'a@example.com',
      'role': 'asm',
      'designation': 'Area Sales Manager',
      'role_label': 'ASM',
      'permissions': [],
      'territories': [
        {'id': 3, 'name': 'Bengaluru South'},
      ],
    });
    expect(u.designation, 'Area Sales Manager');
    expect(u.territories.single.name, 'Bengaluru South');
  });
}
