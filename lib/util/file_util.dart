import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class FileUtil {
  static void copyDirectory(Directory source, Directory destination) {
    if (!source.existsSync()) {
      throw Exception("Source directory doesn't exist: ${source.path}");
    }

    if (destination.existsSync()) {
      destination.deleteSync(recursive: true);
    }
    destination.createSync(recursive: true);

    source.listSync(recursive: false).forEach((FileSystemEntity entity) {
      String newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is File) {
        entity.copySync(newPath);
      } else if (entity is Directory) {
        Directory newDirectory = Directory(newPath);
        copyDirectory(entity, newDirectory);
      }
    });
  }

  static Future<void> copyFile(String sourcePath, String targetPath) async {
    try {
      final file = File(sourcePath);
      Directory(p.dirname(targetPath)).createSync(recursive: true);
      await file.copy(targetPath);
      print('File copied: $sourcePath -> $targetPath');
    } catch (e) {
      print('Error copying file: $e');
    }
  }

  static Future<void> renameFile(String filePath, String newFileName) async {
    try {
      final file = File(filePath);
      final parentDirectory = file.parent.path;
      final newFilePath = '$parentDirectory/$newFileName';
      await file.rename(newFilePath);
      print('File renamed: $filePath -> $newFilePath');
    } catch (e) {
      print('Error renaming file: $e');
    }
  }

  /// 如果目录不存在，则创建它。
  static Future<void> createDirectoryIfNotExist(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      print("hello, directory:$directory, !await directory.exists() -> ${!await directory.exists()}");

      try {
        await directory.create(recursive: true);
      } catch (e) {
        print("hello: e:$e");
      }
      print('Directory created: $directoryPath');
    }
  }

  static Future<FileSystemEntityType> getFilePathEntityType(String path) async {
    final entityType = await FileSystemEntity.type(path);
    return entityType;
  }

  static Future<void> removeEmptyDir({required Directory dir}) async {
    if (!dir.existsSync()) return;
    List<FileSystemEntity> entities = dir.listSync();
    for (FileSystemEntity entity in entities) {
      if (entity is Directory) {
        removeEmptyDir(dir: entity);
      }
    }
    entities = dir.listSync();
    if (entities.isEmpty) {
      print('Deleting empty folder: ${dir.path}');
      dir.deleteSync();
    }
  }

  static List<String> listFilesByExtensions(String directoryPath, List<String> extensions) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      throw FileSystemException('Directory does not exist', directoryPath);
    }

    return _getFilesRecursively(directory, extensions);
  }

  static List<String> _getFilesRecursively(Directory dir, List<String> extensions) {
    final List<String> files = [];
    final normalizedExtensions = extensions.map((ext) => ext.startsWith('.') ? ext : '.$ext').toSet(); // 去重处理

    for (var entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      if (extensions.length == 1 && extensions.first == '*') {
        files.add(entity.path);
      } else {
        if (!normalizedExtensions.any((ext) => entity.path.endsWith(ext))) {
          continue;
        }
        files.add(entity.path);
      }
    }

    return files;
  }
}
