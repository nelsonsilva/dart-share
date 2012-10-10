#import('dart:html');
#import('dart:isolate');

#import('package:dart-share/client.dart', prefix:'share');
#import('package:dart-share/src/client/ws/connection.dart', prefix:'ws');
#source('text_area.dart');

main(){
  TextAreaElement elem = document.query('#pad');
  var client = new share.Client(new ws.Connection());
  var connection = client.open('blag', 'text', 'localhost:8000').then((doc) {
    elem.disabled = false;
    new SharedTextArea(doc, elem);

  });
}
