part of share;

class OTJSON extends OTType<Map, JSONOperation>{
  OTJSON() : super("json");

  Map create() => new Map();

  JSONOperation createOp([List components]) {
    return Op(components.map((c) => new JSONOperationComponent.fromMap(c)));
  }

  bool get hasInvert => true;

  JSONOperation Op([List<JSONOperationComponent> components = null]) {
    var op = new JSONOperation();
    if(components != null){
      op._ops = components;
    }
    return op;
  }

  _checkIsString(e) { if ( e is! String ) { throw new Exception("Referenced element not a String (it was ${JSON.stringify(e)})"); } }
  _checkIsObject(e) { if ( e is! Object ) { throw new Exception("Referenced element not an Object (it was ${JSON.stringify(e)})"); } }
  _checkIsList(e) { if ( e is! List ) { throw new Exception("Referenced element not a List (it was ${JSON.stringify(e)})"); } }

  apply(snapshot, JSONOperation op) {

    var container = {"data": snapshot }; // TODO - clone the snapshot

    var i = 0;
    op.forEach((component) {
      var parent = null,
          parentkey = null,
          elem = container,
          key = 'data';
      for (var p in component.path) {
        parent = elem;
        parentkey = key;
        elem = elem[key];
        key = p;

        if (parent == null) {
          throw new Exception('Path invalid');
        }
      }

      switch (component.type) {
        /**
         * STRING OPS
         */
        // TODO - Use OTText
        case JSONOperationComponent.STRING_INSERT:
          _checkIsString(elem);
          int pos = key;
          String str = elem;
          String text = component.data;
          parent[parentkey] = "${str.substring(0, pos)}${text}${str.substring(pos)}";
          break;
        case JSONOperationComponent.STRING_DELETE:
          _checkIsString(elem);
          int pos = key;
          String str = elem;
          String text = component.data;
          if ( text.substring(pos, pos + text.length) != text) {
            throw new Exception("Deleted string does not match");
          }
          parent[parentkey] = "${str.substring(0, pos)}${str.substring(pos + text.length)}";
          break;

        /**
         * OBJECT OPS
         */
        case JSONOperationComponent.OBJECT_INSERT:
          _checkIsObject(elem);

          // Should check that elem[key] == c.od
          elem[key] = component.obj;
          break;
        case JSONOperationComponent.OBJECT_DELETE:
          _checkIsObject(elem);

          // Should check that elem[key] == c.od
          elem.remove(key);
          break;

        /**
         * LIST OPS
         */
        case JSONOperationComponent.LIST_INSERT:
          _checkIsList(elem);
          List list = elem;
          int idx = key;
          list.insertRange(idx, 1, component.data);
          break;
        case JSONOperationComponent.LIST_DELETE:
          _checkIsList(elem);
          List list = elem;
          int idx = key;
          list.removeRange(idx, 1);
          break;
        case JSONOperationComponent.LIST_MOVE:
          _checkIsList(elem);
          List list = elem;
          int idx1 = key;
          int idx2 = component.data;

          if (idx2 != idx1) {
            var e = list[idx1];
            // Remove it...
            list.removeRange(idx1, 1);
            // And insert it back
            list.insertRange(idx2, 1, e);
          }

          break;

        default:
          throw new Exception("Invalid operation component");
      }

      i++;
    });
    return container["data"];
  }
}

class JSONOperation extends Operation<JSONOperationComponent> implements InvertibleOperation<JSONOperation>{

  JSONOperation();

  JSONOperationComponent _SI(String text, int offset, List path) => new JSONOperationComponent.stringInsert(text, offset, path);
  JSONOperationComponent _SD(String text, int offset, List path) => new JSONOperationComponent.stringDelete(text, offset, path);
  JSONOperationComponent _OI(String key, dynamic obj, List path) => new JSONOperationComponent.objectInsert(key, obj, path);
  JSONOperationComponent _OD(String key, dynamic obj, List path) => new JSONOperationComponent.objectDelete(key, obj, path);
  JSONOperationComponent _LI(int index, dynamic obj, List path) => new JSONOperationComponent.listInsert(index, obj, path);
  JSONOperationComponent _LD(int index, dynamic obj, List path) => new JSONOperationComponent.listDelete(index, obj, path);
  JSONOperationComponent _LM(int index1, int index2, List path) => new JSONOperationComponent.listMove(index1, index2, path);

  bool contains(TextOperationComponent) { throw new UnimplementedError(); }

