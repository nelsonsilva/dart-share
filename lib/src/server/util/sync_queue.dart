/** A synchronous processing queue. The queue calls process on the arguments,
 * ensuring that process() is only executing once at a time.
 * 
 * process(data, callback) _MUST_ eventually call its callback.
 *
 * Example:
 *
 * queue = require 'syncqueue'
 *
 * fn = queue (data, callback) ->
 *     asyncthing data, ->
 *         callback(321)
 *
 * fn(1)
 * fn(2)
 * fn(3, (result) -> console.log(result))
 *
 *   ^--- async thing will only be running once at any time.*/

typedef void SyncQueueProcessor(data, callback);

class SyncQueueArgument {
  var data;
  var callback;
  SyncQueueArgument(this.data, this.callback);
}

class SyncQueue {
  
  SyncQueueProcessor processorFn;
  
  Queue<SyncQueueArgument> queue;
  bool busy = false;
  
  SyncQueue(this.processorFn) : queue = new Queue<SyncQueueArgument>();
  
  clear() {
    busy = true;
    queue = new Queue<SyncQueueArgument>();
  }
  
  push(data, [callback = null]) {
    queue.addLast(new SyncQueueArgument(data, callback));
    flush();
  }
  
  flush() {
    if (busy || queue.isEmpty()) {
      return;
    }
    
    busy = true;
    
    var arg = queue.removeFirst();
    
    processorFn( arg.data, ([result]){
      busy = false;
      // This is called after busy = false so a user can check if enqueue.busy is set in the callback.
      if (arg.callback != null) {
          arg.callback(result);
      }
      
      flush();
    });
  }
  
}
