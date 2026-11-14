import 'package:dio/dio.dart';

/// Answers a few API calls with sample data so the app can be tried in the
/// simulator without the CRM running. Only used when APP_ENV is `demo`;
/// any password works.
class DemoBackend extends Interceptor {
  int _dashboardCalls = 0;

  static const _user = {
    'id': 1,
    'name': 'Arjun Kumar',
    'email': 'demo@example.com',
    'mobile': '9845000000',
    'role': 'rcm',
    'role_label': 'RCM',
    'permissions': [
      'leads.view',
      'leads.update',
      'leads.status',
      'visits.manage',
      'onboarding.view',
      'onboarding.submit',
      'onboarding.verify_partner',
      'payments.record',
      'dashboard.view',
    ],
    'territories': [
      {'id': 1, 'name': 'Bengaluru South'},
    ],
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    Object? data;
    var status = 200;
    switch ((options.method, options.path)) {
      case ('POST', '/auth/login'):
        final body = options.data;
        if (body is Map && '${body['email']}'.trim().isEmpty) {
          status = 422;
          data = {
            'success': false,
            'message': 'Enter your email.',
            'errors': {
              'email': ['Enter your email.'],
            },
          };
        } else {
          data = {
            'success': true,
            'data': {'token': 'demo-token', 'token_type': 'Bearer', 'user': _user},
          };
        }
      case ('GET', '/auth/me'):
        data = {'success': true, 'data': _user};
      case ('POST', '/auth/logout'):
        data = {'success': true, 'data': null};
      case ('GET', '/dashboard'):
        data = {
          'success': true,
          'data': {
            // Changes on each call so refreshes are visible in demo mode.
            'by_status': {'ASSIGNED': 4 + _dashboardCalls++ % 3, 'VISIT_SCHEDULED': 3, 'FOLLOW_UP': 2, 'QUALIFIED': 1},
          },
        };
      default:
        status = 404;
        data = {'success': false, 'message': 'Not available in demo mode.'};
    }

    final response = Response<dynamic>(requestOptions: options, statusCode: status, data: data);
    if (status >= 400) {
      handler.reject(DioException.badResponse(statusCode: status, requestOptions: options, response: response));
    } else {
      handler.resolve(response);
    }
  }
}