  // Operation builders
  JSONOperation SI(String text, int offset, [List path]) {
    this.add(_SI(text, offset, (path==null)?[]:path ));
    return this;
  }

  JSONOperation SD(String text, int offset, [List path]) {
    this.add(_SD(text, offset, (path==null)?[]:path ));
    return this;
  }

  JSONOperation OI(String key, dynamic obj, [List path]) {
    this.add(_OI(key, obj, (path==null)?[]:path ));
    return this;
  }

  JSONOperation OD(String key, dynamic obj, [List path]) {
    this.add(_OD(key, obj, (path==null)?[]:path ));
    return this;
  }

  JSONOperation OR(String key, dynamic before, dynamic after, [List path]) {
    path = (path==null)?[]:path;
    this.add(_OD(key, before, path));
    this.add(_OI(key, after, path));
    return this;
  }

  JSONOperation LI(int index, dynamic obj, [List path]) {
    this.add(_LI(index, obj, (path==null)?[]:path ));
    return this;
  }

  JSONOperation LD(int index, dynamic obj, [List path]) {
    this.add(_LD(index, obj, (path==null)?[]:path ));
    return this;
  }

  JSONOperation LR(int index, dynamic before, dynamic after, [List path]) {
    path = (path==null)?[]:path;
    this.add(_LD(index, before, path));
    this.add(_LI(index, after, path));
    return this;
  }

  JSONOperation LM(int index1, int index2, [List path]) {
    this.add(_LM(index1, index2, (path==null)?[]:path ));
    return this;
  }

  JSONOperation _newOp() => new JSONOperation();

  JSONOperationComponent invertComponent(JSONOperationComponent c) {
    // TODO
  }

  /** No need to use append for invert, because the components won't be able to
   * cancel with one another. */
  JSONOperation invert() {
   // TODO
  }

  // For simplicity, this version of append does not compress adjacent inserts and deletes of
  // the same text. It would be nice to change that at some stage.
  //append(JSONOperationComponent c) {
   // TODO
  //}

  // This helper method transforms a position by an op component.
  //
  // If c is an insert, insertAfter specifies whether the transform
  // is pushed after the insert (true) or before it (false).
  //
  // insertAfter is optional for deletes.
  transformPosition(int pos, JSONOperationComponent c, [bool insertAfter = false]) {
    // TODO
  }

  int _commonPath(List path1, List path2) {
    var p1 = new List.from(path1);
    var p2 = new List.from(path2);

    if (p2.length == 0) {
      return -1;
    }

    p1.insertRange(0, 1, 'data');
    p2.insertRange(0, 1, 'data');

    p1 = p1.getRange(0, p1.length-1);
    p2 = p2.getRange(0, p2.length-1);

    var i = 0;
    while (i < p1.length && p1[i] == p2[i]) {
      i++;
      if (i == p2.length) {
        return i-1;
      }
    }
    return null;
  }

  _handleStringVsString(JSONOperationComponent c, JSONOperationComponent otherC, int common, {bool left: false, bool right: false}) {

    var Text = OT["text"];

    // Convert an op component to a text op component
    convert(component) {
      var pos = component.path.last;
      if (component.isStringInsert()) {
        return Text.Op()._I(component.text, pos);
      } else {
        return Text.Op()._D(component.text, pos);
      }
    }

    var tc1 = convert(c);
    var tc2 = convert(otherC);

    var textOp = Text.Op();
    textOp.transformComponent(tc1, tc2, left:left, right:right);

    textOp.forEach((tc) {

      var offset = tc.pos;
      var path = c.path.getRange(0, common);
      var text = tc.text;

      if (tc.isInsert()) {
        SI(text, offset, path);
      } else if (tc.isDelete()) {
        SD(text, offset, path);
      }

    });

    return textOp;
  }

  _handleListMoveVsListMove(JSONOperationComponent c, JSONOperationComponent otherC, int common, {bool left: false, bool right: false}) {

    var ListOT = OT["list"];

    // Convert an op component to a text op component
    convert(component) {
      var pos = component.path.last;
      if (component.isListMove()) {
        return ListOT.Op()._M(component.path[common], component.index);
      }
    }

    var lc1 = convert(c);
    var lc2 = convert(otherC);

    ListOperation listOp = ListOT.Op();
    listOp.transformComponent(lc1, lc2, left:left, right:right);

    listOp.forEach((ListOperationComponent lc) {

      var from = lc.from;
      var path = c.path.getRange(0, common);
      var to = lc.to;

      if (lc.isMove()) {
        LM(from, to, path);
      }

    });

    return;
  }

