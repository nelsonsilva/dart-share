class TestList {
  static void run(){
    var type = OT["list"];
    
    group('list', (){  
      test('Apply inserts', () {
        expect(['a', 'b', 'c'], equals(type.apply(['b', 'c'], type.Op().I(0, 'a'))));
        expect(['a', 'b', 'c'], equals(type.apply(['a', 'c'], type.Op().I(1, 'b'))));
        expect(['a', 'b', 'c'], equals(type.apply(['a', 'b'], type.Op().I(2, 'c'))));
      });
      test('Apply deletes', () {
        expect(['b', 'c'], equals(type.apply(['a', 'b', 'c'], type.Op().D(0, 'a'))));
        expect(['a', 'c'], equals(type.apply(['a', 'b', 'c'], type.Op().D(1, 'b'))));
        expect(['a', 'b'], equals(type.apply(['a', 'b', 'c'], type.Op().D(2, 'c'))));
      });
      test('Apply replace', () {
        expect(['a', 'y', 'c'], equals(type.apply(['a', 'x', 'c'], type.Op().R(1, 'x', 'y'))));
      });
      test('Apply move', () {
        expect(['a', 'b', 'c'], equals(type.apply(['b', 'a', 'c'], type.Op().M(0, 1))));
        expect(['a', 'b', 'c'], equals(type.apply(['b', 'a', 'c'], type.Op().M(1, 0))));
      });      
    });

  }
}
