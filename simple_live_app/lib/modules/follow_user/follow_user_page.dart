import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/routes/app_navigation.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/widgets/filter_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_app/widgets/page_grid_view.dart';

class FollowUserPage extends GetView<FollowUserController> {
  const FollowUserPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var count = MediaQuery.of(context).size.width ~/ 500;
    if (count < 1) count = 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text("关注用户"),
        actions: [
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
                            return FilterButton(
                              text: option.tag,
                              selected: controller.filterMode.value == option,
                              onTap: () {
                                controller.setFilterMode(option);
                              },
                            );
                          }).toList()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageGridView(
              crossAxisSpacing: 12,
              crossAxisCount: count,
              pageController: controller,
              firstRefresh: true,
              showPCRefreshButton: false,
              itemBuilder: (_, i) {
                var item = controller.list[i];
                var site = Sites.allSites[item.siteId]!;
                return FollowUserItem(
                  item: item,
                  onRemove: () {
                    controller.removeItem(item);
                  },
                  onTap: () {
                    AppNavigator.toLiveRoomDetail(
                        site: site, roomId: item.roomId);
                  },
                  onLongPress: () {
                    setFollowTagDialog(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
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
                          groupValue: checkTag.value,
                          onChanged: (value) {
                            checkTag.value = value!;
                          },
                        ),
                      );
                    },
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
                      color: Colors.grey.withOpacity(.2),
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
