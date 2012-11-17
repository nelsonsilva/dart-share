library html_tests;

import 'package:unittest/unittest.dart';

import 'dart:uri';
import 'dart:math' as Math;

import 'package:dart-share/src/shared/operation.dart';

part 'types/random_word.dart';
part 'types/text.dart';
part 'types/list.dart';
part 'types/json.dart';

void runHtmlTests() {
  // tests that must run in a browser here
  TestText.run();
}
