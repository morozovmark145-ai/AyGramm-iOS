# Функции AyGramm поверх Telegram-iOS: режим призрака с переключателями, сохранение удалённых
# сообщений и отдельное меню AyGramm в настройках.
# Каждая правка проверяет число совпадений и останавливает сборку, если код Telegram изменился.
# Запуск: python3 aygramm/features.py <корень telegram-ios>
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(sys.argv[1])
CORE = "submodules/TelegramCore/Sources"
PEER = "submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources"


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def write(rel, text):
    (ROOT / rel).write_text(text, encoding="utf-8")


def replace(rel, old, new, count=1):
    text = read(rel)
    found = text.count(old)
    if found != count:
        sys.exit(f"{rel}: ожидалось {count} совпадений, найдено {found}: {old[:80]!r}")
    write(rel, text.replace(old, new))
    print(f"{rel}: {found}")


def replace_re(rel, pattern, repl, count):
    text, found = re.subn(pattern, repl, read(rel), flags=re.M)
    if found != count:
        sys.exit(f"{rel}: ожидалось {count} совпадений, найдено {found}: {pattern[:80]!r}")
    write(rel, text)
    print(f"{rel}: {found}")


def guard(rel, call_pattern, condition, body, count):
    # Перед строкой с запросом вставляет: if <condition> { <body> }
    replace_re(rel, r"^(\s*)(" + call_pattern + r")", r"\1if " + condition + r" {\n\1    " + body + r"\n\1}\n\1\2", count)


def wrap(rel, line_pattern, condition, count):
    # Оборачивает целую строку: if <condition> { <строка> }
    replace_re(rel, r"^(\s*)(" + line_pattern + r")$", r"\1if " + condition + r" {\n\1    \2\n\1}", count)


# Новые файлы.
(ROOT / CORE / "AyGramm").mkdir(parents=True, exist_ok=True)
for name in ["AyGrammSettings.swift", "AyGrammCommunity.swift", "AyGrammPlugins.swift", "AyGrammNetwork.swift"]:
    shutil.copy(ROOT / "aygramm" / name, ROOT / CORE / "AyGramm" / name)
shutil.copy(ROOT / "aygramm/AyGrammSettingsController.swift", ROOT / PEER / "AyGrammSettingsController.swift")
shutil.copy(ROOT / "aygramm/AyGrammStartup.swift", ROOT / "submodules/TelegramUI/Sources/AyGrammStartup.swift")

# Метки удалённых сообщений и истории правок хранятся в базе сообщений, их тип надо зарегистрировать.
replace(f"{CORE}/Account/AccountManager.swift",
        "    declareEncodable(GuestChatMessageAttribute.self, f: { GuestChatMessageAttribute(decoder: $0) })\n",
        "    declareEncodable(GuestChatMessageAttribute.self, f: { GuestChatMessageAttribute(decoder: $0) })\n"
        "    declareEncodable(AyGrammDeletedMessageAttribute.self, f: { AyGrammDeletedMessageAttribute(decoder: $0) })\n"
        "    declareEncodable(AyGrammEditHistoryMessageAttribute.self, f: { AyGrammEditHistoryMessageAttribute(decoder: $0) })\n")

# Правка с сервера: прежний текст уходит в историю.
replace(f"{CORE}/State/Sync/StateReplay+Messages.swift",
        "            return .update(mergedServerMessageUpdate(previous: previousMessage, updated: message))\n",
        "            return .update(ayGrammWithEditHistory(previous: previousMessage, updated: mergedServerMessageUpdate(previous: previousMessage, updated: message)))\n")

# Плагины меняют текст исходящих сообщений перед отправкой.
replace(f"{CORE}/PendingMessages/EnqueueMessage.swift",
        "public func enqueueMessages(account: Account, peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[MessageId?], NoError> {\n",
        "public func enqueueMessages(account: Account, peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[MessageId?], NoError> {\n"
        "    let messages = ayGrammTransformOutgoing(messages)\n"
        "    ayGrammAfterSend(account: account)\n")

# Удалённое сообщение полупрозрачное; переход в это состояние плавный, 0.4 с.
replace("submodules/TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift",
        "    open func setupItem(_ item: ChatMessageItem, synchronousLoad: Bool) {\n        self.item = item\n    }\n",
        "    open func setupItem(_ item: ChatMessageItem, synchronousLoad: Bool) {\n"
        "        let previousMessageId = self.item?.message.id\n"
        "        let wasDeleted = self.item?.message.ayGrammIsDeleted ?? false\n"
        "        self.item = item\n"
        "        let isDeleted = item.message.ayGrammIsDeleted\n"
        "        let targetAlpha: CGFloat = isDeleted ? 0.55 : 1.0\n"
        "        if self.alpha != targetAlpha {\n"
        "            if isDeleted && !wasDeleted && previousMessageId == item.message.id {\n"
        "                ContainedViewLayoutTransition.animated(duration: 0.4, curve: .easeInOut).updateAlpha(node: self, alpha: targetAlpha)\n"
        "            } else {\n"
        "                self.alpha = targetAlpha\n"
        "            }\n"
        "        }\n"
        "    }\n")

