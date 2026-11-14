/// Permission strings sent by the backend in `GET /auth/me`.
/// Screens check these, never the user's role.
abstract final class Perm {
  static const leadsView = 'leads.view';
  static const leadsCreate = 'leads.create';
  static const leadsUpdate = 'leads.update';
  static const leadsStatus = 'leads.status';
  static const leadsAssign = 'leads.assign';
  static const leadsCall = 'leads.call';
  static const visitsManage = 'visits.manage';
  static const onboardingView = 'onboarding.view';
  static const onboardingSubmit = 'onboarding.submit';
  static const onboardingVerifyPartner = 'onboarding.verify_partner';
  static const paymentsRecord = 'payments.record';
  static const dashboardView = 'dashboard.view';
}

/// Used only while `/auth/me` has no `permissions` field. Roles are set up
/// in the CRM admin; this map is a stopgap until the backend sends them.
const legacyRolePermissions = <String, Set<String>>{
  'admin': {
    Perm.leadsView,
    Perm.leadsCreate,
    Perm.leadsUpdate,
    Perm.leadsStatus,
    Perm.leadsAssign,
    Perm.visitsManage,
    Perm.onboardingView,
    Perm.onboardingSubmit,
    Perm.onboardingVerifyPartner,
    Perm.paymentsRecord,
    Perm.dashboardView,
  },
  'regional_manager': {
    Perm.leadsView,
    Perm.leadsCreate,
    Perm.leadsUpdate,
    Perm.leadsStatus,
    Perm.leadsAssign,
    Perm.visitsManage,
    Perm.onboardingView,
    Perm.dashboardView,
  },
  'rcm': {
    Perm.leadsView,
    Perm.leadsUpdate,
    Perm.leadsStatus,
    Perm.visitsManage,
    Perm.onboardingView,
    Perm.onboardingSubmit,
    Perm.onboardingVerifyPartner,
    Perm.paymentsRecord,
    Perm.dashboardView,
  },
};
