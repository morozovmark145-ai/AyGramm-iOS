import Foundation

// Встроенный плагин «Шрифт сообщений»: исходящий текст сам меняет вид.
// Стили 1–6 ставят форматирование Telegram на весь текст, оно работает для любых букв.
// Остальные стили заменяют латиницу и цифры символами Unicode (жирный, готический, в кружках и т. д.)
// и добавляют к каждой букве подчёркивание, черту или сердечки. Русские буквы заменяются похожими
// латинскими буквами и цифрами того же начертания, а Г, Д, Л, П, Ф в жирных и курсивных стилях
// становятся греческими Γ, Δ, Λ, Π, Φ того же начертания.
// Ссылки, @имена, #теги и /команды не меняются.
public struct AyGrammFontStyle {
    public let name: String
    let entity: MessageTextEntityType?
    let base: Int
    let mark: String
    let separator: String
    var prefix: String = ""
    var suffix: String = ""
}

public enum AyGrammFonts {
    static let key = "AyGrammFontStyle"
    static let source = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    static let reversedBases: Set<Int> = [23, 25]
    static let baseNames: [String] = ["Обычный", "Жирный", "Курсив", "Жирный курсив", "Рукописный", "Жирный рукописный", "Готический", "Жирный готический", "Двойной контур", "Без засечек", "Без засечек жирный", "Без засечек курсив", "Без засечек жирный курсив", "Пишущая машинка", "Широкий", "В кружках", "Чёрные кружки", "В квадратах", "Чёрные квадраты", "В скобках", "Капитель", "Надстрочный", "Подстрочный", "Вверх ногами", "Под кириллицу", "Зеркальный"]
    static let baseTables: [String] = [
        "A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z|0|1|2|3|4|5|6|7|8|9",
        "𝐀|𝐁|𝐂|𝐃|𝐄|𝐅|𝐆|𝐇|𝐈|𝐉|𝐊|𝐋|𝐌|𝐍|𝐎|𝐏|𝐐|𝐑|𝐒|𝐓|𝐔|𝐕|𝐖|𝐗|𝐘|𝐙|𝐚|𝐛|𝐜|𝐝|𝐞|𝐟|𝐠|𝐡|𝐢|𝐣|𝐤|𝐥|𝐦|𝐧|𝐨|𝐩|𝐪|𝐫|𝐬|𝐭|𝐮|𝐯|𝐰|𝐱|𝐲|𝐳|𝟎|𝟏|𝟐|𝟑|𝟒|𝟓|𝟔|𝟕|𝟖|𝟗",
        "𝐴|𝐵|𝐶|𝐷|𝐸|𝐹|𝐺|𝐻|𝐼|𝐽|𝐾|𝐿|𝑀|𝑁|𝑂|𝑃|𝑄|𝑅|𝑆|𝑇|𝑈|𝑉|𝑊|𝑋|𝑌|𝑍|𝑎|𝑏|𝑐|𝑑|𝑒|𝑓|𝑔|ℎ|𝑖|𝑗|𝑘|𝑙|𝑚|𝑛|𝑜|𝑝|𝑞|𝑟|𝑠|𝑡|𝑢|𝑣|𝑤|𝑥|𝑦|𝑧|0|1|2|3|4|5|6|7|8|9",
        "𝑨|𝑩|𝑪|𝑫|𝑬|𝑭|𝑮|𝑯|𝑰|𝑱|𝑲|𝑳|𝑴|𝑵|𝑶|𝑷|𝑸|𝑹|𝑺|𝑻|𝑼|𝑽|𝑾|𝑿|𝒀|𝒁|𝒂|𝒃|𝒄|𝒅|𝒆|𝒇|𝒈|𝒉|𝒊|𝒋|𝒌|𝒍|𝒎|𝒏|𝒐|𝒑|𝒒|𝒓|𝒔|𝒕|𝒖|𝒗|𝒘|𝒙|𝒚|𝒛|0|1|2|3|4|5|6|7|8|9",
        "𝒜|ℬ|𝒞|𝒟|ℰ|ℱ|𝒢|ℋ|ℐ|𝒥|𝒦|ℒ|ℳ|𝒩|𝒪|𝒫|𝒬|ℛ|𝒮|𝒯|𝒰|𝒱|𝒲|𝒳|𝒴|𝒵|𝒶|𝒷|𝒸|𝒹|ℯ|𝒻|ℊ|𝒽|𝒾|𝒿|𝓀|𝓁|𝓂|𝓃|ℴ|𝓅|𝓆|𝓇|𝓈|𝓉|𝓊|𝓋|𝓌|𝓍|𝓎|𝓏|0|1|2|3|4|5|6|7|8|9",
        "𝓐|𝓑|𝓒|𝓓|𝓔|𝓕|𝓖|𝓗|𝓘|𝓙|𝓚|𝓛|𝓜|𝓝|𝓞|𝓟|𝓠|𝓡|𝓢|𝓣|𝓤|𝓥|𝓦|𝓧|𝓨|𝓩|𝓪|𝓫|𝓬|𝓭|𝓮|𝓯|𝓰|𝓱|𝓲|𝓳|𝓴|𝓵|𝓶|𝓷|𝓸|𝓹|𝓺|𝓻|𝓼|𝓽|𝓾|𝓿|𝔀|𝔁|𝔂|𝔃|0|1|2|3|4|5|6|7|8|9",
        "𝔄|𝔅|ℭ|𝔇|𝔈|𝔉|𝔊|ℌ|ℑ|𝔍|𝔎|𝔏|𝔐|𝔑|𝔒|𝔓|𝔔|ℜ|𝔖|𝔗|𝔘|𝔙|𝔚|𝔛|𝔜|ℨ|𝔞|𝔟|𝔠|𝔡|𝔢|𝔣|𝔤|𝔥|𝔦|𝔧|𝔨|𝔩|𝔪|𝔫|𝔬|𝔭|𝔮|𝔯|𝔰|𝔱|𝔲|𝔳|𝔴|𝔵|𝔶|𝔷|0|1|2|3|4|5|6|7|8|9",
        "𝕬|𝕭|𝕮|𝕯|𝕰|𝕱|𝕲|𝕳|𝕴|𝕵|𝕶|𝕷|𝕸|𝕹|𝕺|𝕻|𝕼|𝕽|𝕾|𝕿|𝖀|𝖁|𝖂|𝖃|𝖄|𝖅|𝖆|𝖇|𝖈|𝖉|𝖊|𝖋|𝖌|𝖍|𝖎|𝖏|𝖐|𝖑|𝖒|𝖓|𝖔|𝖕|𝖖|𝖗|𝖘|𝖙|𝖚|𝖛|𝖜|𝖝|𝖞|𝖟|0|1|2|3|4|5|6|7|8|9",
        "𝔸|𝔹|ℂ|𝔻|𝔼|𝔽|𝔾|ℍ|𝕀|𝕁|𝕂|𝕃|𝕄|ℕ|𝕆|ℙ|ℚ|ℝ|𝕊|𝕋|𝕌|𝕍|𝕎|𝕏|𝕐|ℤ|𝕒|𝕓|𝕔|𝕕|𝕖|𝕗|𝕘|𝕙|𝕚|𝕛|𝕜|𝕝|𝕞|𝕟|𝕠|𝕡|𝕢|𝕣|𝕤|𝕥|𝕦|𝕧|𝕨|𝕩|𝕪|𝕫|𝟘|𝟙|𝟚|𝟛|𝟜|𝟝|𝟞|𝟟|𝟠|𝟡",
        "𝖠|𝖡|𝖢|𝖣|𝖤|𝖥|𝖦|𝖧|𝖨|𝖩|𝖪|𝖫|𝖬|𝖭|𝖮|𝖯|𝖰|𝖱|𝖲|𝖳|𝖴|𝖵|𝖶|𝖷|𝖸|𝖹|𝖺|𝖻|𝖼|𝖽|𝖾|𝖿|𝗀|𝗁|𝗂|𝗃|𝗄|𝗅|𝗆|𝗇|𝗈|𝗉|𝗊|𝗋|𝗌|𝗍|𝗎|𝗏|𝗐|𝗑|𝗒|𝗓|𝟢|𝟣|𝟤|𝟥|𝟦|𝟧|𝟨|𝟩|𝟪|𝟫",
        "𝗔|𝗕|𝗖|𝗗|𝗘|𝗙|𝗚|𝗛|𝗜|𝗝|𝗞|𝗟|𝗠|𝗡|𝗢|𝗣|𝗤|𝗥|𝗦|𝗧|𝗨|𝗩|𝗪|𝗫|𝗬|𝗭|𝗮|𝗯|𝗰|𝗱|𝗲|𝗳|𝗴|𝗵|𝗶|𝗷|𝗸|𝗹|𝗺|𝗻|𝗼|𝗽|𝗾|𝗿|𝘀|𝘁|𝘂|𝘃|𝘄|𝘅|𝘆|𝘇|𝟬|𝟭|𝟮|𝟯|𝟰|𝟱|𝟲|𝟳|𝟴|𝟵",
        "𝘈|𝘉|𝘊|𝘋|𝘌|𝘍|𝘎|𝘏|𝘐|𝘑|𝘒|𝘓|𝘔|𝘕|𝘖|𝘗|𝘘|𝘙|𝘚|𝘛|𝘜|𝘝|𝘞|𝘟|𝘠|𝘡|𝘢|𝘣|𝘤|𝘥|𝘦|𝘧|𝘨|𝘩|𝘪|𝘫|𝘬|𝘭|𝘮|𝘯|𝘰|𝘱|𝘲|𝘳|𝘴|𝘵|𝘶|𝘷|𝘸|𝘹|𝘺|𝘻|0|1|2|3|4|5|6|7|8|9",
        "𝘼|𝘽|𝘾|𝘿|𝙀|𝙁|𝙂|𝙃|𝙄|𝙅|𝙆|𝙇|𝙈|𝙉|𝙊|𝙋|𝙌|𝙍|𝙎|𝙏|𝙐|𝙑|𝙒|𝙓|𝙔|𝙕|𝙖|𝙗|𝙘|𝙙|𝙚|𝙛|𝙜|𝙝|𝙞|𝙟|𝙠|𝙡|𝙢|𝙣|𝙤|𝙥|𝙦|𝙧|𝙨|𝙩|𝙪|𝙫|𝙬|𝙭|𝙮|𝙯|0|1|2|3|4|5|6|7|8|9",
        "𝙰|𝙱|𝙲|𝙳|𝙴|𝙵|𝙶|𝙷|𝙸|𝙹|𝙺|𝙻|𝙼|𝙽|𝙾|𝙿|𝚀|𝚁|𝚂|𝚃|𝚄|𝚅|𝚆|𝚇|𝚈|𝚉|𝚊|𝚋|𝚌|𝚍|𝚎|𝚏|𝚐|𝚑|𝚒|𝚓|𝚔|𝚕|𝚖|𝚗|𝚘|𝚙|𝚚|𝚛|𝚜|𝚝|𝚞|𝚟|𝚠|𝚡|𝚢|𝚣|𝟶|𝟷|𝟸|𝟹|𝟺|𝟻|𝟼|𝟽|𝟾|𝟿",
        "Ａ|Ｂ|Ｃ|Ｄ|Ｅ|Ｆ|Ｇ|Ｈ|Ｉ|Ｊ|Ｋ|Ｌ|Ｍ|Ｎ|Ｏ|Ｐ|Ｑ|Ｒ|Ｓ|Ｔ|Ｕ|Ｖ|Ｗ|Ｘ|Ｙ|Ｚ|ａ|ｂ|ｃ|ｄ|ｅ|ｆ|ｇ|ｈ|ｉ|ｊ|ｋ|ｌ|ｍ|ｎ|ｏ|ｐ|ｑ|ｒ|ｓ|ｔ|ｕ|ｖ|ｗ|ｘ|ｙ|ｚ|０|１|２|３|４|５|６|７|８|９",
        "Ⓐ|Ⓑ|Ⓒ|Ⓓ|Ⓔ|Ⓕ|Ⓖ|Ⓗ|Ⓘ|Ⓙ|Ⓚ|Ⓛ|Ⓜ|Ⓝ|Ⓞ|Ⓟ|Ⓠ|Ⓡ|Ⓢ|Ⓣ|Ⓤ|Ⓥ|Ⓦ|Ⓧ|Ⓨ|Ⓩ|ⓐ|ⓑ|ⓒ|ⓓ|ⓔ|ⓕ|ⓖ|ⓗ|ⓘ|ⓙ|ⓚ|ⓛ|ⓜ|ⓝ|ⓞ|ⓟ|ⓠ|ⓡ|ⓢ|ⓣ|ⓤ|ⓥ|ⓦ|ⓧ|ⓨ|ⓩ|⓪|①|②|③|④|⑤|⑥|⑦|⑧|⑨",
        "🅐|🅑|🅒|🅓|🅔|🅕|🅖|🅗|🅘|🅙|🅚|🅛|🅜|🅝|🅞|🅟|🅠|🅡|🅢|🅣|🅤|🅥|🅦|🅧|🅨|🅩|🅐|🅑|🅒|🅓|🅔|🅕|🅖|🅗|🅘|🅙|🅚|🅛|🅜|🅝|🅞|🅟|🅠|🅡|🅢|🅣|🅤|🅥|🅦|🅧|🅨|🅩|⓿|❶|❷|❸|❹|❺|❻|❼|❽|❾",
        "🄰|🄱|🄲|🄳|🄴|🄵|🄶|🄷|🄸|🄹|🄺|🄻|🄼|🄽|🄾|🄿|🅀|🅁|🅂|🅃|🅄|🅅|🅆|🅇|🅈|🅉|🄰|🄱|🄲|🄳|🄴|🄵|🄶|🄷|🄸|🄹|🄺|🄻|🄼|🄽|🄾|🄿|🅀|🅁|🅂|🅃|🅄|🅅|🅆|🅇|🅈|🅉|0|1|2|3|4|5|6|7|8|9",
        "🅰|🅱|🅲|🅳|🅴|🅵|🅶|🅷|🅸|🅹|🅺|🅻|🅼|🅽|🅾|🅿|🆀|🆁|🆂|🆃|🆄|🆅|🆆|🆇|🆈|🆉|🅰|🅱|🅲|🅳|🅴|🅵|🅶|🅷|🅸|🅹|🅺|🅻|🅼|🅽|🅾|🅿|🆀|🆁|🆂|🆃|🆄|🆅|🆆|🆇|🆈|🆉|0|1|2|3|4|5|6|7|8|9",
        "⒜|⒝|⒞|⒟|⒠|⒡|⒢|⒣|⒤|⒥|⒦|⒧|⒨|⒩|⒪|⒫|⒬|⒭|⒮|⒯|⒰|⒱|⒲|⒳|⒴|⒵|⒜|⒝|⒞|⒟|⒠|⒡|⒢|⒣|⒤|⒥|⒦|⒧|⒨|⒩|⒪|⒫|⒬|⒭|⒮|⒯|⒰|⒱|⒲|⒳|⒴|⒵|0|⑴|⑵|⑶|⑷|⑸|⑹|⑺|⑻|⑼",
        "ᴀ|ʙ|ᴄ|ᴅ|ᴇ|ꜰ|ɢ|ʜ|ɪ|ᴊ|ᴋ|ʟ|ᴍ|ɴ|ᴏ|ᴘ|ǫ|ʀ|ꜱ|ᴛ|ᴜ|ᴠ|ᴡ|x|ʏ|ᴢ|ᴀ|ʙ|ᴄ|ᴅ|ᴇ|ꜰ|ɢ|ʜ|ɪ|ᴊ|ᴋ|ʟ|ᴍ|ɴ|ᴏ|ᴘ|ǫ|ʀ|ꜱ|ᴛ|ᴜ|ᴠ|ᴡ|x|ʏ|ᴢ|0|1|2|3|4|5|6|7|8|9",
        "ᴬ|ᴮ|ᶜ|ᴰ|ᴱ|ᶠ|ᴳ|ᴴ|ᴵ|ᴶ|ᴷ|ᴸ|ᴹ|ᴺ|ᴼ|ᴾ|Q|ᴿ|ˢ|ᵀ|ᵁ|ⱽ|ᵂ|ˣ|ʸ|ᶻ|ᵃ|ᵇ|ᶜ|ᵈ|ᵉ|ᶠ|ᵍ|ʰ|ⁱ|ʲ|ᵏ|ˡ|ᵐ|ⁿ|ᵒ|ᵖ|q|ʳ|ˢ|ᵗ|ᵘ|ᵛ|ʷ|ˣ|ʸ|ᶻ|⁰|¹|²|³|⁴|⁵|⁶|⁷|⁸|⁹",
        "ₐ|B|C|D|ₑ|F|G|ₕ|ᵢ|ⱼ|ₖ|ₗ|ₘ|ₙ|ₒ|ₚ|Q|ᵣ|ₛ|ₜ|ᵤ|ᵥ|W|ₓ|Y|Z|ₐ|b|c|d|ₑ|f|g|ₕ|ᵢ|ⱼ|ₖ|ₗ|ₘ|ₙ|ₒ|ₚ|q|ᵣ|ₛ|ₜ|ᵤ|ᵥ|w|ₓ|y|z|₀|₁|₂|₃|₄|₅|₆|₇|₈|₉",
        "∀|ꓭ|Ɔ|ᗡ|Ǝ|Ⅎ|⅁|H|I|ſ|ꓘ|˥|W|N|O|Ԁ|Ὸ|ᴚ|S|⊥|∩|Λ|M|X|⅄|Z|ɐ|q|ɔ|p|ǝ|ɟ|ƃ|ɥ|ᴉ|ɾ|ʞ|l|ɯ|u|o|d|b|ɹ|s|ʇ|n|ʌ|ʍ|x|ʎ|z|0|Ɩ|ᄅ|Ɛ|ㄣ|ϛ|9|ㄥ|8|6",
        "Д|Б|C|D|Є|Ғ|G|Н|Ї|Ј|К|L|М|И|Ө|Р|Q|Я|Ѕ|Т|Ц|V|Щ|Ж|Ч|Z|д|ъ|c|ↁ|э|f|Б|Ђ|і|ј|к|l|м|и|о|р|q|ѓ|ѕ|т|ц|v|ш|х|у|z|0|1|2|3|4|5|6|7|8|9",
        "A|ᙠ|Ɔ|ᗡ|Ǝ|ꟻ|Ꭾ|H|I|Ⴑ|ᐴ|⅃|M|И|O|ꟼ|Ọ|Я|Ꙅ|T|U|V|W|X|Y|Ƹ|ɒ|d|ɔ|b|ɘ|ʇ|ϱ|ʜ|i|į|ʞ|l|m|n|o|q|p|ɿ|ƨ|ƚ|υ|v|w|x|γ|z|0|Ɩ|ς|Ɛ|μ|ट|მ|٢|8|୧",
    ]
    static let decorations: [(String, String, String)] = [
        ("", "", ""),
        ("подчёркнутый", "\u{0332}", ""),
        ("двойное подчёркивание", "\u{0333}", ""),
        ("зачёркнутый", "\u{0336}", ""),
        ("перечёркнутый косой", "\u{0338}", ""),
        ("с чертой сверху", "\u{0305}", ""),
        ("с точками снизу", "\u{0324}", ""),
        ("с сердечками", "", "♥"),
    ]

