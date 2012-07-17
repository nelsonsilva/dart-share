#library('client');

#import('dart:json');
#import('dart:isolate');

#import('../shared/events.dart', prefix:'event');

#import('../shared/operation.dart');
#source("../shared/types/text_doc.dart");
#source('../shared/message.dart');

#source('op_sink.dart');
#source('doc.dart');
#source('connection.dart');

class Client {
  Map<String, Connection> _connections;
  
  Connection connectionFactory;
  
  Client(this.connectionFactory) : _connections = <Connection>{};
  
  /**
   * */
  Future<Connection> getConnection(String origin) {
    if (origin == null) {
      origin = "${window.location.host}";
    }
    if (_connections.containsKey(origin)){
      return new Future.immediate(_connections[origin]);
    }
    
    var doConnect = connectionFactory.connect(origin);
    
    doConnect.then((c) {
      var del = (_) => _connections.remove(origin);
      c.on.disconnecting.add(del);
      c.on.connectFailed.add(del);
      _connections[origin] = c;
    });
    return doConnect;
  }
  
  /** If you're using the bare API, connections are cleaned up as soon as there's no
   * documents using them. */
  maybeClose(c) {
    var numDocs = 0;
    c._docs.forEach((name,doc) {
      if (doc.state != 'closed' || doc.autoOpen) {
        numDocs++ ;
      }
    });
    if (numDocs == 0) {
      c.disconnect();
    }
  }
      
  Future<Doc> open(docName, type, [String origin = null]) {
    var completer = new Completer();
    
    return getConnection(origin)
        .chain((c) { 
          c.numDocs++;
          var doOpen = c.open(docName, type);
          doOpen.handleException((e) => maybeClose(c) );
          doOpen.then((doc) => doc.on.closed.add((e) => maybeClose(c)));
          return doOpen;
         });
  }
}
