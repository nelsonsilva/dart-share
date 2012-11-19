library share;

import 'dart:math' as Math;
import 'dart:json';

import 'events.dart' as event;

part 'src/shared/message.dart';
part "src/shared/operation.dart";
part "src/shared/types/text.dart";
part "src/shared/types/list.dart";
part "src/shared/types/json.dart";

var OT = {"text": new OTText(),
          "list": new OTList(),
          "json": new OTJSON()};