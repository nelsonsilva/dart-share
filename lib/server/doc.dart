class DocMeta {
  String creator;
  Date ctime;
  Date mtime;
  
  DocMeta([this.creator, this.ctime, this.mtime]){}
  
  factory DocMeta.fromMap(Map m) {
    return new DocMeta( 
      creator: m["creator"],
      ctime: new Date.fromString(m["ctime"]),
      mtime: new Date.fromString(m["mtime"]));
  }
  
  Map toMap() {
    var m = { "creator": creator,
              "ctime": ctime.toString(),
              "mtime": mtime.toString()}; 
  
    return m;
  }
  
}

class Doc<S, O extends Operation> implements event.Emitter<DocEvents> {
  S snapshot;
  int version;
  OTType type;
  DocMeta meta;
  
  SyncQueue opQueue = null;
  
  DocEvents on;
  
  Doc([ this.snapshot,
        this.version,
        this.type,
        this.meta]) : on = new DocEvents() {}

}

class DocEvents extends event.Events {
  get op() => this["op"];
}
