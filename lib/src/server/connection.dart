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

