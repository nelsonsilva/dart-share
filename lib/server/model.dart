class ModelEvents extends event.Events {
  get applyOp() => this["applyOp"];
  get add() => this["add"];
  get create() => this["create"];
  get load() => this["load"];
  get delete() => this["delete"];
}

class DocEvent extends event.Event {
  static final ID = "DocEvent";
  
  String docName;
  var data;
  var snapshot;
  var oldSnapshot;
  DocEvent([this.docName, this.data, this.snapshot, this.oldSnapshot]) : super(ID);
}

/*
class OpEvent extends event.Event {
  static final ID = "OpEvent";
  
  var opData;
  var snapshot;
  var oldSnapshot;
  OpEvent(this.opData, this.snapshot, this.oldSnapshot) : super(ID);
}*/


/**
 * The model of all the ops. Responsible for applying & transforming remote deltas
 * and managing the storage layer.
 *
 * Actual storage is handled by the database wrappers */
class Model implements event.Emitter<ModelEvents> {
  
  Stats stats;
  DB db;
  DocCache docs;
  
  /** This is a map from docName -> [callback]. It is used when a document hasn't been
   * cached and multiple getSnapshot() / getVersion() requests come in. All requests
   * are added to the callback list and called when db.getSnapshot() returns.
   *
   * callback(error, snapshot data) */
  Map awaitingGetSnapshot;
  
  /** The time that documents which no clients have open will stay in the cache.
   * Should be > 0.*/
  int reapTime;
  
  /** The number of operations the cache holds before reusing the space */
  int numCachedOps;
  
  /** This option forces documents to be reaped, even when there's no database backend.
   * This is useful when you don't care about persistance and don't want to gradually
   * fill memory.
   *
   * You might want to set reapTime to a day or something. */
  bool forceReaping;
  
  /** Until I come up with a better strategy, we'll save a copy of the document snapshot
   * to the database every ~20 submitted ops. */
  int opsBeforeCommit = 20;
  
  /** It takes some processing time to transform client ops. The server will punt ops back to the
   * client to transform if they're too old. */
  int maximumAge = 40;
  
  int commitedVersion = null;
  
  ModelEvents on;
  
  Model(this.db, [this.reapTime = 3000,
                  this.numCachedOps = 10,
                  this.forceReaping = false,
                  this.opsBeforeCommit = 20,
                  this.maximumAge = 40])
    : on = new ModelEvents(),
      docs = new DocCache(),
      awaitingGetSnapshot = {},
      stats = new Stats() {}
  
