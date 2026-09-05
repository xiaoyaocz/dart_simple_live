import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';

class _TestPageController extends BasePageController<int> {
  final Map<int, List<int>> pages;

  _TestPageController(this.pages);

  @override
  Future<List<int>> getData(int page, int pageSize) async {
    return pages[page] ?? const [];
  }
}

void main() {
  test('first page replaces stale items instead of appending', () async {
    final controller = _TestPageController({
      1: [1, 2]
    });
    controller.list.value = [99];
    controller.currentPage = 1;

    await controller.loadData();

    expect(controller.list, [1, 2]);
    expect(controller.currentPage, 2);
  });

  test('later pages append to the existing list', () async {
    final controller = _TestPageController({
      2: [3, 4]
    });
    controller.list.value = [1, 2];
    controller.currentPage = 2;

    await controller.loadData();

    expect(controller.list, [1, 2, 3, 4]);
    expect(controller.currentPage, 3);
  });
}
