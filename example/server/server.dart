import 'dart:io';
import 'package:share/server.dart' as share;

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
    if (!file.existsSync()) {
      print("does not exist ${file.name}");
      return;
    }
    
    file.fullPath().then((fullPath) {
      file.exists().then((found) {
        if (found) {
          file.openInputStream().pipe(response.outputStream);
        } else {
          send404(response);
        }
      });
    });
  };

  server.listen('0.0.0.0', 8000);
  print("Example server running at http://0.0.0.0:8000");
}

void main() {
  // Compute base path for the request based on the location of the
  // script and then start the server.
  File script = new File(new Options().script);
  String d = script.directorySync().path;

  startServer(d);
}