# Значок корзины перед временем удалённого сообщения.
replace("submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode/Sources/StringForMessageTimestampStatus.swift",
        "\n    return dateText\n}",
        "\n    if message._asMessage().ayGrammIsDeleted {\n        dateText = \"🗑 \" + dateText\n    }\n    return dateText\n}")

# «История изменений» в меню сообщения по долгому нажатию.
replace("submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift",
        "        let isCopyProtected = chatPresentationInterfaceState.copyProtectionEnabled || message.isCopyProtected()\n",
        "        if AyGrammSettings.hideRead && message.flags.contains(.Incoming) && message.id.namespace == Namespaces.Message.Cloud {\n"
        "            actions.append(.action(ContextMenuActionItem(text: \"Отправить прочтение\", icon: { theme in\n"
        "                return generateTintedImage(image: UIImage(bundleImageName: \"Chat/Context Menu/Read\"), color: theme.actionSheet.primaryTextColor)\n"
        "            }, action: { c, _ in\n"
        "                c?.dismiss(completion: {\n"
        "                    let _ = (ayGrammSendReadReceipt(account: context.account, peerId: message.id.peerId, maxId: message.id.id)\n"
        "                    |> deliverOnMainQueue).start(next: { success in\n"
        "                        controllerInteraction.displayUndo(.info(title: nil, text: success ? \"Прочтение отправлено\" : \"Не удалось отправить прочтение\", timeout: nil, customUndoText: nil))\n"
        "                    })\n"
        "                })\n"
        "            })))\n"
        "        }\n"
        "        if let ayGrammHistoryText = ayGrammEditHistoryDescription(message) {\n"
        "            actions.append(.action(ContextMenuActionItem(text: \"История изменений\", icon: { theme in\n"
        "                return generateTintedImage(image: UIImage(bundleImageName: \"Chat/Context Menu/Edit\"), color: theme.actionSheet.primaryTextColor)\n"
        "            }, action: { c, _ in\n"
        "                c?.dismiss(completion: {\n"
        "                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }\n"
        "                    controllerInteraction.presentController(textAlertController(\n"
        "                        context: context,\n"
        "                        title: \"История изменений\",\n"
        "                        text: ayGrammHistoryText,\n"
        "                        actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})],\n"
        "                        actionLayout: .vertical\n"
        "                    ), nil)\n"
        "                })\n"
        "            })))\n"
        "        }\n"
        "        let isCopyProtected = chatPresentationInterfaceState.copyProtectionEnabled || message.isCopyProtected()\n")

# После входа в аккаунт: проверка бана, согласие на подписку, подсказка о плагинах.
replace("submodules/TelegramUI/Sources/AppDelegate.swift",
        "                    self.mainWindow.viewController = context.rootController\n",
        "                    self.mainWindow.viewController = context.rootController\n"
        "                    ayGrammAccountReady(context: context.context, presentAlert: { alert in\n"
        "                        self.mainWindow?.presentNative(alert)\n"
        "                    })\n")

# «В сети»: вместо него отправляется «не в сети».
replace(f"{CORE}/State/ManagedAccountPresence.swift",
        "updateStatus(offline: .boolFalse)",
        "updateStatus(offline: AyGrammSettings.hideOnline ? .boolTrue : .boolFalse)")

# «Печатает…».
guard(f"{CORE}/State/ManagedLocalInputActivities.swift",
      r"return network\.request\(Api\.functions\.messages\.(?:setTyping|setEncryptedTyping)\(",
      "AyGrammSettings.hideTyping", "return .complete()", 2)

# Прочтение в обычных чатах, группах, каналах и секретных чатах.
guard(f"{CORE}/State/SynchronizePeerReadState.swift",
      r"(?:var pushSignal: Signal<Void, NoError> = |return )network\.request\(Api\.functions\.(?:channels\.readHistory|messages\.readHistory|messages\.readEncryptedHistory)\(",
      "AyGrammSettings.hideRead", "return .single(readState)", 3)

