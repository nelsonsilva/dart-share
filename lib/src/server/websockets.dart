part of server;

class WSConnection extends Connection {
  WebSocketConnection conn;

  WSConnection(this.conn) : super() {
    var _lastSentDoc = null;
    var _lastReceivedDoc = null;

    conn.onMessage = (msg) {
      print("c->s $msg");
      on.message.dispatch( new ConnectionEvent(new Message.fromJSON(msg)) );
    };

    conn.onClosed = (int status, String reason) {
      print('closed with $status for $reason');
      _handleClose();
    };

  }

  _handleClose() {
    on.close.dispatch(new ConnectionEvent());
  }

  get ready => true;
  abort() => conn.close();
  stop() => conn.close();
  send(Message msg) {
    var str = msg.toJSON();
    conn.send(str);
  }

}

class WSServer extends Server {
  WSServer(HttpServer httpServer) : super(httpServer) {
    wsHandler = new WebSocketHandler();

    httpServer.addRequestHandler((req) => req.path == "/ws", wsHandler.onRequest);

    wsHandler.onOpen = (WebSocketConnection conn) {
      new Session(new WSConnection(conn), model);
    };
  }
}


