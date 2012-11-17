library html_demo;

import 'dart:html';
import 'dart:isolate';
import 'dart:math' as Math;

import 'package:dart-share/client.dart' as share;
import 'package:dart-share/src/client/ws/connection.dart' as ws;
part 'text_area.dart';

main(){
  TextAreaElement elem = document.query('#pad');
  var client = new share.Client(new ws.Connection());
  var connection = client.open('blag', 'text', 'localhost:8000').then((doc) {
    elem.disabled = false;
    new SharedTextArea(doc, elem);

  });
}
