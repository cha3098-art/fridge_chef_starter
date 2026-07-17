import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fridge_photo_analysis.dart';
import '../utils/image_compressor.dart';

/// "사진인식" / "냉장고 전체촬영" 탭에서 쓸 서비스 — 사진을 fridge-scans 버킷에 올리고,
/// analyze-fridge-photo Edge Function(GPT-4o-mini Vision)을 호출해 실제 카탈로그와
/// 매칭된 재료 목록을 받아온다. board_screen.dart의 uploadPhoto()와 동일한 업로드 패턴을 쓴다.
class FridgePhotoRecognitionService {
  FridgePhotoRecognitionService._();
  static final FridgePhotoRecognitionService instance =
      FridgePhotoRecognitionService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<FridgePhotoAnalysis> analyze(File imageFile) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인 후 이용해주세요');

    // 업로드 용량/OpenAI 처리 시간을 줄이기 위해 게시판 사진과 동일하게 먼저 압축한다.
    final compressed = await ImageCompressor.compressImage(imageFile);
    final ext = compressed.path.contains('.')
        ? compressed.path.split('.').last.toLowerCase()
        : 'jpg';
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bytes = await compressed.readAsBytes();

    await _client.storage.from('fridge-scans').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
        );
    final imageUrl = _client.storage.from('fridge-scans').getPublicUrl(path);

    final response = await _client.functions.invoke(
      'analyze-fridge-photo',
      body: {'imageUrl': imageUrl},
    );

    if (response.status != 200) {
      final data = response.data;
      final message = data is Map ? data['error']?.toString() : null;
      throw StateError(message ?? '재료 인식에 실패했어요 (${response.status})');
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('재료 인식 응답 형식이 올바르지 않아요');
    }
    return FridgePhotoAnalysis.fromJson(data);
  }
}
