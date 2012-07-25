#library('tests');

#import('../vendor/unittest/unittest.dart');

#import("dart:io");
#import('dart:uri');

#import('../lib/client/client.dart', prefix:'client');
#import('../lib/server/server.dart', prefix:'share');
#import('../lib/shared/operation.dart');

#source('types/random_word.dart');
#source('types/text.dart');
#source('types/list.dart');
#source('types/json.dart');
#source('integration.dart');

void runTests() {
  TestText.run();
  TestList.run();
  TestJSON.run();
  IntegrationTests.run();
}
