import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/routes/app_pages.dart';
import 'package:simple_live_app/routes/route_path.dart';

void main() {
  test('registers the initial application route', () {
    final routeNames = AppPages.routes.map((route) => route.name);

    expect(routeNames, contains(RoutePath.kIndex));
  });
}
