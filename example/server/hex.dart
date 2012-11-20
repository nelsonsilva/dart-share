library hex_demo;

import 'dart:html';
import 'dart:json';
import 'dart:math' as Math;

import 'package:share/share.dart';
import 'package:share/client.dart' as share;
import 'package:share/src/client/ws/connection.dart' as ws;

var JSON = OT["json"];

var $state;

const defaultSide = 20, 
      spacing = 5;

var selectedX = null,
    selectedY = null,
    grid = {"width": 10, "height": 10},
    playerTurn = 1,
    playerColors = [[200,0,0], [0,0,200]];
randomDocName([length = 10]) {
  const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-=";
  var name = [];
  var rnd = new Math.Random();
  for (var x = 0; x < length; x++) {
    name.add(chars[rnd.nextInt(chars.length)]);
  }
  return Strings.join(name, '');
}

      // from http://www.quirksmode.org/js/cookies.html
createCookie(name,value,[days]) {
  var expires = "";
  if (?days) {
    var date = new Date.now();
    date.add(new Duration(days: days));
    var expires = "; expires=${date.toString()}";
  }
  document.cookie = "$name=$value$expires; path=/";
}

readCookie(name) {
  var nameEQ = "$name=";
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++) {
    var c = ca[i];
    while (c.startsWith(' ')) c = c.substring(1);
    if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
  }
  return null;
}

eraseCookie(name) => createCookie(name,"",-1);

gridAt(g,x,y) => g["values"][(y*g["width"]+x).toInt()];

colorStyle(color) => 'rgb(${color[0]},${color[1]},${color[2]})';

fillHex(ctx, x, y, color, [side = defaultSide]) {
  ctx.fillStyle = color;
  x += 0.5;
  y += 0.5;
  pathHex(ctx, x, y, color, side);
  ctx.fill();
}

strokeHex(ctx, x, y, color, [side = defaultSide]) {
  ctx.strokeStyle = color;
  x += 0.5;
  y += 0.5;
  pathHex(ctx, x, y, color, side);
  ctx.stroke();
}

pathHex(ctx, x, y, color, [side = defaultSide]) {
  ctx.beginPath();
  ctx.moveTo(x, y);
  ctx.lineTo(x+side, y);
  ctx.lineTo(x+side+side*Math.cos(Math.PI/3),
      y+side*Math.sin(Math.PI/3));
  ctx.lineTo(x+side, y+2*side*Math.sin(Math.PI/3));
  ctx.lineTo(x, y+2*side*Math.sin(Math.PI/3));
  ctx.lineTo(x-side*Math.cos(Math.PI/3), y+side*Math.sin(Math.PI/3));
  ctx.lineTo(x, y);
}

//  _
// / \
// \_/
//   v ~~~~ this width
hexEdgeWidth([side = defaultSide]) => side*Math.cos(Math.PI/3);

// height of one hex of side length +side+
hexHeight([side = defaultSide]) => 2*side*Math.sin(Math.PI/3);

adjacencies(x, y) {
  // odd and even columns have different adjacencies
  var odd = (x % 2 == 0) ? -1 : 1;
  return [[x-1,y], [x+1,y], [x, y-1], [x, y+1],
          [x-1, y+odd], [x+1,y+odd]];
}

all(f, xs) {
  for (var i = 0; i < xs.length; i++) {
    if (!f(xs[i])) {
      return false;
    }
  }
  return true;
}

okToPlace(gr, player, x, y) {
  if (x < 0 || x >= gr["width"] || y < 0 || y >= gr["height"]) return false;
  if (gridAt(gr, x,y) != 0) return false;
  // a move adjacent to (x,y) would be OK
  var adjMoveOK = (xy) {
    var x = xy[0], y = xy[1];
    if (x < 0 || x >= gr["width"] || y < 0 || y >= gr["width"]) {
      return true;
    }
    var val = gridAt(gr, x,y);
    return val == 0 || val == player;
  };
  return (all(adjMoveOK, adjacencies(x,y)));
}