  /** Its important that all ops are applied in order. This helper method creates the op submission queue
   * for a single document. This contains the logic for transforming & applying ops. */
  makeOpQueue(String docName, DocEntry doc) { 
    return new SyncQueue( (opData, callback) {
      if (opData.version < 0) { return callback('Version missing'); }
      if (opData.version > doc.version) { return callback('Op at future version'); }
  
      // Punt the transforming work back to the client if the op is too old.
      if (opData.version + maximumAge < doc.version) { return callback('Op too old'); } 
  
      if (opData.meta == null) {
        opData.meta = new MessageMeta();
        opData.meta.ts = new Date.now();
      }
      
      // We'll need to transform the op to the current version of the document. This
      // calls the callback immediately if opVersion == doc.v.
      getOps(docName, opData.version, doc.version).then((ops) {

        if (doc.version - opData.version != ops.length) {
          // This should never happen. It indicates that we didn't get all the ops we
          // asked for. Its important that the submitted op is correctly transformed.
          print("Could not get old ops in model for document $docName");
          print("Expected ops ${opData.version} to ${doc.version} and got ${ops.length} ops");
          return callback('Internal error');
        }
        if (ops.length > 0) {
          // If there's enough ops, it might be worth spinning this out into a webworker thread.
          ops.forEach( (oldOp) {
              // Dup detection works by sending the id(s) the op has been submitted with previously.
              // If the id matches, we reject it. The client can also detect the op has been submitted
              // already if it sees its own previous id in the ops it sees when it does catchup.
              if (oldOp.meta.source != null && opData.dupIfSource && opData.dupIfSource.indexOf(oldOp.meta.source) != -1) {
                return callback('Op already submitted');
              }
  
              opData.op = doc.type.transform(opData.op, oldOp.op, left: true);
              opData.version++;
          });
          //catch error
          //  console.error error.stack
          //  return callback error.message
        }
        var snapshot = doc.type.apply(doc.snapshot, opData.op);
        //catch error
        //  console.error error.stack
        //  return callback error.message
  
        // The op data should be at the current version, and the new document data should be at
        // the next version.
        //
        // This should never happen in practice, but its a nice little check to make sure everything
        // is hunky-dory.
        if (opData.version != doc.version) {
          // This should never happen.
          print("Version mismatch detected in model. File a ticket - this is a bug.");
          print("Expecting ${opData.version} == ${doc.version}");
          throw new Exception('Internal error');
        }
  
  
        var writeOp = db.writeOp(docName, opData);
        writeOp.handleException((e) {
          print("Error writing ops to database: ${e}");
          throw new Exception(e);
        });
        writeOp.then((_) {
          stats.writeOp();
  
          // This is needed when we emit the 'change' event, below.
          var oldSnapshot = doc.snapshot;
  
          // All the heavy lifting is now done. Finally, we'll update the cache with the new data
          // and (maybe!) save a new document snapshot to the database.
  
          doc.version = opData.version + 1;
          doc.snapshot = snapshot;
  
          doc.ops.add(opData);
          if (db != null && doc.ops.length > numCachedOps) {
            doc.ops.removeRange(0, 1); // shift
          }
  
          on.applyOp.dispatch(new DocEvent(docName, opData, snapshot, oldSnapshot));
          // TODO(nelsonsilva) - figure out why this crashes
          doc.on.op.dispatch(new DocEvent(docName, opData, snapshot, oldSnapshot));
  
          // The callback is called with the version of the document at which the op was applied.
          // This is the op.v after transformation, and its doc.v - 1.
          callback(opData.version);
      
          // I need a decent strategy here for deciding whether or not to save the snapshot.
          //
          // The 'right' strategy looks something like "Store the snapshot whenever the snapshot
          // is smaller than the accumulated op data". For now, I'll just store it every 20
          // ops or something. (Configurable with doc.committedVersion)
          if (!doc.snapshotWriteLock && (doc.committedVersion + opsBeforeCommit <= doc.version)){
            var writeTask = tryWriteSnapshot(docName);
            writeTask.handleException((e) => print("Error writing snapshot e. This is nonfatal"));
          }
        });
      });
    });
  }
  
  /** Add the data for the given docName to the cache. The named document shouldn't already
   * exist in the doc set.
   *
   * Returns the new doc. */
  DocEntry add(docName, [DBDocEntry data, int committedVersion, ops]) {

    //var callbacks = awaitingGetSnapshot[docName];
    //awaitingGetSnapshot.remove(docName);

    //if (error != null) {
    //  if (callbacks != null) {
    //    callbacks.forEach((callback) => callback(error));
    //  }
    //} else {

      if (commitedVersion == null) {
        committedVersion = data.version;
      }

      var type = OT[data.type];
      if (type == null) {
        print("Type '${data.type}' missing");
        throw new Exception("Type not found");
      }
      
      var doc = new Doc(
        snapshot: data.snapshot,
        version: data.version,
        type: type,
        meta: data.meta);
      
      var docEntry = new DocEntry(
        doc: doc,
        // Cache of ops
        ops: ops,
        reapTimer: null,
        committedVersion: committedVersion,
        snapshotWriteLock: false);
        //dbMeta: dbMeta);

      docs[docName] = docEntry;
      
      doc.opQueue = makeOpQueue(docName, docEntry);
      
      refreshReapingTimeout(docName);
      on.add.dispatch(new DocEvent(docName, data));
      //callbacks.forEach((c) => callback(null, doc));
   //}

    return docEntry;
  }
    
   /** This is a little helper wrapper around db.getOps. It does two things:
    * 
    * - If there's no database set, it returns an error to the callback
    * - It adds version numbers to each op returned from the database
    * (These can be inferred from context so the DB doesn't store them, but its useful to have them). **/
  Future<List<OpEntry>> _getOpsInternal(docName, OTType type, start, [end]) { 
   return db.getOps(docName, start, end).transform((ops) {
      var v = start;
      return ops.map((DBOpEntry op) {
        
        Operation otOp = type.createOp(op.components);
        //otOp.version = v++;
        return new OpEntry(op:otOp, version:v++, meta:op.meta);
      });
    });
   
  }
 
