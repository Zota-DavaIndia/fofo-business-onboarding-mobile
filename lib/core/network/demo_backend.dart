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

  static const _track = {
    'account_type': 'enquirer',
    'name': 'Ravi Shankar',
    'mobile': '9845012301',
    'reference': 'LD-000001',
    'partner_no': null,
    'store_code': null,
    'headline': 'Site visit: your area manager will visit on 20 Nov.',
    'done': 3,
    'total': 10,
    'area_manager': {'name': 'Arjun Kumar', 'mobile': '9845000000'},
    'support': {'phone': '+91 80 4000 0000', 'email': 'support@example.com'},
    'can_submit': false,
    'sign_in_again': false,
    'steps': [
      {
        'key': 'enquiry',
        'title': 'Enquiry received',
        'who': 'Dava India',
        'state': 'done',
        'detail': 'We received your enquiry via Instagram. Your reference is LD-000001.',
        'date': '2026-10-17T10:01:00+05:30',
      },
      {
        'key': 'call',
        'title': 'Call from our team',
        'who': 'Call centre',
        'state': 'done',
        'detail': 'You told us you have a 450 sq ft shop and are ready to invest.',
        'date': '2026-10-18T15:20:00+05:30',
      },
      {
        'key': 'area_manager',
        'title': 'Area manager assigned',
        'who': 'Dava India',
        'state': 'done',
        'detail': 'Arjun Kumar will guide you from here.',
        'date': '2026-10-18T16:05:00+05:30',
      },
      {
        'key': 'visit',
        'title': 'Site visit',
        'who': 'Area manager',
        'state': 'waiting',
        'detail': 'Your area manager will visit on 20 Nov.',
        'date': null,
      },
      {
        'key': 'approved',
        'title': 'Application approved',
        'who': 'Dava India',
        'state': 'upcoming',
        'detail': 'After the site visit.',
        'date': null,
      },
      {
        'key': 'store_basics',
        'title': 'Store details',
        'who': 'You and your area manager',
        'state': 'upcoming',
        'detail': null,
        'date': null,
      },
    ],
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    Object? data;
    var status = 200;
    switch ((options.method, options.path)) {
      case ('POST', '/auth/login'):
        final body = options.data;
        if (body is Map && body['email'] == null && body['mobile'] == null) {
          status = 422;
          data = {
            'success': false,
            'message': 'Enter your email or mobile number.',
            'errors': {
              'email': ['The email field is required when mobile is not present.'],
            },
          };
        } else {
          data = {
            'success': true,
            'data': {'token': 'demo-token', 'token_type': 'Bearer', 'user': _user},
          };
        }
      case ('POST', '/auth/start'):
        final mobile = '${(options.data as Map?)?['mobile'] ?? ''}';
        if (mobile == '9000000009') {
          data = {
            'success': true,
            'data': {'account_type': 'staff', 'next': 'password'},
          };
        } else if (RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
          data = {
            'success': true,
            'data': {'account_type': 'enquirer', 'next': 'otp'},
          };
        } else {
          status = 404;
          data = {'success': false, 'code': 'not_found', 'message': 'No enquiry for this number.'};
        }
      case ('POST', '/partner/auth/request-otp'):
        data = {'success': true, 'data': null};
      case ('POST', '/partner/auth/verify-otp'):
        if ('${(options.data as Map?)?['otp']}' == '123456') {
          data = {
            'success': true,
            'data': {'token': 'demo-track-token', 'account_type': 'enquirer', 'track': _track},
          };
        } else {
          status = 422;
          data = {
            'success': false,
            'code': 'validation_failed',
            'message': 'That code is wrong. 2 tries left.',
            'errors': {
              'otp': ['That code is wrong. 2 tries left.'],
            },
          };
        }
      case ('GET', '/partner/track'):
        data = {'success': true, 'data': _track};
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
