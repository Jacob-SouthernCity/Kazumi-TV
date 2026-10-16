import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_scroll_edges.dart';

void main() {
  final first = FocusNode();
  final last = FocusNode();
  final chip = FocusNode();

  tearDownAll(() {
    first.dispose();
    last.dispose();
    chip.dispose();
  });

  Widget button(FocusNode node, String label) => SizedBox(
    height: 80,
    child: TextButton(focusNode: node, onPressed: () {}, child: Text(label)),
  );

  const header = SizedBox(height: 150, child: Text('header'));

  Future<ScrollPosition> pump(WidgetTester tester, Widget list) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TVScrollEdges(child: SizedBox(height: 400, child: list)),
      ),
    );
    return tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
  }

  Future<void> focus(WidgetTester tester, FocusNode node) async {
    node.requestFocus();
    await tester.pumpAndSettle();
  }

  testWidgets('reveals the header above the first control', (tester) async {
    final position = await pump(
      tester,
      SingleChildScrollView(
        child: Column(
          children: [
            header,
            button(first, 'first'),
            for (var i = 0; i < 10; i++) button(FocusNode(), 'item $i'),
            button(last, 'last'),
          ],
        ),
      ),
    );
    await focus(tester, last);
    expect(position.pixels, position.maxScrollExtent);

    position.jumpTo(150);
    await focus(tester, first);
    expect(position.pixels, 0);
  });

  testWidgets('aligns the page from inside a horizontal row', (tester) async {
    final position = await pump(
      tester,
      CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: header),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  SizedBox(
                    width: 120,
                    child: TextButton(
                      focusNode: chip,
                      onPressed: () {},
                      child: const Text('chip'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.list(
            children: [
              for (var i = 0; i < 10; i++) button(FocusNode(), 'item $i'),
            ],
          ),
        ],
      ),
    );
    position.jumpTo(150);
    await focus(tester, chip);
    expect(position.pixels, 0);
  });
}