    static let entityStyles: [(String, MessageTextEntityType)] = [
        ("Жирный (Telegram)", .Bold),
        ("Курсив (Telegram)", .Italic),
        ("Моноширинный (Telegram)", .Code),
        ("Подчёркнутый (Telegram)", .Underline),
        ("Зачёркнутый (Telegram)", .Strikethrough),
        ("Скрытый (Telegram)", .Spoiler),
    ]

    // Рамки для ников в стиле стримеров: значки до и после всего сообщения. Работают и с русскими буквами.
    static let frames: [(String, String, String)] = [
        ("Мелстрой", "💸👑 ", " 👑💸"),
        ("Корона", "👑 ", " 👑"),
        ("Узоры", "꧁༺ ", " ༻꧂"),
        ("Звёзды", "★彡 ", " 彡★"),
        ("Мешки денег", "💰 ", " 💰"),
        ("Молнии", "⚡ ", " ⚡"),
        ("Огонь", "🔥 ", " 🔥"),
        ("Бриллианты", "💎 ", " 💎"),
        ("Скобки 『』", "『", "』"),
        ("Скобки 【】", "【", "】"),
        ("Знак 亗", "亗 ", " 亗"),
        ("Знак 乂", "乂 ", " 乂"),
        ("Цветы", "✿ ", " ✿"),
        ("Стрелки", "»» ", " ««"),
        ("Ромбы", "◆ ", " ◆"),
        ("Сердечки", "♡ ", " ♡"),
    ]
    // Начертания для рамок: обычные буквы, капитель, жирный, жирный готический.
    static let frameBases: [Int] = [0, 20, 1, 7]

