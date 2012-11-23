#!/bin/sh
if [ ! -d "dart-sdk" ]; then
    echo "Downloading latest Dart SDK"
    wget https://gsdview.appspot.com/dart-editor-archive-integration/latest/dartsdk-linux-64.tar.gz
    tar xzf dartsdk-linux-64.tar.gz
fi
if [ ! -d "packages" ]; then
    cp deploy/pubspec.yaml . # Override to use hosted deps
    ./dart-sdk/bin/pub install
fi
echo "Starting example server at http://$VCAP_APP_HOST:$VCAP_APP_PORT"
./dart-sdk/bin/dart ./example/server.dart --host $VCAP_APP_HOST --port $VCAP_APP_PORT