drawGrid(ctx, gr) {
  for (var y = 0; y < gr["height"]; y++) {
    for (var x = 0; x < gr["width"]; x++) {
      var hexX = hexEdgeWidth() + (defaultSide+hexEdgeWidth() +
          spacing*Math.cos(Math.PI/6))*x;
      var hexY = (hexHeight() + spacing)*y +
          (x % 2 == 0 ? 0 :
            spacing*Math.sin(Math.PI/6) +
            hexHeight()/2);

      var value = gridAt(gr,x,y);
      if (value != 0) {
        var fillColor = colorStyle(playerColors[value-1]);
        fillHex(ctx, hexX, hexY, fillColor);
      }

      var strokeColor = 'rgb(0,0,0)';
      var ok1 = okToPlace(gr, 1, x, y),
          ok2 = okToPlace(gr, 2, x, y);
      if (ok1 && !ok2) {
        strokeColor = 'rgb(250,140,140)';
      } else if (!ok1 && ok2) {
        strokeColor = 'rgb(140,140,250)';
      } else if (!ok1 && !ok2) {
        strokeColor = 'rgb(255,255,255)';
      }
      if (x == selectedX && y == selectedY) {
        strokeColor = 'rgb(0,200,0)';
      }

      strokeHex(ctx, hexX, hexY, strokeColor);
    }
  }
}

yForX(m, b, x) => m*x + b; // y = mx + b

hexForPixel(x,y) {
  // take the pixel (x,y) and return the coordinates of the hex under
  // that pixel
  var xspacing = Math.cos(Math.PI/6)*spacing;
  x += xspacing;
  var cellwidth = defaultSide + hexEdgeWidth() + xspacing;
  var cellheight = hexHeight() + spacing;
  var xcell = (x / cellwidth).floor();
  // determine if we're in an odd column
  var odd = xcell % 2 != 0;
  if (odd) {
    y -= cellheight/2;
  }
  var ycell = (y / cellheight).floor();
  var xoff = x - xcell*cellwidth;
  var yoff = y - ycell*cellheight;

  var s3 = Math.sqrt(3);
  // top line
  var t_m = -s3, t_b = s3*(xspacing + hexEdgeWidth());
  // bottom line
  var b_m = s3, b_b = hexHeight()/2 - s3*xspacing;

  if ((xoff >= hexEdgeWidth() + xspacing && yoff <= hexHeight()) ||
      (xoff >= xspacing && xoff < hexEdgeWidth() + xspacing &&
      yoff >= yForX(t_m, t_b, xoff) &&
      yoff <= yForX(b_m, b_b, xoff))
  ) {
    return {"x": xcell, "y": ycell};
  }
  if (yoff <= hexHeight()/2 && yoff <= yForX(t_m, hexHeight()/2, xoff)) {
    return {"x": xcell-1, "y": ycell + (odd ? 0 : -1)};
  }
  if (yoff >= hexHeight()/2 + spacing &&
      yoff >= yForX(b_m, spacing + hexHeight() / 2, xoff)) {
    return {"x": xcell-1, "y": ycell + (odd ? 1 : 0)};
  }
}

isComplete(gr) {
  for (var y = 0; y < gr["height"]; y++) {
    for (var x = 0; x < gr["width"]; x++) {
      var ok1 = okToPlace(gr, 1, x, y),
          ok2 = okToPlace(gr, 2, x, y);
      if (ok1 && ok2) {
        // either player can place; board not complete.
        return false;
      } else if (ok1 && !ok2) {
        // player 1 can place. if player 2 can place at any point
        // adjacent to this one, the board is not complete.
        if (adjacencies(x,y).some( (xy) => okToPlace(gr, 2, xy[0], xy[1]))){
          return false;
        }
      } else if (!ok1 && ok2) {
        // player 2 can place. if player 1 can place at any point
        // adjacent to this one, the board is not complete.
        if (adjacencies(x,y).some( (xy) => okToPlace(gr, 1, xy[0], xy[1]) ) ) {
          return false;
        }
      } else if (!ok1 && !ok2) {
        // no-man's land
      }
    }
  }
  return true;
}

