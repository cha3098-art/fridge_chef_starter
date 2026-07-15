import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

class ImageCompressor {
  /// 원본 이미지 파일을 받아 압축된 새 임시 파일로 반환한다.
  /// 가로/세로 최대 1080px, 품질 80%로 압축해 업로드 용량과 대기 시간을 줄인다.
  static Future<File> compressImage(File file) async {
    final tempDir = await path_provider.getTemporaryDirectory();
    final targetPath = p.join(
      tempDir.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}',
    );

    final compressedXFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 80,
      minWidth: 1080,
      minHeight: 1080,
    );

    if (compressedXFile == null) {
      return file; // 압축 실패 시 원본 반환 (예외 방지 안전장치)
    }

    return File(compressedXFile.path);
  }
}
