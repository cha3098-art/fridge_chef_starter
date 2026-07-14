import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_chef/widgets/fridge_mascot.dart';

void main() {
  // FridgeChefApp 전체는 실행 즉시 Supabase 세션을 조회하므로(main()의 Supabase.initialize()가
  // 필요), 위젯 테스트에서는 네트워크/플랫폼 의존이 없는 마스코트 위젯만 스모크 테스트한다.
  testWidgets('냉장고 마스코트가 에러 없이 그려진다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FridgeMascot())));
    expect(find.byType(FridgeMascot), findsOneWidget);
  });
}
