library SockJSConnection;

import "dart:html";

import "package:share/client.dart" as share;
import "package:sockjs_client/sockjs.dart" as sockjs;

class Connection extends share.Connection {
  sockjs.Client _sockjs;

  doConnect(Completer<Connection> completer) {
    _sockjs = new sockjs.Client('http://$origin/sockjs', protocolsWhitelist:['xhr-streaming'], debug: true);
    
    _sockjs.on.open.add( (_) => handleOpen(completer) );
    _sockjs.on.message.add( (m) => handleMessage(m.data) );
    _sockjs.on.close.add( (_) => handleClose() );
  }

  doSend(String msg) => _sockjs.send(msg);

  doDisconnect() {} // TODO - _sockjs.close();

}
