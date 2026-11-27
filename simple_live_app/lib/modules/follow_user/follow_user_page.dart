import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyrefresh/easy_refresh.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/modules/follow_user/follow_category_name.dart';
import 'package:simple_live_app/modules/indexed/indexed_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/filter_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_app/widgets/status/app_empty_widget.dart';
import 'package:simple_live_app/widgets/status/app_error_widget.dart';

class FollowUserPage extends StatefulWidget {
  const FollowUserPage({Key? key}) : super(key: key);

  @override
  State<FollowUserPage> createState() => _FollowUserPageState();
}

class _FollowUserPageState extends State<FollowUserPage>
    with SingleTickerProviderStateMixin {
  FollowUserController get controller => Get.find<FollowUserController>();
  late final AnimationController _filterFade =
      AnimationController(vsync: this, value: 1);
  FollowUserTag? _targetFilter;
  double _horizontalDistance = 0;
  int _filterChange = 0;
  Worker? _navigationWorker;

  @override
  void initState() {
    super.initState();
    controller.restoreDefaultFilter();
    // 主导航缓存页面；返回关注页时也恢复默认，而非沿用临时筛选。
    if (Get.isRegistered<IndexedController>()) {
      final navigation = Get.find<IndexedController>();
      _navigationWorker = ever<int>(navigation.index, (index) {
        if (index >= 0 &&
            index < navigation.items.length &&
            navigation.items[index].index == 1) {
          _filterChange++;
          _targetFilter = null;
          _filterFade.value = 1;
          controller.restoreDefaultFilter();
        }
      });
    }
  }

  Future<void> _showDefaultFilterMenu(
      FollowUserTag option, Offset position) async {
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final local = overlay.globalToLocal(position);
    final isDefault = controller.defaultFilterId.value == option.id;
    final selected = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromRect(
          Rect.fromLTWH(local.dx, local.dy, 0, 0), Offset.zero & overlay.size),
      items: [
        CheckedPopupMenuItem<bool>(
          value: true,
          checked: isDefault,
          enabled: !isDefault,
          child: Text(isDefault ? '当前默认显示' : '设为默认显示'),
        ),
      ],
    );
    if (selected != true || !mounted) return;
    try {
      await controller.setDefaultFilter(option);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('默认显示设置失败，请重试')));
    }
  }

  bool get _mobile => defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _selectFilter(FollowUserTag option) async {
    if (!_mobile) {
      controller.setFilterMode(option);
      return;
    }
    if ((_targetFilter ?? controller.filterMode.value).id == option.id) return;
    _targetFilter = option;
    final change = ++_filterChange;
    try {
      await _filterFade.animateTo(0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut).orCancel;
      if (!mounted || change != _filterChange) return;
      controller.setFilterMode(option);
      await _filterFade.animateTo(1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeIn).orCancel;
      if (mounted && change == _filterChange) _targetFilter = null;
    } on TickerCanceled {
      // 新的切换或页面退出会取消旧动画，旧回调不再更新筛选。
    }
  }

  Widget _buildFilterContent(BuildContext context, int count) {
    final list = _buildFollowList(context, count);
    if (!_mobile) return list;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _horizontalDistance = 0,
      onHorizontalDragUpdate: (details) =>
          _horizontalDistance += details.primaryDelta ?? 0,
      onHorizontalDragEnd: (_) {
        if (_horizontalDistance.abs() < 48) return;
        final index = controller.tagList.indexWhere((tag) =>
            tag.id == (_targetFilter ?? controller.filterMode.value).id);
        if (index < 0 || index > 2) return;
        final next = index + (_horizontalDistance < 0 ? 1 : -1);
        if (next >= 0 && next <= 2) _selectFilter(controller.tagList[next]);
      },
      child: FadeTransition(opacity: _filterFade, child: list),
    );
  }

  @override
  void dispose() {
    _navigationWorker?.dispose();
    _filterFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var count = MediaQuery.of(context).size.width ~/ 500;
    if (count < 1) count = 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text("关注用户"),
        actions: [
          if (Platform.isWindows)
            IconButton(
              tooltip: '多画面同屏',
              onPressed: () {
                Get.toNamed(RoutePath.kMultiView);
              },
              icon: const Icon(Icons.grid_view_outlined),
            ),
          PopupMenuButton(
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.save_2_line),
                      AppStyle.hGap12,
                      Text("导出文件")
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.folder_open_line),
                      AppStyle.hGap12,
                      Text("导入文件")
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.text),
                      AppStyle.hGap12,
                      Text("导出文本"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.file_text_line),
                      AppStyle.hGap12,
                      Text("导入文本"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Remix.price_tag_line),
                      AppStyle.hGap12,
                      Text("标签管理"),
                    ],
                  ),
                ),
              ];
            },
            onSelected: (value) {
              if (value == 0) {
                FollowService.instance.exportFile();
              } else if (value == 1) {
                FollowService.instance.inputFile();
              } else if (value == 2) {
                FollowService.instance.exportText();
              } else if (value == 3) {
                FollowService.instance.inputText();
              } else if (value == 4) {
                showTagsManager();
              }
            },
          ),
        ],
        leading: Obx(
          () => FollowService.instance.updating.value
              ? const IconButton(
                  onPressed: null,
                  icon: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: () {
                    controller.refreshData();
                  },
                  icon: const Icon(Icons.refresh),
                ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AppStyle.edgeInsetsL8,
            child: Row(
              children: [
                Expanded(
                  child: Obx(
                    () => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                          spacing: 12,
                          children: controller.tagList.map((option) {
                            final button = FilterButton(
                              text: option.tag,
                              selected: controller.filterMode.value == option,
                              onTap: () {
                                _selectFilter(option);
                              },
                            );
                            if (!controller.tagList.take(3).contains(option)) {
                              return button;
                            }
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onSecondaryTapUp: (details) =>
                                  _showDefaultFilterMenu(
                                      option, details.globalPosition),
                              onLongPressStart: (details) =>
                                  _showDefaultFilterMenu(
                                      option, details.globalPosition),
                              child: button,
                            );
                          }).toList()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildFilterContent(context, count),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowList(BuildContext context, int count) {
    return Obx(() {
      // controller.list 已由原有筛选逻辑过滤；按首次出现顺序分组。
      final groups = <String, List<FollowUser>>{};
      for (final item in controller.list) {
        final name = normalizeFollowCategory(item.categoryName);
        groups.putIfAbsent(name, () => []).add(item);
      }
      return Stack(
        children: [
          EasyRefresh(
            header: MaterialHeader(
              completeDuration: const Duration(milliseconds: 400),
            ),
            scrollController: controller.scrollController,
            controller: controller.easyRefreshController,
            firstRefresh: true,
            onRefresh: controller.refreshData,
            child: CustomScrollView(
              slivers: [
                for (final group in controller.sortCategoryGroups(groups))
                  SliverToBoxAdapter(
                    key: ValueKey(group.key),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: AppStyle.edgeInsetsV8.copyWith(left: 16),
                          color: Theme.of(context).scaffoldBackgroundColor,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${group.key} ${group.value.length}人',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        LayoutBuilder(builder: (_, constraints) {
                          final width =
                              (constraints.maxWidth - 12 * (count - 1)) / count;
                          return Wrap(
                            spacing: 12,
                            children: [
                              for (final item in controller.sortCategoryMembers(
                                  group.value,
                                  AppSettingsController.instance.siteSort.toList()))
                                SizedBox(
                                  key: ValueKey(item.id),
                                  width: width,
                                  child: _buildFollowItem(item),
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Offstage(
            offstage: !controller.pageEmpty.value,
            child: controller.filterMode.value.tag != '全部' &&
                    !FollowService.instance.updating.value &&
                    FollowService.instance.followList.any((item) => item.liveStatus.value == 0)
                ? AppErrorWidget(
                    errorMsg: '关注记录仍在，直播状态暂未获取，请重试或切换“全部”',
                    onRefresh: () => controller.refreshData())
                : AppEmptyWidget(onRefresh: () => controller.refreshData()),
          ),
          Offstage(
            offstage: !controller.pageError.value,
            child: AppErrorWidget(
              errorMsg: controller.errorMsg.value,
              onRefresh: () => controller.refreshData(),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildFollowItem(FollowUser item) {
    final site = Sites.allSites[item.siteId]!;
    return FollowUserItem(
      item: item,
      onRemove: () {
        controller.removeItem(item, confirm: false);
      },
      onTap: () {
        AppNavigator.toLiveRoomDetail(site: site, roomId: item.roomId);
      },
      onLongPress: () {
        setFollowTagDialog(item);
      },
    );
  }

  void setFollowTagDialog(FollowUser item) {
    /// 控制单选ui
    List<FollowUserTag> copiedList = [
      controller.tagList.first,
      ...controller.tagList.skip(3),
    ];
    Rx<FollowUserTag> checkTag =
        controller.tagList.indexOf(controller.filterMode.value) < 3
            ? copiedList.first.obs
            : controller.filterMode.value.obs;
    final ScrollController scrollController = ScrollController();
    Get.dialog(
      AlertDialog(
        contentPadding: const EdgeInsets.all(16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '设置标签',
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.check,
                  ),
                  onPressed: () {
                    controller.setItemTag(item, checkTag.value);
                    Get.back();
                  },
                ),
              ],
            ),
            const Divider(),
            Obx(
              () {
                int selectedIndex = copiedList.indexOf(checkTag.value);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (selectedIndex >= 0) {
                    scrollController.animateTo(
                      selectedIndex * 60.0, // 假设每项高度为 60
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                });
                return SizedBox(
                  height: 300,
                  width: 300,
                  child: RadioGroup(
                    groupValue: checkTag.value,
                    onChanged: (value) {
                      checkTag.value = value!;
                    },
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: copiedList.length,
                      itemBuilder: (context, index) {
                        var tagItem = copiedList[index];
                        return Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: Colors.grey.shade300, width: 1.0),
                            ),
                          ),
                          child: RadioListTile<FollowUserTag>(
                            title: Text(tagItem.tag),
                            value: tagItem,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void showTagsManager() {
    Utils.showBottomSheet(
      title: '标签管理',
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppStyle.divider,
            ListTile(
              title: const Text("添加标签"),
              leading: const Icon(Icons.add),
              onTap: () {
                editTagDialog("添加标签");
              },
            ),
            AppStyle.divider,
            // 列表内容
            Expanded(
              child: Obx(
                () => ReorderableListView.builder(
                  itemCount: controller.userTagList.length,
                  itemBuilder: (context, index) {
                    // 偏移
                    FollowUserTag item = controller.userTagList[index];
                    return ListTile(
                      key: ValueKey(item.id),
                      title: GestureDetector(
                        child: Text(item.tag),
                        onLongPress: () {
                          {
                            editTagDialog("修改标签", followUserTag: item);
                          }
                        },
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          controller.removeTag(item);
                        },
                      ),
                    );
                  },
                  onReorder: (int oldIndex, int newIndex) {
                    controller.updateTagOrder(oldIndex, newIndex);
                  },
                ),
              ),
            ),
          ]),
    );
  }

  void editTagDialog(String title, {FollowUserTag? followUserTag}) {
    final TextEditingController tagEditController =
        TextEditingController(text: followUserTag?.tag);
    bool upMode = title == "添加标签" ? true : false;
    Get.dialog(
      AlertDialog(
        contentPadding: const EdgeInsets.all(16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        content: SingleChildScrollView(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(Get.context!).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),
              TextField(
                controller: tagEditController,
                minLines: 1,
                maxLines: 1,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  contentPadding: AppStyle.edgeInsetsA12,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey.withAlpha(51),
                    ),
                  ),
                ),
                onSubmitted: (tag) {
                  upMode
                      ? controller.addTag(tagEditController.text)
                      : controller.updateTagName(
                          followUserTag!, tagEditController.text);
                  Get.back();
                },
              ),
              Container(
                margin: AppStyle.edgeInsetsB4,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Get.back();
                      },
                      child: const Text('否'),
                    ),
                    TextButton(
                      onPressed: () {
                        upMode
                            ? controller.addTag(tagEditController.text)
                            : controller.updateTagName(
                                followUserTag!, tagEditController.text);
                        Get.back();
                      },
                      child: const Text('是'),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
