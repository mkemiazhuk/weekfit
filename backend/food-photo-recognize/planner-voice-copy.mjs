/** Spoken planner copy. Language comes from the app setting, never from the time zone. */

export const PLANNER_VOICE_LANGUAGES = ['en', 'ru', 'zh-Hans', 'fr', 'pl', 'es', 'de', 'ja', 'it', 'ko'];

const SPOKEN = {
  Cycling: { ru: 'велосипед', en: 'cycling', pl: 'rower', fr: 'vélo', es: 'ciclismo', de: 'Radfahren', 'zh-Hans': '骑行', ja: 'サイクリング', it: 'ciclismo', ko: '사이클링' },
  Running: { ru: 'бег', en: 'running', pl: 'bieg', fr: 'course', es: 'carrera', de: 'Laufen', 'zh-Hans': '跑步', ja: 'ランニング', it: 'corsa', ko: '러닝' },
  Swimming: { ru: 'плавание', en: 'swimming', pl: 'pływanie', fr: 'natation', es: 'natación', de: 'Schwimmen', 'zh-Hans': '游泳', ja: '水泳', it: 'nuoto', ko: '수영' },
  Hiking: { ru: 'поход', en: 'hiking', pl: 'wędrówkę', fr: 'randonnée', es: 'senderismo', de: 'Wandern', 'zh-Hans': '徒步', ja: 'ハイキング', it: 'escursione', ko: '하이킹' },
  Snowboarding: { ru: 'сноуборд', en: 'snowboarding', pl: 'snowboard', fr: 'snowboard', es: 'snowboard', de: 'Snowboarden', 'zh-Hans': '单板滑雪', ja: 'スノーボード', it: 'snowboard', ko: '스노보드' },
  'Alpine Skiing': { ru: 'лыжи', en: 'skiing', pl: 'narty', fr: 'ski', es: 'esquí', de: 'Skifahren', 'zh-Hans': '滑雪', ja: 'スキー', it: 'sci', ko: '스키' },
  'Upper Body': { ru: 'верх', en: 'upper body', pl: 'górną część ciała', fr: 'haut du corps', es: 'tren superior', de: 'Oberkörper', 'zh-Hans': '上肢', ja: '上半身', it: 'parte superiore', ko: '상체' },
  Core: { ru: 'пресс', en: 'core', pl: 'core', fr: 'gainage', es: 'core', de: 'Core', 'zh-Hans': '核心', ja: '体幹', it: 'core', ko: '코어' },
  'Lower Body': { ru: 'низ', en: 'lower body', pl: 'dolną część ciała', fr: 'bas du corps', es: 'tren inferior', de: 'Unterkörper', 'zh-Hans': '下肢', ja: '下半身', it: 'parte inferiore', ko: '하체' },
  'Full Body': { ru: 'всё тело', en: 'full body', pl: 'całe ciało', fr: 'corps entier', es: 'cuerpo completo', de: 'Ganzkörper', 'zh-Hans': '全身', ja: '全身', it: 'corpo intero', ko: '전신' },
  Tennis: { ru: 'теннис', en: 'tennis', pl: 'tenis', fr: 'tennis', es: 'tenis', de: 'Tennis', 'zh-Hans': '网球', ja: 'テニス', it: 'tennis', ko: '테니스' },
  Padel: { ru: 'падел', en: 'padel', pl: 'padel', fr: 'padel', es: 'pádel', de: 'Padel', 'zh-Hans': '板式网球', ja: 'パデル', it: 'padel', ko: '파델' },
  Squash: { ru: 'сквош', en: 'squash', pl: 'squash', fr: 'squash', es: 'squash', de: 'Squash', 'zh-Hans': '壁球', ja: 'スカッシュ', it: 'squash', ko: '스쿼시' },
  'High Intensity Interval Training': { ru: 'интервалы', en: 'intervals', pl: 'interwały', fr: 'intervalles', es: 'intervalos', de: 'Intervalle', 'zh-Hans': '间歇训练', ja: 'インターバル', it: 'intervalli', ko: '인터벌' },
  Stretching: { ru: 'растяжку', en: 'stretching', pl: 'rozciąganie', fr: 'étirements', es: 'estiramientos', de: 'Dehnen', 'zh-Hans': '拉伸', ja: 'ストレッチ', it: 'stretching', ko: '스트레칭' },
  Walk: { ru: 'прогулку', en: 'a walk', pl: 'spacer', fr: 'marche', es: 'un paseo', de: 'einen Spaziergang', 'zh-Hans': '散步', ja: '散歩', it: 'una camminata', ko: '산책' },
  Sauna: { ru: 'сауну', en: 'the sauna', pl: 'saunę', fr: 'sauna', es: 'la sauna', de: 'die Sauna', 'zh-Hans': '桑拿', ja: 'サウナ', it: 'la sauna', ko: '사우나' },
  Yoga: { ru: 'йогу', en: 'yoga', pl: 'jogę', fr: 'yoga', es: 'yoga', de: 'Yoga', 'zh-Hans': '瑜伽', ja: 'ヨガ', it: 'yoga', ko: '요가' },
  Breathing: { ru: 'дыхание', en: 'breathing', pl: 'oddech', fr: 'respiration', es: 'respiración', de: 'Atmung', 'zh-Hans': '呼吸', ja: '呼吸', it: 'respirazione', ko: '호흡' },
  'Drink Water': { ru: 'воду', en: 'water', pl: 'wodę', fr: 'eau', es: 'agua', de: 'Wasser', 'zh-Hans': '喝水', ja: '水分', it: 'acqua', ko: '물' },
  'Sleep Routine': { ru: 'сон', en: 'sleep', pl: 'sen', fr: 'sommeil', es: 'sueño', de: 'Schlaf', 'zh-Hans': '睡眠', ja: '睡眠', it: 'sonno', ko: '수면' },
  'No Screens': { ru: 'без экрана', en: 'no screens', pl: 'bez ekranu', fr: 'sans écran', es: 'sin pantallas', de: 'keine Bildschirme', 'zh-Hans': '远离屏幕', ja: '画面オフ', it: 'niente schermi', ko: '화면 끄기' },
  'Morning Routine': { ru: 'утренние дела', en: 'the morning routine', pl: 'poranną rutynę', fr: 'routine du matin', es: 'la rutina de la mañana', de: 'die Morgenroutine', 'zh-Hans': '早晨例程', ja: '朝のルーティン', it: 'la routine del mattino', ko: '아침 루틴' },
};