    // Все стили: 0 = «Обычный» (плагин выключен), дальше 6 стилей Telegram, 207 стилей Unicode и 64 рамки для ников.
    public static let styles: [AyGrammFontStyle] = {
        var result: [AyGrammFontStyle] = [AyGrammFontStyle(name: "Обычный", entity: nil, base: 0, mark: "", separator: "")]
        for (name, type) in entityStyles {
            result.append(AyGrammFontStyle(name: name, entity: type, base: 0, mark: "", separator: ""))
        }
        for base in 0 ..< baseNames.count {
            for (decorationIndex, decoration) in decorations.enumerated() {
                if base == 0 && decorationIndex == 0 {
                    continue
                }
                var name = baseNames[base]
                if !decoration.0.isEmpty {
                    if base == 0 {
                        name = String(decoration.0.prefix(1)).uppercased() + String(decoration.0.dropFirst())
                    } else {
                        name = name + ", " + decoration.0
                    }
                }
                result.append(AyGrammFontStyle(name: name, entity: nil, base: base, mark: decoration.1, separator: decoration.2))
            }
        }
        for base in frameBases {
            for frame in frames {
                let baseName = base == 0 ? "Ник" : "Ник, " + baseNames[base].lowercased()
                result.append(AyGrammFontStyle(name: baseName + ", " + frame.0, entity: nil, base: base, mark: "", separator: "", prefix: frame.1, suffix: frame.2))
            }
        }
        return result
    }()

