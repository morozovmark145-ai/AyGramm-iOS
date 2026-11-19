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
for name in ["AyGrammSettings.swift", "AyGrammCommunity.swift", "AyGrammPlugins.swift", "AyGrammNetwork.swift", "AyGrammDecorations.swift", "AyGrammFonts.swift", "AyGrammVoice.swift", "AyGrammTools.swift", "AyGrammFilters.swift", "AyGrammExtras.swift", "AyGrammAutoReply.swift"]:
    shutil.copy(ROOT / "aygramm" / name, ROOT / CORE / "AyGramm" / name)
shutil.copy(ROOT / "aygramm/AyGrammSettingsController.swift", ROOT / PEER / "AyGrammSettingsController.swift")
shutil.copy(ROOT / "aygramm/AyGrammDecorationsController.swift", ROOT / PEER / "AyGrammDecorationsController.swift")
shutil.copy(ROOT / "aygramm/AyGrammBuiltinController.swift", ROOT / PEER / "AyGrammBuiltinController.swift")
shutil.copy(ROOT / "aygramm/AyGrammIcons.swift", ROOT / PEER / "AyGrammIcons.swift")
shutil.copy(ROOT / "aygramm/AyGrammStartup.swift", ROOT / "submodules/TelegramUI/Sources/AyGrammStartup.swift")
shutil.copy(ROOT / "aygramm/AyGrammKeepAlive.swift", ROOT / "submodules/TelegramUI/Sources/AyGrammKeepAlive.swift")
shutil.copy(ROOT / "aygramm/AyGrammActions.swift", ROOT / "submodules/TelegramUI/Sources/AyGrammActions.swift")

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

# Плагины меняют текст исходящих сообщений перед отправкой. Режим из меню «Отправить» (бомба, перевод,
# шифровка, голос) получает текст без шрифтов и плагинов, меняет сообщения и отправляет их сюда же ещё раз.
replace(f"{CORE}/PendingMessages/EnqueueMessage.swift",
        "public func enqueueMessages(account: Account, peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[MessageId?], NoError> {\n",
        "public func enqueueMessages(account: Account, peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[MessageId?], NoError> {\n"
        "    let messages = ayGrammTransformOutgoing(messages, peerId: peerId)\n"
        "    if let ayGrammSpecial = ayGrammSpecialSend(account: account, peerId: peerId, messages: messages) {\n"
        "        return ayGrammSpecial\n"
        "    }\n"
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
      "AyGrammSettings.hideTyping && !AyGrammGhost.isException(peerId)", "return .complete()", 2)

# Прочтение в обычных чатах, группах, каналах и секретных чатах.
guard(f"{CORE}/State/SynchronizePeerReadState.swift",
      r"(?:var pushSignal: Signal<Void, NoError> = |return )network\.request\(Api\.functions\.(?:channels\.readHistory|messages\.readHistory|messages\.readEncryptedHistory)\(",
      "AyGrammSettings.hideRead && !AyGrammGhost.isException(peerId)", "return .single(readState)", 3)

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
        "    items[.shortcuts]!.append(PeerInfoScreenDisclosureItem(id: 100, text: \"AyGramm\", icon: ayGrammLogoIcon(), action: {\n"
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

# Аккаунты без лимита: Telegram пускает 3 аккаунта, с Premium 4. В AyGramm предел 1000.
for rel in [f"{PEER}/PeerInfoScreenSettingsActions.swift",
            "submodules/SettingsUI/Sources/LogoutOptionsController.swift",
            "submodules/SettingsUI/Sources/DeleteAccountOptionsController.swift"]:
    replace(rel, "var maximumAvailableAccounts: Int = 3", "var maximumAvailableAccounts: Int = AyGrammSettings.unlimitedAccounts ? 1000 : 3")
    replace(rel, "maximumAvailableAccounts = 4\n", "maximumAvailableAccounts = AyGrammSettings.unlimitedAccounts ? 1000 : 4\n", 2)
replace("submodules/AccountUtils/Sources/AccountUtils.swift",
        "public let maximumNumberOfAccounts = 3\npublic let maximumPremiumNumberOfAccounts = 4\n",
        "public var maximumNumberOfAccounts: Int {\n    return AyGrammSettings.unlimitedAccounts ? 1000 : 3\n}\n"
        "public var maximumPremiumNumberOfAccounts: Int {\n    return AyGrammSettings.unlimitedAccounts ? 1000 : 4\n}\n")

