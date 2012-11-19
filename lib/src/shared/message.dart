part of share;

class MessageMeta {
  String source;
  Date ts;
  String path = null;
  MessageMeta({this.source: null, this.ts: null});
}

class Message {
  String doc;
  bool open = null;
  String type = "text";
  int version = null;
  bool create = null;
  String error = null;
  String auth = null;
  // TODO : Handle the generics
  dynamic snapshot = null;
  dynamic op = null; // This can be either an Operation or a List of components
  MessageMeta meta = null;

  Message({this.doc: null, this.snapshot: null, this.open: null, this.type: null, this.version: null, this.create: null, this.error: null, this.auth: null, this.op: null, this.meta: null});

  factory Message.fromJSON(str) {
    var msg = JSON.parse(str);
    return new Message(
      doc: msg["doc"],
      open: msg["open"],
      type: msg["type"],
      version: msg["v"],
      create: msg["create"],
      snapshot: msg["snapshot"],
      error: msg["error"],
      auth: msg["auth"],
      op: msg["op"]);
  }

  String toJSON() {
    var m = {};
    var put = (key, value, [defaultValue = null]) { if (value != null && value != defaultValue) { m[key] = value; } };

    put("doc", doc);
    put("auth", auth);
    put("open", open);
    put("type", type);
    put("v",version);
    put("create", create, false);
    put("snapshot", snapshot);
    put("error", error);
    put("op", (op != null) ? op.map((c) => c.toMap()) : null );
    return JSON.stringify(m);
  }
}