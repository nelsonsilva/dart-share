# Vendor Files

A place to put code from other projects that you can't include with `dart pub`.

By default `unittest` and `dart.js` are included to make testing and browser execution a bit easier.

## unittest

FYI: These files were copied from the Dart SDK, with a few tweaks to remove warnings.

I'd rather reference the unit test libraries in the SDK, but at the moment this requires hard-coding absolute paths, wich is a non-started for code sharing.

Tracking the removal of these via Issue #2 - https://github.com/kevmoo/dartlib/issues/2

## dart.js

Similiar to `unittest` this file is needed to run dart code in the _Dartium_ Chrome browser.

The default html page references the web-hosted version of `dart.js` which is great unless you're coding on a bus.

Ideally, this kind of boiler plate would not be needed in a library.

...but until it's fixed.

*TODO: open an issue to track this*
