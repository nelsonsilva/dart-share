part of client;

class OpSink {
  /** The auth ids which the client has previously used to attempt to send inflightOp.
   * This is usually empty. */
  List _inflightSubmittedIds;

  Operation _inflightOp = null;
  var _inflightCallbacks; // List<Completer<Operation>>

  /** All ops that are waiting for the server to acknowledge inflightOp */
  Operation _pendingOp = null;
  var _pendingCallbacks; // List<Completer<Operation>>

  var doc;//Doc doc;
  var connection; //Connection connection;

  OpSink(this.connection, this.doc)
      :   _inflightCallbacks = [],
          _pendingCallbacks = [],
          _inflightSubmittedIds = [] {

      doc.on.open.add((_) {
        if (hasInFlightOp) {
          _handleReconnect();
        } else {
          flush();
        }
      });

      doc.on.closed.add((_){
        // This is used by the server to make sure that when an op is resubmitted it
        // doesn't end up getting applied twice.
        if (_inflightOp != null) {
          _inflightSubmittedIds.add(connection.id);
        }
      });
  }

  // Future<Operation>
  add(Operation op) {
    if (_pendingOp != null) {
      _pendingOp = doc.type.compose(_pendingOp, op);
    } else {
      _pendingOp = op;
    }

    var completer = new Completer();
    _pendingCallbacks.add(completer);


    // A timeout is used so if the user sends multiple ops at the same time, they'll be composed
    // & sent together.
    new Timer(0, (Timer timer) => flush() );

    return completer.future;
  }

  get hasInFlightOp => _inflightOp != null;


  /** Send ops to the server, if appropriate.
   *
   * Only one op can be in-flight at a time, so if an op is already on its way then
   * this method does nothing. */
  flush() {
    if ( !(connection.isOk && (_inflightOp == null) && (_pendingOp != null) ) ) {
      return;
    }

    // Rotate null -> pending -> inflight
    _inflightOp = _pendingOp;
    _inflightCallbacks = _pendingCallbacks;

    _pendingOp = null;
    _pendingCallbacks = [];

    sendNextOp();
  }

  sendNextOp() =>
      connection.send( new Message(doc:doc.name, op:_inflightOp, version:doc.version) )
        // Wait for the aknowledge
        .waitFor((reply) =>
            (reply.op == null && reply.version != null) ||
            ((reply.op != null) && (reply.meta != null) && (_inflightSubmittedIds.indexOf(reply.meta.source) != -1)))
        .then((Message msg) {
          // Our inflight op has been acknowledged.
          var oldInflightOp = _inflightOp;
          _inflightOp = null;
          _inflightSubmittedIds.length = 0;

          var error = msg.error;
          if (error != null) {
            // The server has rejected an op from the client for some reason.
            // We'll send the error message to the user and roll back the change.
            //
            // If the server isn't going to allow edits anyway, we should probably
            // figure out some way to flag that (readonly:true in the open request?)

            if (oldInflightOp is InvertibleOperation) {
              var undo = oldInflightOp.invert();

              // Now we have to transform the undo operation by any server ops & pending ops
              if (_pendingOp != null) {
                var pair = _xf(_pendingOp, undo);
                _pendingOp = pair.left;
                undo = pair.right;
              }
              // ... and apply it locally, reverting the changes.
              //
              // This call will also call @emit 'remoteop'. I'm still not 100% sure about this
              // functionality, because its really a local op. Basically, the problem is that
              // if the client's op is rejected by the server, the editor window should update
              // to reflect the undo.
              doc.apply(undo, true);
            } else {
              throw new Exception("Op apply failed (${error}) and the op could not be reverted");
            }

            _inflightCallbacks.forEach( (c) => c.complete(null));

          } else {
            // The op applied successfully.
            if (msg.version != doc.version) {
              throw new Exception('Invalid version from server');
            }

            //_serverOps[version.toString()] = oldInflightOp;
            doc.version++;

            // TODO - notify the proper completer!
            _inflightCallbacks.forEach((c)=>c.complete(oldInflightOp));
          }

          // Send the next op.
          flush();
        });

  /** handles a new server op
   * transforms the pending and inflight op
   * return the new op */
  Operation transformServerOp(Operation op) {
    var docOp = op;
    if (_inflightOp != null) {
      var pair = _xf(_inflightOp, op);
      _inflightOp = pair.left;
      docOp = pair.right;
    }
    if (_pendingOp != null) {
      var pair = _xf(_pendingOp, op);
      _pendingOp = pair.left;
      docOp = pair.right;
    }
    return docOp;
  }


  /** Transform a server op by a client op, and vice versa. **/
  // Pair<Operation, Operation>
  _xf(Operation client, Operation server) => client.transform(server);

  /** Resend any previously queued operation.
   * return a bool indicating if this is a reconnect */
  _handleReconnect() {
    var response = new Message(
      doc: doc.name,
      op: _inflightOp,
      version: doc.version
    );
    if (!_inflightSubmittedIds.isEmpty) {
      // response.dupIfSource = _inflightSubmittedIds;
    }
    connection.send(response);

  }
}
