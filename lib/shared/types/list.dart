class OTList extends OTType<List, ListOperation>{
  OTList() : super("list");
  
  List create() => [];
    
  ListOperation createOp([List components]) {
    return Op(components.map((c) => new ListOperation.fromMap(c)));
  }
  
  bool get hasInvert() => true;
  
  ListOperation Op([List<ListOperationComponent> components = null]) {
    var op = new ListOperation();
    if(components != null){
      op._ops = components;
    }
    return op;
  }
  
  apply(List snapshot, ListOperation op) {
    var list = new List.from(snapshot);
    op.forEach((c) {      
      switch (c.type) {
        case ListOperationComponent.INSERT:   
          list.insertRange(c.index, 1, c.obj);
          break;
        case ListOperationComponent.DELETE:   
          list.removeRange(c.index, 1);
          break;
        case ListOperationComponent.REPLACE:   
          list[c.index] = c.after;
          break;
        case ListOperationComponent.MOVE:   
          if (c.from != c.to) {
            var e = list[c.from];
            // Remove it...
            list.removeRange(c.from, 1);
            // And insert it back
            list.insertRange(c.to, 1, e);
          }
          break;
        default:
          throw new Exception("Invalid operation component");
      }
    });
    return list;
  }
}

class ListOperation extends Operation<ListOperationComponent> implements InvertibleOperation<ListOperation>{
  
  ListOperation();
  
  ListOperationComponent _I(int index, Dynamic obj) => new ListOperationComponent.insert(index, obj);
  ListOperationComponent _D(int index, Dynamic obj) => new ListOperationComponent.delete(index, obj);
  ListOperationComponent _M(int index1, int index2) => new ListOperationComponent.move(index1, index2);
  ListOperationComponent _R(int index, Dynamic before, Dynamic after) => new ListOperationComponent.replace(index, before, after);
  
  // Operation builders
  ListOperation I(int index, Dynamic obj) {
    this.add(_I(index, obj));
    return this;
  }

  ListOperation D(int index, Dynamic obj) {
    this.add(_D(index, obj));
    return this;
  }
  
  ListOperation R(int index, Dynamic before, Dynamic after) {
    this.add(_R(index, before, after));
    return this;
  }
  
  ListOperation M(int index1, int index2) {
    this.add(_M(index1, index2));
    return this;
  }
  
  ListOperation _newOp() => new ListOperation();
  
  ListOperationComponent invertComponent(ListOperationComponent c) {
    // TODO
  }

  /** No need to use append for invert, because the components won't be able to
   * cancel with one another. */
  ListOperation invert() {
   // TODO
  }
  
  // This helper method transforms a position by an op component.
  //
  // If c is an insert, insertAfter specifies whether the transform
  // is pushed after the insert (true) or before it (false).
  //
  // insertAfter is optional for deletes.
  transformPosition(int pos, JSONOperationComponent c, [bool insertAfter = false]) {
    // TODO
  }
  
  _handleListMoveVsListMove(JSONOperationComponent c, JSONOperationComponent other, bool left) {
    int from = c.from,
        to = c.to;
    
    // if otherFrom == otherTo, we don't need to change our op.
    if (other.from == other.to) {
      append(c.clone());
      return;
    }
      
    // where did my thing go?
    if (c.from == other.from) {
      // they moved it! tie break.
      if (left) {
        from = other.o;
        if (c.from == c.to) { // # ugh
          to = other.to;
        }
      } else {
        return;
      }
      
    } else {
      // they moved around it
      if (c.from > other.from) {
        from--;
      }
      if (c.from > other.to) {
        from++;
      } else if (c.from == other.to) {
        if (other.from > other.to) {
          from++;
          if (c.from == c.to) { // ugh, again
            to++;
          }
        }
      }

      // step 2: where am i going to put it?
      if (c.to > other.from) {
        to--;
      } else if (c.to == other.from) {
        if (c.to > c.from) {
          to--;
        }
      }
      if (c.to > other.to) {
        to++;
      } else if (c.to == other.to) {
        // if we're both moving in the same direction, tie break
        if ( (other.to > other.from && c.to > c.from) ||
             (other.to < other.from && c.to < c.from) ) {
          if (!left) {
            to++;
          }
        } else {
          if (c.to > c.from) {
            to++;
          } else if (c.to == other.from) {
            to--;
          }
        }
      }
    }
    
    append(_M(from, to));
  }
  
  _clone(obj) {
    if (obj is String) { return obj; }
    if (obj is List) { return new List.from(obj); }
    return obj.clone();
  }
  
  _handleOtherReplace(ListOperationComponent c, ListOperationComponent otherC, bool left){
    // TODO - Try to remove this clone and create the proper op
    c = c.clone();
    
    if (otherC.index == c.index) {
      if (c.isReplace() && left) {
        // we're both replacing one element with another. only one can
        // survive!
        c.before = otherC.after.clone();
      } else {
        return; // we're trying to delete the same element, -> noop
      }
    }
    
    append(c);
  }
   