const PHRASES = {
  ru: {
    englishName: 'Russian',
    assistantName: 'Майя',
    greeting: (_name, introduced) => (introduced
      ? 'Здравствуйте. Рада вас слышать. Что обсудим сегодня?'
      : 'Здравствуйте. Я Майя. Помогу разобраться, как вы себя чувствуете, что у вас по питанию и как лучше спланировать день. Вместе подберём подходящие активности — я могу добавить их в план, перенести или убрать по вашей просьбе. С чего начнём?'),
    goodbye: 'До встречи.',
    anythingElse: 'Что-нибудь ещё?',
    closing: '«нет, всё», «нет, всё, спасибо», «больше ничего», «ничего», «это всё», «всё, спасибо», «до свидания», «до встречи», «увидимся», «пока»',
    askTime: 'Во сколько?',
    askActivity: 'Что добавить?',
    conflict: 'Это время уже занято. Подойдёт другое свободное?',
    saveFailed: 'Не сохранилось. Скажите ещё раз, пожалуйста.',
    today: 'сегодня',
    tomorrow: 'завтра',
    dayAfter: 'послезавтра',
    added: (spoken, day, start, end) => `Записала ${spoken} на ${day}, с ${start} до ${end}.`,
  },
  en: {
    englishName: 'English',
    assistantName: 'Maya',
    greeting: (_name, introduced) => (introduced
      ? 'Hi! Good to hear you. What should we talk about today?'
      : 'Hi! I\'m Maya. I can help you see how you\'re feeling, where your food stands, and how to shape the day. I can add activities to the plan, move them, or remove them when you ask. Where should we start?'),
    goodbye: 'Talk soon.',
    anythingElse: 'Anything else?',
    closing: '"no, I\'m good", "no, that\'s all", "nothing else", "that\'s all", "that\'s it", "goodbye", "bye"',
    askTime: 'What time?',
    askActivity: 'What do you want to add?',
    conflict: 'Something is already there then. Want another time?',
    saveFailed: "I couldn't save that. Please try again.",
    today: 'today',
    tomorrow: 'tomorrow',
    dayAfter: 'the day after tomorrow',
    added: (spoken, day, start, end) => `Added ${spoken} for ${day}, from ${start} to ${end}.`,
  },
  pl: {
    englishName: 'Polish',
    assistantName: 'Maya',
    greeting: (_name, introduced) => (introduced
      ? 'Dzień dobry. Miło pana lub panią słyszeć. O czym dziś porozmawiamy?'
      : 'Dzień dobry. Jestem Maya. Pomogę zobaczyć, jak się pan lub pani czuje, co z jedzeniem i jak ułożyć dzień. Mogę dodać aktywność do planu, przenieść ją albo usunąć, kiedy pan lub pani poprosi. Od czego zaczynamy?'),
    goodbye: 'Do usłyszenia.',
    anythingElse: 'Coś jeszcze?',
    closing: '«nie», «nic więcej», «to wszystko», «do widzenia», «pa»',
    askTime: 'O której?',
    askActivity: 'Jaką aktywność?',
    conflict: 'Ta godzina jest już zajęta.',
    saveFailed: 'Nie udało się zapisać. Spróbuj jeszcze raz.',
    today: 'dzisiaj',
    tomorrow: 'jutro',
    dayAfter: 'pojutrze',
    added: (spoken, day, start, end) => `Dodałam ${spoken} na ${day}, od ${start} do ${end}.`,
  },
  fr: {
    englishName: 'French',
    assistantName: 'Maya',
    greeting: (_name, introduced) => (introduced
      ? "Bonjour. Contente de vous entendre. De quoi parlons-nous aujourd'hui ?"
      : "Bonjour. Je suis Maya. Je vous aide à voir comment vous vous sentez, où en est l'alimentation et comment organiser la journée. Je peux ajouter une activité au planning, la déplacer ou la retirer si vous me le demandez. Par quoi commençons-nous ?"),
    goodbye: 'À bientôt.',
    anythingElse: 'Autre chose ?',
    closing: '«non», «rien d\'autre», «c\'est tout», «au revoir»',
    askTime: 'À quelle heure ?',
    askActivity: 'Quelle activité ?',
    conflict: 'Ce créneau est déjà pris.',
    saveFailed: "Je n'ai pas pu enregistrer. Réessaie.",
    today: "aujourd'hui",
    tomorrow: 'demain',
    dayAfter: 'après-demain',
    added: (spoken, day, start, end) => `J'ai ajouté ${spoken} pour ${day}, de ${start} à ${end}.`,
  },
  es: {
    englishName: 'Spanish',
    assistantName: 'Maya',
    greeting: (_name, introduced) => (introduced
      ? 'Hola. Me alegra oírle. ¿De qué hablamos hoy?'
      : 'Hola. Soy Maya. Le ayudo a ver cómo se siente, cómo va la comida y cómo organizar el día. Puedo añadir una actividad al plan, moverla o quitarla cuando me lo pida. ¿Por dónde empezamos?'),
    goodbye: 'Hasta luego.',
    anythingElse: '¿Algo más?',
    closing: '«no», «nada más», «eso es todo», «adiós»',
    askTime: '¿A qué hora?',
    askActivity: '¿Qué actividad?',
    conflict: 'Esa hora ya está ocupada.',
    saveFailed: 'No pude guardarlo. Inténtalo de nuevo.',
    today: 'hoy',
    tomorrow: 'mañana',
    dayAfter: 'pasado mañana',
    added: (spoken, day, start, end) => `Añadí ${spoken} para ${day}, de ${start} a ${end}.`,
  },
  de: {
    englishName: 'German',
    assistantName: 'Maya',
    greeting: (_name, introduced) => (introduced
      ? 'Guten Tag. Schön, Sie zu hören. Was besprechen wir heute?'
      : 'Guten Tag. Ich bin Maya. Ich helfe Ihnen zu sehen, wie es Ihnen geht, wie die Ernährung aussieht und wie Sie den Tag planen. Eine Aktivität kann ich auf Ihre Bitte in den Plan setzen, verschieben oder entfernen. Womit fangen wir an?'),
    goodbye: 'Auf Wiederhören.',
    anythingElse: 'Noch etwas?',
    closing: '«nein», «nichts weiter», «das war\'s», «auf Wiedersehen»',
    askTime: 'Um wie viel Uhr?',
    askActivity: 'Welche Aktivität?',
    conflict: 'Diese Zeit ist schon belegt.',
    saveFailed: 'Speichern hat nicht geklappt. Bitte versuch es noch einmal.',
    today: 'heute',
    tomorrow: 'morgen',
    dayAfter: 'übermorgen',
    added: (spoken, day, start, end) => `${spoken} ist drin, ${day}, von ${start} bis ${end}.`,
  },
  'zh-Hans': {
    englishName: 'Chinese',
    assistantName: 'Maya',
    greeting: (_name, introduced) => (introduced
      ? '您好。听到您的声音真好。今天想聊什么？'
      : '您好。我是 Maya。我帮您看看状态、饮食，以及怎么安排今天。您要的话，我可以把活动加进计划、改时间或删掉。我们从哪开始？'),
    goodbye: '再见。',
    anythingElse: '还有别的吗？',
    closing: '「不用了」「没有了」「就这样」「再见」',
    askTime: '几点？',
    askActivity: '哪一项活动？',
    conflict: '这个时间已经有安排了。',
    saveFailed: '没保存上。请再说一次。',
    today: '今天',
    tomorrow: '明天',
    dayAfter: '后天',
    added: (spoken, day, start, end) => `已添加${spoken}，${day}，${start}到${end}。`,
  },
  ja: {
    englishName: 'Japanese',
    assistantName: 'Maya',
    greeting: (_name, introduced) => (introduced
      ? 'こんにちは。お声が聞けてうれしいです。今日は何を話しますか？'
      : 'こんにちは。マヤです。調子、食事、今日の計画を一緒に整理します。頼まれたら、予定を追加したり、動かしたり、消したりできます。どこから始めますか？'),
    goodbye: 'では、また。',
    anythingElse: 'ほかにある？',
    closing: '「いいえ」「ほかにはない」「以上です」「さようなら」',
    askTime: '何時にしますか？',
    askActivity: 'どのアクティビティ？',
    conflict: 'その時間はすでに埋まっています。',
    saveFailed: '保存できませんでした。もう一度お願いします。',
    today: '今日',
    tomorrow: '明日',
    dayAfter: '明後日',
    added: (spoken, day, start, end) => `${spoken}を追加しました。${day}、${start}から${end}まで。`,
  },
  it: {
    englishName: 'Italian',
    assistantName: 'Maya',
    greeting: (_name, introduced) => (introduced
      ? 'Buongiorno. Che bello sentirla. Di che cosa parliamo oggi?'
      : 'Buongiorno. Sono Maya. La aiuto a capire come si sente, com\'è l\'alimentazione e come organizzare la giornata. Se me lo chiede, posso aggiungere un\'attività al piano, spostarla o toglierla. Da dove partiamo?'),
    goodbye: 'Arrivederci.',
    anythingElse: 'Altro?',
    closing: '«no», «nient\'altro», «è tutto», «arrivederci»',
    askTime: 'A che ora?',
    askActivity: 'Quale attività?',
    conflict: 'Quell\'orario è già occupato.',
    saveFailed: 'Non sono riuscita a salvare. Riprova.',
    today: 'oggi',
    tomorrow: 'domani',
    dayAfter: 'dopodomani',
    added: (spoken, day, start, end) => `Ho aggiunto ${spoken} per ${day}, dalle ${start} alle ${end}.`,
  },
  ko: {
    englishName: 'Korean',
    assistantName: 'Maya',
    greeting: (_name, introduced) => (introduced
      ? '안녕하세요. 목소리 들려서 반가워요. 오늘은 무엇을 이야기할까요?'
      : '안녕하세요. 저는 Maya예요. 컨디션, 식사, 오늘 계획을 같이 정리해 드릴게요. 말씀하시면 활동을 계획에 넣거나, 옮기거나, 지울 수 있어요. 무엇부터 할까요?'),
    goodbye: '안녕히 계세요.',
    anythingElse: '또 있을까?',
    closing: '「아니요」, 「없어요」, 「그거예요」, 「안녕히 가세요」',
    askTime: '몇 시요?',
    askActivity: '어떤 활동이요?',
    conflict: '그 시간은 이미 차 있어요.',
    saveFailed: '저장하지 못했어요. 다시 말해 주세요.',
    today: '오늘',
    tomorrow: '내일',
    dayAfter: '모레',
    added: (spoken, day, start, end) => `${spoken} 추가했어요. ${day}, ${start}부터 ${end}까지.`,
  },
};

