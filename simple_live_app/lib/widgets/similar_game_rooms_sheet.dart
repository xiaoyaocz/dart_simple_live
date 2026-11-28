import 'package:flutter/material.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/services/similar_game_rooms.dart';
import 'package:simple_live_app/widgets/net_image.dart';

class SimilarGameRoomsSheet extends StatefulWidget {
  const SimilarGameRoomsSheet(
      {super.key,
      required this.site,
      required this.detail,
      required this.onRoomSelected,
      this.loader});
  final LiveSite site;
  final LiveRoomDetail detail;
  final ValueChanged<LiveRoomItem> onRoomSelected;
  final SimilarGameRoomsLoader? loader;
  @override
  State<SimilarGameRoomsSheet> createState() => _SimilarGameRoomsSheetState();
}

class _SimilarGameRoomsSheetState extends State<SimilarGameRoomsSheet> {
  late Future<SimilarGameRooms?> _request;
  SimilarGameRoomsLoader get _loader =>
      widget.loader ?? SimilarGameRoomsLoader.shared;
  @override
  void initState() {
    super.initState();
    _request = _loader.load(widget.site, widget.detail);
  }

  void _refresh() {
    setState(() {
      _request = _loader.load(widget.site, widget.detail, force: true);
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: FutureBuilder<SimilarGameRooms?>(
            future: _request,
            builder: (context, snapshot) {
              final loading = snapshot.connectionState != ConnectionState.done;
              final data = snapshot.data;
              final seen = <String>{};
              final rooms = data?.rooms
                  .where((room) =>
                      room.roomId != widget.detail.roomId &&
                      seen.add(room.roomId))
                  .toList();
              return Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(children: [
                      const Expanded(
                          child:
                              Text('同类游戏主播', style: TextStyle(fontSize: 18))),
                      IconButton(
                          tooltip: '刷新同类主播',
                          onPressed: loading ? null : _refresh,
                          icon: const Icon(Icons.refresh)),
                    ])),
                Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : snapshot.hasError
                            ? Center(
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                    const Text('推荐加载失败，请重试'),
                                    TextButton(
                                        onPressed: _refresh,
                                        child: const Text('重试')),
                                  ]))
                            : data == null
                                ? const Center(child: Text('未找到当前游戏的主播分类'))
                                : Column(children: [
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Text(data.category.name)),
                                    Expanded(
                                        child: rooms!.isEmpty
                                            ? Center(
                                                child: Text(
                                                    '${data.category.name}暂无其他主播'))
                                            : ListView.builder(
                                                itemCount: rooms.length,
                                                itemBuilder: (context, index) {
                                                  final room = rooms[index];
                                                  return ListTile(
                                                    leading: NetImage(
                                                        room.cover,
                                                        width: 72,
                                                        height: 48,
                                                        borderRadius: 6),
                                                    title: Text(room.title,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis),
                                                    subtitle:
                                                        Text(room.userName),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      widget
                                                          .onRoomSelected(room);
                                                    },
                                                  );
                                                })),
                                    TextButton.icon(
                                        onPressed: () => Navigator.pop(
                                            context, data.category),
                                        icon: const Icon(
                                            Icons.grid_view_outlined),
                                        label: const Text('查看完整分类')),
                                  ])),
              ]);
            },
          ),
        ),
      );
}
