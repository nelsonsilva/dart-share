part of client;

class TextDocEvents extends event.Events {
  get insert => this["insert"];
  get delete => this["delete"];
}

class TextOpEvent extends event.Event {
  int pos;
  String text;
  TextOpEvent(this.pos, this.text) : super("textop");
}

class TextDoc implements event.Emitter<TextDocEvents> {
  Doc doc;
  TextDocEvents on;

  TextDoc.adapt(this.doc) : on =  new TextDocEvents() {
    doc.on.remoteOp.add((OpEvent evt) {
      TextOperation op = evt.op;
      op.forEach((c) {
        if (c.isInsert()) {
          on.insert.dispatch(new TextOpEvent(c.pos, c.text));
        } else {
          on.delete.dispatch(new TextOpEvent(c.pos, c.text));
        }
      });
    });
  }

  Future<Operation> insert(int pos, String text) {
    var op = new TextOperation().I(text, pos);
    return doc.submitOp(op);
  }

  Future<Operation> delete(int pos, int length) {
    var op = new TextOperation().D(doc.snapshot.substring(pos, pos + length), pos);
    return doc.submitOp(op);
  }

  /** The number of characters in the string */
  get length => doc.snapshot.length;

  /** Get the text contents of a document */
  get text => doc.snapshot;
}
