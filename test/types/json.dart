class TestJSON {
  static void run(){
    var JSON = OT["json"];
    
    group('string', (){  
      test('Apply works', () {
        expect('abc', equals(JSON.apply('a', JSON.Op().SI('bc', [1]))));
        expect('bc', equals(JSON.apply('abc', JSON.Op().SD('a', [0]))));
        expect({"x":'abc'}, equals(JSON.apply({"x":'a'}, JSON.Op().SI('bc', ['x', 1]))));
       });
    });
  }
}