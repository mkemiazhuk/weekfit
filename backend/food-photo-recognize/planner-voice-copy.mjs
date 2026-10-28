/** Spoken planner copy. Language comes from the app setting, never from the time zone. */

export const PLANNER_VOICE_LANGUAGES = ['en', 'ru', 'zh-Hans', 'fr', 'pl', 'es', 'de', 'ja', 'it', 'ko'];

const SPOKEN = {
  Cycling: { ru: 'велосипед', en: 'cycling', pl: 'rower', fr: 'vélo', es: 'ciclismo', de: 'Radfahren', 'zh-Hans': '骑行', ja: 'サイクリング', it: 'ciclismo', ko: '사이클링' },
  Running: { ru: 'бег', en: 'running', pl: 'bieg', fr: 'course', es: 'carrera', de: 'Laufen', 'zh-Hans': '跑步', ja: 'ランニング', it: 'corsa', ko: '러닝' },
  Swimming: { ru: 'плавание', en: 'swimming', pl: 'pływanie', fr: 'natation', es: 'natación', de: 'Schwimmen', 'zh-Hans': '游泳', ja: '水泳', it: 'nuoto', ko: '수영' },
  Hiking: { ru: 'хайкинг', en: 'hiking', pl: 'wędrówkę', fr: 'randonnée', es: 'senderismo', de: 'Wandern', 'zh-Hans': '徒步', ja: 'ハイキング', it: 'escursione', ko: '하이킹' },
  Snowboarding: { ru: 'сноуборд', en: 'snowboarding', pl: 'snowboard', fr: 'snowboard', es: 'snowboard', de: 'Snowboarden', 'zh-Hans': '单板滑雪', ja: 'スノーボード', it: 'snowboard', ko: '스노보드' },
  'Alpine Skiing': { ru: 'лыжи', en: 'skiing', pl: 'narty', fr: 'ski', es: 'esquí', de: 'Skifahren', 'zh-Hans': '滑雪', ja: 'スキー', it: 'sci', ko: '스키' },
  'Upper Body': { ru: 'верх тела', en: 'upper body', pl: 'górną część ciała', fr: 'haut du corps', es: 'tren superior', de: 'Oberkörper', 'zh-Hans': '上肢', ja: '上半身', it: 'parte superiore', ko: '상체' },
  Core: { ru: 'кор', en: 'core', pl: 'core', fr: 'gainage', es: 'core', de: 'Core', 'zh-Hans': '核心', ja: '体幹', it: 'core', ko: '코어' },
  'Lower Body': { ru: 'низ тела', en: 'lower body', pl: 'dolną część ciała', fr: 'bas du corps', es: 'tren inferior', de: 'Unterkörper', 'zh-Hans': '下肢', ja: '下半身', it: 'parte inferiore', ko: '하체' },
  'Full Body': { ru: 'все тело', en: 'full body', pl: 'całe ciało', fr: 'corps entier', es: 'cuerpo completo', de: 'Ganzkörper', 'zh-Hans': '全身', ja: '全身', it: 'corpo intero', ko: '전신' },
  Tennis: { ru: 'теннис', en: 'tennis', pl: 'tenis', fr: 'tennis', es: 'tenis', de: 'Tennis', 'zh-Hans': '网球', ja: 'テニス', it: 'tennis', ko: '테니스' },
  Padel: { ru: 'падел', en: 'padel', pl: 'padel', fr: 'padel', es: 'pádel', de: 'Padel', 'zh-Hans': '板式网球', ja: 'パデル', it: 'padel', ko: '파델' },
  Squash: { ru: 'сквош', en: 'squash', pl: 'squash', fr: 'squash', es: 'squash', de: 'Squash', 'zh-Hans': '壁球', ja: 'スカッシュ', it: 'squash', ko: '스쿼시' },
  'High Intensity Interval Training': { ru: 'интервальную', en: 'intervals', pl: 'interwały', fr: 'intervalles', es: 'intervalos', de: 'Intervalle', 'zh-Hans': '间歇训练', ja: 'インターバル', it: 'intervalli', ko: '인터벌' },
  Stretching: { ru: 'растяжку', en: 'stretching', pl: 'rozciąganie', fr: 'étirements', es: 'estiramientos', de: 'Dehnen', 'zh-Hans': '拉伸', ja: 'ストレッチ', it: 'stretching', ko: '스트레칭' },
  Walk: { ru: 'прогулку', en: 'a walk', pl: 'spacer', fr: 'marche', es: 'un paseo', de: 'einen Spaziergang', 'zh-Hans': '散步', ja: '散歩', it: 'una camminata', ko: '산책' },
  Sauna: { ru: 'сауну', en: 'the sauna', pl: 'saunę', fr: 'sauna', es: 'la sauna', de: 'die Sauna', 'zh-Hans': '桑拿', ja: 'サウナ', it: 'la sauna', ko: '사우나' },
  Yoga: { ru: 'йогу', en: 'yoga', pl: 'jogę', fr: 'yoga', es: 'yoga', de: 'Yoga', 'zh-Hans': '瑜伽', ja: 'ヨガ', it: 'yoga', ko: '요가' },
  Breathing: { ru: 'дыхание', en: 'breathing', pl: 'oddech', fr: 'respiration', es: 'respiración', de: 'Atmung', 'zh-Hans': '呼吸', ja: '呼吸', it: 'respirazione', ko: '호흡' },
  'Drink Water': { ru: 'воду', en: 'water', pl: 'wodę', fr: 'eau', es: 'agua', de: 'Wasser', 'zh-Hans': '喝水', ja: '水分', it: 'acqua', ko: '물' },
  'Sleep Routine': { ru: 'сон', en: 'sleep', pl: 'sen', fr: 'sommeil', es: 'sueño', de: 'Schlaf', 'zh-Hans': '睡眠', ja: '睡眠', it: 'sonno', ko: '수면' },
  'No Screens': { ru: 'без экрана', en: 'no screens', pl: 'bez ekranu', fr: 'sans écran', es: 'sin pantallas', de: 'keine Bildschirme', 'zh-Hans': '远离屏幕', ja: '画面オフ', it: 'niente schermi', ko: '화면 끄기' },
  'Morning Routine': { ru: 'утреннюю рутину', en: 'the morning routine', pl: 'poranną rutynę', fr: 'routine du matin', es: 'la rutina de la mañana', de: 'die Morgenroutine', 'zh-Hans': '早晨例程', ja: '朝のルーティン', it: 'la routine del mattino', ko: '아침 루틴' },
};