controller(gr, x, y) {
  var ok1 = okToPlace(gr, 1, x, y) || gridAt(gr, x,y) == 1,
      ok2 = okToPlace(gr, 2, x, y) || gridAt(gr, x,y) == 2;
  if (ok1 && !ok2) return 1;
  if (ok2 && !ok1) return 2;
  return 0;
}

territory(gr, player) {
  var num = 0;
  for (var y = 0; y < gr["height"]; y++) {
    for (var x = 0; x < gr["width"]; x++) {
      if (controller(gr, x, y) == player) {
        num++;
      }
    }
  }
  return num;
}

boardMouseMoved(e) {
  var board = query('#board').getBoundingClientRect();

  var x = e.pageX - board.left, 
      y = e.pageY - board.top;

  var hex = hexForPixel(x,y);
  if (hex != null) {
    selectedX = hex["x"];
    selectedY = hex["y"];
  } else {
    selectedX = null;
    selectedY = null;
  }
  redraw();
}

boardMouseClicked(e) {
  var board = query('#board').getBoundingClientRect();

  var x = e.pageX - board.left, 
      y = e.pageY - board.top;
  var hex = hexForPixel(x,y);
  if (hex != null && hex["x"] >= 0 && hex["x"] < grid["width"] &&
      hex["y"] >= 0 && hex["y"] < grid["height"] &&
      okToPlace(grid, playerTurn, hex["x"], hex["y"])) {
    //grid.values[hex.y*grid["width"]+hex.x] = playerTurn;
    
    // LR(String key, dynamic before, dynamic after, [List path])
    // OR(String key, dynamic before, dynamic after, [List path])
    var op = JSON.Op()
        .LR((hex["y"]*grid["width"]+hex["x"]).toInt(), 0, playerTurn, ['grid', 'values'])
        .OR('playerTurn', playerTurn, playerTurn == 1 ? 2 : 1);
    
    $state.submitOp(op);
  }
}

redraw() {
  var board = query('#board');
  var ctx = board.context2d;
  ctx.clearRect(0, 0, board.clientWidth, board.clientHeight);
  drawGrid(ctx, grid);

  ctx.font = '30px sans-serif';
  ctx.textBaseline = 'top';
  ctx.fillStyle = colorStyle(playerColors[playerTurn-1]);
  ctx.fillText('Player $playerTurn', 400,100);

  ctx.font = '20px sans-serif';
  ctx.fillStyle = colorStyle(playerColors[0]);
  ctx.fillText('P1: ${territory(grid, 1)}', 400,140);

  ctx.fillStyle = colorStyle(playerColors[1]);
  ctx.fillText('P2: ${territory(grid, 2)}', 400,165);

  if (isComplete(grid)) {
    ctx.fillStyle = '#000';
    ctx.fillText('Board complete!', 400,200);
  }
}

clear() {
  var size = grid["width"] * grid["height"];
  grid["values"] = [];
  while(--size >= 0) grid["values"].add(0);
}

reset() {
  clear();
  playerTurn = 1;
  // OR(String key, dynamic before, dynamic after, [List path])
  var op = JSON.Op()
      .OR('values', $state.snapshot["grid"]["values"], grid["values"], ['grid'])
      .OR('playerTurn', $state.snapshot["playerTurn"], playerTurn);

  $state.submitOp(op);
}

begin() {
  var board = query('#board');
  board.on.mouseMove.add(boardMouseMoved);
  board.on.click.add(boardMouseClicked);
  redraw();
}

