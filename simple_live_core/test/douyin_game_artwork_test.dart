import 'package:simple_live_core/simple_live_core.dart';
import 'package:test/test.dart';

void main() {
  test('maps reviewed artwork by Douyin category ID only', () {
    expect(
      DouyinGameArtwork.assetUriForCategoryId('1010003,1'),
      startsWith('asset://assets/images/douyin_games/steam_'),
    );
    expect(
      DouyinGameArtwork.assetUriForCategoryId('1010004,1'),
      startsWith('asset://assets/images/douyin_games/app_store_'),
    );
    expect(
      DouyinGameArtwork.assetUriForCategoryId('1010509,1'),
      startsWith('asset://assets/images/douyin_games/user_provided_'),
    );
    expect(DouyinGameArtwork.assetUriForCategoryId('3,1'), isNull);
  });

  test('maps maintainer-provided artwork by category name', () {
    expect(
      DouyinGameArtwork.assetUriForCategoryName('聊天'),
      'asset://assets/images/douyin_games/user_category_chat.png',
    );
    expect(
      DouyinGameArtwork.assetUriForCategoryName('单机游戏'),
      'asset://assets/images/douyin_games/user_category_single_player_game.png',
    );
    expect(
      DouyinGameArtwork.assetUriForCategoryName('境·界 刀鸣'),
      'asset://assets/images/douyin_games/user_game_bleach_soul_resonance.png',
    );
    expect(
      DouyinGameArtwork.assetUriForCategoryName('潜行者2: 切尔诺贝利之心'),
      'asset://assets/images/douyin_games/user_game_stalker_2_heart_of_chornobyl.jpg',
    );
  });

  test('prefers reviewed ID artwork before name fallback', () {
    expect(
      DouyinGameArtwork.assetUriForCategory(
        categoryId: '1010003,1',
        categoryName: '聊天',
      ),
      startsWith('asset://assets/images/douyin_games/steam_'),
    );
    expect(
      DouyinGameArtwork.assetUriForCategory(
        categoryId: 'unknown',
        categoryName: '聊天',
      ),
      'asset://assets/images/douyin_games/user_category_chat.png',
    );
  });

  test('recognizes only generated local game-artwork URIs', () {
    expect(
      DouyinGameArtwork.isLocalGameArtwork(
        'asset://assets/images/douyin_games/steam_example.jpg',
      ),
      isTrue,
    );
    expect(
      DouyinGameArtwork.isLocalGameArtwork('https://example.com/image.png'),
      isFalse,
    );
  });
}