# «Звонки в фоне»: свёрнутый AyGramm играет тишину и держит соединение всех аккаунтов.
WAKE = "submodules/TelegramUI/Sources/SharedWakeupManager.swift"
replace(WAKE, "            strongSelf.inForeground = value\n",
        "            strongSelf.inForeground = value\n"
        "            AyGrammKeepAlive.shared.update(inForeground: value, hasOtherAudio: strongSelf.hasActiveAudioSession)\n")
replace(WAKE, "            strongSelf.hasActiveAudioSession = value\n",
        "            strongSelf.hasActiveAudioSession = value\n"
        "            AyGrammKeepAlive.shared.update(inForeground: strongSelf.inForeground, hasOtherAudio: value)\n")
replace(WAKE, "|| self.silenceAudioRenderer != nil {",
        "|| self.silenceAudioRenderer != nil || AyGrammKeepAlive.shared.isRunning {")
replace(WAKE, "if (self.inForeground && primary) || !tasks.isEmpty || (self.activeExplicitExtensionTimer != nil && primary) {",
        "if (self.inForeground && primary) || !tasks.isEmpty || (self.activeExplicitExtensionTimer != nil && primary) || AyGrammKeepAlive.shared.isRunning {")
# Уведомление о сообщении, пока AyGramm свёрнут: push от Telegram не приходит.
replace("submodules/TelegramUI/Sources/ApplicationContext.swift",
        "            if let strongSelf = self, let (messages, _, notify, threadData) = messageList.last, let firstMessage = messages.first {\n",
        "            if UIApplication.shared.applicationState != .active {\n"
        "                for (messages, _, notify, _) in messageList where notify {\n"
        "                    AyGrammKeepAlive.notify(messages: messages.map { EngineMessage($0) })\n"
        "                }\n"
        "            }\n"
        "            if let strongSelf = self, let (messages, _, notify, threadData) = messageList.last, let firstMessage = messages.first {\n")

# Украшения: свои подарки видны только на этом телефоне, во вкладке «Подарки» своего профиля,
# с лентой AyGramm. Нажатие открывает экран подарка Telegram: скрыть, удалить, улучшить со слотами.
GIFTS = f"{CORE}/TelegramEngine/Payments/StarGifts.swift"
replace(GIFTS,
        "    public var state: Signal<ProfileGiftsContext.State, NoError> {\n        return Signal { subscriber in\n",
        "    public var state: Signal<ProfileGiftsContext.State, NoError> {\n"
        "        let isOwn = self.ayGrammIsOwn\n"
        "        return combineLatest(self.ayGrammServerState, AyGrammDecorations.updates)\n"
        "        |> map { state, _ -> ProfileGiftsContext.State in\n"
        "            return isOwn ? ayGrammWithDecorations(state) : state\n"
        "        }\n"
        "    }\n"
        "    \n"
        "    var ayGrammServerState: Signal<ProfileGiftsContext.State, NoError> {\n"
        "        return Signal { subscriber in\n")
replace(GIFTS, "    public let peerId: EnginePeer.Id\n    public let collectionId: Int32?\n    \n    public init(\n        account: Account,\n",
        "    public let peerId: EnginePeer.Id\n    public let collectionId: Int32?\n    let ayGrammIsOwn: Bool\n    \n    public init(\n        account: Account,\n")
replace(GIFTS, "        limit: Int32 = 36\n    ) {\n        self.peerId = peerId\n        self.collectionId = collectionId\n",
        "        limit: Int32 = 36\n    ) {\n        self.peerId = peerId\n        self.collectionId = collectionId\n"
        "        self.ayGrammIsOwn = peerId == account.peerId && collectionId == nil\n")
replace(f"{PEER}/PeerInfoData.swift",
        "                        if let starGiftsCount = cachedData.starGiftsCount, starGiftsCount > 0 {\n                            availablePanes?.insert(.gifts, at: 1)\n",
        "                        if (cachedData.starGiftsCount ?? 0) > 0 || AyGrammDecorations.hasGifts {\n                            availablePanes?.insert(.gifts, at: 1)\n")