  transformComponent(JSONOperationComponent c, JSONOperationComponent otherC, {bool left: false, bool right: false}) {
    c = c.clone();

    //if (c.type == JSONOperationComponent.NUMBER_ADD) { c.path.add(0); }
    //if (otherC.type == JSONOperationComponent.NUMBER_ADD) { otherC.path.add(0);}

    var common = _commonPath(c.path, otherC.path);
    var common2 = _commonPath(otherC.path, c.path);

    var cplength = c.path.length;
    var otherCplength = otherC.path.length;

    //if (c.type == JSONOperationComponent.NUMBER_ADD) { c.path.removeLast();}
    //if (otherC.type == JSONOperationComponent.NUMBER_ADD) { otherC.path.removeLast();}

    // TODO if (otherC.type == JSONOperationComponent.NUMBER_ADD) {

    if ( (common2 != null) && (otherCplength > cplength) && c.path[common2] == otherC.path[common2]) {
      // transform based on c
      if (c.isListDelete() || c.isObjectDelete() ) {
        var oc = otherC.clone();
        oc.path = oc.path.getRange(cplength, oc.path.length - cplength); // [cplength..]
        var op = _newOp();
        op.add(oc);
        c.data = OT["json"].apply(c.data.clone, op);
      }
    }

    // Nothing in common so no  need to transform
    if (common == null) {
      add(c);
      return;
    }

    // Let's keep going
    cplength = otherCplength;
    var commonOperand = cplength;

    // String op vs string op - pass through to text type
    if ( (otherC.isStringInsert() || otherC.isStringDelete()) &&
         (c.isStringInsert() || c.isStringDelete()) ) {
      if (commonOperand == null) { throw new Exception("must be a string?"); }
      return _handleStringVsString(c, otherC, common, left:left, right:right);
    } // TODO - else if (otherC.isListReplace())
    else if (otherC.isListInsert()) {
      if (c.isListInsert() && commonOperand != null && c.path[common] == otherC.path[common]) {
        // in li vs. li, left wins.
        if (right) {
          c.path[common]++;
        }
      } else if (otherC.path[common] <= c.path[common]){
        c.path[common]++;
      }

      if (c.isListMove()) {
        if (commonOperand != null) {
          // otherC edits the same list we edit
          if (otherC.path[common] <= c.index) {
              c.data++;
          }
          // changing c.from is handled above.
        }
      }
    } else if (otherC.isListDelete()) {
      if (c.isListMove()) {
        if (commonOperand != null) {
          if (otherC.path[common] == c.path[common]) {
            // they deleted the thing we're trying to move
            return;
          }
          // otherC edits the same list we edit
          var p = otherC.path[common];
          var from = c.path[common];
          var to = c.index;
          if ( p < to || (p == to && from < to) ) {
            c.index--;
          }
        }
      }

      if (otherC.path[common] < c.path[common]) {
        c.path[common]--;
      } else if (otherC.path[common] == c.path[common]) {
        if (otherCplength < cplength) {
          // we're below the deleted element, so -> noop
          return;
        } else if (c.isListDelete()){
          //if c.li != undefined
          //  # we're replacing, they're deleting. we become an insert.
          //  delete c.ld
          //else
            // we're trying to delete the same element, -> noop
            return;
        }
      }
    } else if (otherC.isListMove()) {
      if (c.isListMove() && cplength == otherCplength) {
        // lm vs lm, here we go!
        return _handleListMoveVsListMove(c, otherC, common, left: left, right: right);

      /* TODO - else if c.li != undefined and c.ld == undefined and commonOperand
          # li
          from = otherC.p[common]
          to = otherC.lm
          p = c.p[common]
          if p > from
            c.p[common]--
          if p > to
            c.p[common]++ */
      } else {
        // ld, ld+li, si, sd, na, oi, od, oi+od, any li on an element beneath
        // the lm
        //
        // i.e. things care about where their item is after the move.
        int from = otherC.path[common],
            to = otherC.index,
            p = c.path[common];
        if (p == from) {
          c.path[common] = to;
        } else {
          if (p > from) {
            c.path[common]--;
          }
          if (p > to) {
            c.path[common]++;
          } else if (p == to) {
            if (from > to) {
              c.path[common]++;
            }
          }
        }
      }
    // TODO - } else if (otherC.isObjectReplace()) {
    } else if (otherC.isObjectInsert()) {
      // oi vs oi
      if (c.isObjectInsert() && c.path[common] == otherC.path[common]) {
        // left wins if we try to insert at the same place
        if (left) {
          var key = c.path.last;
          var path = c.path.getRange(0, c.path.length - 1);
          OD(key, otherC.obj, path);
        } else {
          return;
        }
      }
    } else if (otherC.isObjectDelete()) {
      if (c.path[common] == otherC.path[common]) {
        if (commonOperand == null) {
          return;
        }
        if (c.isObjectInsert()) {
          // TODO - If is replace keep insert and remove the delete - delete c.od
        } else {
          return;
        }
      }
    }

    // Let's add the component
    add(c);
  }
}

