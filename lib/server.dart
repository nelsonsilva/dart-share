library server;

import 'dart:io';
import 'dart:json';
import 'dart:isolate';
import 'dart:math' as Math;

// TODO - Use packages:...
// #import('../../packages/DartRedisClient/RedisClient.dart');

import 'package:share/share.dart';
import 'package:share/events.dart' as event;

import 'package:sockjs/sockjs.dart' as sockjs;

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

part 'src/server/websockets.dart';
part 'src/server/sockjs.dart';

abstract class Server {
  HttpServer httpServer;
  WebSocketHandler wsHandler;
  Model model;

  Server(this.httpServer) {
    DB db = new DB();
    model = new Model(db);
  }
}

HttpServer attach(HttpServer httpServer, {useSockJS: false}) {
  var share = new WSServer(httpServer);
  
  if (useSockJS) new SockJSServer(httpServer);
  return httpServer;
}
