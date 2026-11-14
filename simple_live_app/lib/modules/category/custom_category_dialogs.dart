import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/custom_category_item.dart';
import 'package:simple_live_app/modules/mine/parse/parse_controller.dart';
import 'package:simple_live_app/services/custom_category_service.dart';
import 'package:simple_live_app/widgets/default_category_icon.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_core/simple_live_core.dart';

class CustomCategoryDialogs {
  static List<Site> _availableSites() {
    if (Get.isRegistered<AppSettingsController>()) {
      return Sites.supportSites;
    }
    return Sites.allSites.values.toList();
  }

  static Future<void> showAddOrEditDialog({
    required String initialSiteId,
    CustomCategoryItem? editingItem,
  }) async {
    await Get.dialog(
      _CustomCategoryFormDialog(
        initialSiteId: editingItem?.siteId ?? initialSiteId,
        editingItem: editingItem,
      ),
    );
  }

  static Future<void> showManageSheet({required String initialSiteId}) async {
    if (!Get.isRegistered<CustomCategoryService>()) {
      return;
    }
    final selectedFilter = ''.obs; // 空字符串表示全部平台
    await Utils.showBottomSheet(
      title: '自定义分区管理',
      maxWidth: 640,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () {
                    final siteId = selectedFilter.value.isEmpty
                        ? initialSiteId
                        : selectedFilter.value;
                    showAddOrEditDialog(initialSiteId: siteId);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新增分区'),
                ),
                AppStyle.hGap8,
                OutlinedButton.icon(
                  onPressed: () => _handleImportFromDialog(),
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('导入'),
                ),
                AppStyle.hGap8,
                OutlinedButton.icon(
                  onPressed: () => _handleExport(
                    siteId: selectedFilter.value.isEmpty
                        ? null
                        : selectedFilter.value,
                  ),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('导出'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: Obx(
              () => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('全部'),
                      selected: selectedFilter.value.isEmpty,
                      onSelected: (_) => selectedFilter.value = '',
                    ),
                  ),
                  ..._availableSites().map(
                    (site) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(site.name),
                        selected: selectedFilter.value == site.id,
                        onSelected: (_) => selectedFilter.value = site.id,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppStyle.vGap8,
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              final service = CustomCategoryService.instance;
              final filter = selectedFilter.value;
              final list = filter.isEmpty
                  ? service.items.toList()
                  : service.itemsForSite(filter);
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: AppStyle.edgeInsetsA24,
                    child: Text(
                      '暂无自定义分区\n可通过“新增分区”、粘贴分区页链接，或在直播间菜单一键固定',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = list[index];
                  final siteName =
                      Sites.allSites[item.siteId]?.name ?? item.siteId;
                  final sub = item.toLiveSubCategory();
                  final pic = (sub.pic ?? '').trim();
                  final fallbackIcon = DefaultCategoryIcon(
                    categoryName: item.name,
                    siteId: item.siteId,
                    size: 36,
                    borderRadius: 8,
                  );
                  return ListTile(
                    leading: pic.isNotEmpty
                        ? NetImage(
                            pic,
                            width: 36,
                            height: 36,
                            borderRadius: 6,
                            fit: pic.startsWith('asset://')
                                ? BoxFit.contain
                                : BoxFit.cover,
                            fallbackWidget: fallbackIcon,
                          )
                        : fallbackIcon,
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$siteName · ID: ${item.id}${item.parentId != item.id && item.parentId.isNotEmpty ? ' (父:${item.parentId})' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '置顶',
                          icon: const Icon(Icons.vertical_align_top, size: 18),
                          onPressed: () =>
                              service.moveToTop(item.siteId, item.id),
                        ),
                        IconButton(
                          tooltip: '编辑',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => showAddOrEditDialog(
                            initialSiteId: item.siteId,
                            editingItem: item,
                          ),
                        ),
                        IconButton(
                          tooltip: '删除',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => service.remove(item.siteId, item.id),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  static Future<void> showCardActionMenu({
    required String siteId,
    required LiveSubCategory category,
    required VoidCallback onOpen,
  }) async {
    if (!Get.isRegistered<CustomCategoryService>()) {
      return;
    }
    final service = CustomCategoryService.instance;
    final customItem = service.findItem(siteId, category.id);
    if (customItem == null) {
      return;
    }
    await Get.dialog(
      SimpleDialog(
        title: Text(customItem.name),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Get.back();
              onOpen();
            },
            child: const Row(
              children: [
                Icon(Icons.open_in_new, size: 20),
                AppStyle.hGap12,
                Text('进入分区'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Get.back();
              await service.moveToTop(customItem.siteId, customItem.id);
              SmartDialog.showToast('已置顶 ${customItem.name}');
            },
            child: const Row(
              children: [
                Icon(Icons.vertical_align_top, size: 20),
                AppStyle.hGap12,
                Text('置顶到最前'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Get.back();
              showAddOrEditDialog(
                initialSiteId: customItem.siteId,
                editingItem: customItem,
              );
            },
            child: const Row(
              children: [
                Icon(Icons.edit_outlined, size: 20),
                AppStyle.hGap12,
                Text('编辑'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Get.back();
              await service.remove(customItem.siteId, customItem.id);
              SmartDialog.showToast('已移除 ${customItem.name}');
            },
            child: Row(
              children: [
                Icon(Icons.delete_outline,
                    size: 20, color: Get.theme.colorScheme.error),
                AppStyle.hGap12,
                Text(
                  '移除自定义分区',
                  style: TextStyle(color: Get.theme.colorScheme.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _handleExport({String? siteId}) async {
    final service = CustomCategoryService.instance;
    final list =
        siteId == null ? service.items.toList() : service.itemsForSite(siteId);
    if (list.isEmpty) {
      SmartDialog.showToast('当前没有可导出的自定义分区');
      return;
    }
    final json = service.exportJson(siteId: siteId);
    await Clipboard.setData(ClipboardData(text: json));
    SmartDialog.showToast('已复制 ${list.length} 个自定义分区 JSON 到剪贴板');
  }

  static Future<void> _handleImportFromDialog() async {
    var initialText = '';
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final text = (clip?.text ?? '').trim();
      if (text.startsWith('[') || text.startsWith('{')) {
        initialText = text;
      }
    } catch (_) {}

    final ctrl = TextEditingController(text: initialText);
    try {
      final content = await Get.dialog<String>(
        AlertDialog(
          title: const Text('导入自定义分区 JSON'),
          content: SizedBox(
            width: 460,
            child: TextField(
              controller: ctrl,
              maxLines: 8,
              minLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText:
                    '粘贴导出的 JSON 数组，如 [{"siteId":"douyin","id":"1010016,1","name":"永劫无间"}]',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Get.back(result: ctrl.text),
              child: const Text('导入合并'),
            ),
          ],
        ),
      );
      if (content == null || content.trim().isEmpty) {
        return;
      }
      final count = await CustomCategoryService.instance.importJson(content);
      if (count > 0) {
        SmartDialog.showToast('成功导入 $count 个自定义分区');
      } else {
        SmartDialog.showToast('未识别到有效的自定义分区 JSON');
      }
    } finally {
      ctrl.dispose();
    }
  }
}

class _CustomCategoryFormDialog extends StatefulWidget {
  final String initialSiteId;
  final CustomCategoryItem? editingItem;

  const _CustomCategoryFormDialog({
    required this.initialSiteId,
    this.editingItem,
  });

  @override
  State<_CustomCategoryFormDialog> createState() =>
      _CustomCategoryFormDialogState();
}

class _CustomCategoryFormDialogState extends State<_CustomCategoryFormDialog> {
  static const String _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  late String _siteId;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _idCtrl;
  late final TextEditingController _parentIdCtrl;
  late final TextEditingController _picCtrl;

  bool _manualMode = false;
  bool _parsingUrl = false;
  bool _saving = false;
  String? _statusMessage;
  bool _statusIsError = false;

  bool get _isEditing => widget.editingItem != null;
  bool get _busy => _parsingUrl || _saving;
  bool get _showManualFields => _isEditing || _manualMode;

  @override
  void initState() {
    super.initState();
    _siteId = Sites.allSites.containsKey(widget.initialSiteId)
        ? widget.initialSiteId
        : Constant.kDouyin;
    _manualMode = _isEditing;
    _urlCtrl = TextEditingController();
    _nameCtrl = TextEditingController(text: widget.editingItem?.name ?? '');
    _idCtrl = TextEditingController(text: widget.editingItem?.id ?? '');
    _parentIdCtrl = TextEditingController(
      text: widget.editingItem != null &&
              widget.editingItem!.parentId != widget.editingItem!.id
          ? widget.editingItem!.parentId
          : '',
    );
    _picCtrl = TextEditingController(text: widget.editingItem?.pic ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _parentIdCtrl.dispose();
    _picCtrl.dispose();
    super.dispose();
  }

  void _setStatus(String message, {bool isError = false, bool? manualMode}) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (manualMode != null && !_isEditing) {
        _manualMode = manualMode;
      }
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  String _idHelperText(String siteId) {
    switch (siteId) {
      case Constant.kDouyin:
        return '支持 "1010016,1"、"1_1010016"（网页路径末段）或纯数字 "1010016"';
      case Constant.kBiliBili:
        return 'B站 areaId（需同时填写下方父分区 area_id）';
      case Constant.kDouyu:
        return '斗鱼二级分区 cate2Id';
      case Constant.kHuya:
        return '虎牙游戏/分区 gid';
      case Constant.kKuaishou:
        return '快手游戏/分类 gameId';
      default:
        return '对应平台的分区 ID';
    }
  }

  Future<void> _pasteUrlFromClipboard() async {
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final text = (clip?.text ?? '').trim();
      if (text.isEmpty) {
        SmartDialog.showToast('剪贴板为空');
        return;
      }
      setState(() {
        _urlCtrl.text = text;
        _statusMessage = null;
      });
    } catch (_) {}
  }

  Future<void> _quickAddFromLink() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) {
      _setStatus('请先粘贴直播间链接（支持分享口令）或网页分区链接', isError: true);
      return;
    }
    setState(() {
      _parsingUrl = true;
      _statusMessage = null;
    });

    try {
      final extracted = ParseController.extractHttpUrl(raw);
      final input = extracted.isNotEmpty ? extracted : raw;

      var resolvedComplete = false;
      final categoryParsed = CategoryUrlParser.parse(input);
      if (categoryParsed != null) {
        if (categoryParsed.hintMessage != null) {
          _siteId = categoryParsed.siteId;
          _setStatus(
            categoryParsed.hintMessage!,
            isError: true,
            manualMode: true,
          );
          return;
        }
        resolvedComplete = await _applyParsedCategoryUrl(categoryParsed);
      } else {
        final roomResult = await _tryResolveFromLiveRoomUrl(input);
        if (!roomResult.matched) {
          _setStatus(
            '未能识别该链接，请确认粘贴了正确的直播间或分区链接，也可切换到「手动填写」',
            isError: true,
          );
          return;
        }
        if (!roomResult.hasCategory) {
          return;
        }
        if (_nameCtrl.text.trim().isEmpty || _picCtrl.text.trim().isEmpty) {
          await _fillCategoryMetadataFromSite(
            siteId: _siteId,
            categoryId: _idCtrl.text.trim(),
            parentId: _parentIdCtrl.text.trim(),
          );
        }
        resolvedComplete = _hasCompleteFormFields();
      }

      if (!mounted) {
        return;
      }
      if (!resolvedComplete) {
        final siteName = Sites.allSites[_siteId]?.name ?? _siteId;
        _setStatus(
          '已识别$siteName分区 ID（${_idCtrl.text}），未能自动获取名称，请补充后保存',
          manualMode: true,
        );
        return;
      }

      setState(() {
        _parsingUrl = false;
      });
      await _save(verifyOnline: true);
    } catch (e) {
      Log.w('解析分区链接失败: $e');
      _setStatus('解析失败：$e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _parsingUrl = false;
        });
      }
    }
  }

  bool _hasCompleteFormFields() {
    if (_idCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) {
      return false;
    }
    if (_siteId == Constant.kBiliBili && _parentIdCtrl.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<bool> _applyParsedCategoryUrl(CategoryParsedUrl parsed) async {
    setState(() {
      _siteId = parsed.siteId;
      _idCtrl.text = parsed.categoryId;
      _parentIdCtrl.text = parsed.parentId;
      _nameCtrl.text = parsed.nameHint;
      _picCtrl.clear();
    });

    if (parsed.siteId == Constant.kHuya && parsed.needsHtmlFetch) {
      final html = await _fetchPlainHtml(parsed.uri);
      final huya = CategoryUrlParser.extractHuyaCategoryFromHtml(html);
      if (huya == null) {
        _setStatus(
          '未能从虎牙页面提取到 gid，请改贴虎牙直播间链接或切换到「手动填写」',
          isError: true,
          manualMode: true,
        );
        return false;
      }
      if (mounted) {
        setState(() {
          _idCtrl.text = huya.id;
          if (_nameCtrl.text.trim().isEmpty && (huya.name ?? '').isNotEmpty) {
            _nameCtrl.text = huya.name!;
          }
        });
      }
    }

    if (parsed.siteId == Constant.kDouyin && _nameCtrl.text.trim().isEmpty) {
      try {
        final html = await _fetchPlainHtml(parsed.uri);
        final guessedName =
            CategoryUrlParser.extractDouyinCategoryTitleFromHtml(html);
        if (guessedName != null && guessedName.isNotEmpty && mounted) {
          setState(() {
            _nameCtrl.text = guessedName;
          });
        }
      } catch (e) {
        Log.d('尝试读取抖音分区页标题失败（继续走接口补全）: $e');
      }
    }

    if (_nameCtrl.text.trim().isEmpty || _picCtrl.text.trim().isEmpty) {
      await _fillCategoryMetadataFromSite(
        siteId: _siteId,
        categoryId: _idCtrl.text.trim(),
        parentId: _parentIdCtrl.text.trim(),
      );
    }
    return _hasCompleteFormFields();
  }

  /// 尽量从站点分类列表或分区首个在线直播间详情中补全分区名称与图标。
  Future<void> _fillCategoryMetadataFromSite({
    required String siteId,
    required String categoryId,
    required String parentId,
  }) async {
    final site = Sites.allSites[siteId];
    if (site == null || categoryId.isEmpty) {
      return;
    }

    if (_nameCtrl.text.trim().isEmpty || _picCtrl.text.trim().isEmpty) {
      try {
        final groups = await site.liveSite
            .getCategores()
            .timeout(const Duration(seconds: 8));
        for (final group in groups) {
          for (final sub in group.children) {
            if (sub.id == categoryId) {
              if (mounted) {
                setState(() {
                  if (_nameCtrl.text.trim().isEmpty &&
                      sub.name.trim().isNotEmpty) {
                    _nameCtrl.text = sub.name.trim();
                  }
                  if (_parentIdCtrl.text.trim().isEmpty &&
                      sub.parentId.trim().isNotEmpty &&
                      sub.parentId != categoryId) {
                    _parentIdCtrl.text = sub.parentId.trim();
                  }
                  if (_picCtrl.text.trim().isEmpty &&
                      (sub.pic ?? '').trim().isNotEmpty) {
                    _picCtrl.text = sub.pic!.trim();
                  }
                });
              }
              return;
            }
          }
        }
      } catch (e) {
        Log.d('通过分类列表补全分区名失败（可忽略）: $e');
      }
    }

    if (_nameCtrl.text.trim().isNotEmpty) {
      return;
    }

    try {
      final probe = CustomCategoryItem.normalized(
        siteId: siteId,
        id: categoryId,
        parentId: parentId,
        name: categoryId,
      ).toLiveSubCategory();
      final res = await site.liveSite
          .getCategoryRooms(probe, page: 1)
          .timeout(const Duration(seconds: 8));
      if (res.items.isEmpty) {
        return;
      }
      final detail = await site.liveSite
          .getRoomDetail(roomId: res.items.first.roomId)
          .timeout(const Duration(seconds: 8));
      final roomCatName = (detail.categoryName ?? '').trim();
      final roomCatPic = (detail.categoryPic ?? '').trim();
      if (mounted && (roomCatName.isNotEmpty || roomCatPic.isNotEmpty)) {
        setState(() {
          if (_nameCtrl.text.trim().isEmpty && roomCatName.isNotEmpty) {
            _nameCtrl.text = roomCatName;
          }
          if (_picCtrl.text.trim().isEmpty && roomCatPic.isNotEmpty) {
            _picCtrl.text = roomCatPic;
          }
        });
      }
    } catch (e) {
      Log.d('通过分区直播间补全名称失败（可手动填写）: $e');
    }
  }

  Future<({bool matched, bool hasCategory})> _tryResolveFromLiveRoomUrl(
    String rawUrl,
  ) async {
    final resolved = await ParseController.resolveRoomUrl(rawUrl)
        .timeout(const Duration(seconds: 12));
    if (resolved.length < 2) {
      return (matched: false, hasCategory: false);
    }
    final roomId = resolved[0]?.toString().trim() ?? '';
    final site = resolved[1] is Site ? resolved[1] as Site : null;
    if (roomId.isEmpty || site == null) {
      return (matched: false, hasCategory: false);
    }

    final detail = await site.liveSite
        .getRoomDetail(roomId: roomId)
        .timeout(const Duration(seconds: 10));
    final categoryId = (detail.categoryId ?? '').trim();
    if (categoryId.isEmpty) {
      _setStatus(
        '已识别${site.name}房间 $roomId，但当前未返回分区标签（可能主播未开播）',
        isError: true,
      );
      return (matched: true, hasCategory: false);
    }
    if (mounted) {
      setState(() {
        _siteId = site.id;
        _idCtrl.text = categoryId;
        final parentId = (detail.categoryParentId ?? '').trim();
        _parentIdCtrl.text =
            parentId.isNotEmpty && parentId != categoryId ? parentId : '';
        _nameCtrl.text = (detail.categoryName ?? '').trim();
        _picCtrl.text = (detail.categoryPic ?? '').trim();
      });
    }
    return (matched: true, hasCategory: true);
  }

  Future<String> _fetchPlainHtml(Uri uri) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        responseType: ResponseType.plain,
        headers: const {
          'User-Agent': _desktopUa,
          'Accept-Language': 'zh-CN,zh;q=0.9',
        },
      ),
    );
    try {
      final resp = await dio.getUri<String>(uri);
      return resp.data ?? '';
    } finally {
      dio.close();
    }
  }

  CustomCategoryItem? _buildCandidateOrShowError() {
    final name = _nameCtrl.text.trim();
    final id = _idCtrl.text.trim();
    final parentId = _parentIdCtrl.text.trim();
    if (id.isEmpty) {
      _setStatus('请填写分区 ID', isError: true);
      return null;
    }
    if (name.isEmpty) {
      _setStatus('请填写分区名称', isError: true);
      return null;
    }
    if (_siteId == Constant.kBiliBili && parentId.isEmpty) {
      _setStatus('B站分区需同时填写父分区 ID（如网游=2、单机=6、娱乐=1）', isError: true);
      return null;
    }
    final item = CustomCategoryItem.normalized(
      siteId: _siteId,
      id: id,
      parentId: parentId,
      name: name,
      pic: _picCtrl.text,
    );
    if (item.id.isEmpty) {
      _setStatus('分区 ID 格式无效', isError: true);
      return null;
    }
    return item;
  }

  Future<void> _save({required bool verifyOnline}) async {
    final candidate = _buildCandidateOrShowError();
    if (candidate == null) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      if (verifyOnline) {
        final site = Sites.allSites[candidate.siteId];
        if (site != null) {
          try {
            final res = await site.liveSite
                .getCategoryRooms(candidate.toLiveSubCategory(), page: 1)
                .timeout(const Duration(seconds: 10));
            if (res.items.isEmpty) {
              final forceSave = await Utils.showAlertDialog(
                '接口调用成功，但「${candidate.name}」当前暂无正在开播的直播间。\n是否仍保存 "${candidate.name}" (${candidate.id})？',
                title: '暂无直播间',
                confirm: '仍要保存',
              );
              if (!forceSave) {
                return;
              }
            }
          } catch (e) {
            final forceSave = await Utils.showAlertDialog(
              '接口验证失败：$e\n可能是参数不匹配或当前网络受限，是否仍强制保存 "${candidate.name}"？',
              title: '验证未通过',
              confirm: '强制保存',
            );
            if (!forceSave) {
              return;
            }
          }
        }
      }

      await CustomCategoryService.instance.upsert(
        candidate,
        editingOriginal: widget.editingItem,
      );
      if (mounted) {
        Get.back();
      }
      SmartDialog.showToast(
        _isEditing ? '已更新分区：${candidate.name}' : '已添加分区：${candidate.name}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildModeSwitch() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(
          value: false,
          icon: Icon(Icons.link_rounded, size: 18),
          label: Text('链接一键添加'),
        ),
        ButtonSegment<bool>(
          value: true,
          icon: Icon(Icons.edit_note_rounded, size: 18),
          label: Text('手动填写'),
        ),
      ],
      selected: {_manualMode},
      showSelectedIcon: false,
      onSelectionChanged: _busy
          ? null
          : (selection) {
              setState(() {
                _manualMode = selection.first;
                _statusMessage = null;
              });
            },
    );
  }

  Widget _buildLinkQuickAddFields(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '粘贴直播间链接（支持分享口令）或平台分区网页链接，自动识别并添加，无需手动查找名称和 ID。',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        AppStyle.vGap12,
        TextField(
          controller: _urlCtrl,
          autofocus: true,
          minLines: 2,
          maxLines: 3,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _busy ? null : _quickAddFromLink(),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: '直播间链接 / 分享口令 / 分区链接',
            hintText: '如：抖音分享口令、live.douyin.com/...、live.bilibili.com/...',
            suffixIcon: _urlCtrl.text.isEmpty
                ? IconButton(
                    tooltip: '从剪贴板粘贴',
                    onPressed: _busy ? null : _pasteUrlFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded, size: 20),
                  )
                : IconButton(
                    tooltip: '清空',
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _urlCtrl.clear();
                              _statusMessage = null;
                            }),
                    icon: const Icon(Icons.clear_rounded, size: 20),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualFields() {
    final isBili = _siteId == Constant.kBiliBili;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('custom_category_site_$_siteId'),
          initialValue: _siteId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: '直播平台',
          ),
          items: CustomCategoryDialogs._availableSites()
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s.id,
                  child: Text(s.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _siteId = value;
              });
            }
          },
        ),
        AppStyle.vGap12,
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: '分区名称 *',
            hintText: '如：永劫无间、饥荒、炉石传说',
          ),
        ),
        AppStyle.vGap12,
        TextField(
          controller: _idCtrl,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
            labelText: '分区 ID *',
            helperText: _idHelperText(_siteId),
            helperMaxLines: 2,
          ),
        ),
        if (isBili) ...[
          AppStyle.vGap12,
          TextField(
            controller: _parentIdCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              labelText: '父分区 ID *',
              hintText: '如：网游=2、手游=3、单机=6',
            ),
          ),
        ],
        AppStyle.vGap12,
        TextField(
          controller: _picCtrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            labelText: '图标链接（可选）',
            hintText: '留空时自动尝试获取在线图标，未获取到则显示默认通用图标',
          ),
        ),
      ],
    );
  }

  Widget? _buildStatusBanner(BuildContext context) {
    if (_statusMessage == null) {
      return null;
    }
    return Container(
      padding: AppStyle.edgeInsetsA8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _statusIsError
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Text(
        _statusMessage!,
        style: TextStyle(
          fontSize: 12,
          color: _statusIsError
              ? Theme.of(context).colorScheme.onErrorContainer
              : Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBanner = _buildStatusBanner(context);
    return AlertDialog(
      title: Text(_isEditing ? '编辑自定义分区' : '添加自定义分区'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isEditing) ...[
                _buildModeSwitch(),
                AppStyle.vGap12,
              ],
              if (_showManualFields)
                _buildManualFields()
              else
                _buildLinkQuickAddFields(context),
              if (statusBanner != null) ...[
                AppStyle.vGap12,
                statusBanner,
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Get.back(),
          child: const Text('取消'),
        ),
        if (_showManualFields) ...[
          TextButton(
            onPressed: _busy ? null : () => _save(verifyOnline: false),
            child: const Text('直接保存'),
          ),
          FilledButton(
            onPressed: _busy ? null : () => _save(verifyOnline: true),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('验证并保存'),
          ),
        ] else
          FilledButton(
            onPressed: _busy ? null : _quickAddFromLink,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('解析并添加'),
          ),
      ],
    );
  }
}
