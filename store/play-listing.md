# Recur: Google Play listing texts

Limits: app name up to 30 characters, short description up to 80, full description up to 4000, what's new up to 500. Lengths are checked below.

## English (default)

**App name**
Recur: Subscription Tracker

**Short description**
Track subscriptions, get charge reminders and see your monthly spending.

**Full description**
Recur keeps all your subscriptions in one place, so a charge never catches you by surprise.

• Add in seconds. Pick a popular service or enter your own: price, currency, billing period and the next charge date.
• Reminders. Get a notification before every charge. You choose how many days ahead and at what time.
• Free trials. Mark a trial and Recur reminds you to cancel before the first payment. Trials are not counted in your totals.
• Shared plans. Split a family or group subscription: Recur counts only your share.
• Many currencies. Convert everything to your main currency at current exchange rates, for one subscription or for all at once.
• Analytics. See your spending by category and your most expensive subscriptions, per month and per year.
• How to cancel. A quick link to the cancellation page of popular services.
• Home screen widgets. Three Material 3 widgets: a list that adapts to the widget size, the next charge, and your monthly total.
• Material 3 design. Dynamic colors from your wallpaper, light, dark and black AMOLED themes, plus color palettes.
• Backup and restore. Export subscriptions and settings to a file and restore them after reinstalling. Export to CSV for spreadsheets.
• Available in English and Russian.

Optional beta feature
Find subscriptions from receipts in your Gmail (read-only access). Everything is analysed on your device and nothing is uploaded. You always confirm what gets added.

Private by design
No account, no ads, no analytics. Your data stays on your device.

Service names are trademarks of their respective owners. Recur is not affiliated with or endorsed by them.

**What's new**
Version 1.0: first release. Subscriptions, reminders, trials, shared plans, currency conversion, analytics, three home screen widgets and Material 3 themes.

## Русский

**Название**
Recur: учёт подписок

**Краткое описание**
Все подписки в одном месте: даты списаний, расходы, напоминания и виджеты.

**Полное описание**
Recur собирает все ваши подписки в одном месте, чтобы списания не заставали врасплох.

• Добавление за секунды. Выберите популярный сервис или введите свой: цена, валюта, периодичность и дата следующего списания.
• Напоминания. Уведомление перед каждым списанием. Вы выбираете, за сколько дней и в какое время.
• Пробные периоды. Отметьте триал, и Recur напомнит отменить его до первого платежа. В итоги триалы не входят.
• Общая оплата. Разделите семейную или групповую подписку: Recur считает только вашу долю.
• Разные валюты. Пересчёт в основную валюту по текущему курсу: для одной подписки или сразу для всех.
• Аналитика. Расходы по категориям и самые дорогие подписки, за месяц и за год.
• Как отменить. Быстрая ссылка на страницу отмены популярных сервисов.
• Виджеты на рабочий стол. Три виджета в стиле Material 3: список, который подстраивается под размер, ближайшее списание и итог за месяц.
• Дизайн Material 3. Цвета из ваших обоев, светлая, тёмная и чёрная (AMOLED) темы, цветовые палитры.
• Резервная копия. Экспорт подписок и настроек в файл и восстановление после переустановки. Экспорт в CSV для таблиц.
• Русский и английский языки.

Необязательная бета-функция
Поиск подписок по чекам в вашей почте Gmail (доступ только на чтение). Всё анализируется на вашем устройстве и никуда не загружается. Что добавить, решаете вы.

Конфиденциальность
Без аккаунта, без рекламы, без аналитики. Ваши данные остаются на вашем устройстве.

Названия сервисов принадлежат их владельцам. Recur не связан с ними и не одобрен ими.

**Что нового**
Версия 1.0: первый выпуск. Подписки, напоминания, триалы, общая оплата, пересчёт валют, аналитика, три виджета и темы Material 3.

## Category and contact

- Type: Application. Category: Finance or Productivity (Finance triggers extra declarations; Productivity is simpler).
- Email, website: [YOUR EMAIL], [YOUR SITE OR POLICY URL]
- Privacy policy URL: [LINK TO PUBLISHED privacy-policy PAGE]
- Tags to pick in the console: subscription manager, budget, expense tracker.

## Data safety form: suggested answers

Check each answer against your final build before submitting.

- Does the app collect or share user data? **No.** Subscriptions and settings stay on the device. Gmail messages are read directly from Google to the device and processed only there; nothing is sent to the developer.
- Data encrypted in transit: **Yes** (HTTPS for exchange rates and Google APIs).
- Can users request data deletion: **Not applicable**, data is local; uninstalling removes it.
- Ads: **No**. Account required: **No**.
- The exchange-rate request goes to a public API without any personal data, and the provider sees an IP address as any website does. Mention it in the privacy policy (done).

## Google OAuth consent screen: scope justification

Scope: `https://www.googleapis.com/auth/gmail.readonly`

> Recur lets the user find recurring subscriptions in their own receipt and billing emails. After the user taps "Sign in to Google and search", the app reads messages from the last 180 days that match charge-related keywords and extracts the service name, amount, currency and date. The analysis runs entirely on the user's device. Message content is not stored, not transmitted to our servers (we have none) and not shared with third parties. Only subscriptions the user explicitly confirms are saved locally. A narrower scope such as gmail.metadata is not enough, because the amount and billing period are in the message body.

Also needed for the OAuth verification: the privacy policy link (with the Limited Use sentence, already included), a verified domain for it, and a short screen-recording video of the sign-in and search flow.

## Content rating and declarations

- Questionnaire: no violence, no user-generated content, no ads, no purchases. Expected rating: everyone.
- Target audience: 18+ (not for children).
- Financial features: the app is a personal budgeting tool, it does not move money, lend or trade. Declare it as such if the console asks.
