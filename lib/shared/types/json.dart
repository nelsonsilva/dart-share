class OTJSON extends OTType<Object, JSONOperation>{
  OTJSON() : super("json");
  
  Object create() => new Dynamic();
    
  JSONOperation createOp([List components]) {
    return Op(components.map((c) => new JSONOperation.fromMap(c)));
  }
  
  bool get hasInvert() => true;
  
  JSONOperation Op([List<JSONOperationComponent> components = null]) {
    var op = new JSONOperation();
    if(components != null){
      op._ops = components;
    }
    return op;
  }
  
  
  apply(Object snapshot, JSONOperation op) {
    
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

        // TODO - Use OTText
        case JSONOperationComponent.STRING_INSERT:
          if ( elem is! String ) {
            throw new Exception("Referenced element not a string (it was ${JSON.stringify(elem)})");
          }
          int pos = key;
          String str = elem;
          String text = component.data;
          parent[parentkey] = "${str.substring(0, pos)}${text}${str.substring(pos)}";
          break;
        case JSONOperationComponent.STRING_DELETE:
          if ( elem.data is! String ) {
            throw new Exception("Referenced element not a string (it was ${JSON.stringify(elem)})");
          }
          int pos = key;
          String str = elem;
          String text = component.data;
          if ( text.substring(pos, pos + text.length) != text) {
            throw new Exception("Deleted string does not match");
          }
          parent[parentkey] = "${str.substring(0, pos)}${str.substring(pos + text.length)}";
          break;
      }
      
      i++;
    });
    return snapshot;
  }
}

class JSONOperation extends Operation<JSONOperationComponent> implements InvertibleOperation<JSONOperation>{
  
  JSONOperation();
  
  JSONOperation _SI(String text, List path) => new JSONOperationComponent.stringInsert(text, path);
  JSONOperation _SD(String text, List path) => new JSONOperationComponent.stringDelete(text, path);
  
  // Operation builders
  JSONOperation SI(String text, List path) {
    this.add(_SI(text, path));
    return this;
  }
  
  JSONOperation SD(String text, List path) {
    this.add(_SD(text, path));
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
  append(JSONOperationComponent c) {
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
  
  transformComponent(JSONOperationComponent c, JSONOperationComponent otherC, [bool left = false, bool right = false]) {
   // TODO
  }
}

class JSONOperationComponent extends OperationComponent {
  
  static final int STRING_INSERT = 1;
  static final int STRING_DELETE = 2;
  
  /** List of strings and ints */
  List path;
  var data;
  int type;
  
  JSONOperationComponent._internal(this.type, this.path, this.data) {
  }
  
  factory JSONOperationComponent.stringInsert(String text, List path, [int offset]) {
    
    if (offset != null) {
      path.add(offset);
    }

    return new JSONOperationComponent._internal(STRING_INSERT, path, text);
  }
  
  factory JSONOperationComponent.stringDelete(String text, List path, [int offset]) {
    if (offset != null) {
      path.add(offset);
    }
    return new JSONOperationComponent._internal( STRING_DELETE, path, text);
  }
  
  bool isInsertString() => type == STRING_INSERT;
  bool isDeleteString() => type == STRING_DELETE;
  
  factory JSONOperationComponent.fromMap(Map m) {
    var path = m["p"];
    var key = m.containsKey("i") ? "i" : "d";
    var type = (key == "i") ? INSERT : STRING_DELETE;
    return new JSONOperationComponent._internal(type, m[key], pos);
  }
  
  Map toMap() {
    var m = { "p": pos };
    var key = (isInsert())? "i" : "d";
    m[key] = text;
    return m;
  }
  
  bool operator ==(JSONOperationComponent other) => other!=null && type == other.type && pos == other.pos && text == other.text;
}

