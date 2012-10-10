class WSClientConnection extends client.Connection {
  WebSocketClientConnection _ws;
  
  doConnect(completer) {
    var uri = new Uri.fromString(origin);
    
    var conn = new HttpClient().get(uri.domain, uri.port, uri.path);
    _ws = new WebSocketClientConnection(conn);
    
    _ws.onOpen = () => handleOpen(completer);
    
    _ws.onClosed = (int status, String reason) => handleClose();
    
    _ws.onMessage = (Object m) => handleMessage(m);
     
  }
  
  doSend(String msg) => _ws.send(msg);
  
  doDisconnect() => _ws.close();
  
}

Pair<TextOperation, String> generateRandomOp(String docStr) {

  var pct = 0.9;
  var op = new TextOperation();
  var rnd = new Math.Random();
  
  while(rnd.nextDouble() < pct) {

    pct /= 2;
    
    if (rnd.nextDouble() > 0.5 || ( docStr.length == 0 ) ) {
      // Append an insert
      var pos = rnd.nextInt((docStr.length + 1));
      var str = "${randomWord()} ";
      op.I(str, pos);
      docStr = "${docStr.substring(0, pos)}$str${docStr.substring(pos)}";
    } else {
      // Append a delete
      var pos = rnd.nextInt(docStr.length);
      var length = Math.min(rnd.nextInt(4), docStr.length - pos);
      op.D(docStr.substring(pos, pos + length), pos);
      //print("generated D('${docStr.substring(pos, pos + length)}',${pos}) on '$docStr'");
      docStr = "${docStr.substring(0, pos)}${docStr.substring(pos + length)}";
    }
  }
 
  return new Pair(op, docStr);
}
    
Future<List> doubleOpen(c1, c2, docName, type) => Futures.wait([c1.open(docName, type), c2.open(docName, type)]);

class IntegrationTests {
  static void run(){
    
    loadRandomWords();
    
    var Text = OT["text"];
    var docName = "testingdoc";
    var type = "text";

    group("integration tests", () {
      
      var server, c1, c2, testDone;
      
      Future<List> doConnect;
      
      setUp( () {
        
        testDone = new Completer<bool>().future;
        
        server = share.attach(new HttpServer());
        
        server.listen('127.0.0.1', 0);
        
        var port = server.port;
   
        c1 = new WSClientConnection();
        c2 = new WSClientConnection();
        doConnect = Futures.wait([c1.connect("http://127.0.0.1:$port/ws"), c2.connect("http://127.0.0.1:$port/ws")]);
      });
      
      doTearDown() {
        c1.disconnect();
        c2.disconnect();
        
        server.close();
      }
      
      test('ops submitted on one document get sent to another', () {
       
        doConnect
        .chain((_) => doubleOpen(c1, c2, "testingdoc", "text"))
        .then(expectAsync1((docs) {
          var doc1 = docs[0];
          var doc2 = docs[1];
          
          var res = generateRandomOp(doc1.snapshot);
          var submittedOp = res.left;
          var result = res.right;
          
          doc1.submitOp(submittedOp);
          
          doc2.on.remoteOp.add(expectAsync1( (evt) {
            var op = evt.op;
            expect(op, equals(submittedOp));
            expect(doc2.snapshot, equals(result));
            expect(doc2.version, equals(1));
            
            doTearDown();
          }));
        }));
        return;
      });
      
      /*
      test('JSON documents work', () {
        doConnect
        .chain((_) => doubleOpen(c1, c2, "jsondocument", "json"))
        .then(expectAsync1( (docs) {
          var doc1 = docs[0];
          var doc2 = docs[1];
          
          expect(doc1.snapshot == null);
          expect(doc1.version).equals(0);
          expect(doc2.snapshot == null);
          expect(doc2.version).equals(0);
          expect(doc1.created != doc2.created);
          
          doc1.submitOp(submittedOp);
          
          doc2.on.remoteOp.add(expectAsync1( (evt) {
            var op = evt.op;
            expect(doc2.snapshot).equals(new Object());
          }));
        }));
      });*/
      
      test('randomized op spam test', () {
        doConnect
        .chain((_) => doubleOpen(c1, c2, "testingdoc", "text"))
        .then(expectAsync1( (docs) {
          var doc1 = docs[0];
          var doc2 = docs[1];
          
          // TODO - This test fails with more ops!
          var opsRemaining = 20;
          var inflight = 0;
          var maxV = 0;
          
          var checkSync = null;
          var testSome = null;
          
          testSome = () {
            
            var rnd = new Math.Random();
            var ops = Math.min(rnd.nextInt(10) + 1, opsRemaining);
            inflight = ops;
            opsRemaining -= ops;
            
            for ( var k = 0; k < ops; k++) {
              client.Doc doc = (rnd.nextDouble() > 0.4) ? doc1 : doc2;
              
              var res = generateRandomOp(doc.snapshot);
              var op = res.left;
              var expected = res.right;
              
              checkSync = () {
                if (inflight == 0 && doc1.version == maxV && doc2.version == maxV) {
                  // The docs should be in sync.

                  expect(doc1.snapshot, equals(doc2.snapshot));

                  (opsRemaining > 0) ? testSome() : doTearDown();
                }
              };
              
              doc.submitOp(op).then( expectAsync1( (_) {
                maxV = Math.max(maxV, doc.version);
                inflight--;
                checkSync();
              }));
           }
          };
          
          doc1.on.remoteOp.add((evt) {
            maxV = Math.max(maxV, doc1.version);
            checkSync();
          });
            
          doc2.on.remoteOp.add((evt) {
            maxV = Math.max(maxV, doc2.version);
            checkSync();
          });
          
          testSome();
        }));
        
      });
      
    });
  }
}
