#library('server');

#import('dart:io');
#import('dart:json');
#import('dart:isolate');

// TODO - Use packages:...
#import('../../packages/DartRedisClient/RedisClient.dart');

#import('../shared/events.dart', prefix:'event');

#source('../shared/operation.dart');
#source('../shared/types/text.dart');
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
  
  int sessionId = 0;
  
  Server(this.httpServer) {
    DB db = new DB();
    Model docDAO = new Model(db);
    
    wsHandler = new WebSocketHandler();
    
    httpServer.addRequestHandler((req) => req.path == "/ws", wsHandler.onRequest);
    
    wsHandler.onOpen = (WebSocketConnection conn) { 
      new Session(new WSConnection(conn), docDAO);
    };
  }

}

attach(HttpServer httpServer) => new Server(httpServer);