  /** Load the named document into the cache. This function is re-entrant.
   *
   * The callback is called with (error, doc) **/
  Future<DocEntry> load(docName) {
    if (docs.containsKey(docName)) { // The document is already loaded. Return immediately.
      stats.cacheHit('getSnapshot');
      var doc = docs[docName];
      return new Future<DocEntry>.immediate(docs[docName]);
    }

    //var callbacks = awaitingGetSnapshot[docName];

    // The document is being loaded already. Add ourselves as a callback.
    //if (callbacks != null) {
    //  return callbacks.add(callback);
    //}

    stats.cacheMiss('getSnapshot');

    // The document isn't loaded and isn't being loaded. Load it.
    //awaitingGetSnapshot[docName] = [callback];
    
    
    return db.getSnapshot(docName).chain((DBDocEntry data) {
      if (data == null) {
        return new Future.immediate(null);
      }

      var committedVersion = data.version;

      // The server can close without saving the most recent document snapshot.
      // In this case, there are extra ops which need to be applied before
      // returning the snapshot.
      return _getOpsInternal(docName, OT[data.type], data.version).transform( (ops) {
        //if (error != null) { return callback(error); } 

        if (ops.length > 0) {
          print("Catchup $docName ${data.version} -> ${data.version + ops.length}");
          var type = docs[docName].type;
          ops.forEach((op) {
            data.snapshot = type.apply(data.snapshot, op);
            data.version++;
          });
        }
        on.load.dispatch( new DocEvent(docName, data));
        
        return add(docName, data, committedVersion, ops);
      });
    });
  }
    
  /** This makes sure the cache contains a document. If the doc cache doesn't contain
   * a document, it is loaded from the database and stored.
   * 
   * Documents are stored so long as either:
   * - They have been accessed within the past #{PERIOD}
   * - At least one client has the document open **/
  refreshReapingTimeout(docName) {
    
    if (!docs.containsKey(docName)) { return; }
    
    var docEntry = docs[docName];

    /* I want to let the clients list be updated before this is called.
    process.nextTick -> */
      // This is an awkward way to find out the number of clients on a document. If this
      // causes performance issues, add a numClients field to the document.
      //
      // The first check is because its possible that between refreshReapingTimeout being called and this
      // event being fired, someone called delete() on the document and hence the doc is something else now.
      if ( (docEntry == docs[docName]) &&
           (docEntry.doc.on.op.isEmpty()) &&
           (!docEntry.opQueue.busy) ) {

        if (docEntry.reapTimer != null) {
          docEntry.reapTimer.cancel();
        }
        
        var reapTimer;
        reapTimer = new Timer(reapTime, (timer) {
          tryWriteSnapshot(docName).then((_) {
            // If the reaping timeout has been refreshed while we're writing the snapshot, or if we're
            // in the middle of applying an operation, don't reap.
            if ( (docs[docName].reapTimer == reapTimer) && !docEntry.opQueue.busy) {
              docs.remove(docName); 
            }
           });
         });
      
        docEntry.reapTimer = reapTimer;
      }
          
  }
  
  Future<DocEntry> tryWriteSnapshot(docName) {
    var completer = new Completer();
    if (!docs.containsKey(docName)) { 
      completer.complete(null); 
    } else {
    
      var docEntry = docs[docName];
    
      // The document is already saved.
      if (docEntry.committedVersion == docEntry.doc.version) {  
        completer.complete(docEntry);
      } else {
  
        if (docEntry.snapshotWriteLock) {
          throw new Exception('Another snapshot write is in progress');
        }
      
        docEntry.snapshotWriteLock = true;
      
        stats.writeSnapshot();
      
        var data = new DBDocEntry(
          version: docEntry.version,
          meta: docEntry.meta,
          snapshot: docEntry.snapshot,
          type: docEntry.type.name);
      
        // Commit snapshot.
        
        db.writeSnapshot(docName, data, docEntry.dbMeta).then((dbMeta) {
          docEntry.snapshotWriteLock = false;
      
          // We have to use data.v here because the version in the doc could
          // have been updated between the call to writeSnapshot() and now.
          docEntry.committedVersion = data.version;
          docEntry.dbMeta = dbMeta;
      
          completer.complete(docEntry);
        });
      }
    }
    return completer.future;
  }
  
