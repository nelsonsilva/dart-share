#import('dart:html');
#import('dart:isolate');
#import('../../lib/client/client.dart', prefix:'share');
#source('text_area.dart');

main(){
  TextAreaElement elem = document.query('#pad');
  var client = new share.Client();
  var connection = client.open('blag', 'text', 'localhost:8000').then((doc) {
    elem.disabled = false;
    new SharedTextArea(doc, elem);

  });
}