GLIST = "submodules/TelegramUI/Components/PeerInfo/PeerInfoVisualMediaPaneNode/Sources/GiftsListView.swift"
replace(GLIST, "                let itemReferenceId = product.reference?.stringValue ?? \"\"\n",
        "                if AyGrammDecorations.isDecoration(product) {\n"
        "                    ribbonText = AyGrammDecorations.ribbonText\n"
        "                    ribbonFont = .generic\n"
        "                    if case .generic = product.gift {\n"
        "                        ribbonColor = .purple\n"
        "                    }\n"
        "                }\n"
        "                let itemReferenceId = product.reference?.stringValue ?? \"\"\n")
replace(GLIST, "                                guard let self, !isAdded, let presentationData = self.currentParams?.presentationData else {\n                                    return\n                                }\n",
        "                                guard let self, !isAdded, let presentationData = self.currentParams?.presentationData else {\n                                    return\n                                }\n"
        "                                if AyGrammDecorations.isDecoration(product) && !self.canSelect && !self.isReordering {\n"
        "                                    let engine = self.context.engine\n"
        "                                    let controller = GiftViewScreen(\n"
        "                                        context: self.context,\n"
        "                                        subject: .profileGift(self.peerId, product),\n"
        "                                        updateSavedToProfile: { reference, added in\n"
        "                                            AyGrammDecorations.setHidden(reference: reference, hidden: !added)\n"
        "                                        },\n"
        "                                        deleteGift: { reference in\n"
        "                                            AyGrammDecorations.remove(reference: reference)\n"
        "                                        },\n"
        "                                        upgradeGift: { _, reference, _ in\n"
        "                                            return AyGrammDecorations.upgradeSignal(engine: engine, reference: reference)\n"
        "                                        }\n"
        "                                    )\n"
        "                                    self.parentController?.push(controller)\n"
        "                                    return\n"
        "                                }\n")
# Встроенный плагин «Прочитать вслух» в меню сообщения.
replace("submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift",
        "        let isCopyProtected = chatPresentationInterfaceState.copyProtectionEnabled || message.isCopyProtected()\n",
        "        if AyGrammSettings.value(AyGrammSettings.readAloudKey) && !message.text.isEmpty {\n"
        "            actions.append(.action(ContextMenuActionItem(text: \"Прочитать вслух\", icon: { theme in\n"
        "                return generateTintedImage(image: UIImage(bundleImageName: \"Chat/Context Menu/Unmute\"), color: theme.actionSheet.primaryTextColor)\n"
        "            }, action: { c, _ in\n"
        "                c?.dismiss(completion: {\n"
        "                    AyGrammSpeech.shared.speak(message.text)\n"
        "                })\n"
        "            })))\n"
        "        }\n"
        "        let isCopyProtected = chatPresentationInterfaceState.copyProtectionEnabled || message.isCopyProtected()\n")

replace(GLIST, "(self.starsProducts ?? []).map { .profileGift(self.peerId, $0) }",
        "(self.starsProducts ?? []).filter { !AyGrammDecorations.isDecoration($0) }.map { .profileGift(self.peerId, $0) }")
replace(GLIST, "let index = self.starsProducts?.firstIndex(where: { $0 == product }) ?? 0",
        "let index = self.starsProducts?.filter({ !AyGrammDecorations.isDecoration($0) }).firstIndex(where: { $0 == product }) ?? 0")

# Секунды во времени сообщений: «14:05» → «14:05:37».
STATUS = "submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode/Sources/StringForMessageTimestampStatus.swift"
replace(STATUS, "    var dateText = stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat)\n",
        "    var dateText = stringForMessageTimestamp(timestamp: timestamp, dateTimeFormat: dateTimeFormat)\n"
        "    if AyGrammSettings.value(AyGrammSettings.secondsKey) {\n"
        "        dateText = AyGrammSettings.addSeconds(dateText, timestamp: timestamp)\n"
        "    }\n")

