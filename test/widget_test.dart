import 'package:flutter_test/flutter_test.dart';

import 'package:flowez/core/routes/app_routes.dart';

void main() {
  test('authentication routes are registered', () {
    final routes = AppRoutes.routes;

    expect(routes.containsKey(AppRoutes.login), isTrue);
    expect(routes.containsKey(AppRoutes.signup), isTrue);
    expect(routes.containsKey(AppRoutes.forgotPassword), isTrue);
    expect(routes.containsKey(AppRoutes.home), isTrue);
    expect(routes.containsKey(AppRoutes.queueDetails), isFalse);
    expect(routes.containsKey(AppRoutes.adminDashboard), isTrue);
    expect(routes.containsKey(AppRoutes.analytics), isTrue);
  });
}
