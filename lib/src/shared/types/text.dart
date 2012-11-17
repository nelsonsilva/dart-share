part of ot;

class OTText extends OTType<String, TextOperation>{
  OTText() : super("text");

  String create() => "";

  TextOperation createOp([List components]) {
    return Op(components.map((c) => new TextOperationComponent.fromMap(c)));
  }

  bool get hasInvert => true;

  TextOperation Op([List<TextOperationComponent> components = null]) {
    var op = new TextOperation();
    if(components != null){
      op._ops = components;
    }
    return op;
  }

  /** Injects s2 in s1 in the pos */
  static _strInject(String s1, num pos, String s2) => "${s1.substring(0, pos)}$s2${s1.substring(pos)}";

  apply(String snapshot, TextOperation op) {
    op.forEach((component) {
      if (component.isInsert()) {
        snapshot = _strInject(snapshot, component.pos, component.text);
      } else {
        var deleted = snapshot.substring(component.pos, (component.pos + component.text.length));
        if (component.text != deleted) {
          throw new Exception("Delete component '${component.text}' does not match deleted text '${deleted}'");
        }
        snapshot = "${snapshot.substring(0, component.pos)}${snapshot.substring(component.pos + component.text.length)}";
      }
    });
    return snapshot;
  }
}

class TextOperation extends Operation<TextOperationComponent> implements InvertibleOperation<TextOperation>{

  TextOperation();

  // TODO - ugly....
  String get oTType => "text";

  bool contains(TextOperationComponent) { throw new UnimplementedError(); }
  
  TextOperationComponent _I(String text, num pos) => new TextOperationComponent.insert(text, pos);
  TextOperationComponent _D(String text, num pos) => new TextOperationComponent.delete(text, pos);

  // Operation builders
  TextOperation I(String text, num pos) {
    this.add(_I(text, pos));
    return this;
  }

  TextOperation D(String text, num pos) {
    this.add(_D(text, pos));
    return this;
  }

  TextOperation _newOp() => new TextOperation();

  TextOperationComponent invertComponent(TextOperationComponent c) {
    if (c.isInsert()) {
      return _D(c.text, c.pos);
    } else {
      return _I(c.text, c.pos);
    }
  }

  /** No need to use append for invert, because the components won't be able to
   * cancel with one another. */
  TextOperation invert() {
    var invOp = _newOp();
    for(var i = length; i >=0; i--) {
      invOp.add(invertComponent(this[i]));
    }
    return invOp;
  }

  // For simplicity, this version of append does not compress adjacent inserts and deletes of
  // the same text. It would be nice to change that at some stage.
  append(TextOperationComponent c) {
    if(isEmpty) {
      add(c);
    } else {
      var lastC = last;

      // Compose the insert into the previous insert if possible
      if( lastC.isInsert() && c.isInsert() && lastC.pos <= c.pos && c.pos <= (lastC.pos + lastC.text.length)) {
        this[length - 1] = _I(OTText._strInject(lastC.text, c.pos - lastC.pos, c.text), lastC.pos);
      } else if(lastC.isDelete() && c.isDelete() && c.pos <= lastC.pos &&  lastC.pos <= (c.pos + c.text.length)) {
        this[length - 1] = _D(OTText._strInject(c.text, lastC.pos - c.pos, lastC.text), c.pos);
      } else {
        add(c);
      }
    }
  }

  // This helper method transforms a position by an op component.
  //
  // If c is an insert, insertAfter specifies whether the transform
  // is pushed after the insert (true) or before it (false).
  //
  // insertAfter is optional for deletes.
  transformPosition(int pos, TextOperationComponent c, [bool insertAfter = false]) {
    if(c.isInsert()) {
      if(c.pos < pos || (c.pos == pos && insertAfter)) {
        return pos + c.text.length;
      } else {
        return pos;
      }
    } else { // Delete
      if(pos <= c.pos) {
        return pos;
      } else if(pos <= c.pos + c.text.length) {
        return c.pos;
      } else {
        return pos - c.text.length;
      }
    }
  }

