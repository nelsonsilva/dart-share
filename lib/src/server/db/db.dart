part of server;

abstract class DB {

  factory DB() => new MemDB();

  /**  Creates a new document.
   * data = {snapshot, type:typename, [meta]}
   * calls callback(true) if the document was created or callback(false) if a document with that name
   * already exists. */
  Future<DBDocEntry> create(String docName, DBDocEntry data);
  Future<bool> writeOp(String docName, opData);
  Future<bool> writeSnapshot(String docName, docData, dbMeta);
  /** Return a list of ops. The elements are simple maps since we don't now the OTType to deserialize! */
  Future<List<DBOpEntry>> getOps(String docName, start, [end]);
  /** return data, dbMeta **/
  Future<DBDocEntry> getSnapshot(docName);

  /** Permanently deletes a document. There is no undo.*/
  Future<bool> delete(String docName, dbMeta);

  close();
}

class DBOpEntry {
 List components;
 var meta;
 DBOpEntry(this.components, this.meta);
}

class DBDocEntry {
  var snapshot;
  String type;
  DocMeta meta;
  int version=0;

  DBDocEntry( { this.snapshot,
             this.type,
             this.meta,
             this.version}) {}

  factory DBDocEntry.fromMap(Map entry) {
    return new DBDocEntry(
      snapshot: entry["snapshot"],
      type: entry["type"],
      meta: new DocMeta.fromMap(entry["meta"]),
      version: entry["version"]);
  }

  Map toMap() {
    var m = { "snapshot": snapshot,
              "type": type,
              "meta": meta.toMap(),
              "version": version};

    return m;
  }
}

class MemDB implements DB{
  Map<String, DBDocEntry> _docs;
  Map<String, List<DBOpEntry>> _ops;

  MemDB() : _docs = <DBDocEntry>{}, _ops = <List<DBOpEntry>>{} {}

  Future<bool> writeOp(String docName, OpEntry opData) {
    if (opData.op is Operation) {
      Operation op = opData.op;
      var ops = op.map((OperationComponent c) => c.toMap());
      var key = keyForOps(docName);
      _ops.putIfAbsent(key, () => []);
      _ops[key].add(new DBOpEntry(ops, opData.meta));
    }
    //_ops[docName] = opData.op.map();
    return new Future.immediate(true);
  }

  Future<bool> writeSnapshot(String docName, docData, dbMeta) {
    _docs[keyForDoc(docName)] = docData;
    return new Future.immediate(true);
  }

  /** return data, dbMeta **/
  Future<DBDocEntry> getSnapshot(docName) {
    var doc = _docs[keyForDoc(docName)];
    return new Future.immediate(doc);
  }

  keyForOps(docName) => "ops:${docName}";
  keyForDoc(docName) => "doc:${docName}";

  Future<DBDocEntry> create(String docName, DBDocEntry data) {
    _docs[keyForDoc(docName)] = data;
    return new Future.immediate(data);
  }

  Future<List<DBOpEntry>> getOps(String docName, start, [end]) {
    var key = keyForOps(docName);
    if (start == end || !_ops.containsKey(key)) {
      return new Future.immediate([]);
    }

    // In redis, lrange values are inclusive.
    var ops = _ops[key];
    if(end == null) {
      end = ops.length;
    }

    return new Future.immediate(ops.getRange(start, end - start));
  }

  Future<bool> delete(String docName, dbMeta) {
      DBDocEntry doc = _docs.remove(keyForDoc(docName));
      _ops.remove(keyForOps(docName));
      return new Future.immediate(doc != null);
  }

  close() {}
}