class JSONOperationComponent extends OperationComponent {

  static const String STRING_INSERT = "si";
  static const String STRING_DELETE = "sd";
  static const String OBJECT_INSERT = "oi";
  static const String OBJECT_DELETE = "od";
  static const String LIST_INSERT = "li";
  static const String LIST_DELETE = "ld";
  static const String LIST_MOVE = "lm";

  /** List of strings and ints */
  List path;
  dynamic data;
  String type;

  JSONOperationComponent._internal(this.type, this.path, this.data) {
  }

  /** STRINGS **/
  String get text => data;
  set text(String s) => data = s;

  factory JSONOperationComponent.stringInsert(String text, int offset, List path) {
    path = new List.from(path);
    path.add(offset);
    return new JSONOperationComponent._internal(STRING_INSERT, path, text);
  }

  factory JSONOperationComponent.stringDelete(String text, int offset, List path) {
    path.add(offset);
    return new JSONOperationComponent._internal( STRING_DELETE, path, text);
  }

  /** OBJECTS **/
  dynamic get obj => data;
  set obj(dynamic o) => data = o;

  factory JSONOperationComponent.objectInsert(String key, dynamic obj, List path) {
    path = new List.from(path);
    if (key != null) path.add(key);
    return new JSONOperationComponent._internal( OBJECT_INSERT, path, obj);
  }

  factory JSONOperationComponent.objectDelete(String key, dynamic obj, List path) {
    path = new List.from(path);
    if (key != null) path.add(key);
    return new JSONOperationComponent._internal( OBJECT_DELETE, path, obj);
  }

  /** LISTS **/

  factory JSONOperationComponent.listInsert(int index, dynamic obj, List path) {
    path = new List.from(path);
    path.add(index);
    return new JSONOperationComponent._internal( LIST_INSERT, path, obj);
  }

  factory JSONOperationComponent.listDelete(int index, dynamic obj, List path) {
    path = new List.from(path);
    path.add(index);
    return new JSONOperationComponent._internal( LIST_DELETE, path, obj);
  }

  int get index => data;
  set index(int idx) => data = idx;

  factory JSONOperationComponent.listMove(int index1, int index2, List path) {
    path = new List.from(path);
    path.add(index1);
    return new JSONOperationComponent._internal( LIST_MOVE, path, index2);
  }

  bool isStringInsert() => type == STRING_INSERT;
  bool isStringDelete() => type == STRING_DELETE;
  bool isObjectInsert() => type == OBJECT_INSERT;
  bool isObjectDelete() => type == OBJECT_DELETE;
  bool isListInsert() => type == LIST_INSERT;
  bool isListDelete() => type == LIST_DELETE;
  bool isListMove() => type == LIST_MOVE;

  factory JSONOperationComponent.fromMap(Map m) {
    //var path = m["p"];
    var path = m["p"];
    var data;
    var type;
    
    m.forEach((k, v) {
      if (k == "p") {
        path = v;  
      } else {
        data = m[k];
        type = k;
      }
    });
    
    return new JSONOperationComponent._internal(type, path, data);
  }

  Map toMap() {
    var m = { "p": path };
    var key = type;
    m[key] = data;
    return m;
  }

  clone() {
    return new JSONOperationComponent._internal(type, new List.from(path), data);
  }

  bool operator ==(JSONOperationComponent other) {
    if (other == null) { return false; }
    if (type != other.type) { return false; }
    if (data != other.data) { return false; }

    int n = path.length;
    if (n != other.path.length) {
      return false;
    }
    for (int i = 0; i < n; i++) {
      if (path[i] != other.path[i]) {
        return false;
      }
    }
    return true;
  }
}

