// Плагин AyGramm «Без точки в конце». Многоточие остаётся.
function onOutgoingText(text) {
  if (/[^.]\.$/.test(text)) {
    return text.slice(0, -1);
  }
  return text;
}
