import 'dart:io';

import 'package:app/utils/pending_folder_expand.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('expandDirectoryToPendingEntries', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('pending_folder_expand_');
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('records relativeSubPath for nested files', () async {
      final root = Directory(p.join(tempRoot.path, 'project'));
      final nested = Directory(p.join(root.path, '介绍图'));
      await nested.create(recursive: true);
      final nestedFile = File(p.join(nested.path, '主页.png'));
      await nestedFile.writeAsBytes([1, 2, 3]);
      final rootFile = File(p.join(root.path, 'readme.txt'));
      await rootFile.writeAsBytes([4]);

      final entries = await expandDirectoryToPendingEntries(root.path);
      final byPath = {for (final e in entries) e.relativeSubPath: e.file.name};

      expect(byPath['readme.txt'], 'readme.txt');
      expect(byPath['介绍图/主页.png'], '主页.png');
    });
  });
}
