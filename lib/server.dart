#library('server');

#import('dart:io');
#import('dart:json');
#import('dart:isolate');
#import('dart:math', prefix:'Math');

// TODO - Use packages:...
// #import('../../packages/DartRedisClient/RedisClient.dart');

#import('src/shared/events.dart', prefix:'event');

#import('src/shared/operation.dart');

#source('src/shared/message.dart');
#source('src/server/doc.dart');
#source('src/server/util/cache.dart');
#source('src/server/util/stats.dart');
#source('src/server/util/sync_queue.dart');
#source('src/server/model.dart');

#source('src/server/db/db.dart');
#source('src/server/db/redis.dart');

#source('src/server/connection.dart');
#source('src/server/session.dart');
#source('src/server/user_agent.dart');

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
