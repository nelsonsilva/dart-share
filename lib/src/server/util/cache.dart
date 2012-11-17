part of server;

/**
 *   # The cache is a map from docName -> {
  #   ops:[{op, meta}]
  #   snapshot
  #   type
  #   v
  #   meta
  #   eventEmitter
  #   reapTimer
  #   committedVersion: v
  #   snapshotWriteLock: bool to make sure writeSnapshot isn't re-entrant
  #   dbMeta: database specific data
  #   opQueue: syncQueue for processing ops
  # */
class DocEntry {
  Doc doc;

  // Cache of ops
  List<OpEntry> ops;

  /** Timer before the document will be invalidated from the cache (if the document has no listeners) */
  var reapTimer;

  /** Version of the snapshot thats in the database */
  int committedVersion;
  bool snapshotWriteLock = false;

  var dbMeta;

  DocEntry({this.doc: null,
        this.ops: null,
        this.reapTimer: null,
        this.committedVersion: null,
        this.snapshotWriteLock: null,
        this.dbMeta: null});

  get version => doc.version;
  set version(int v) => doc.version = v;

  get snapshot => doc.snapshot;
  set snapshot(var s) => doc.snapshot = s;

  get meta => doc.meta;
  get type => doc.type;
  get opQueue => doc.opQueue;

  get on => doc.on;
}

class OpEntry {
  Operation op;
  int version;
  var meta;
  OpEntry({this.op,
             this.version,
             this.meta });
}

/**
  # This is a cache of 'live' documents.
  #
  #
  # The ops list contains the document's last options.numCachedOps ops. (Or all
  # of them if we're using a memory store).
  #
  # Documents are stored in this set so long as the document has been accessed in
  # the last few seconds (options.reapTime) OR at least one client has the document
  # open. I don't know if I should keep open (but not being edited) documents live -
  # maybe if a client has a document open but the document isn't being edited, I should
  # flush it from the cache.
  #
  # In any case, the API to model is designed such that if we want to change that later
  # it should be pretty easy to do so without any external-to-the-model code changes. */
class DocCache implements Map<String, DocEntry>{
  Map<String, DocEntry> _docs;

  DocCache() : _docs = <DocEntry>{};

  // Delegates
  bool containsValue(DocEntry value) => _docs.containsValue(value);
  bool containsKey(String key) => _docs.containsKey(key);
  DocEntry operator [](String key) => _docs[key];
  void operator []=(String key, DocEntry value) { _docs[key] = value; }
  DocEntry putIfAbsent(String key, DocEntry ifAbsent()) => _docs.putIfAbsent(key, ifAbsent);
  DocEntry remove(String key)=> _docs.remove(key);
  void clear()=> _docs.clear();
  void forEach(void f(String key, DocEntry value)) => _docs.forEach(f);
  Collection<String> getKeys() => _docs.keys;
  Collection<DocEntry> getValues() => _docs.values;
  Collection<String> get keys => _docs.keys;
  Collection<DocEntry> get values => _docs.values;
  int get length => _docs.length;
  bool get isEmpty => _docs.isEmpty;
}
