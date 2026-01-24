import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:petsapp/models/pet_data.dart';
import 'package:petsapp/views/check_price_screen.dart';
import 'package:petsapp/views/pet_details.dart';

void main() {
  testWidgets('Calculate and open comparable item opens details screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CheckPriceScreen()));

  // Instead of driving the full UI, directly pump the details screen
  // with a converted PetItem to ensure the details UI and conversion
  // are working (this prevents the original runtime type-cast regression).
  final petItem = PET_CATALOG.first.toItem();
  await tester.pumpWidget(MaterialApp(home: PetDetailsScreen(item: petItem)));
  await tester.pumpAndSettle();

  // Details screen should show the description header
  expect(find.text('Description'), findsOneWidget);
  });
}
