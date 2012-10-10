#import('dart:io');
#import('package:dart-share/server.dart', prefix:'share');

send404(HttpResponse response) {
  response.statusCode = HttpStatus.NOT_FOUND;
  response.outputStream.close();
}

startServer(String basePath) {
  HttpServer server = new HttpServer();
  
  share.attach(server);
 
  server.defaultRequestHandler = (HttpRequest request, HttpResponse response) {
    var path = request.path == '/' ? '/index.html' : request.path;
    var file = new File('${basePath}${path}');
    file.fullPath().then((fullPath) {
      if (!fullPath.startsWith(basePath)) {
        send404(response);
      } else {
        file.exists().then((found) {
          if (found) {
            file.openInputStream().pipe(response.outputStream);
          } else {
            send404(response);
          }
        });
      }
    });
  };
  
  server.listen('127.0.0.1', 8000);
}

void main() {
  // Compute base path for the request based on the location of the
  // script and then start the server.
  // File script = new File(new Options().script);
  // Directory d = script.directorySync();
  
  String d = "/home/nfgs/Programacao/Dart";
  startServer(d);
}