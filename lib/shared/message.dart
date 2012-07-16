class MessageMeta {
  String source;
  Date ts;
  String path = null;
  MessageMeta([this.source, this.ts]);
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
  Dynamic snapshot = null;
  Dynamic op = null; // This can be either an Operation or a List of components
  MessageMeta meta = null;
  
  Message([this.doc, this.snapshot, this.open, this.type, this.version, this.create, this.error, this.auth, this.op, this.meta]);
  
  factory Message.fromJSON(String str) {
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
    put("create", create, defaultValue: false);
    put("snapshot", snapshot);
    put("error", error);
    put("op", (op != null) ? op.map((c) => c.toMap()) : null );
    return JSON.stringify(m);
  }
}