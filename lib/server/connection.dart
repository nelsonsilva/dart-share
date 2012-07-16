class ConnectionEvents extends event.Events {
  get message() => this["message"]; // MessageEvent
  get close() => this["close"];
}

abstract class Connection implements event.Emitter<ConnectionEvents> {
  abstract abort();
  abstract stop();
  abstract send(Message msg);
  abstract bool get ready();
  
  ConnectionEvents _events;
  Connection() : _events = new ConnectionEvents();
 
  ConnectionEvents get on() => _events;
  
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
    
    conn.onMessage = (String msg) {
      print("c->s $msg");
      on.message.dispatch( new ConnectionEvent(new Message.fromJSON(msg)) );
    };
    
    conn.onClosed = (int status, String reason) {
      print('closed with $status for $reason');
      _handleClose();
    };
          
    conn.onError = (e) {
      print('WSConnection Error : $e');
      _handleClose();
    };
    
   
  }
  
  _handleClose() {
    on.close.dispatch(new ConnectionEvent());
  }
  
  get ready() => true;
  abort() => conn.close();
  stop() => conn.close();
  send(Message msg) { 
    var str = msg.toJSON();
    print('s->c $str');
    conn.send(str);
  }

}