  handleInsert(TextOperationComponent c, TextOperationComponent otherC, [bool insertAfter = false]) {
    append(_I(c.text, transformPosition(c.pos, otherC, insertAfter)));
  }

  handleDeleteVsInsert(TextOperationComponent c, TextOperationComponent otherC) {
    var s = c.text;
    if(c.pos < otherC.pos) {
      var dPos = Math.min(otherC.pos - c.pos, s.length);
      append(_D(s.substring(0, dPos), c.pos));
      s = s.substring(dPos);
    }
    if(s != '') {
      append(_D(s, c.pos + otherC.text.length));
    }
  }

  handleDeleteVsDelete(TextOperationComponent c, TextOperationComponent otherC) {
    if(c.pos >= otherC.pos + otherC.text.length) {
      append(_D(c.text, c.pos - otherC.text.length));
    } else if(c.pos + c.text.length <= otherC.pos) {
      append(c);
    } else {
      // They overlap somewhere.
      var newC = _D('', c.pos);
      if (c.pos < otherC.pos) {
        newC.text = c.text.substring(0, otherC.pos - c.pos);
      }
      if (c.pos + c.text.length > otherC.pos + otherC.text.length) {
        newC.text = "${newC.text}${c.text.substring(otherC.pos + otherC.text.length - c.pos)}";
      }

      // This is entirely optional - just for a check that the deleted
      // text in the two ops matches
      var intersectStart = Math.max(c.pos, otherC.pos);
      var intersectEnd = Math.min(c.pos + c.text.length, otherC.pos + otherC.text.length);
      var cIntersect = c.text.substring(intersectStart - c.pos, intersectEnd - c.pos);
      var otherIntersect = otherC.text.substring(intersectStart - otherC.pos, intersectEnd - otherC.pos);
      if(cIntersect != otherIntersect) {
        throw new Exception('Delete ops delete different text in the same region of the document');
      }

      if(newC.text != '') {
        // This could be rewritten similarly to insert v delete, above.
        newC.pos = transformPosition(newC.pos, otherC);
        append(newC);
      }
    }
  }
  handleDelete(TextOperationComponent c, TextOperationComponent otherC) {
    if(otherC.isInsert()) { // delete vs insert
      handleDeleteVsInsert(c, otherC);
    } else { // Delete vs delete
      handleDeleteVsDelete(c, otherC);
    }
  }
  transformComponent(TextOperationComponent c, TextOperationComponent otherC, {bool left: false, bool right: false}) {
    if(c.isInsert()){
      handleInsert(c, otherC, right);
    } else { // Delete
      handleDelete(c, otherC);
    }
  }
}

class TextOperationComponent extends OperationComponent {

  static final int INSERT = 1;
  static final int DELETE = 2;

  String text;
  num pos;
  int type;

  TextOperationComponent._internal(this.type, this.text, this.pos) {
    if(pos<0) {
      throw new Exception('position cannot be negative');
    }
  }

  TextOperationComponent.insert(String text, num pos) : this._internal(INSERT, text, pos);
  TextOperationComponent.delete(String text, num pos) : this._internal(DELETE, text, pos);

  bool isInsert() => type == INSERT;
  bool isDelete() => type == DELETE;

  factory TextOperationComponent.fromMap(Map m) {
    var pos = m["p"];
    var key = m.containsKey("i") ? "i" : "d";
    var type = (key == "i") ? INSERT : DELETE;
    return new TextOperationComponent._internal(type, m[key], pos);
  }

  Map toMap() {
    var m = { "p": pos };
    var key = (isInsert())? "i" : "d";
    m[key] = text;
    return m;
  }

  clone() {
    return new TextOperationComponent._internal(type, text, pos);
  }

  bool operator ==(TextOperationComponent other) => other!=null && type == other.type && pos == other.pos && text == other.text;
}

