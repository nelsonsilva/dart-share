/**
 * A useragent is assigned to each client when the client connects. The useragent is responsible for making
 * sure all requests are authorized and maintaining document metadata.
 *
 * This is used by all the client frontends to interact with the server.
 * */

typedef void ActionFn();

class Action {
  String name;
  String type;
  ActionFn reject;
  ActionFn accept;
  Map data;
  Action([this.name, this.data]);
}

typedef AuthFn(agent, Action action);

// TODO - Come up with a nice random string generator
var _hatCount = 0;
String hat() => (_hatCount++).toString();

class UserAgent {
  
  Model model; // Doc DAO
  
  AuthFn _auth;
   
  String _sessionId;
  Date _connectTime;
  
  /** This is a map from docName -> listener function */
  Map _listeners;
  
  /** Should be manually set by the auth function. */
  String _name;
  
  UserAgent(this.model, [auth = null])
    : _auth = auth,
      _listeners = {},
      _name = null {
      
    if (_auth == null) {
      
      // By default, accept all connections + data submissions.
      // Don't let anyone delete documents though.
      _auth = (agent, Action action) {
        if(['connect', 'read', 'create', 'update'].indexOf(action.type) != -1) { 
          action.accept();
        } else {
          action.reject();
        }
      };
    }
    _sessionId = hat();
    _connectTime = new Date.now();
    
  }
  
  String get sessionId() => _sessionId;
  
  Future<bool> connect() => doAuth('connect');
  
  /**
   * This is a helper method which wraps auth() above. It creates the action and calls
   * auth. If authentication succeeds, acceptCallback() is called if it exists. otherwise
   * rejectCallback(true) is called.
   *
   * If authentication fails, userCallback('forbidden', null) is called.
   *
   * If supplied, actionData is turned into the action object passed to auth. */
  Future<bool> doAuth(name, [Map actionData = null]) {
    var completer = new Completer();
    var action = new Action(name, data: actionData);
    switch (name) {
      case 'connect': 
        action.type = 'connect';
        break;
      case 'create': 
        action.type = 'create';
        break;
      case 'get snapshot':
      case 'get ops':
      case 'open':
        action.type = 'read';
        break;
      case 'submit op':
        action.type = 'update';
        break;
      case 'submit meta':
        action.type = 'update';
        break;
      case 'delete':
        action.type = 'delete';
        break;
      default:
        throw new Exception("Invalid action name $name");
    }

    action.reject = () {
      throw new Exception('forbidden');
    };
    action.accept = () {
      completer.complete(true);
    };
    
    _auth(this, action);
    
    return completer.future;
  }
  
  disconnect() {
    _listeners.forEach((docName, listener) => model.removeListener(docName, listener));
  }
    
  Future<List> getOps(docName, start, end, callback) =>
      doAuth('get ops',{"docName": docName, "start": start, "end": end}).chain((_) => model.getOps(docName, start, end) );
        

  Future<Doc> getSnapshot(docName) =>
      doAuth('get snapshot').chain((_) => model.getSnapshot(docName));
  
  Future<Doc> create(docName, String type, meta) {
    // We don't check that types[type.name] == type. That might be important at some point.
    OTType otType = OT[type];
  
    // I'm not sure what client-specified metadata should be allowed in the document metadata
    // object. For now, I'm going to ignore all create metadata until I know how it should work.
    meta = new DocMeta();
  
    if (_name != null) {
      meta.creator = _name;
    }
    meta.ctime = meta.mtime = new Date.now();
  
    // The action object has a 'type' property already. Hence the doc type is renamed to 'docType'
    return doAuth('create', {"docName":docName, "docType":type, "meta": meta}).chain( (_) => model.create(docName, otType, meta));
  }
  
  /* return version */
  Future<int> submitOp(String docName, OpEntry opData) {
    if (opData.meta == null) {
      opData.meta = new MessageMeta(source: _sessionId);
    }
    
    //var dupIfSource = opData.dupIfSource || [];
    var dupIfSource = [];
    
    // If ops and meta get coalesced, they should be separated here.
    if (opData.op != null) {
      return doAuth( 'submit op', {"docName": docName, "op":opData.op, "version":opData.version, "meta":opData.meta, "dupIfSource": dupIfSource}) 
      .chain( (_) => model.applyOp(docName, opData) );
    } else {
      return doAuth('submit meta', {"docName":docName, "meta":opData.meta})
          .chain((_) => model.applyMetaOp(docName, opData));
    }
  }
  
  /** Delete the named operation. */
  Future delete(docName) =>
    doAuth('delete', {"docName": docName}).chain((_) =>  model.delete(docName));
  
  /** Open the named document for reading. Just like model.listen, version is optional.
   * returns version */
  Future<Doc> listen(String docName, event.Listener listener, [int version]) {
    
    var authOps;
    
    if (version != null) {
      // If the specified version is older than the current version, we have to also check that the
      // agent is allowed to get ops from the specified version.
      //
      // We _could_ check the version number of the document and then only check getOps if
      // the specified version is old, but an auth check is almost certainly faster than a db roundtrip.
      authOps = doAuth('get ops', {"docName": docName, "start":version, "end":null});
    } else {
      authOps = new Future.immediate(null);
    }

    var authOpen = doAuth( 'open', {"docName": docName, "version":version});
    
    return authOps
        .chain( (_) => authOpen)
        .chain( (_) {
          if (_listeners.containsKey(docName)) {
            throw new Exception('Document is already open'); 
          }
          
          var listenTask = model.listen(docName, version, listener);
          listenTask.then((_) => _listeners[docName] = listener);
          return listenTask;
        });
  }

  removeListener(docName) {
    if (!_listeners.containsKey(docName)) {
      throw new Exception('Document is not open');
    }
    model.removeListener(docName, _listeners[docName]);
    _listeners.remove(docName);
  }
}