const PHRASES = {
  ru: {
    englishName: 'Russian',
    greeting: name => (name ? `Привет, ${name}. Чем могу помочь?` : 'Привет. Чем могу помочь?'),
    goodbye: 'До свидания!',
    closing: '«всё», «всё, спасибо», «спасибо», «до свидания», «пока»',
    askTime: 'Во сколько?',
    askActivity: 'Какую активность?',
    conflict: 'Это время уже занято.',
    saveFailed: 'Не получилось сохранить. Повтори, пожалуйста.',
    today: 'сегодня',
    tomorrow: 'завтра',
    dayAfter: 'послезавтра',
    added: (spoken, day, start, end) => `Добавил ${spoken} на ${day}, с ${start} до ${end}.`,
  },
  en: {
    englishName: 'English',
    greeting: name => (name ? `Hi, ${name}. How can I help you?` : 'Hi. How can I help you?'),
    goodbye: 'Bye!',
    closing: '"that\'s all", "thanks", "thank you", "goodbye", "bye"',
    askTime: 'What time?',
    askActivity: 'Which activity?',
    conflict: 'That time is already taken.',
    saveFailed: "I couldn't save that. Please try again.",
    today: 'today',
    tomorrow: 'tomorrow',
    dayAfter: 'the day after tomorrow',
    added: (spoken, day, start, end) => `Added ${spoken} for ${day}, from ${start} to ${end}.`,
  },
  pl: {
    englishName: 'Polish',
    greeting: name => (name ? `Cześć, ${name}. W czym mogę pomóc?` : 'Cześć. W czym mogę pomóc?'),
    goodbye: 'Do widzenia!',
    closing: '«to wszystko», «dzięki», «dziękuję», «do widzenia», «pa»',
    askTime: 'O której?',
    askActivity: 'Jaką aktywność?',
    conflict: 'Ta godzina jest już zajęta.',
    saveFailed: 'Nie udało się zapisać. Spróbuj jeszcze raz.',
    today: 'dzisiaj',
    tomorrow: 'jutro',
    dayAfter: 'pojutrze',
    added: (spoken, day, start, end) => `Dodałem ${spoken} na ${day}, od ${start} do ${end}.`,
  },
  fr: {
    englishName: 'French',
    greeting: name => (name ? `Salut, ${name}. Comment puis-je t'aider ?` : 'Salut. Comment puis-je t\'aider ?'),
    goodbye: 'Au revoir !',
    closing: '«c\'est tout», «merci», «au revoir», «salut»',
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
    greeting: name => (name ? `Hola, ${name}. ¿En qué puedo ayudarte?` : 'Hola. ¿En qué puedo ayudarte?'),
    goodbye: '¡Adiós!',
    closing: '«eso es todo», «gracias», «adiós», «hasta luego»',
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
    greeting: name => (name ? `Hi, ${name}. Womit kann ich helfen?` : 'Hi. Womit kann ich helfen?'),
    goodbye: 'Tschüss!',
    closing: '«das war\'s», «danke», «auf Wiedersehen», «tschüss»',
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
    greeting: name => (name ? `你好，${name}。需要我帮什么？` : '你好。需要我帮什么？'),
    goodbye: '再见！',
    closing: '「就这样」「谢谢」「再见」',
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
    greeting: name => (name ? `こんにちは、${name}。何かお手伝いしましょうか？` : 'こんにちは。何かお手伝いしましょうか？'),
    goodbye: 'さようなら！',
    closing: '「以上です」「ありがとう」「さようなら」',
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
    greeting: name => (name ? `Ciao, ${name}. Come posso aiutarti?` : 'Ciao. Come posso aiutarti?'),
    goodbye: 'Ciao!',
    closing: '«è tutto», «grazie», «arrivederci», «ciao»',
    askTime: 'A che ora?',
    askActivity: 'Quale attività?',
    conflict: 'Quell\'orario è già occupato.',
    saveFailed: 'Non sono riuscito a salvare. Riprova.',
    today: 'oggi',
    tomorrow: 'domani',
    dayAfter: 'dopodomani',
    added: (spoken, day, start, end) => `Ho aggiunto ${spoken} per ${day}, dalle ${start} alle ${end}.`,
  },
  ko: {
    englishName: 'Korean',
    greeting: name => (name ? `안녕하세요, ${name}. 무엇을 도와드릴까요?` : '안녕하세요. 무엇을 도와드릴까요?'),
    goodbye: '안녕히 가세요!',
    closing: '「그거예요」, 「감사합니다」, 「안녕히 가세요」',
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

export function greetingLine(language, givenName) {
  return plannerVoicePhrases(language).greeting(givenName);
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
    clockWords(activity.localStart, code),
    clockWords(activity.localEnd, code),
  );
}

function clockWords(stamp, language) {
  const time = stamp.slice(11, 16);
  const [hour, minute] = time.split(':').map(Number);
  if (language === 'en') {
    const period = hour < 12 ? 'AM' : 'PM';
    const clockHour = hour % 12 || 12;
    const minutes = String(minute).padStart(2, '0');
    return minute === 0 ? `${clockHour} ${period}` : `${clockHour}:${minutes} ${period}`;
  }
  return minute === 0 ? String(hour) : `${hour}:${String(minute).padStart(2, '0')}`;
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