const LOCALES = {
  en: 'en-US',
  ru: 'ru-RU',
  'zh-Hans': 'zh-Hans',
  fr: 'fr-FR',
  pl: 'pl-PL',
  es: 'es-ES',
  de: 'de-DE',
  ja: 'ja-JP',
  it: 'it-IT',
  ko: 'ko-KR',
};

export function plannerVoiceLanguage(value) {
  return PLANNER_VOICE_LANGUAGES.includes(value) ? value : 'ru';
}

export function plannerVoicePhrases(language) {
  return PHRASES[plannerVoiceLanguage(language)];
}

export function spokenActivityName(catalogTitle, language) {
  const names = SPOKEN[catalogTitle];
  if (!names) return catalogTitle;
  const code = plannerVoiceLanguage(language);
  return names[code] ?? names.ru;
}

export function greetingLine(language, givenName, introduced = false) {
  return plannerVoicePhrases(language).greeting(givenName, introduced === true);
}

export function askTimeLine(language) {
  return plannerVoicePhrases(language).askTime;
}

export function askActivityLine(language) {
  return plannerVoicePhrases(language).askActivity;
}

export function conflictLine(language) {
  return plannerVoicePhrases(language).conflict;
}

export function saveFailedLine(language) {
  return plannerVoicePhrases(language).saveFailed;
}

