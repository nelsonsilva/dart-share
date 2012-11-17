part of html_tests;

class TestList {
  static void run(){
    OTList List = OT["list"];
    OTText Text = OT["text"];

    group('list', (){
      test('Apply inserts', () {
        expect(['a', 'b', 'c'], equals(List.apply(['b', 'c'], List.Op().I(0, 'a'))));
        expect(['a', 'b', 'c'], equals(List.apply(['a', 'c'], List.Op().I(1, 'b'))));
        expect(['a', 'b', 'c'], equals(List.apply(['a', 'b'], List.Op().I(2, 'c'))));
      });
      test('Apply deletes', () {
        expect(['b', 'c'], equals(List.apply(['a', 'b', 'c'], List.Op().D(0, 'a'))));
        expect(['a', 'c'], equals(List.apply(['a', 'b', 'c'], List.Op().D(1, 'b'))));
        expect(['a', 'b'], equals(List.apply(['a', 'b', 'c'], List.Op().D(2, 'c'))));
      });
      test('Apply replace', () {
        expect(['a', 'y', 'c'], equals(List.apply(['a', 'x', 'c'], List.Op().R(1, 'x', 'y'))));
      });
      test('Apply move', () {
        expect(['a', 'b', 'c'], equals(List.apply(['b', 'a', 'c'], List.Op().M(0, 1))));
        expect(['a', 'b', 'c'], equals(List.apply(['b', 'a', 'c'], List.Op().M(1, 0))));
      });

      test('Inserting then deleting an element composes into a no-op', () {
        expect(List.Op(), equals(List.compose(List.Op().I(1, 'abc'), List.Op().D(1, 'abc'))));
        expect(
            List.Op().I(1, 'x'),
            equals(
            List.Op().I(0, 'x').transform( List.Op().I(0, 'The')).right
         ));
      });

      test('Inserting then deleting an element composes into a no-op', () {
        expect(List.Op(), equals(List.compose(List.Op().I(1, 'abc'), List.Op().D(1, 'abc'))));
        expect(
            List.Op().I(1, 'x'),
            equals(
            List.Op().I(0, 'x').transform( List.Op().I(0, 'The')).right
         ));
      });

    });

    group('list - text ops', (){
      test('Paths are bumped when list elements are inserted or removed', () {

        expect(
          List.Op().At(2, Text.Op().I('hi', 200))
          , equals(
            List.transform(List.Op().At(1, Text.Op().I('hi', 200)), List.Op().I(0, 'x'), left:true)
           ));

          expect(
            List.Op().At(1, Text.Op().I('hi', 201))
          , equals(
              List.transform(List.Op().At(0, Text.Op().I('hi', 201)), List.Op().I(0, 'x'), right:true)
           ));

          expect(
            List.Op().At(0, Text.Op().I('hi', 202))
          , equals(
            List.transform(List.Op().At(0, Text.Op().I('hi', 202)), List.Op().I(1, 'x'), left:true)
           ));

      });

      test('Apply works', () {
        var op =  List.Op().At(0, Text.Op().I('bc', 1));
        var res = List.apply(['a'], op);
        expect(["abc"], equals(List.apply(['a'], List.Op().At(0, Text.Op().I('bc', 1)))));
      });

    });

  }
}
