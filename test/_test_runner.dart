#library('tests');

#import('package:unittest/unittest.dart');

#import("dart:io");
#import('dart:uri');
#import('dart:math', prefix:'Math');

#import('package:dart-share/client.dart', prefix:'client');
#import('package:dart-share/server.dart', prefix:'share');
#import('package:dart-share/src/shared/operation.dart');

#source('types/random_word.dart');
#source('types/text.dart');
#source('types/list.dart');
#source('types/json.dart');
#source('integration.dart');

void runTests() {
  TestText.run();
  TestList.run();
  //TestJSON.run();
  IntegrationTests.run();
}
