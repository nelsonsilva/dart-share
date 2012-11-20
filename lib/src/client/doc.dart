part of client;

 /** DocEvents:
 *  - remoteop (op)
 *  - changed (op)
 *  - error
 *  - open, closing, closed. 'closing' is not guaranteed to fire before closed.
 **/
class DocEvents extends event.Events {

  get remoteOp => this["remoteOp"];
  get change => this["change"];
  get error => this["error"];
  get open => this["open"];
  get closed => this["closed"];
  get closing => this["closing"];
}

class DocEvent extends event.Event {

  DocEvent() : super("docEvent");
}

class OpEvent extends event.Event {
  static final ID = "op";

  Operation op;
  var snapshot;
  var oldSnapshot;
  OpEvent(this.op, {this.snapshot: null, this.oldSnapshot: null}) : super(ID);
}

/**
 * A Doc is a client's view on a sharejs document.
 *
 * Documents are created by calling Connection.open().
 *
 * Documents are event emitters - use doc.on(eventname, fn) to subscribe.
 *
 * Documents get mixed in with their type's API methods. So, you can .insert('foo', 0) into
 * a text document and stuff like that.
 **/
class Doc implements event.Emitter<DocEvents>{
  Connection connection;
  String name;
  int version;
  var snapshot;

  // Has the document already been created?
  bool create;
  bool created = false;
  String _state = "closed";
  bool _autoOpen = false;

  OpSink _opSink;

  /** Some recent ops, incase submitOp is called with an old op version number. */
  Map _serverOps;

  OTType type;

  DocEvents on;

  Doc(this.connection, this.name, {type: "text", this.version: 0, this.snapshot: null, this.create: false})
    : on = new DocEvents() {

    this.type = OT[type];

    _opSink = new OpSink(connection, this);

    _serverOps = {};
  }

  apply(Operation docOp, [isRemote = false]) {
    var oldSnapshot = snapshot;
    snapshot = type.apply(snapshot, docOp);

    // Its important that these event handlers are called with oldSnapshot.
    // The reason is that the OT type APIs might need to access the snapshots to
    // determine information about the received op.
    on.change.dispatch(new OpEvent(docOp, oldSnapshot: oldSnapshot));
    if (isRemote) {
      on.remoteOp.dispatch(new OpEvent(docOp, oldSnapshot: oldSnapshot));
    }
  }

  _connectionStateChanged(state, data) {
    switch(state) {
      case 'disconnected':
        _state = 'closed';
        on.closed.dispatch();
        break;

      case 'ok': // Might be able to do this when we're connecting... that would save a roundtrip.
        if (_autoOpen) {
          open();
        }
        break;

      //case 'stopped':
      //  if (_openCompleter != null) {
      //    _openCompleter.complete(data);
      //  }
    }
    on[state].dispatch(data);
  }

  /** Open a document. The document starts closed.
   * returns Future<Doc> */
  open() {
    _autoOpen = true;
    if(_state != 'closed') {
      return new Future.immediate(true);
    }

    _state = 'opening';

    var message = new Message(
      doc: name,
      open: true,
      type: type.name,
      version: version,
      create: create,
      snapshot: snapshot
    );

    return connection.send(message)
        .waitFor( (reply) => (reply.open == true))
        .transform( (Message msg) {
            // The document has been successfully opened.
            _state = 'open';
            create = false; // Don't try and create the document again next time open() is called.
            if (!created) {
              created = ( (msg.create != null) && msg.create);
            }

            //@_setType msg.type if msg.type

            if (created) {
              snapshot = type.create();
            } else {
              //_created = false unless @created is true
              if (msg.snapshot != null) {
                snapshot = msg.snapshot;
              }
            }

            if (msg.version != null) {
              version = msg.version;
            }

            on.open.dispatch();

            return this;
          });
  }

  /** Close a document.
   *  returns Future<bool> */
  close() {
    _autoOpen = false;

    if (_state == 'closed') {
      return new Future.immediate(true);
    }

    // Should this happen immediately or when we get open:false back from the server?
    _state = 'closed';

    on.closing.dispatch();

    return connection.send(new Message(doc: name, open:false))
        .waitFor((reply) => reply.open == false)
        .transform((Message msg) {
          // The document has either been closed, or an open request has failed.
          if (msg.error != null) {
            // An error occurred opening the document.
            print("Could not open document: ${msg.error}");
            throw new Exception(msg.error);
            //_openCallback(msg.error);
          }
          _state = 'closed';
          on.closed.dispatch();
          return true;
        });

  }

  /** We got a new op from the server.
   * msg is {doc:, op:, v:} */
  _handleOp(msg) {

    // There is a bug in socket.io (produced on firefox 3.6) which causes messages
    // to be duplicated sometimes.
    // We'll just silently drop subsequent messages.
    //return if msg.v < @version

    if (msg.doc != name) {
      throw new Exception("Expected docName '${name}' but got ${msg.doc}");
    }
    if (msg.version != version) {
      throw new Exception("Expected version ${version} but got ${msg.version}");
    }

    // TODO - try to handle op deserialization before
    var op = type.createOp(msg.op);

    _serverOps[version.toString()] = op;

    var docOp = _opSink.transformServerOp(op);

    version++;
    // Finally, apply the op to @snapshot and trigger any event listeners
    apply(docOp, true);
  }

  _onMessage(Message msg) {
    //console.warn 's->c', msg

    if (msg.op != null) {
      _handleOp(msg);
    } else if (msg.meta != null) {
      //{path, value} = msg.meta

      //switch path?[0]
      //  when 'shout'
      //    return @emit 'shout', value
      //  else
      //    console?.warn 'Unhandled meta op:', msg

    } else {
      print('Unhandled document message: ${msg.toJSON()}');
    }
  }

  /** Submit an op to the server. The op maybe held for a little while before being sent, as only one
   * op can be inflight at any time.
   * returns Future<Operation> */
  submitOp(op) {
    if (op is NormalizableOperation) {
      op = op.normalize();
    }

    // If this throws an exception, no changes should have been made to the doc
    snapshot = type.apply(snapshot, op);

    on.change.dispatch(new OpEvent(op));

    return _opSink.add(op);

  }

}