    // Разделы меню выбора: «Без шрифта», стили Telegram и по разделу на каждое начертание.
    // Номера стилей идут в том же порядке, что и в styles.
    public static let menuSections: [(String, [(Int, String)])] = {
        var sections: [(String, [(Int, String)])] = []
        sections.append(("Без шрифта", [(0, "Плагин выключен")]))
        sections.append(("Форматирование Telegram", (1 ... entityStyles.count).map { ($0, "Работает и для русских букв") }))
        var index = entityStyles.count + 1
        for base in 0 ..< baseNames.count {
            var items: [(Int, String)] = []
            for (decorationIndex, decoration) in decorations.enumerated() {
                if base == 0 && decorationIndex == 0 {
                    continue
                }
                let title = decoration.0.isEmpty ? "Без украшений" : String(decoration.0.prefix(1)).uppercased() + String(decoration.0.dropFirst())
                items.append((index, title))
                index += 1
            }
            sections.append((base == 0 ? "Обычные буквы" : baseNames[base], items))
        }
        for base in frameBases {
            var items: [(Int, String)] = []
            for frame in frames {
                items.append((index, frame.0))
                index += 1
            }
            sections.append((base == 0 ? "Ники: обычные буквы" : "Ники: " + baseNames[base].lowercased(), items))
        }
        return sections
    }()

