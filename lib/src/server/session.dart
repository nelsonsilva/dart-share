part of server;

class SessionDocEntry {
  SyncQueue queue;
  var listener;
}

class Session {
  UserAgent agent;
  Connection connection;

  Model model;

  /** temporary handler that buffers the messages */
  var _bufferMessage;
  List<Message> _buffer;

  /** This is set when the session is authenticated. */
  bool _connected = false;

  // To save on network traffic, the agent & server can leave out the docName with each message to mean
  // 'same as the last message'
  String _lastSentDoc = null;
  String _lastReceivedDoc = null;

  // Map from docName -> {queue, listener if open}
  Map<String, SessionDocEntry> _docState;

  Session(this.connection, this.model)
    : _buffer = [] {

     _docState = new Map<String, SessionDocEntry>();

    _bufferMessage = (ConnectionEvent evt) => _buffer.add(evt.msg);

    connection.on.message.add(_bufferMessage);

    agent = new UserAgent(model);

    // Check if we're allowed to connect
    var connect = agent.connect();
    connect.handleException((Exception e) {
      connection.send(new Message(auth: null, error: e.toString()));
      connection.stop();
    });
    connect.then( (_) {
      _connected = true;

      connection.send(new Message(auth: agent.sessionId));

      // Ok. Now we can handle all the messages in the buffer. They'll go straight to
      // handleMessage from now on.
      connection.on.message.remove(_bufferMessage);

      // Handle buffered messages
      _buffer.forEach( _handleMessage );
      _buffer = null;

      // setup the default message handler
      connection.on.message.add((ConnectionEvent evt) => _handleMessage(evt.msg));

    });

    connection.on.close.add( (evt) {
      if(!_connected) {
        return;
      }
      _connected = false;

      _docState.forEach((docName,entry) {

        entry.queue.clear();

        if (entry.listener != null) {
          agent.removeListener(docName);
        }
      });

      _docState.clear();
    });
  }

  // We'll only handle one message from each client at a time.
  _handleMessage(Message msg) {

    var error = null;
    if (msg.doc == null &&  _lastReceivedDoc == null ) {
      error = 'Invalid docName';
    }
    if (msg.create != null && !msg.create) {
      error = "'create' must be true or missing";
    }
    // error = "'open' must be true, false or missing" unless query.open in [true, false, undefined]
    if (msg.snapshot != null ) {
      error = "'snapshot' must be null or missing";
    }
    //error = "'type' invalid" unless query.type is undefined or typeof query.type is 'string'
    if (msg.version != null && msg.version < 0) {
      error = "'v' invalid";
    }

    if (error != null) {
      connection.abort();
      throw new Exception("Invalid query ${msg} from #{agent.sessionId}: #{error}");
    }

    // The agent can specify null as the docName to get a random doc name.
    if (msg.doc == null && _lastReceivedDoc == null) {
      msg.doc = _lastReceivedDoc = hat();
    } else if (msg.doc != null){
      _lastReceivedDoc = msg.doc;
    } else {
      msg.doc = _lastReceivedDoc;
    }

    _docState.putIfAbsent(msg.doc, () {
      var entry = new SessionDocEntry();
      entry.queue = new SyncQueue( (query, callback) {
          // When the session is closed, we'll nuke docState. When that happens, no more messages
          // should be handled.
          if (_docState == null) {
            return callback();
          }

          Future task;

          // Close messages are {open:false}
          if (query.open == false) {
           task = handleClose(query);

          // Open messages are {open:true}. There's a lot of shared logic with getting snapshots
          // and creating documents. These operations can be done together; and I'll handle them
          // together.

          } else if ( (query.open == true) || (query.snapshot == true) || (query.create == true) ) {
            // You can open, request a snapshot and create all in the same
            // request. They're all handled together.
            task = handleOpenCreateSnapshot(query);


          //# The socket is submitting an op.
          } else if (query.op != null || (query.meta != null && query.meta.path  != null )) {
            // TODO(nelsonsilva) - find another way to create the proper Operation type
            // the original sharejs code did not load the document here
            task = model.load(query.doc).chain( (doc) {
              var op = doc.type.createOp(query.op);
              query.op = op;

              return handleOp(query);
            });

          } else {
            print("Invalid query $query from ${agent.sessionId}");
            connection.abort();
            callback();
          }

          // Handle task errors and result
          task.handleException((e) => callback(e));
          task.then((_) => callback(null));

        });
      return entry;
    });

    // ... And add the message to the queue.
    _docState[msg.doc].queue.push(msg);
  }

  /**
   * Send a message to the socket.
   * msg _must_ have the doc:DOCNAME property set. We'll remove it if its the same as lastReceivedDoc. */
  send(Message response) {
    if (response.doc == _lastSentDoc) {
      response.doc = null;
    } else {
      _lastSentDoc = response.doc;
    }
    // Its invalid to send a message to a closed session. We'll silently drop messages if the
    // session has closed.
    if (connection.ready) {
      var str = response.toJSON();
      print('s->c(${agent.sessionId}) $str');
      connection.send(response);
    }
  }

