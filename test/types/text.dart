class TestText {
  static void run(){
    var Text = OT["text"];
    
    group('compress', (){  
      test('sanity checks', () {
        expect(Text.Op(), equals(Text.Op().compress()));
        expect(Text.Op().I('blah', 3), equals(Text.Op().I('blah', 3).compress()));
        expect(Text.Op().D('blah', 3), equals(Text.Op().D('blah', 3).compress()));
        expect(Text.Op().D('blah', 3).I('blah', 10), equals(Text.Op().D('blah', 3).I('blah', 10).compress()));
      });
      
      test('compress inserts', () {
        expect(Text.Op().I('xyzabc', 10), equals(Text.Op().I('abc', 10).I('xyz', 10).compress()));
        expect(Text.Op().I('axyzbc', 10), equals(Text.Op().I('abc', 10).I('xyz', 11).compress()));
        expect(Text.Op().I('abcxyz', 10), equals(Text.Op().I('abc', 10).I('xyz', 13).compress()));
      });
      
      test('dont compress separate inserts', () {
        var op;
        
        op = Text.Op().I('abc', 10).I('xyz', 9);
        expect(op, equals(op.compress()));
        
        op = Text.Op().I('abc', 10).I('xyz', 14);
        expect(op, equals(op.compress()));
      });
      
      test('compress deletes', () {
        expect(Text.Op().D('xyabc', 8), equals(Text.Op().D('abc', 10).D('xy', 8).compress()));
        expect(Text.Op().D('xabcy', 9), equals(Text.Op().D('abc', 10).D('xy', 9).compress()));
        expect(Text.Op().D('abcxy', 10), equals(Text.Op().D('abc', 10).D('xy', 10).compress()));
      });
      
      test('dont compress separate deletes', () {
        var op;
        
        op = Text.Op().D('abc', 10).D('xyz', 6);
        expect(op, equals(op.compress()));
        
        op = Text.Op().D('abc', 10).D('xyz', 11);
        expect(op, equals(op.compress()));

      });
    });
    
    group('compose', (){
      test('sanity checks', () { 
        expect(Text.Op(), equals(Text.compose(Text.Op(), Text.Op())));
        expect(Text.Op().I('x', 0), equals(Text.compose(Text.Op().I('x', 0), Text.Op())));
        expect(Text.Op().I('x', 0), equals(Text.compose(Text.Op(), Text.Op().I('x', 0))));
        expect(Text.Op().I('y', 100).I('x', 0), equals(Text.compose(Text.Op().I('y', 100), Text.Op().I('x', 0))));
      });
    });
    
    group('transform', (){

      test('sanity checks', () {   
        expect(Text.Op(), equals(Text.Op().transform(Text.Op()).left));
        expect(Text.Op(), equals(Text.Op().transform(Text.Op()).right));
        expect(Text.Op().I('y', 100).I('x',0), equals(Text.Op().I('y', 100).I('x',0).transform(Text.Op()).left));
        expect(Text.Op(), equals(Text.Op().I('y', 100).I('x', 0).transform(Text.Op()).right));
      });
      test('insert', () {
        expect(
          [Text.Op().I('x', 10), Text.Op().I('a', 1)]
        , equals(
          Text.Op().I('x',9).transform(Text.Op().I('a',1))
        ));
        
        expect(
          [Text.Op().I('x', 10), Text.Op().I('a', 11)]
        , equals(
            Text.Op().I('x', 10).transform(Text.Op().I('a',10))
        ));
        
        //test.deepEqual [[{i:'x', p:10}], [{d:'a', p:9}]], type.transformX [{i:'x', p:11}], [{d:'a', p:9}]
        expect(
          [Text.Op().I('x', 10), Text.Op().D('a', 9)]
        , equals(
            Text.Op().I('x', 11).transform(Text.Op().D('a',9))
        ));
        
        expect(
          [Text.Op().I('x', 10), Text.Op().D('a', 10)]
        , equals(
          Text.Op().I('x', 11).transform(Text.Op().D('a',10))
        ));
        
        expect(
          [Text.Op().I('x', 11), Text.Op().D('a', 12)]
        , equals(
          Text.Op().I('x', 11).transform(Text.Op().D('a',11))
        ));
        
        expect(
          Text.Op().I('x', 10)
        , equals(
          Text.transform(Text.Op().I('x', 10), Text.Op().D('a',11), left: true)
        ));
        
        expect(
          Text.Op().I('x', 10)
        , equals(
          Text.transform(Text.Op().I('x', 10), Text.Op().D('a',10), left: true)
        ));
        
        expect(
          Text.Op().I('x', 10)
        , equals(
          Text.transform(Text.Op().I('x', 10), Text.Op().D('a',10), right: true)
        ));
        
              
      });
      test('delete', () {
        expect(
          [Text.Op().D('abc', 8), Text.Op().D('xy', 4)]
        , equals(
          Text.Op().D('abc', 10).transform(Text.Op().D('xy', 4))
        ));
        expect(
          [Text.Op().D('ac', 10), Text.Op()]
          , equals(
          Text.Op().D('abc', 10).transform(Text.Op().D('b', 11))
        ));
        expect(
          [Text.Op(), Text.Op().D('ac', 10)]
        , equals(
          Text.Op().D('b', 11).transform(Text.Op().D('abc', 10))
        ));
        expect(
          [Text.Op().D('a', 10), Text.Op()]
        , equals(
          Text.Op().D('abc', 10).transform(Text.Op().D('bc', 11))
        ));
        expect(
          [Text.Op().D('c', 10), Text.Op()]
        , equals(
          Text.Op().D('abc', 10).transform(Text.Op().D('ab', 10))
        ));
        expect(
          [Text.Op().D('a', 10), Text.Op().D('d', 10)]
        , equals(
          Text.Op().D('abc', 10).transform(Text.Op().D('bcd', 11))
        ));
        expect(
          [Text.Op().D('d', 10), Text.Op().D('a', 10)]
        , equals(
          Text.Op().D('bcd', 11).transform(Text.Op().D('abc', 10))
        ));
        expect(
          [Text.Op().D('abc', 10), Text.Op().D('xy', 10)]
        , equals(
          Text.Op().D('abc', 10).transform(Text.Op().D('xy', 13))
        ));
      });
    });
  }
}