# ID в профиле пользователя (нажатие копирует) и режим стримера (номер телефона скрыт).
PITEMS = f"{PEER}/PeerInfoProfileItems.swift"
replace(PITEMS, "        if let phone = user.phone {\n            let formattedPhone = formatPhoneNumber(context: context, number: phone)\n",
        "        if AyGrammSettings.value(AyGrammSettings.showIdKey) {\n"
        "            let ayGrammId = \"\\(user.id.id._internalGetInt64Value())\"\n"
        "            items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: 3100, label: \"ID · нажмите, чтобы скопировать\", text: ayGrammId, textColor: .primary, action: { _, _ in\n"
        "                UIPasteboard.general.string = ayGrammId\n"
        "                UINotificationFeedbackGenerator().notificationOccurred(.success)\n"
        "            }, requestLayout: { animated in\n"
        "                interaction.requestLayout(animated)\n"
        "            }))\n"
        "        }\n"
        "        if AyGrammSettings.value(AyGrammSettings.accountAgeKey) {\n"
        "            items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: 3101, label: \"Аккаунт создан\", text: AyGrammAccountAge.describe(userId: user.id.id._internalGetInt64Value()), textColor: .primary, action: nil, requestLayout: { animated in\n"
        "                interaction.requestLayout(animated)\n"
        "            }))\n"
        "        }\n"
        "        if AyGrammSettings.value(AyGrammSettings.mutualKey), let ayGrammMutual = AyGrammMutual.describe(user: user, isContact: data.isContact) {\n"
        "            items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: 3102, label: \"Контакт\", text: ayGrammMutual, textColor: .primary, action: nil, requestLayout: { animated in\n"
        "                interaction.requestLayout(animated)\n"
        "            }))\n"
        "        }\n"
        "        if let phone = user.phone, !AyGrammSettings.value(AyGrammSettings.streamerKey) {\n"
        "            let formattedPhone = formatPhoneNumber(context: context, number: phone)\n")
replace(f"{PEER}/PeerInfoHeaderNode.swift", "                var subtitle = formatPhoneNumber(context: self.context, number: user.phone ?? \"\")\n",
        "                var subtitle = AyGrammSettings.value(AyGrammSettings.streamerKey) ? \"Номер скрыт\" : formatPhoneNumber(context: self.context, number: user.phone ?? \"\")\n")

# Встроенный плагин «Изменение голоса»: эффект меняет отсчёты голосового до кодека Opus.
replace("submodules/TelegramUI/Sources/ManagedAudioRecorder.swift",
        "                self.processWaveformPreview(samples: currentEncoderPacket.assumingMemoryBound(to: Int16.self), count: currentEncoderPacketSize / 2)\n",
        "                AyGrammVoice.process(currentEncoderPacket.assumingMemoryBound(to: Int16.self), count: currentEncoderPacketSize / 2)\n"
        "                self.processWaveformPreview(samples: currentEncoderPacket.assumingMemoryBound(to: Int16.self), count: currentEncoderPacketSize / 2)\n")

# Фильтры в группах: сообщения со словами из списка и сообщения скрытых людей не попадают в ленту.
replace("submodules/TelegramUI/Sources/ChatHistoryEntriesForView.swift",
        "        if pendingRemovedMessages.contains(message.id) {\n            continue\n        }\n",
        "        if pendingRemovedMessages.contains(message.id) {\n            continue\n        }\n"
        "        if AyGrammFilters.shouldHide(message) {\n            continue\n        }\n")
# Меню сообщения: «Скрывать сообщения автора» в группах и «Экспорт чата в файл» без запрета копирования.
replace("submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift",
        "        let isCopyProtected = chatPresentationInterfaceState.copyProtectionEnabled || message.isCopyProtected()\n",
        "        if AyGrammSettings.value(AyGrammSettings.filtersKey), message.id.peerId.namespace != Namespaces.Peer.CloudUser, let author = message.author, author.id != context.account.peerId {\n"
        "            actions.append(.action(ContextMenuActionItem(text: \"Скрывать сообщения автора\", icon: { theme in\n"
        "                return generateTintedImage(image: UIImage(bundleImageName: \"Chat/Context Menu/Restrict\"), color: theme.actionSheet.primaryTextColor)\n"
        "            }, action: { c, _ in\n"
        "                c?.dismiss(completion: {\n"
        "                    AyGrammFilters.hideAuthor(id: author.id.id._internalGetInt64Value(), name: EnginePeer(author).compactDisplayTitle)\n"
        "                })\n"
        "            })))\n"
        "        }\n"
        "        if AyGrammSettings.value(AyGrammSettings.exportKey) && !(chatPresentationInterfaceState.copyProtectionEnabled || message.isCopyProtected()) {\n"
        "            actions.append(.action(ContextMenuActionItem(text: \"Экспорт чата в файл\", icon: { theme in\n"
        "                return generateTintedImage(image: UIImage(bundleImageName: \"Chat/Context Menu/Forward\"), color: theme.actionSheet.primaryTextColor)\n"
        "            }, action: { c, _ in\n"
        "                c?.dismiss(completion: {\n"
        "                    let _ = (AyGrammExport.chatFile(account: context.account, peerId: message.id.peerId)\n"
        "                    |> deliverOnMainQueue).start(next: { url in\n"
        "                        guard let url = url else {\n"
        "                            return\n"
        "                        }\n"
        "                        context.sharedContext.mainWindow?.presentNative(UIActivityViewController(activityItems: [url], applicationActivities: nil))\n"
        "                    })\n"
        "                })\n"
        "            })))\n"
        "        }\n"
        "        let isCopyProtected = chatPresentationInterfaceState.copyProtectionEnabled || message.isCopyProtected()\n")