  /** Open the given document name, at the requested version.
   * returns version */
  Future<int> open(String docName, int version) {
    if (_docState == null) {
      throw new Exception('Session closed');
    }
    if (_docState[docName].listener != null) {
      throw new Exception('Document already open');
    }

    var listener;

    listener = (evt) {
      var opData = evt.data;

      if (_docState[docName].listener != listener) {
        // TODO - Ensure listeners are removed when client disconnects
        print('Consistency violation - doc listener invalid');
        return;
      }

      // Skip the op if this socket sent it.
      if (opData.meta.source == agent.sessionId) {
        return;
      }

      var opMsg = new Message(
        doc: docName,
        op: opData.op,
        version: opData.version,
        meta: opData.meta);

      send(opMsg);
    };


    // Tell the socket the doc is open at the requested version
    _docState[docName].listener = listener;
    var listenTask = agent.listen(docName, listener, version);
    listenTask.then((Doc doc) {
      if (version != null) {
        // Send the existing ops to the listener
        model.dispatchOps(docName, doc, listener);
      }
    });
    return listenTask.transform((Doc doc) => doc.version);
  }

  /** Close the named document.
   * callback([error]) */
  close(docName) {
    if (_docState == null) {
      throw new Exception('Session closed');
    }
    var listener = _docState[docName].listener;
    if (listener == null) {
      throw new Exception('Doc already closed');
    }

    agent.removeListener(docName);
    _docState[docName].listener = null;
  }

  /** Handles messages with any combination of the open:true, create:true and snapshot:null parameters
   * return version **/
  Future<int> handleOpenCreateSnapshot(query) {
    var docName = query.doc;

    var msg = new Message(doc:docName);

    if (query.doc == null) {
      throw new Exception('No docName specified');
    }

    if (query.create == true) {
      if (query.type == null) {
        throw new Exception('create:true requires type specified');
      }
    }

    // This is implemented with a series of cascading methods for each different type of
    // thing this method can handle. This would be so much nicer with an async library. Welcome to
    // callback hell.

    var step1Create = (Doc docData) {

      if(query.create != true) {
        return new Future.immediate(null);
      }

      // The document obviously already exists if we have a snapshot.
      if (docData != null) {
        msg.create = false;
        return new Future.immediate(docData);
      }

      var createTask = agent.create(docName, query.type, query.meta);
      createTask.then((doc) {
        /*
        // TODO - Make this error a const
        if (error == 'Document already exists') {
           // We've called getSnapshot (-> null), then create (-> already exists). Its possible
           // another agent has called create() between our getSnapshot and create() calls.
          agent.getSnapshot(docName, (error, data) {
            if (error != null) {
              throw new Exception(error);
            }

            docData = data;
            msg.create = false;
            completer.complete(null);
          });
        } else if (error != null) {

          throw new Exception(error);

        } else {*/
          msg.create = true;
        //}
      });
      return createTask;
    };

    // The socket requested a document snapshot
    var step2Snapshot = (Doc docData) {

      // Skip inserting a snapshot if the document was just created.
      if ( (query.snapshot != null) || (msg.create == true) ) {

      } else {
        if (docData != null) {
          msg.version = docData.version;
          //msg.type = docData.type.name unless query.type == docData.type.name
          msg.snapshot = docData.snapshot;
        } else {
          throw new Exception('Document does not exist');
          return;
        }
      }
      return new Future.immediate(docData);
    };

    // Attempt to open a document with a given name. Version is optional.
    // callback(opened at version) or callback(null, errormessage)
    var step3Open = (Doc docData) {

      if (query.open != true) {
        return new Future.immediate(docData);
      }

      // Verify the type matches
      //return callback 'Type mismatch' if query.type and docData and query.type != docData.type.name

      var openTask = open(docName, query.version);
      openTask.then((version) {
        msg.open = true;
        msg.version = version;
      });
      return openTask;

    };

    // Technically, we don't need a snapshot if the user called create but not open or createSnapshot,
    // but no clients do that yet anyway.
    var getSnapshotTask;
    if (query.snapshot == null || query.open == true) { //and query.type
      getSnapshotTask = agent.getSnapshot(query.doc);
    } else {
      getSnapshotTask = new Future.immediate(null);
    }
    var createChain = getSnapshotTask
        .chain(step1Create)
        .chain(step2Snapshot)
        .chain(step3Open);

    createChain.handleException((error) {
      if (error != null) {
        if (msg.open == true) { close(docName); }
        if (query.open == true) {msg.open = false; }
        if (query.snapshot != null) { msg.snapshot = null; }
        msg.create = null;
        msg.error = error;
      }
    });

    createChain.then( (version) {
        send(msg);
    });

    return createChain;
  }

  /** The socket closes a document */
  Future<bool> handleClose(query) {
    var completer = new Completer<bool>();
    try {
      close(query.doc);
    } on Exception catch (error) {
      // An error closing still results in the doc being closed.
      send(new Message(doc:query.doc, open:false, error:error.toString()));
      completer.complete(false);
    }
    send(new Message(doc:query.doc, open:false));
    completer.complete(true);

    return completer.future;
  }

  /** We received an op from the socket
   * return version */
  Future<int> handleOp(Message query) {
    // ...
    //throw new Error 'No version specified' unless query.v?

    var opData = new OpEntry(version:query.version, op:query.op, meta:query.meta);//, dupIfSource:query.dupIfSource);

    var doSubmitOp = agent.submitOp(query.doc, opData);

    // If it's a metaOp don't send a response
    if (opData.op == null && opData.meta != null && opData.meta.path != null ) {

    } else {
      doSubmitOp.handleException((e) => send(new Message(doc:query.doc, version:null, error:e.toString())));
      doSubmitOp.then( (appliedVersion) => send(new Message(doc:query.doc, version:appliedVersion)));
    }
    return doSubmitOp;
  }

}

