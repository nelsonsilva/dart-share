library tests;

import 'package:unittest/unittest.dart';

import "dart:io";
import 'dart:uri';
import 'dart:math' as Math;

import 'package:dart-share/client.dart' as client;
import 'package:dart-share/server.dart' as share;
import 'package:dart-share/src/shared/operation.dart';

part 'types/random_word.dart';
part 'types/text.dart';
part 'types/list.dart';
part 'types/json.dart';
part 'integration.dart';

void runTests() {
  TestText.run();
  TestList.run();
  //TestJSON.run();
  IntegrationTests.run();
}
