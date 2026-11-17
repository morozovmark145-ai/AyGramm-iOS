// Плагин AyGramm «Заглавная буква». Получает текст исходящего сообщения и возвращает новый.
function onOutgoingText(text) {
  return text.replace(/(^\s*|[.!?]\s+)([a-zа-яё])/g, function (match, before, letter) {
    return before + letter.toUpperCase();
  });
}