  // *** Model interface methods

  /** Create a new document.
   *
   * data should be {snapshot, type, [meta]}. The version of a new document is 0. */
  Future<Doc> create(String docName, OTType type, DocMeta meta) {

    //if (docName.match("/\//")) {
    //  throw new Exception('Invalid document name');
    //}
    if (docs.containsKey(docName)) {
      throw new Exception('Document already exists');
    }

    //type = types[type] if typeof type == 'string'
    //return callback? 'Type not found' unless type

    var data = new DBDocEntry(
      snapshot:type.create(),
      type:type.name,
      meta:meta,
      version:0
      );

    
    return db.create(docName, data).transform( (dbDoc) {
      // dbMeta can be used to cache extra state needed by the database to access the document, like an ID or something.
      //return callback? error if error

      // From here on we'll store the object version of the type name.
      //data.type = type.name;
      on.create.dispatch(new DocEvent(docName, dbDoc));
      return add(docName, dbDoc, 0, []).doc;
      
    });
  }
    
  /** Perminantly deletes the specified document.
   * If listeners are attached, they are removed.
   * 
   * The callback is called with (error) if there was an error. If error is null / undefined, the
   * document was deleted.
   *
   * WARNING: This isn't well supported throughout the code. (Eg, streaming clients aren't told about the
   * deletion. Subsequent op submissions will fail). **/
  Future delete(docName) {
    
    var doc = docs[docName];

    if (doc != null) {
      doc.reapTimer.cancel();
      docs.remove(docName);
    }
    
    var deleteTask = db.delete(docName, doc.dbMeta);
    deleteTask.then((_) {
      on.delete.dispatch(new DocEvent(docName));
    });
    return deleteTask;
  }
  
  /** This gets all operations from [start...end]. (That is, its not inclusive.)
   *
   * end can be null. This means 'get me all ops from start'.
   *
   * Each op returned is in the form {op:o, meta:m, v:version}.
   *
   * Callback is called with (error, [ops])
   *
   * If the document does not exist, getOps doesn't necessarily return an error. This is because
   * its awkward to figure out whether or not the document exists for things
   * like the redis database backend. I guess its a bit gross having this inconsistant
   * with the other DB calls, but its certainly convenient.
   *
   * Use getVersion() to determine if a document actually exists, if thats what you're after. **/
  Future<List<OpEntry>> getOps(String docName, int start, [int end]) {
    // getOps will only use the op cache if its there. It won't fill the op cache in.
    if (start < 0) {
      throw new Exception('start must be 0+');
    }

    if (!docs.containsKey(docName)) { throw new Exception('Unknow doc $docName'); }
    //[end, callback] = [null, end] if typeof end is 'function'

    var ops = docs[docName].ops;

    if (ops != null) {
      var version = docs[docName].version;

      // Ops contains an array of ops. The last op in the list is the last op applied
      if (end == null) { end = version; }
      
      start = Math.min(start, end);

      if (start == end) {
        return new Future.immediate([]);
      }

      // Base is the version number of the oldest op we have cached
      var base = version - ops.length;

      if (start >= base) {
        refreshReapingTimeout(docName);
        stats.cacheHit('getOps');

        var startIdx = start - base;
        var endIdx = end - base;
        return new Future.immediate(ops.getRange(startIdx, endIdx - startIdx)); // [(start - base)...(end - base)]
      }
    }
    stats.cacheMiss('getOps');

    return _getOpsInternal(docName, docs[docName].type, start, end);
  }
    
  /** Gets the snapshot data for the specified document.
   * getSnapshot(docName, callback)
   * Callback is called with (error, {v: <version>, type: <type>, snapshot: <snapshot>, meta: <meta>}) */
  Future<Doc> getSnapshot(docName) => load(docName).transform((entry) => (entry == null)? null : entry.doc);

