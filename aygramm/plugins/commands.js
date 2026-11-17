// Команды
// Плагин AyGramm «Команды»: .calc 2+2*3 → 2+2*3 = 8, .time → текущее время, .shrug → ¯\_(ツ)_/¯
function onOutgoingText(text) {
  var t = text.trim();
  if (t.indexOf(".calc ") === 0) {
    var expr = t.slice(6);
    if (!/^[0-9+\-*/().,\s%]+$/.test(expr)) {
      return text;
    }
    try {
      var value = Function("return (" + expr.replace(/,/g, ".") + ")")();
      return expr + " = " + (Math.round(value * 1e10) / 1e10);
    } catch (e) {
      return text;
    }
  }
  if (t === ".time") {
    var d = new Date();
    var pad = function (n) { return (n < 10 ? "0" : "") + n; };
    return "Сейчас " + pad(d.getHours()) + ":" + pad(d.getMinutes());
  }
  if (t === ".shrug") {
    return "¯\\_(ツ)_/¯";
  }
  return text;
}
