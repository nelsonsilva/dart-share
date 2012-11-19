library server;

import 'dart:io';
import 'dart:json';
import 'dart:isolate';
import 'dart:math' as Math;

// TODO - Use packages:...
// #import('../../packages/DartRedisClient/RedisClient.dart');

import 'package:share/share.dart';
import 'package:share/events.dart' as event;

part 'src/server/doc.dart';
part 'src/server/util/cache.dart';
part 'src/server/util/stats.dart';
part 'src/server/util/sync_queue.dart';
part 'src/server/model.dart';

part 'src/server/db/db.dart';
part 'src/server/db/redis.dart';

part 'src/server/connection.dart';
part 'src/server/session.dart';
part 'src/server/user_agent.dart';

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
