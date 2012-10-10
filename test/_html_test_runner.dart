#library('html_tests');

#import('package:unittest/unittest.dart');

#import('dart:uri');
#import('dart:math', prefix:'Math');

#import('package:dart-share/src/shared/operation.dart');

#source('types/random_word.dart');
#source('types/text.dart');
#source('types/list.dart');
#source('types/json.dart');

void runHtmlTests() {
  // tests that must run in a browser here
  TestText.run();
}