# Кнопка шрифта: долгое нажатие на «Отправить» включает или выключает шрифт сообщений.
replace("submodules/ChatSendMessageActionUI/Sources/ChatSendMessageContextScreen.swift",
        "            case let.sendMessage(sendMessage):\n                if !reminders {\n",
        "            case let.sendMessage(sendMessage):\n"
        "                if AyGrammSettings.value(AyGrammSettings.fontButtonKey) {\n"
        "                    items.append(.action(ContextMenuActionItem(\n"
        "                        id: AnyHashable(\"aygrammFont\"),\n"
        "                        text: AyGrammFonts.quickTitle,\n"
        "                        icon: { theme in\n"
        "                            return generateTintedImage(image: UIImage(systemName: \"textformat\"), color: theme.contextMenu.primaryColor)\n"
        "                        }, action: { [weak self] _, _ in\n"
        "                            AyGrammFonts.toggleQuick()\n"
        "                            self?.environment?.controller()?.dismiss()\n"
        "                        }\n"
        "                    )))\n"
        "                }\n"
        "                if let ayGrammPeerId = component.peerId, textString.length != 0, mediaPreview == nil, !sendMessage.isScheduledMessages {\n"
        "                    for ayGrammItem in AyGrammOutgoing.menuItems(peerId: ayGrammPeerId) {\n"
        "                        items.append(.action(ContextMenuActionItem(\n"
        "                            id: AnyHashable(\"aygramm.\" + ayGrammItem.id),\n"
        "                            text: ayGrammItem.title,\n"
        "                            icon: { theme in\n"
        "                                return generateTintedImage(image: UIImage(systemName: ayGrammItem.icon), color: theme.contextMenu.primaryColor)\n"
        "                            }, action: { [weak self] _, _ in\n"
        "                                guard let self, let component = self.component else {\n"
        "                                    return\n"
        "                                }\n"
        "                                AyGrammOutgoing.arm(ayGrammItem.mode, peerId: ayGrammPeerId)\n"
        "                                self.animateOutToEmpty = true\n"
        "                                let sendParameters = ChatSendMessageActionSheetController.SendParameters(\n"
        "                                    effect: self.selectedMessageEffect.flatMap({ ChatSendMessageActionSheetController.SendParameters.Effect(id: $0.id) }),\n"
        "                                    textIsAboveMedia: self.mediaCaptionIsAbove\n"
        "                                )\n"
        "                                component.sendMessage(.generic, sendParameters)\n"
        "                                self.environment?.controller()?.dismiss()\n"
        "                            }\n"
        "                        )))\n"
        "                    }\n"
        "                }\n"
        "                if !reminders {\n")

