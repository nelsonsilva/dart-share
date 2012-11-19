part of server;

class ConnectionEvents extends event.Events {
  get message => this["message"]; // MessageEvent
  get close => this["close"];
}

abstract class Connection implements event.Emitter<ConnectionEvents> {
  abort();
  stop();
  send(Message msg);
  bool get ready;

  ConnectionEvents _events;
  Connection() : _events = new ConnectionEvents();

  ConnectionEvents get on => _events;

}


class ConnectionEvent extends event.Event {
  Message msg;
  ConnectionEvent([this.msg, String type = 'message']) : super(type);
}


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

