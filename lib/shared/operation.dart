#library("ot");
#source("types/text.dart");
#source("types/json.dart");

_OT get OT() => new _OT();

class _OT {

  OTType operator [](String type) {
    switch (type) {
      case "text":
        return new OTText();
      case "json":
        return new OTJSON();
      default:
        throw new Exception("Unknown OT type");
    }
  }
}

class OTType<S, O extends Operation> {
  
  final String name;
  
  OTType(this.name);
  
  abstract S create();
  abstract O createOp([List components]);
  
  /** Transforms rightOp by this Op. Returns ['rightOp', clientOp'] **/
  O transform(O leftOp, O rightOp, [bool left = false, bool right = false]) {
    if (!left && !right){
      throw new Exception("type must be 'left' or 'right'");
    }
    if (left) {
      return leftOp.transform(rightOp).left;
    } else {
      return rightOp.transform(leftOp).right;
    }
  }
  
  abstract S apply(S snapshot, O op);
 
  Operation compose(Operation op1, Operation op2) => op1.compose(op2);
}

class Pair<A,B> {
  A left;
  B right;
  Pair(this.left, this.right);
  
  // equality 
  bool operator ==(other) {
   if(other == null){ return false; }
   if(this === other){ return true; }
   if(other is List){ return left == other[0] && right == other[1]; }
   if(other is Pair){ return left == other.left && right == other.right; }
  }
}

class OperationComponent {
  abstract Map toMap();
  abstract clone();
  abstract bool operator ==(OperationComponent other);
}

interface InvertibleOperation<O> {
 O invert();
}

interface NormalizableOperation<O> {
  O normalize();
 }

class Operation<C extends OperationComponent> implements Collection<C> {
  List<C> _ops;
  
  Operation() : _ops = [];
      
  // Override to add and compose if possible
  append(C c) => add(c);
  appendAll(Collection<C> lst) => lst.forEach((l) => append(l));

  Operation<C> compress() => _newOp().compose(this);
      
  Operation compose(Operation op2) {  
    var newOp = clone();
    newOp.appendAll(op2._ops.map((oc) => oc.clone()));
    return newOp;
  }
  
  abstract transformComponent(C c, C otherC, [bool left = false, bool right = false]);
  abstract Operation<C> _newOp();
  
  _transformComponent(OperationComponent left, OperationComponent right, Operation<C> destLeft, Operation<C> destRight) {
    destLeft.transformComponent(left, right, left:true);
    destRight.transformComponent(right, left, right:true);
  }
  
  /** Transforms rightOp by this Op. Returns ['rightOp', clientOp'] **/
  Pair<Operation, Operation> transform(Operation rightOp) {
 
   var leftOp = this;
   var newRightOp = _newOp();
   
   for(var rightComponent in rightOp) {
     // Generate newLeftOp by composing leftOp by rightComponent
     var newLeftOp = _newOp();
  
     var k = 0;
     while(k < leftOp.length) {
       var nextC = _newOp();
       _transformComponent(leftOp[k], rightComponent, newLeftOp, nextC);
       k++;
  
       if(nextC.length == 1) {
         rightComponent = nextC[0];
       } else if(nextC.length == 0) {
         newLeftOp.appendAll(leftOp.subList(k));
         rightComponent = null;
         break;
       } else {
         // Recurse.
           var lr = leftOp.subOp(k).transform(nextC);
           newLeftOp.appendAll(lr.left);
           newLeftOp.appendAll(lr.right);
           rightComponent = null;
           break;
         }
       }
   
       if(rightComponent != null) {
         newRightOp.append(rightComponent);
       }
       leftOp = newLeftOp;
     }
 
   return new Pair(leftOp, newRightOp);
   }
  
  Operation<C> clone() {
    var op = _newOp();
    op._ops.addAll(_ops.map((oc)=>oc.clone()));
    return op;
  }
  
  // Return a new operation with the list of ops starting at start
  Operation<C> subOp(int startIdx) {
    Operation op = _newOp();
    op._ops = this.subList(startIdx);
    return op;
  }

  List<C> subList(int start) => getRange(start, length - start);
  
  // equality 
  bool operator ==(Operation<C> other) {
    if (other == null) { return false; }
    int n = this.length;
    if (n != other.length) {
      return false;
    }
    for (int i = 0; i < n; i++) {
      if (this[i] != other[i]) {
        return false;
      }
    }
    return true;
  }

  
  // delegates for Collection
  Iterator<C> iterator() => _ops.iterator();
  bool isEmpty() => _ops.isEmpty();
  void forEach(void f(C c)) => _ops.forEach(f);
  Collection map(f(C c)) => _ops.map(f);
  Collection<C> filter(bool f(C c)) => _ops.filter(f);
  bool every(bool f(C c)) => _ops.every(f);
  bool some(bool f(C c)) => _ops.some(f);
  int get length() => _ops.length;
  
  // delegates for List
  void add(C c) => _ops.add(c);
  C operator [](int index) => _ops[index];
  void operator []=(int index, C c) { _ops[index] = c; }
  C last() => _ops.last(); 
  List<C> getRange(int start, int length) => _ops.getRange(start, length);
}
