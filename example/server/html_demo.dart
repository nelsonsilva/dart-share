library html_demo;

import 'dart:html';
import 'dart:isolate';
import 'dart:math' as Math;

import 'package:share/client.dart' as share;
import 'package:share/src/client/ws/connection.dart' as ws;
part 'text_area.dart';

main(){
  TextAreaElement elem = document.query('#pad');
  var client = new share.Client(new ws.Connection());

  // TODO - I need to import dart:html in the client but this will prevent running the integration
  // tests in the console. So for now I'm explicity setting window.location.host as the origin
  var connection = client.open('blag', 'text', window.location.host).then((doc) {
    elem.disabled = false;
    new SharedTextArea(doc, elem);
  });
}