  _handleOtherInsert(ListOperationComponent c, ListOperationComponent otherC, bool left){
    
    // TODO - Try to remove this clone and create the proper op
    c = c.clone();
    
    if (c.isInsert() && c.index == otherC.index) {
      // in li vs. li, left wins.
      if (!left) {
        c.index++;
      }
    } else if (otherC.index <= c.index){
      c.index++;
    }
    
    if (c.isMove()) {
      // otherC edits the same list we edit
      if (otherC.index <= c.to) {
          c.to++;
      }
      // changing c.from is handled above.
    }
    
    append(c);
  }
  
  _handleOtherDelete(ListOperationComponent c, ListOperationComponent otherC) {
    // TODO - Try to remove this clone and create the proper op
    c = c.clone();
    
    if (c.isMove()) {
      if (otherC.index == c.from) {
        // they deleted the thing we're trying to move
        return;
      }
      // otherC edits the same list we edit
      var p = otherC.index;
      var from = c.from;
      var to = c.to;
      if ( p < to || (p == to && from < to) ) {
        c.to--;
      }
    }
    
    if (otherC.delete < c.from) {
      c.from--;
    } else if (otherC.index == c.from) {
      if (c.isReplace()){
        // we're replacing, they're deleting. we become an insert.
        append(_I(c.index, c.obj));
        return;
      } else if (c.isDelete()) {
        return; // we're trying to delete the same element, -> noop 
      }
    }
    
    append(c);
  }

  _handleOtherMove(ListOperationComponent c, ListOperationComponent otherC, bool left) {
    if (c.isMove()) {
      // lm vs lm, here we go!
      _handleListMoveVsListMove(c, otherC, left);
    } else if (c.isReplace()) {
      c = c.clone();
      if (c.index > otherC.from) {
        c.index--;
      }
      if (c.index > otherC.to ) {
        c.index++;
      }
      
      append(c);
      
    } else {
      // ld, ld+li, si, sd, na, oi, od, oi+od, any li on an element beneath
      // the lm
      //
      // i.e. things care about where their item is after the move.
      c = c.clone();
      if (c.index == otherC.from) {
        c.index = otherC.to;
      } else {
        if (c.index > otherC.from) {
          c.index--;
        }
        if (c.index > otherC.to) {
          c.index++;
        } else if (c.index == otherC.to) {
          if (otherC.from > otherC.to) {
            c.index++;
          }
        }
      }
      
      append(c);
    }
  }
  
  transformComponent(ListOperationComponent c, ListOperationComponent otherC, [bool left = false, bool right = false]) {
    c = c.clone();
    
    if (otherC.isReplace()) {
      _handleOtherReplace(c, otherC, left:left, right:right);
    } else if (otherC.isInsert()) {
      _handleOtherInsert(); 
    } else if (otherC.isListDelete()) {
      _handleOtherDelete();
    } else if (otherC.isListMove()) {
      _handleOtherMove();
    }   
    // Let's add the component
    add(c);
  }
}

class ListOperationComponent extends OperationComponent {
 
  static final String INSERT = "li";
  static final String DELETE = "ld";
  static final String MOVE = "lm";
  static final String REPLACE = "lr"; // this is li + ld in sharejs
  
  /** This can be 
   *  - an obj for li and ld
   *  - an array [before, after] for a replace
   *  - or an int which is the idx2 for a move */
  Dynamic _data;
  
  int index;
  String type;
  
  ListOperationComponent._internal(this.type, this.index, this._data) {
  }
  
  // li or ld
  Dynamic get obj() => _data;
  set obj(Dynamic o) => _data = o;

  factory ListOperationComponent.insert(int index, Dynamic obj) => 
      new ListOperationComponent._internal( INSERT, index, obj);
  

  factory ListOperationComponent.delete(int index, Dynamic obj) =>
      new ListOperationComponent._internal( DELETE, index, obj);
  
  // lm
  int get from() => index;
  set from(int v) => _data = v;
  int get to() => _data;
  set to(int v) => _data = v;
  
  factory ListOperationComponent.move(int from, int to) => 
      new ListOperationComponent._internal( MOVE, from, to);
  
  // lr
  Dynamic get before() => _data[0];
  set before(Dynamic v) { 
    if (_data == null) { _data = [v, null]; return; }
    _data[0] = v;
  }
    
  Dynamic get after() => _data[1];
  set after(Dynamic v) { 
    if (_data == null) { _data = [null, v]; return; }
    _data[1] = v;
  }
  
  factory ListOperationComponent.replace(int index, Dynamic before, Dynamic after) => 
      new ListOperationComponent._internal( REPLACE, index, [before, after]);
  
  bool isInsert() => type == INSERT;
  bool isDelete() => type == DELETE;
  bool isMove() => type == MOVE;
  bool isReplace() => type == REPLACE;
  
  
  factory ListOperationComponent.fromMap(Map m) {
    // TODO
  }
  
  Map toMap() {
    // TODO
  }
  
  clone() {
    return new ListOperationComponent._internal(type, index, _data);
  }
  
  bool operator ==(ListOperationComponent other) {
      if ((other != null) && 
          (type == other.type) &&
          (index == other.index)) { return true; }
      
      if (_data is List) {
        return (before == other.before && after == other.after);
      } else {
        return (_data == other._data);
      }
  }
  
}

