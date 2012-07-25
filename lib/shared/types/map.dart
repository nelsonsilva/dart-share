class OTMap extends OTType<Map, MapOperation>{
  OTMap() : super("map");
  
  Object create() => {};
    
  MapOperation createOp([List components]) {
    return Op(components.map((c) => new MapOperation.fromMap(c)));
  }
  
  bool get hasInvert() => true;
  
  MapOperation Op([List<MapOperationComponent> components = null]) {
    var op = new MapOperation();
    if(components != null){
      op._ops = components;
    }
    return op;
  }
  
  apply(Map snapshot, MapOperation op) {
    var map = new Map.from(snapshot);
    op.forEach((c) {
      switch (c.type) {
        case MapOperationComponent.INSERT:
          // Should check that elem[key] == c.od
          map[c.key] = c.obj;
          break;
        case MapOperationComponent.DELETE:   
           // Should check that elem[key] == c.od
          map.remove(c.key);
          break;
        case MapOperationComponent.REPLACE:
          // TODO - Should check that map[c.key] == c.before
          map[c.key] = c.after;
          break;
        default:
          throw new Exception("Invalid operation component");
      }
    });
    return map;
  }
}

class MapOperation extends Operation<MapOperationComponent> implements InvertibleOperation<MapOperation>{
  
  MapOperation();
  
  MapOperationComponent _I(String key, Dynamic obj) => new MapOperationComponent.insert(key, obj);
  MapOperationComponent _D(String key, Dynamic obj) => new MapOperationComponent.delete(key, obj);
  MapOperationComponent _R(String key, Dynamic before, Dynamic after) => new MapOperationComponent.replace(key, before, after);
  
  // Operation builders
  MapOperation I(String key, Dynamic obj) {
    this.add(_I(key, obj));
    return this;
  }

  JSONOperation D(String key, Dynamic obj) {
    this.add(_D(key, obj));
    return this;
  }
  
  JSONOperation R(String key, Dynamic before, Dynamic after) {
    this.add(_R(key, before, after));
    return this;
  }
    
  MapOperation _newOp() => new MapOperation();
  
  MapOperationComponent invertComponent(MapOperationComponent c) {
    // TODO
  }

  /** No need to use append for invert, because the components won't be able to
   * cancel with one another. */
  MapOperation invert() {
   // TODO
  }

  _handleOtherReplace(JSONOperationComponent c, JSONOperationComponent otherC, bool left) {
    
    c = c.clone();
    
    if (c.key == otherC.key) {
      if (c.isInsert()) {
       // we inserted where someone else replaced
        if(!left) {
          // left wins
          return;
        } else {
          // we win, make our op replace what they inserted
          c.obj = otherC.obj;
        }
      } else {
        // -> noop if the other component is deleting the same object (or any
        // parent)
        return;
      }
    }
    append(c);
  }
  
  _handleOtherInsert(c, otherC, left) {
    // oi vs oi
    if (c.isObjectInsert() && c.key == otherC.key) {
      // left wins if we try to insert at the same place
      if (left) {
        append(OD(c.key, otherC.obj));
      } else {
        return;
      }
    }
    
    append(c.clone());
  }
  
                
  transformComponent(JSONOperationComponent c, JSONOperationComponent otherC, [bool left = false, bool right = false]) {
    c = c.clone();
    
    if (otherC.isReplace()) {
      _handleOtherReplace(c, otherC, left);
    } else if (otherC.isInsert()) {
      _handleOtherInsert(c, otherC, left);
    } else if (otherC.isDelete()) {
      if (c.key == otherC.key) {
        if (c.isObjectReplace()) {
          append(_I(c.key, c.after));
          return
        
        } else {
          return;
        }
      }
    } else if (otherC.isReplace()) {
     
    }
    
    // Let's add the component
    add(c);
  }
}

class JSONOperationComponent extends OperationComponent {
  
  static final String STRING_INSERT = "si";
  static final String STRING_DELETE = "sd";
  static final String OBJECT_INSERT = "oi";
  static final String OBJECT_DELETE = "od";
  static final String LIST_INSERT = "li";
  static final String LIST_DELETE = "ld";
  static final String LIST_MOVE = "lm";
  
  /** List of strings and ints */
  List path;
  Dynamic data;
  String type;
  
  JSONOperationComponent._internal(this.type, this.path, this.data) {
  }
  
  /** STRINGS **/
  String get text() => data;
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
  Dynamic get obj() => data;
  set obj(Dynamic o) => data = o;
  
  factory JSONOperationComponent.objectInsert(String key, Dynamic obj, List path) {
    path = new List.from(path);
    path.add(key);
    return new JSONOperationComponent._internal( OBJECT_INSERT, path, obj);
  }

  factory JSONOperationComponent.objectDelete(String key, Dynamic obj, List path) {
    path = new List.from(path);
    path.add(key);
    return new JSONOperationComponent._internal( OBJECT_DELETE, path, obj);
  }
  
  /** LISTS **/
  
  factory JSONOperationComponent.listInsert(int index, Dynamic obj, List path) {
    path = new List.from(path);
    path.add(index);
    return new JSONOperationComponent._internal( LIST_INSERT, path, obj);
  }

  factory JSONOperationComponent.listDelete(int index, Dynamic obj, List path) {
    path = new List.from(path);
    path.add(index);
    return new JSONOperationComponent._internal( LIST_DELETE, path, obj);
  }
  
  int get index() => data;
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
    var path = m["p"];
    var key = m.containsKey("i") ? "i" : "d";
    var type = (key == "i") ? INSERT : STRING_DELETE;
    return new JSONOperationComponent._internal(type, m[key], pos);
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

