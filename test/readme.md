# Library Tests

To run tests from the console: `dart console_test_harness.dart`
To run tests from browser: open `browser_test_harness.html` in Dartium. (Right-click, Run from Dart Editor).

## Files you play with
* `_html_test_runner.dart` - a place to run all tests that need the browser
* `_test_runner.dart` - a place to run all tests that can run in the console and the browser.

## Files you replace
* `test_two_numbers.dart` - sample test file for the sample class.
* `test_something_html.dart` - sample test files that doesn't do much.

## Files you shouldn't have to touch
* `console_test_harness.dart` - runs all tests in _test_runner.dart
* `browser_test_harness.dart` - runs all tests in `_test_runner.dart` *and* `_html_test_runner.dart`
* `browser_test_harness.html` - What you open in Dartium browser.
