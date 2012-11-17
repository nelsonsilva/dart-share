part of html_tests;

var randomWord = null;

int randomInt(num max) => new Math.Random().nextInt(max);

void readWordFile(String filename) {
  var file = new File(filename);
  file.readAsText(Encoding.ASCII)
  .transform((String text) => text.split(new RegExp(r"\W+")))
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