  /** Gets the latest version # of the document.
   * getVersion(docName, callback)
   * callback is called with (error, version). */
  Future<int> getVersion(docName) {
    return load(docName).chain((doc) {
      int version = null;
      if (doc != null) { 
        version = doc.version;
      }
      return version;
    });
  }
  
  /** Apply an op to the specified document.
   * The callback is passed (error, applied version #)
   * opData = {op:op, v:v, meta:metadata}
   * 
   * Ops are queued before being applied so that the following code applies op C before op B:
   * model.applyOp 'doc', OPA, -> model.applyOp 'doc', OPB
   * model.applyOp 'doc', OPC **/
  Future<int> applyOp(String docName, OpEntry opData) {
    var completer = new Completer();
    
    // All the logic for this is in makeOpQueue, above.
    load(docName).then((doc) {

      //process.nextTick -> 
      doc.opQueue.push(opData, (newVersion) {
        refreshReapingTimeout(docName);
        completer.complete(newVersion);
      });
    });
    
    return completer.future;
  }
  
  /** TODO: store (some) metadata in DB
   * TODO: op and meta should be combineable in the op that gets sent */
  Future<int> applyMetaOp(docName, metaOpData) {
    var path = metaOpData.meta.path;
    var value = metaOpData.meta.value;
    
    //return callback? "path should be an array" unless isArray path

    return load(docName).chain((doc) {
        //applied = false
        //switch path[0]
        //  when 'shout'
        //    doc.eventEmitter.emit 'op', metaOpData
        //    applied = true

        //model.emit 'applyMetaOp', docName, path, value if applied
        return doc.version;
    });
  }
  
  /** Listen to all ops from the specified version. If version is in the past, all
   * ops since that version are sent immediately to the listener.
   *
   * The callback is called once the listener is attached, but before any ops have been passed
   * to the listener.
   * 
   * This will _not_ edit the document metadata.
   *
   * If there are any listeners, we don't purge the document from the cache. But be aware, this behaviour
   * might change in a future version.
   *
   * version is the document version at which the document is opened. It can be left out if you want to open
   * the document at the most recent version.
   *
   * listener is called with (opData) each time an op is applied.
   *
   * callback(error, openedVersion) */
  Future<Doc> listen(String docName, int version, final event.Listener listener) {
    //[version, listener, callback] = [null, version, listener] if typeof version is 'function'


    return load(docName).chain((DocEntry docEntry) {
      //var l = listener; // TODO - Find out why listener is null in the transform step!
      
      var doc = docEntry.doc;
      
      if (docEntry.reapTimer != null) {
        docEntry.reapTimer.cancel();
      }
     
      doc.on.op.add(listener);
      
      return new Future.immediate(doc);
    });
  }
  
  void dispatchOps(String docName, Doc doc, listener) {
   getOps(docName, doc.version).then( (List<OpEntry> opEntries) {
    for (var entry in opEntries){
      var evt = new DocEvent(data:entry);
      listener(evt);

      // The listener may well remove itself during the catchup phase. If this happens, break early.
      // This is done in a quite inefficient way. (O(n) where n = #listeners on doc)
      if (doc.on.op.listeners.indexOf(listener) == -1) {
        break;
      }
    }
    });}
    
    
  /** Remove a listener for a particular document.
   *
   * removeListener(docName, listener)
   *
   * This is synchronous. */
  removeListener(docName, listener) {
    // The document should already be loaded.
    if (!docs.containsKey(docName)) {
      throw new Exception('removeListener called but document not loaded');
    }
    var doc = docs[docName];
    doc.on.op.remove(listener);
    refreshReapingTimeout(docName);
  }
  
  /** Flush saves all snapshot data to the database. I'm not sure whether or not this is actually needed -
   * sharejs will happily replay uncommitted ops when documents are re-opened anyway. */
  Future flush(callback) {
    var futures = [];
        
   docs.forEach((docName, doc) {
      if (doc.committedVersion < doc.version) {
        // I'm hoping writeSnapshot will always happen in another thread.
        futures.add(tryWriteSnapshot(docName));
      }
    });
    
    return Futures.wait(futures);
  }
  
  /** Close the database connection. This is needed so nodejs can shut down cleanly. */
  closeDb() {
    db.close();
    db = null;
  }
  
}
