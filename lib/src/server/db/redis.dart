class RedisDB implements DB{
  RedisClient client;
  
  String _prefix = "";
  
  RedisDB() : client = new RedisClient() {}
  
  Future<bool> writeOp(String docName, opData) {}
  Future<bool> writeSnapshot(String docName, docData, dbMeta) {}
  
  /** return data, dbMeta **/
  Future<DBDocEntry> getSnapshot(docName) {
    return client.get(keyForDoc(docName)).transform((json) {
      //var m = JSON.parse(json);
      return new DBDocEntry.fromMap(json);
    });
   
  }
  
  keyForOps(docName) => "${_prefix}ops:${docName}";
  keyForDoc(docName) => "${_prefix}doc:${docName}";
  
  Future<DBDocEntry> create(String docName, DBDocEntry data) {
    var m = data.toMap();
    //var value = JSON.stringify(m);
    return client.set(keyForDoc(docName), m);
  }
  
  Future<List> getOps(String docName, start, [end]) {
    if (start == end) {
      return new Future.immediate([]);
    }
  
    // In redis, lrange values are inclusive.
    if(end != null) {
      end--;
    } else {
      end = -1;
    }
  
    return client.lrange(keyForOps(docName), start, end).transform((op) {
      return JSON.parse(op);
    });
  }

}