export function confirmationLine(catalogTitle, activity, days, language) {
  const code = plannerVoiceLanguage(language);
  const phrases = plannerVoicePhrases(code);
  const day = activity.localDate === days.today
    ? phrases.today
    : activity.localDate === days.tomorrow
      ? phrases.tomorrow
      : activity.localDate === days.dayAfterTomorrow
        ? phrases.dayAfter
        : spokenDate(activity.localDate, code);
  return phrases.added(
    spokenActivityName(catalogTitle, code),
    day,
    rangeClock(activity.localStart, code),
    rangeClock(activity.localEnd, code),
  );
}

const RUSSIAN_HOUR = {
  nom: ['двенадцать', 'час', 'два часа', 'три часа', 'четыре часа', 'пять', 'шесть', 'семь', 'восемь', 'девять', 'десять', 'одиннадцать'],
  gen: ['двенадцати', 'часа', 'двух часов', 'трёх часов', 'четырёх часов', 'пяти', 'шести', 'семи', 'восьми', 'девяти', 'десяти', 'одиннадцати'],
};

function russianMinuteWords(minute) {
  if (minute === 0) return '';
  const under = ['', 'один', 'два', 'три', 'четыре', 'пять', 'шесть', 'семь', 'восемь', 'девять', 'десять', 'одиннадцать', 'двенадцать', 'тринадцать', 'четырнадцать', 'пятнадцать', 'шестнадцать', 'семнадцать', 'восемнадцать', 'девятнадцать'];
  if (minute < 20) return minute < 10 ? `ноль ${under[minute]}` : under[minute];
  const tens = ['', '', 'двадцать', 'тридцать', 'сорок', 'пятьдесят'];
  const one = minute % 10;
  const ten = Math.floor(minute / 10);
  return one === 0 ? tens[ten] : `${tens[ten]} ${under[one]}`;
}

