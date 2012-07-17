var randomWord = null;

int randomInt(num max) => (Math.random() * max).toInt();

void readWordFile(String filename) {
  var file = new File(filename);
  file.readAsText(Encoding.ASCII)
  .transform((String text) => text.split(new RegExp(@"\W+")))
  .then((words) {
    randomWord = () => words[randomInt(words.length)];
  });
}

loadRandomWords() {
  if(randomWord == null) {  
    File script = new File(new Options().script);
    script.directory().then((Directory d) {
      readWordFile("${d.path}/types/jabberwocky.txt"); 
    }); 
  }
}

