#library("WSConnection");

#import("dart:html");

#import("../client.dart", prefix:'share');

class Connection extends share.Connection {
  WebSocket _ws;
  
  doConnect(Completer<Connection> completer) {
    
    _ws = new WebSocket("ws://$origin/ws");
    
    _ws.on.open.add((_) => handleOpen(completer));
    
    _ws.on.close.add((_) => handleClose());
    
    _ws.on.message.add((m) => handleMessage(m.data));
     
  }
  
  doSend(String msg) => _ws.send(msg);
  
  doDisconnect() => _ws.close();
  
}
