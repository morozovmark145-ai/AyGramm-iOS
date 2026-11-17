// Плагин AyGramm «Смайлы в эмодзи». Меняет текстовые смайлы, отделённые пробелами, на эмодзи.
var smileys = { ":)": "🙂", ";)": "😉", ":(": "🙁", ":D": "😄", "<3": "❤️" };
function onOutgoingText(text) {
  return text.replace(/(^|\s)(:\)|;\)|:\(|:D|<3)(?=\s|$)/g, function (match, before, smile) {
    return before + smileys[smile];
  });
}