hue2rgb(p, q, t) {
  if(t < 0) t += 1;
  if(t > 1) t -= 1;
  if(t < 1/6) return p + (q - p) * 6 * t;
  if(t < 1/2) return q;
  if(t < 2/3) return p + (q - p) * (2/3 - t) * 6;
  return p;
}

hslToRgb(h, s, l){
  var r, g, b;

  if(s == 0){
    r = g = b = l; // achromatic
  } else {
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    var p = 2 * l - q;
    r = hue2rgb(p, q, h + 1/3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1/3);
  }

  return '#${(r * 255).round().toStringAsFixed(16)}${(g * 255).round().toStringAsFixed(16)}${(b * 255).round().toStringAsFixed(16)}';
}

colorForName(name) {
  var x = 0;
  var p = 31;
  for (var i = 0; i < name.length; i++) {
    var c = name.charCodeAt(i);
    x += c * p;
    p *= p;
    x = x % 4294967295;
  }
  var h = (x % 89)/89;
  var color = hslToRgb(h, 0.7, 0.3);
  return color;
}

addChatMessage(m) {
  var msg = new Element.html('<div class="message"><div class="user"></div><div class="text"></div></div>')
  ..query('.text').text = m["message"]
  ..query('.user').text = m["from"]
  ..query('.user')..style.color = colorForName(m["from"]);

  query('#chat #messages').elements.add(msg);
  var allMsgs = queryAll('.message');
  if (allMsgs.length > 15) {
    allMsgs.getRange(0, Math.max(0,allMsgs.length - 15)).forEach( (e) {
      e.remove();
    });
  }
}

stateUpdated([op]) {
  if (?op) {
    var ops = query('#ops');
    var opel = new Element.html('<div class="op">');
    opel.text = Strings.join(op.map((c) => c.toMap().toString()), " , ");
    ops.elements.add(opel);
    //opel.fadeIn('fast')
    var allOps = queryAll('.op');
    if (allOps.length > 10) {
      allOps.getRange(0, Math.max(0,allOps.length - 10)).forEach((e) {
        e.remove();
      });
    }
    op.forEach((c) {
      if (!c.path.isEmpty && c.path[0] == 'chat' && c.isListInsert()) {
        addChatMessage(c.data);
      }
    });
  } else {
    // first run
    var msgs = $state.snapshot["chat"];
   msgs = msgs.getRange(0, Math.min(10, msgs.length));
    var i = msgs.length;
    while(--i >= 0) { addChatMessage(msgs[i]); }
  }
  query('#doc').text = $state.snapshot.toString();
  grid = $state.snapshot["grid"];
  playerTurn = $state.snapshot["playerTurn"];
  redraw();
}

main(){
      var username = readCookie('username');
      if (username == null) {
        username = randomDocName(4);
        createCookie('username', username, 5);
      }

      query('#reset').on.click.add((_) => reset());
      
      query('#message').on.keyDown.add( (KeyboardEvent e) {
        if ((e.keyCode == 13) || (e.which == 13)) {
          if ((e.target as InputElement).value == null) return;
          // enter was pressed
          // LI(int index, dynamic obj, [List path])
          var op = JSON.Op().LI(0, {
            "from": username,
            "message": (e.target as InputElement).value
          }, ["chat"]);
          $state.submitOp(op);
          (e.target as InputElement).value = '';
        }
      });

      

      if (window.location.hash == null || window.location.hash.isEmpty) {
        window.location.hash = '#${randomDocName()}';
      }

      var docname = 'hex:${window.location.hash.substring(1)}';

      var client = new share.Client(new ws.Connection());

      var connection = client.open(docname, 'json', 'localhost:8000').then((doc) {
        $state = doc;
        doc.on.change.add((opEvt) => stateUpdated(opEvt.op));
        if (doc.created) {
          clear();
          var op = JSON.Op().OI(null, {"grid": grid, "playerTurn":1, "chat":[]});
          doc.submitOp(op);
        } else {
          stateUpdated();
        }
        begin();
      });
}
