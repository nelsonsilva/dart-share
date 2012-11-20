library tests;

import 'package:unittest/unittest.dart';

import 'dart:uri';
import 'dart:math' as Math;

import 'package:share/share.dart';

part 'types/random_word.dart';
part 'types/text.dart';
part 'types/list.dart';
part 'types/json.dart';

void runHtmlTests() {
  // tests that must run in a browser here
  TestText.run();
  TestList.run();
  TestJSON.run();
}