    // Русская буква: похожая латиница или цифра и номер похожей греческой буквы в блоке математических символов.
    // Без пары остаются Ж и Ц, а Г, Л, Ф остаются русскими там, где у начертания нет греческих букв.
    static let cyrillicLookalikes: [Character: (String?, UInt32?)] = [
        "А": ("A", nil), "Б": ("6", nil), "В": ("B", nil), "Г": (nil, 2), "Д": ("D", 3), "Е": ("E", nil), "Ё": ("E", nil),
        "З": ("3", nil), "И": ("U", nil), "Й": ("U", nil), "К": ("K", nil), "Л": (nil, 10), "М": ("M", nil), "Н": ("H", nil),
        "О": ("O", nil), "П": (nil, 15), "Р": ("P", nil), "С": ("C", nil), "Т": ("T", nil), "У": ("Y", nil), "Ф": (nil, 21),
        "Х": ("X", nil), "Ч": ("4", nil), "Ш": ("W", nil), "Щ": ("W", nil), "Ъ": ("b", nil), "Ы": ("bI", nil), "Ь": ("b", nil),
        "Э": ("3", nil), "Ю": ("IO", nil), "Я": ("R", nil),
        "а": ("a", nil), "б": ("6", nil), "в": ("B", nil), "г": ("r", nil), "д": ("g", 29), "е": ("e", nil), "ё": ("e", nil),
        "з": ("3", nil), "и": ("u", nil), "й": ("u", nil), "к": ("k", nil), "л": (nil, 36), "м": ("m", nil), "н": ("H", nil),
        "о": ("o", nil), "п": ("n", 41), "р": ("p", nil), "с": ("c", nil), "т": ("T", nil), "у": ("y", nil), "ф": (nil, 47),
        "х": ("x", nil), "ч": ("4", nil), "ш": ("w", nil), "щ": ("w", nil), "ъ": ("b", nil), "ы": ("bl", nil), "ь": ("b", nil),
        "э": ("3", nil), "ю": ("io", nil), "я": ("R", nil),
        "І": ("I", nil), "і": ("i", nil), "Ї": ("I", nil), "ї": ("i", nil), "Є": ("E", nil), "є": ("e", nil), "Ў": ("Y", nil), "ў": ("y", nil)
    ]
    // Первая греческая буква (Α) жирного, курсивного, жирного курсивного и двух жирных стилей без засечек.
    static let greekStarts: [Int: UInt32] = [1: 0x1D6A8, 2: 0x1D6E2, 3: 0x1D71C, 10: 0x1D756, 12: 0x1D790]
    // «Обычные буквы» и «Под кириллицу» русские буквы не меняют.
    static let cyrillicSkipBases: Set<Int> = [0, 24]

