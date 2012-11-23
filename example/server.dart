import 'dart:io';
import 'package:args/args.dart';
import 'package:share/server.dart' as share;

send404(HttpResponse response) {
  response.statusCode = HttpStatus.NOT_FOUND;
  response.outputStream.close();
}

startServer(String basePath) {
  HttpServer server = new HttpServer();

  share.attach(server, useSockJS: true);

  server.defaultRequestHandler = (HttpRequest request, HttpResponse response) {
    var path = request.path;
    var file = new File('${basePath}${path}');
    if (!file.existsSync()) {
      file = new File('${basePath}${path}/index.html');
    }
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

  var parser = new ArgParser();

  parser
    ..addOption('port', defaultsTo: '8000')
    ..addOption('host', defaultsTo: '0.0.0.0');

  List<String> argv = (new Options()).arguments;

  var opts = parser.parse(argv);
  
  var host = opts["host"],
      port = int.parse(opts["port"]);
  
  server.listen(host, port);
  print("Example server running at http://$host:$port");
}

void main() {
  // Compute base path for the request based on the location of the
  // script and then start the server.
  File script = new File(new Options().script);
  String d = script.directorySync().path;

  startServer(d);
}