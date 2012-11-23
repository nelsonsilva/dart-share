part of server;

class SockJSConnection extends Connection {
  sockjs.SockJSConnection conn;

  SockJSConnection(this.conn) : super() {

    conn.on.data.add((msg) {
      print("c->s $msg");
      on.message.dispatch( new ConnectionEvent(new Message.fromJSON(msg)) );
    });

    conn.on.close.add((_){
      _handleClose();
    });

  }

  _handleClose() {
    on.close.dispatch();
  }

  get ready => conn.readyState == 1;
  abort() => conn.close();
  stop() => conn.end();
  send(Message msg) {
    var str = msg.toJSON();
    conn.write(str);
  }

}

class SockJSServer extends Server {
  sockjs.Server sjsServer;
  
  SockJSServer(HttpServer httpServer) : super(httpServer) {
    
    sjsServer = sockjs.createServer()
    ..on.connection.add( (conn) {
      new Session(new SockJSConnection(conn), model);
    });
      
    sjsServer.installHandlers(httpServer, prefix: '/sockjs');
  }
}

