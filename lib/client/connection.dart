class ConnectionEvents extends event.Events {
  get disconnected() => this["disconnected"];
  get disconnecting() => this["disconnecting"];
  get connectFailed() => this["connectFailed"];
}

class ConnectionEvent extends event.Event {
  var data;
  ConnectionEvent([this.data, String type = 'connectionEvent']) : super(type);
}

/**
 * allows you to wait for a given message 
 * */
class MessageHandler {
  
  Connection conn;
  var replyHandler;
  
  MessageHandler(this.conn);
  
  Future<Message> waitFor(bool testFn(Message reply)) {
   var completer = new Completer<Message>();
    
   completer.future.handleException((e) {
     print("Exception waiting for message : $e");
   });
    
    replyHandler = (reply) {
      if (testFn(reply)) {
        var idx = conn._messageHandlers.indexOf(replyHandler); 
        if (idx == -1) {
          throw new Exception("Was not waiting for ${reply.toJSON()}");
        }
        conn._messageHandlers.removeRange(idx, 1);
        completer.complete(reply);
        return true;
      }
      return false;
    };
    
    conn._messageHandlers.add(replyHandler);
    
    return completer.future;
  }
}

abstract class Connection implements event.Emitter<ConnectionEvents>{
  String _state;
  bool isConnected;
  String _lastReceivedDoc;
  Map<String, Doc> _docs;
  String _lastSentDoc = null;
  String id; /** clientId */
  int numDocs = 0;
  String origin;
  
  /** List of Future messages we're waiting for */
  List _messageHandlers;
  
  ConnectionEvents on;
  
  Connection() 
    :   on = new ConnectionEvents(),
        _docs = <Doc>{}, 
        _messageHandlers = [];
  
  Future<Connection> connect(String origin) {
    this.origin = origin;
    
    _state = "connecting";
    isConnected = false;
    
    // Setup auth handler
    waitFor((Message msg) => (msg.auth != null) || (msg.auth == null && (msg.error != null)))
    // Handle auth
    .then((Message msg) {
      
      if (msg.auth == null && (msg.error != null)) {
        // Auth failed
        //_lastError = msg.error; // 'forbidden'
        disconnect();
        on.connectFailed.dispatch(new ConnectionEvent(msg.error));
        return ;
      } else if (msg.auth != null) {
        // Got a client id
        id = msg.auth;
        setState('ok');
        return;
      }
    });
    
    var opening = new Completer();
    doConnect(opening);
    return opening.future;
  }
  
  Future<Message> waitFor(bool testFn(Message reply)) => new MessageHandler(this).waitFor(testFn);
  
  /** This will call @socket.onclose(), which in turn will emit the 'disconnected' event. */
  abstract doDisconnect();
  abstract doConnect(Completer<Connection> completer);
  abstract doSend(String msg);
  
  handleOpen(Completer<Connection> completer) {
    isConnected = true;
    completer.complete(this);
  }
  
  handleClose() {
    on.disconnected.dispatch(new ConnectionEvent());
    isConnected = false;
  }
  
  handleMessage(String str) {

    print("s->c($id) ${str}");
    var msg = new Message.fromJSON(str);
    
    // Fill in the docName
    var docName = msg.doc;
    
    if (docName != null) {
      _lastReceivedDoc = docName;
    } else {
      msg.doc = docName = _lastReceivedDoc;
    }
    
    /* check if we're expecting this message 
     * if so this message has already been handled */
    if (_messageHandlers.some((fn) => fn(msg))) {
      return;
    }
    
    // All other messages go to the corresponding doc for handling
    
    if (_docs.containsKey(docName)) {
      _docs[docName]._onMessage(msg);
    } else {
      print("Error: unhandled message $msg");
    }
      
  }

  setState(state, [data]) {
    if (_state == state) {
      return;
    }
    _state = state;
     
    if (state == 'disconnected') {
      id = null;
    }
    
    on[state].dispatch(new ConnectionEvent(data));
    
    // Documents could just subscribe to the state change events, but there's less state to
    // clean up when you close a document if I just notify the doucments directly.
    _docs.forEach( (docName, doc) => doc._connectionStateChanged(state, data));
  }
  
  /**
   * sends the [Message]
   * @returns a MessageHandler instance that allows you to wait for a given message 
   * */
  MessageHandler send(Message data) {
    String docName = data.doc;
  
    if (docName == _lastSentDoc) {
      data.doc = null;
    } else {
      _lastSentDoc = docName;
    }
    
    var str = data.toJSON();
    print('c($id)->s  $str');
    doSend(data.toJSON());
    
    return new MessageHandler(this);
  }
  
  /**
   *  Open a document. It will be created if it doesn't already exist.
   * Callback is passed a document or an error
   * type is either a type name (eg 'text' or 'simple') or the actual type object.
   * Types must be supported by the server.
   * callback(error, doc)
   * */
  Future<Doc> open(String docName, String type) {
    if (_state == 'stopped') {
      throw new Exception('connection closed');
    }

    if (docName == null) {
      throw new Exception('Server-generated random doc names are not currently supported');
    }

    if (_docs.containsKey(docName)) {
      var doc = _docs[docName];
      //if doc.type == type
      return new Future.immediate(doc);
      //else
      //  callback 'Type mismatch', doc
      //return;
    }
    
    var doc = new Doc(this, docName, create:true, type:type);
    
    _docs[docName] = doc;
    var doOpen = doc.open();
    doOpen.handleException((_) => _docs.remove(docName) );
    return doOpen;
  }

  disconnect() => doDisconnect();
  
  get isOk() => _state == "ok";
}