    static func cyrillic(_ character: Character, base: Int, table: [Character: String]) -> String? {
        if cyrillicSkipBases.contains(base) {
            return nil
        }
        guard let entry = cyrillicLookalikes[character] else {
            return nil
        }
        if let offset = entry.1, let start = greekStarts[base], let scalar = Unicode.Scalar(start + offset) {
            return String(Character(scalar))
        }
        guard let latin = entry.0 else {
            return nil
        }
        var result = ""
        for letter in latin {
            result += table[letter] ?? String(letter)
        }
        return result
    }

    // Таблицы замены строятся один раз при первом обращении.
    static let tables: [[Character: String]] = baseTables.map { row -> [Character: String] in
        var table: [Character: String] = [:]
        let targets = row.components(separatedBy: "|")
        for (index, character) in source.enumerated() where index < targets.count {
            table[character] = targets[index]
        }
        return table
    }

    public static var selectedIndex: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: key)
            return value >= 0 && value < styles.count ? value : 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            if newValue > 0 {
                UserDefaults.standard.set(newValue, forKey: lastKey)
            }
        }
    }

    // Кнопка в меню «Отправить» (долгое нажатие): включает последний выбранный шрифт или выключает шрифт.
    static let lastKey = "AyGrammFontLastStyle"

    static var lastIndex: Int {
        let value = UserDefaults.standard.integer(forKey: lastKey)
        return value > 0 && value < styles.count ? value : 1
    }

    public static var quickTitle: String {
        let current = selectedIndex
        if current != 0 {
            return "Выключить шрифт «\(styles[current].name)»"
        }
        return "Включить шрифт «\(styles[lastIndex].name)»"
    }

    public static func toggleQuick() {
        selectedIndex = selectedIndex != 0 ? 0 : lastIndex
    }

    public static var selected: AyGrammFontStyle? {
        let index = selectedIndex
        return index == 0 ? nil : styles[index]
    }

    // Ссылки, @имена, #теги и /команды остаются как есть, иначе Telegram перестанет их узнавать.
    static func isProtected(_ word: Substring) -> Bool {
        guard let first = word.first else {
            return true
        }
        if first == "@" || first == "#" || first == "/" || first == "$" {
            return true
        }
        let lower = word.lowercased()
        return lower.contains("://") || lower.hasPrefix("www.") || lower.contains(".ru") || lower.contains(".com") || lower.contains("t.me")
    }

    static func transformWord(_ word: Substring, style: AyGrammFontStyle) -> String {
        let table = tables[style.base]
        var characters: [String] = []
        for character in word {
            var value = table[character] ?? cyrillic(character, base: style.base, table: table) ?? String(character)
            if character.isLetter || character.isNumber {
                value += style.mark
            }
            characters.append(value)
        }
        if reversedBases.contains(style.base) {
            characters.reverse()
        }
        if style.separator.isEmpty {
            return characters.joined()
        }
        return characters.joined(separator: style.separator)
    }

    // Текст в выбранном стиле Unicode. Стили Telegram здесь текст не меняют.
    public static func apply(_ text: String, style: AyGrammFontStyle) -> String {
        if style.entity != nil {
            return text
        }
        var lines: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var words: [String] = []
            for word in line.split(separator: " ", omittingEmptySubsequences: false) {
                words.append(isProtected(word) ? String(word) : transformWord(word, style: style))
            }
            if reversedBases.contains(style.base) {
                words.reverse()
            }
            lines.append(words.joined(separator: " "))
        }
        let body = lines.joined(separator: "\n")
        // Рамку не ставим на команды ботов и пустой текст, иначе бот не узнает команду.
        if (style.prefix.isEmpty && style.suffix.isEmpty) || text.hasPrefix("/") || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return body
        }
        return style.prefix + body + style.suffix
    }

    // Шрифт при наборе: готовое слово (после пробела или переноса строки) сразу меняет вид в поле ввода.
    // Слово под курсором ждёт, поэтому автозамена iOS работает как обычно. Только начертания с таблицей
    // замены: повторная замена их не меняет, и отправка не портит уже изменённые слова.
    // Слово с разным форматированием внутри (эмодзи из набора, ссылка) не меняется.
    public static func liveTransform(_ text: NSAttributedString, selection: Range<Int>) -> (NSAttributedString, Range<Int>)? {
        guard AyGrammSettings.value(AyGrammSettings.fontLiveKey), let style = selected, style.entity == nil, style.mark.isEmpty, style.separator.isEmpty, style.prefix.isEmpty, style.suffix.isEmpty, !reversedBases.contains(style.base), selection.isEmpty else {
            return nil
        }
        let string = text.string as NSString
        let length = string.length
        let cursor = selection.lowerBound
        if length == 0 || cursor > length {
            return nil
        }
        var words: [NSRange] = []
        var index = 0
        while index < length {
            if isSpace(string.character(at: index)) {
                index += 1
                continue
            }
            let start = index
            while index < length && !isSpace(string.character(at: index)) {
                index += 1
            }
            words.append(NSRange(location: start, length: index - start))
        }
        let result = NSMutableAttributedString(attributedString: text)
        var shift = 0
        var changed = false
        for range in words.reversed() {
            if range.location <= cursor && cursor <= range.location + range.length {
                continue
            }
            var effective = NSRange()
            _ = text.attributes(at: range.location, longestEffectiveRange: &effective, in: range)
            if effective.length != range.length {
                continue
            }
            let word = string.substring(with: range)
            if isProtected(Substring(word)) {
                continue
            }
            let styled = transformWord(Substring(word), style: style)
            if styled == word {
                continue
            }
            result.replaceCharacters(in: range, with: styled)
            if range.location + range.length <= cursor {
                shift += (styled as NSString).length - range.length
            }
            changed = true
        }
        if !changed {
            return nil
        }
        let output: NSAttributedString = result
        return (output, cursor + shift ..< cursor + shift)
    }

    static func isSpace(_ unit: unichar) -> Bool {
        return unit == 0x20 || unit == 0x0A || unit == 0x09 || unit == 0x0D || unit == 0xA0 || unit == 0x2028 || unit == 0x2029
    }

    // Образец для меню выбора.
    public static func sample(_ index: Int) -> String {
        guard index >= 0 && index < styles.count else {
            return ""
        }
        let style = styles[index]
        if style.entity != nil || index == 0 {
            return style.name
        }
        return apply("AyGramm Привет 2026", style: style)
    }

    // Форматирование Telegram на весь текст для стилей 1–6.
    static func entities(for text: String, style: AyGrammFontStyle) -> [MessageTextEntity] {
        guard let type = style.entity else {
            return []
        }
        let length = (text as NSString).length
        if length == 0 {
            return []
        }
        return [MessageTextEntity(range: 0 ..< length, type: type)]
    }
}
