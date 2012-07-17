#library('server');

#import('dart:io');
#import('dart:json');
#import('dart:isolate');

// TODO - Use packages:...
#import('../../packages/DartRedisClient/RedisClient.dart');

#import('../shared/events.dart', prefix:'event');

#import('../shared/operation.dart');

#source('../shared/message.dart');
#source('doc.dart');
#source('util/cache.dart');
#source('util/stats.dart');
#source('util/sync_queue.dart');
#source('model.dart');

#source('db/db.dart');
#source('db/redis.dart');

#source('connection.dart');
#source('session.dart');
#source('user_agent.dart');

class Server {
  HttpServer httpServer;
  WebSocketHandler wsHandler;
  Model model;
  
  Server(this.httpServer) {
    DB db = new DB();
    model = new Model(db);
    
    wsHandler = new WebSocketHandler();
    
    httpServer.addRequestHandler((req) => req.path == "/ws", wsHandler.onRequest);
    
    wsHandler.onOpen = (WebSocketConnection conn) { 
      new Session(new WSConnection(conn), model);
    };
  }
}

HttpServer attach(HttpServer httpServer) {
  var share = new Server(httpServer);
  return share.httpServer;
}