# Подменю AyGramm в меню сообщения: статистика, первое сообщение, скриншот, кружок, стирание своих сообщений, автоответ.
replace("submodules/TelegramUI/Sources/ChatInterfaceStateContextMenus.swift",
        "        let isCopyProtected = chatPresentationInterfaceState.copyProtectionEnabled || message.isCopyProtected()\n",
        "        if AyGrammSettings.value(AyGrammSettings.chatToolsKey) && message.id.namespace == Namespaces.Message.Cloud {\n"
        "            let ayGrammMessage = EngineMessage(message)\n"
        "            let ayGrammPeer = chatPresentationInterfaceState.renderedPeer?.peer.flatMap { EnginePeer($0) }\n"
        "            let ayGrammProtected = chatPresentationInterfaceState.copyProtectionEnabled || message.isCopyProtected()\n"
        "            actions.append(.action(ContextMenuActionItem(text: \"AyGramm\", icon: { theme in\n"
        "                return generateTintedImage(image: UIImage(systemName: \"sparkles\"), color: theme.actionSheet.primaryTextColor)\n"
        "            }, action: { c, _ in\n"
        "                let ayGrammItems = ayGrammChatMenuItems(context: context, message: ayGrammMessage, peer: ayGrammPeer, isCopyProtected: ayGrammProtected, navigate: { id in\n"
        "                    controllerInteraction?.navigateToMessage(ayGrammMessage.id, id, NavigateToMessageParams())\n"
        "                }, present: { controller in\n"
        "                    controllerInteraction?.presentController(controller, nil)\n"
        "                }, toast: { text in\n"
        "                    controllerInteraction?.displayUndo(.info(title: nil, text: text, timeout: nil, customUndoText: nil))\n"
        "                })\n"
        "                c?.pushItems(items: .single(ContextController.Items(content: .list(ayGrammItems))))\n"
        "            })))\n"
        "        }\n"
        "        let isCopyProtected = chatPresentationInterfaceState.copyProtectionEnabled || message.isCopyProtected()\n")

# Шифровка AyGramm: пузырь показывает расшифрованный текст, если пароль совпадает.
replace("submodules/TelegramUI/Components/Chat/ChatMessageTextBubbleContentNode/Sources/ChatMessageTextBubbleContentNode.swift",
        "                    let translateToLanguage = item.associatedData.translateToLanguage\n",
        "                    if let ayGrammPlain = AyGrammCipher.displayText(rawText) {\n"
        "                        rawText = ayGrammPlain\n"
        "                        messageEntities = nil\n"
        "                    }\n"
        "                    let translateToLanguage = item.associatedData.translateToLanguage\n")

# Шрифт при наборе: после каждого изменения текста готовые слова получают выбранный шрифт.
# Сложное содержимое нового редактора (таблицы, медиа в тексте) не трогается.
INPUT = "submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode/Sources/ChatTextInputPanelNode.swift"
replace(INPUT,
        "            self.interfaceInteraction?.updateTextInputStateAndMode({ _, inputMode in return (inputTextState, inputMode) })\n"
        "            self.interfaceInteraction?.updateInputLanguage({ _ in return self.richTextInputNode?.primaryLanguage })\n",
        "            let ayGrammLiveState = ayGrammLiveFontState(inputTextState)\n"
        "            self.interfaceInteraction?.updateTextInputStateAndMode({ _, inputMode in return (ayGrammLiveState, inputMode) })\n"
        "            self.interfaceInteraction?.updateInputLanguage({ _ in return self.richTextInputNode?.primaryLanguage })\n")
with open(ROOT / INPUT, "a", encoding="utf-8") as f:
    f.write("\n// AyGramm: шрифт при наборе.\n"
            "private func ayGrammLiveFontState(_ state: ChatTextInputState) -> ChatTextInputState {\n"
            "    if ChatTextInputState(inputText: state.inputText, selectionRange: state.selectionRange) != state {\n"
            "        return state\n"
            "    }\n"
            "    guard let ayGrammResult = AyGrammFonts.liveTransform(state.inputText, selection: state.selectionRange) else {\n"
            "        return state\n"
            "    }\n"
            "    return ChatTextInputState(inputText: ayGrammResult.0, selectionRange: ayGrammResult.1)\n"
            "}\n")

# Своя заметка о человеке в профиле (задаётся в меню сообщения → AyGramm).
replace(PITEMS, "        if let phone = user.phone, !AyGrammSettings.value(AyGrammSettings.streamerKey) {\n",
        "        if let ayGrammNote = AyGrammNotes.note(user.id) {\n"
        "            items[currentPeerInfoSection]!.append(PeerInfoScreenLabeledValueItem(id: 3103, label: \"Ваша заметка\", text: ayGrammNote, textColor: .primary, action: nil, requestLayout: { animated in\n"
        "                interaction.requestLayout(animated)\n"
        "            }))\n"
        "        }\n"
        "        if let phone = user.phone, !AyGrammSettings.value(AyGrammSettings.streamerKey) {\n")

print("AyGramm: все правки применены")