function russianClock(hour, minute, grammaticalCase) {
  if (hour === 0 && minute === 0) return grammaticalCase === 'gen' ? 'полуночи' : 'полночь';
  if (hour === 12 && minute === 0) return grammaticalCase === 'gen' ? 'полудня' : 'полдень';
  const clock = hour % 12;
  const period = hour < 12 ? 'утра' : hour < 17 ? 'дня' : 'вечера';
  const name = RUSSIAN_HOUR[grammaticalCase === 'gen' ? 'gen' : 'nom'][clock];
  const minutes = russianMinuteWords(minute);
  return minutes ? `${name} ${minutes} ${period}` : `${name} ${period}`;
}

export function spokenClock(time, language, grammaticalCase = 'nom') {
  const match = /^(\d{1,2}):(\d{2})$/.exec(String(time || ''));
  if (!match) return String(time || '');
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return String(time);
  const code = plannerVoiceLanguage(language);
  if (code === 'ru') return russianClock(hour, minute, grammaticalCase);
  const clockHour = hour % 12 || 12;
  const minutes = minute === 0 ? '' : `:${String(minute).padStart(2, '0')}`;
  const padded = minute === 0 ? '' : String(minute).padStart(2, '0');
  if (code === 'en') return `${clockHour}${minutes}${hour < 12 ? 'am' : 'pm'}`;
  if (code === 'pl') return `${clockHour}${minutes} ${hour < 12 ? 'rano' : 'wieczorem'}`;
  if (code === 'fr') return `${clockHour}h${padded} ${hour < 12 ? 'du matin' : 'du soir'}`;
  if (code === 'es') return `${clockHour}${minutes} ${hour < 12 ? 'de la mañana' : 'de la tarde'}`;
  if (code === 'de') return `${clockHour}${minutes} Uhr ${hour < 12 ? 'morgens' : 'abends'}`;
  if (code === 'it') return `${clockHour}${minutes} ${hour < 12 ? 'di mattina' : 'di sera'}`;
  if (code === 'ja') return `${hour < 12 ? '午前' : '午後'}${clockHour}時${minute === 0 ? '' : `${minute}分`}`;
  if (code === 'ko') return `${hour < 12 ? '오전' : '오후'} ${clockHour}시${minute === 0 ? '' : ` ${minute}분`}`;
  if (code === 'zh-Hans') return `${hour < 12 ? '早上' : '晚上'}${clockHour}点${minute === 0 ? '' : `${minute}分`}`;
  return minute === 0 ? String(hour) : `${hour}:${String(minute).padStart(2, '0')}`;
}

