import 'dart:io';

import 'package:simple_live_app/app/log.dart';

// 扩展 Directory 类，添加清空文件夹的功能并验证是否为文件夹
extension DirectoryCleaner on Directory {
  Future<void> clear() async {
    // 首先判断是否为文件夹
    if (await exists() && await FileSystemEntity.isDirectory(path)) {
      // 列出文件夹中的所有文件和子文件夹
      List<FileSystemEntity> files = listSync();

      // 遍历文件列表并删除每个文件或子文件夹
      for (FileSystemEntity file in files) {
        if (file is File) {
          await file.delete();
          Log.i('删除文件: ${file.path}');
        } else if (file is Directory) {
          await Directory(file.path).delete(recursive: true);
          Log.i('删除文件夹: ${file.path}');
        }
      }

      Log.i('文件夹清空完成');
    } else {
      Log.i('$path 不是一个有效的文件夹');
    }
  }
  // 阻塞主线程
  void clearSync()  {
    if ( existsSync() && FileSystemEntity.isDirectorySync(path)) {
      List<FileSystemEntity> files = listSync();
      for (FileSystemEntity file in files) {
        if (file is File) {
          file.deleteSync();
          Log.i('删除文件: ${file.path}');
        } else if (file is Directory) {
          Directory(file.path).deleteSync(recursive: true);
          Log.i('删除文件夹: ${file.path}');
        }
      }

      Log.i('文件夹清空完成');
    } else {
      Log.i('$path 不是一个有效的文件夹');
    }
  }
}