# Прочтение в темах форумов и комментариях.
wrap(f"{CORE}/TelegramEngine/Messages/ApplyMaxReadIndexInteractively.swift",
     r"let _ = network\.request\(Api\.functions\.messages\.(?:readDiscussion|readSavedHistory)\(.*\)\.start\(\)",
     "!AyGrammSettings.hideRead", 6)
wrap(f"{CORE}/TelegramEngine/Messages/ReplyThreadHistory.swift",
     r"strongSelf\.readDisposable\.set\(signal\.start\(\)\)",
     "!AyGrammSettings.hideRead", 2)

# Просмотры историй.
guard(f"{CORE}/State/ManagedSynchronizeViewStoriesOperations.swift",
      r"return network\.request\(Api\.functions\.stories\.readStories\(",
      "AyGrammSettings.hideStoryViews", "return .complete()", 1)
guard(f"{CORE}/TelegramEngine/Messages/Stories.swift",
      r"return account\.network\.request\(Api\.functions\.stories\.incrementStoryViews\(",
      "AyGrammSettings.hideStoryViews", "return .complete()", 1)

# Удалённые сообщения: вместо удаления в конец текста дописывается метка.
REPLAY = f"{CORE}/State/Sync/StateReplay+Messages.swift"
replace(REPLAY,
        "    func applyDeleteMessagesWithGlobalIds(_ ids: [Int32]) {\n",
        "    func applyDeleteMessagesWithGlobalIds(_ ids: [Int32]) {\n"
        "        if AyGrammSettings.saveDeleted {\n"
        "            ayGrammMarkMessagesDeleted(transaction: transaction, ids: transaction.messageIdsForGlobalIds(ids))\n"
        "            return\n"
        "        }\n")
# Отложенные и быстрые ответы удаляются как обычно: их удаление не значит, что собеседник что-то стёр.
replace(REPLAY,
        "    func applyDeleteMessages(_ ids: [MessageId]) {\n",
        "    func applyDeleteMessages(_ ids: [MessageId]) {\n"
        "        var ids = ids\n"
        "        if AyGrammSettings.saveDeleted {\n"
        "            ayGrammMarkMessagesDeleted(transaction: transaction, ids: ids.filter { $0.namespace == Namespaces.Message.Cloud })\n"
        "            ids = ids.filter { $0.namespace != Namespaces.Message.Cloud }\n"
        "            if ids.isEmpty {\n"
        "                return\n"
        "            }\n"
        "        }\n")

# Группы и каналы: при сверке истории с сервером Telegram удаляет пропавшие сообщения напрямую,
# без уведомления об удалении. С «Сохранять удалённые» они тоже остаются с меткой.
replace(f"{CORE}/State/StoredMessageConfirmation.swift",
        "func deleteStoredMessagesAsReceivedDeletion(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId]) -> [MessageId] {\n",
        "func deleteStoredMessagesAsReceivedDeletion(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId]) -> [MessageId] {\n"
        "    var ids = ids\n"
        "    if AyGrammSettings.saveDeleted {\n"
        "        ayGrammMarkMessagesDeleted(transaction: transaction, ids: ids.filter { $0.namespace == Namespaces.Message.Cloud })\n"
        "        ids = ids.filter { $0.namespace != Namespaces.Message.Cloud }\n"
        "    }\n")

# Меню AyGramm: первый пункт в блоке «Избранное, Звонки, Устройства». Пункт «Возможности Telegram»
# убирается, его раздел .tips открывает меню AyGramm.
ITEMS = f"{PEER}/PeerInfoSettingsItems.swift"
replace(ITEMS,
        "    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 1, text: presentationData.strings.Settings_SavedMessages,",
        "    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 100, text: \"AyGramm\", icon: PresentationResourcesSettings.tips, action: {\n"
        "        interaction.openSettings(.tips)\n"
        "    }))\n"
        "    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 1, text: presentationData.strings.Settings_SavedMessages,")
replace_re(ITEMS,
           r"^\s*items\[\.support\]!\.append\(PeerInfoScreenDisclosureItem\(id: 2, text: presentationData\.strings\.Settings_Tips, icon: PresentationResourcesSettings\.tips, action: \{\n\s*interaction\.openSettings\(\.tips\)\n\s*\}\)\)\n",
           "", 1)
replace(f"{PEER}/PeerInfoScreenSettingsActions.swift",
        "        case .tips:\n            self.openTips()\n",
        "        case .tips:\n"
        "            push(ayGrammSettingsController(context: self.context, openChannel: { [weak self] in\n"
        "                self?.openPeerMention(\"augrammipa\")\n"
        "            }))\n")

print("AyGramm: все правки применены")