const RUSSIAN_RANGE_HOUR = [
  'полуночи', 'часа', 'двух', 'трёх', 'четырёх', 'пяти', 'шести', 'семи', 'восьми', 'девяти', 'десяти', 'одиннадцати',
  'двенадцати', 'тринадцати', 'четырнадцати', 'пятнадцати', 'шестнадцати', 'семнадцати', 'восемнадцати', 'девятнадцати',
  'двадцати', 'двадцати одного', 'двадцати двух', 'двадцати трёх',
];

function russianRangeMinutes(minute) {
  if (minute === 0) return '';
  const under = ['', 'одного', 'двух', 'трёх', 'четырёх', 'пяти', 'шести', 'семи', 'восьми', 'девяти', 'десяти', 'одиннадцати', 'двенадцати', 'тринадцати', 'четырнадцати', 'пятнадцати', 'шестнадцати', 'семнадцати', 'восемнадцати', 'девятнадцати'];
  if (minute < 20) return minute < 10 ? `ноль ${under[minute]}` : under[minute];
  const tens = ['', '', 'двадцати', 'тридцати', 'сорока', 'пятидесяти'];
  const one = minute % 10;
  const ten = Math.floor(minute / 10);
  return one === 0 ? tens[ten] : `${tens[ten]} ${under[one]}`;
}

function russianRangeClock(hour, minute) {
  if (hour === 0 && minute === 0) return 'полуночи';
  const name = RUSSIAN_RANGE_HOUR[hour] || String(hour);
  const minutes = russianRangeMinutes(minute);
  return minutes ? `${name} ${minutes}` : name;
}

function rangeClock(stamp, language) {
  const match = /^(\d{2}):(\d{2})$/.exec(String(stamp || '').slice(11, 16));
  if (!match) return spokenClock(String(stamp || '').slice(11, 16), language);
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (plannerVoiceLanguage(language) === 'ru') return russianRangeClock(hour, minute);
  return spokenClock(`${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`, language);
}

function spokenDate(iso, language) {
  const [year, month, day] = iso.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day, 12));
  return new Intl.DateTimeFormat(LOCALES[language], {
    day: 'numeric',
    month: 'long',
    timeZone: 'UTC',
  }).format(date);
}

export function plannerVoicePreviewPhrases(language = 'ru', givenName = 'Макс') {
  const code = plannerVoiceLanguage(language);
  const days = {
    today: '2026-10-28',
    tomorrow: '2026-10-29',
    dayAfterTomorrow: '2026-10-30',
    timeZone: 'Europe/Moscow',
  };
  return {
    language: code,
    greeting: greetingLine(code, givenName),
    askTime: askTimeLine(code),
    confirmation: confirmationLine('Tennis', {
      localDate: days.tomorrow,
      localStart: '2026-10-29T13:00',
      localEnd: '2026-10-29T14:00',
    }, days, code),
    conflict: conflictLine(code),
  };
}
