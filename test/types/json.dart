class TestJSON {
  static void run(){
    var JSON = OT["json"];
    
    group('string', (){  
      test('Apply works', () {
        expect('abc', equals(JSON.apply('a', JSON.Op().SI('bc', 1))));
        expect('bc', equals(JSON.apply('abc', JSON.Op().SD('a', 0))));
        expect({"x":'abc'}, equals(JSON.apply({"x":'a'}, JSON.Op().SI('bc', 1, ['x']))));
       });
      
      test('transform splits deletes', () {
        expect(
          JSON.transform(JSON.Op().SD('ab',0), JSON.Op().SI('x', 1), left:true)
        , equals(
          JSON.Op().SD('a', 0).SD('b', 1)
        ));
      });
      
      test('deletes cancel each other out', () {
        expect(
          JSON.transform(JSON.Op().SD('a', 5, ['k']), JSON.Op().SD('a', 5, ['k']), left:true)
        , equals(
          JSON.Op()
        ));
      });
      
    });

    group('object', (){  
      test('Apply sanity checks', () {
        expect({'x':'a', 'y':'b'}, equals(JSON.apply({'x':'a'}, JSON.Op().OI('y', 'b'))));
        expect({}, equals(JSON.apply({'x':'a'}, JSON.Op().OD('x', 'a'))));
        expect({'x':'b'}, equals(JSON.apply({'x':'a'}, JSON.Op().OR('x', 'a', 'b'))));
       });
      /*
      test('Ops on deleted elements become noops', () {
        expect(
          JSON.transform(JSON.Op().SI('hi', 0, [1]), JSON.Op().OD('x', 1), left:true)
        , equals(
          JSON.Op()
        ));
        expect(
          JSON.transform(JSON.Op().SI('bite ', 9), JSON.Op().OD(null, 'agimble s'), right:true)
        , equals(
          JSON.Op()
        ));
      });*/
    });

    group('list', (){  
      test('Apply inserts', () {
        expect(['a', 'b', 'c'], equals(JSON.apply(['b', 'c'], JSON.Op().LI(0, 'a'))));
        expect(['a', 'b', 'c'], equals(JSON.apply(['a', 'c'], JSON.Op().LI(1, 'b'))));
        expect(['a', 'b', 'c'], equals(JSON.apply(['a', 'b'], JSON.Op().LI(2, 'c'))));
      });
      test('Apply deletes', () {
        expect(['b', 'c'], equals(JSON.apply(['a', 'b', 'c'], JSON.Op().LD(0, 'a'))));
        expect(['a', 'c'], equals(JSON.apply(['a', 'b', 'c'], JSON.Op().LD(1, 'b'))));
        expect(['a', 'b'], equals(JSON.apply(['a', 'b', 'c'], JSON.Op().LD(2, 'c'))));
      });
      test('Apply replace', () {
        expect(['a', 'y', 'c'], equals(JSON.apply(['a', 'x', 'c'], JSON.Op().LR(1, 'x', 'y'))));
      });
      test('Apply move', () {
        expect(['a', 'b', 'c'], equals(JSON.apply(['b', 'a', 'c'], JSON.Op().LM(0, 1))));
        expect(['a', 'b', 'c'], equals(JSON.apply(['b', 'a', 'c'], JSON.Op().LM(1, 0))));
      });
      
      test('Paths are bumped when list elements are inserted or removed', () {
        expect(
          JSON.Op().SI('hi', 200, [2])
        , equals(
          JSON.transform(JSON.Op().SI('hi', 200, [1]), JSON.Op().LI(0, 'x'), left:true)
         ));
        
        expect(
          JSON.Op().SI('hi', 201, [1])
        , equals(
          JSON.transform(JSON.Op().SI('hi', 201, [0]), JSON.Op().LI(0, 'x'), right:true)
         ));
        
        expect(
          JSON.Op().SI('hi', 202, [0])
        , equals(
          JSON.transform(JSON.Op().SI('hi', 202, [0]), JSON.Op().LI(1, 'x'), left:true)
         ));
      });
      
    });

  }
}