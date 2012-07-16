#import('../vendor/unittest/html_config.dart');

#import('_test_runner.dart');
#import('_html_test_runner.dart');

main() {
  useHtmlConfiguration();

  runTests();
  runHtmlTests();
}
