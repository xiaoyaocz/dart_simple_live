import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  test('读取网页中的抖音分类，不受后续页面数据影响', () {
    const page =
        r'''<script>self.__next_f.push([1,"{\"pathname\":\"/\",\"categoryData\":[{\"partition\":{\"id_str\":\"103\",\"type\":4,\"title\":\"游戏\"},\"sub_partition\":[{\"partition\":{\"id_str\":\"1\",\"type\":1,\"title\":\"射击游戏\"}}]}],\"extra\":[1,2]}"])</script>''';

    final categories = DouyinSite.parseCategories(page);

    expect(categories, hasLength(1));
    expect(categories.single.name, '游戏');
    expect(categories.single.children.map((item) => item.name), ['游戏', '射击游戏']);
  });
}
