import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_chef/main.dart';

void main() {
  testWidgets('내 냉장고 화면이 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(const FridgeChefApp());

    expect(find.textContaining('내 냉장고'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
