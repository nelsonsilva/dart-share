part of html_demo;

class SharedTextArea {
  TextAreaElement elem;
  share.TextDoc doc;

  String _prevValue;

  SharedTextArea(share.Doc d, this.elem) : doc = new share.TextDoc.adapt(d){
    elem.value = doc.text;
    _prevValue = elem.value;

    // Add listener to the text area
    TextAreaElement e;
    ['textInput', 'keydown', 'keyup', 'select', 'cut', 'paste'].forEach((evt) {
      elem.on[evt].add(genOp, false);
    });

    // Add listeners to the doc
    doc.on.insert.add((share.TextOpEvent op){
      var transformCursor = (cursor) {
        if (op.pos < cursor) {
          return cursor + op.text.length;
        } else {
          return cursor;
        }
      };
      //for IE8 and Opera that replace \n with \r\n.
      _prevValue = elem.value; //prevvalue = elem.value.replace /\r\n/g, '\n'

      replaceText("${_prevValue.substring(0, op.pos)}${op.text}${_prevValue.substring(op.pos)}", transformCursor);
    });

    doc.on.delete.add((share.TextOpEvent op){
      var transformCursor = (cursor) {
        if (op.pos < cursor) {
          return cursor - Math.min(op.text.length, cursor - op.pos);
        } else {
          return cursor;
        }
      };
      //for IE8 and Opera that replace \n with \r\n.
      _prevValue = elem.value; //prevvalue = elem.value.replace /\r\n/g, '\n'
      replaceText("${_prevValue.substring(0, op.pos)}${_prevValue.substring(op.pos + op.text.length)}", transformCursor);
    });

  }

  replaceText(newText, transformCursor) {
    var newSelectionStart = transformCursor(elem.selectionStart),
        newSelectionEnd = transformCursor(elem.selectionEnd);

    elem.value = newText;

    elem.selectionStart = newSelectionStart;
    elem.selectionEnd = newSelectionEnd;
  }

  genOp(event) {
    //var onNextTick = (fn) => new Timer(0, (Timer time) => fn());
    //onNextTick( () {
      if (elem.value != _prevValue) {
        // IE constantly replaces unix newlines with \r\n. ShareJS docs
        // should only have unix newlines.
        try {
          applyChange(doc.text, elem.value); //elem.value.replace /\r\n/g, '\n'
          _prevValue = elem.value;
        } catch (e) {
          print("[SharedTextArea] $e");
          elem.value = _prevValue; // reset the text area to the original state
        }
      }
    //});
  }

  /** Create an op which converts oldval -> newval.
   *
   * This function should be called every time the text element is changed. Because changes are
   * always localised, the diffing is quite easy.
   *
   * This algorithm is O(N), but I suspect you could speed it up somehow using regular expressions. */
  applyChange(String oldval, String newval) {
    if (oldval == newval) { return; }
    var commonStart = 0;

    // seek first diff pos
    while( (oldval.length > commonStart) && (newval.length > commonStart)
        && (oldval[commonStart] == newval[commonStart]) ) {
      commonStart++;
    }

    var commonEnd = 0;

    // seek last diff pos
    while (
        (commonEnd + commonStart < oldval.length) && ( commonEnd + commonStart < newval.length) &&
        ( oldval[oldval.length - 1 - commonEnd] == newval[newval.length - 1 - commonEnd] ) ) {
      commonEnd++;
    }

    if (oldval.length != (commonStart + commonEnd)) {
      doc.delete(commonStart, oldval.length - commonStart - commonEnd);
    }

    if (newval.length != commonStart + commonEnd) {
      doc.insert(commonStart, newval.substring(commonStart, newval.length - commonEnd));
    }
  }
}
