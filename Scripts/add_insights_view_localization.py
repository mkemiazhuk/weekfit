#!/usr/bin/env python3
"""Add InsightsView / InsightsViewModel localization keys to Localizable.xcstrings."""
import json
from pathlib import Path

XCSTRINGS = Path(__file__).resolve().parents[1] / "WeekFit" / "Localizable.xcstrings"

TRANSLATIONS = {
    # Section / UI labels
    "insights.section.whyThisScore": ("WHY THIS SCORE", "ПОЧЕМУ ЭТОТ БАЛЛ"),
    "insights.section.driver": ("DRIVER", "ФАКТОР"),
    "insights.section.nextFocus": ("NEXT FOCUS", "СЛЕДУЮЩИЙ ФОКУС"),
    "insights.section.dataCoverage": ("DATA COVERAGE", "ПОКРЫТИЕ ДАННЫХ"),
    "insights.section.sleep": ("Sleep", "Сон"),
    "insights.section.meals": ("Meals", "Блюда"),
    "insights.section.water": ("Water", "Вода"),
    "insights.section.training": ("Training", "Тренировки"),
    "insights.section.trustMeter": ("Trust meter", "Индекс доверия"),
    "insights.section.building": ("Building", "Формируется"),
    "insights.section.secondarySignal": ("SECONDARY SIGNAL", "ДОПОЛНИТЕЛЬНЫЙ СИГНАЛ"),
    "insights.section.goal": ("Goal", "Цель"),
    "insights.section.expectedOutcome": ("Expected outcome", "Ожидаемый результат"),
    "insights.section.strongestPattern": ("STRONGEST PATTERN", "САМЫЙ СИЛЬНЫЙ ПАТТЕРН"),
    "insights.section.emergingTrend": ("EMERGING TREND", "НАМЕЧАЮЩИЙСЯ ТРЕНД"),
    "insights.section.weakestSignal": ("WEAKEST SIGNAL", "САМЫЙ СЛАБЫЙ СИГНАЛ"),
    "insights.section.whatWeLearned": ("WHAT WE LEARNED", "ЧТО МЫ УЗНАЛИ"),
    "insights.section.adjacentSignal": ("ADJACENT SIGNAL", "СМЕЖНЫЙ СИГНАЛ"),
    "insights.section.recoveryClue": ("RECOVERY CLUE", "ПОДСКАЗКА ПО ВОССТАНОВЛЕНИЮ"),
    "insights.section.biggestOpportunity": ("BIGGEST OPPORTUNITY", "ГЛАВНАЯ ВОЗМОЖНОСТЬ"),
    "insights.section.mostLikelyNextImprovement": ("MOST LIKELY NEXT IMPROVEMENT", "НАИБОЛЕЕ ВЕРОЯТНОЕ УЛУЧШЕНИЕ"),
    "insights.section.recoveryResponse": ("RECOVERY RESPONSE", "РЕАКЦИЯ ВОССТАНОВЛЕНИЯ"),
    "insights.section.trainingAndRecovery": ("TRAINING & RECOVERY", "ТРЕНИРОВКИ И ВОССТАНОВЛЕНИЕ"),
    "insights.section.nutritionInsight": ("NUTRITION INSIGHT", "ИНСАЙТ ПО ПИТАНИЮ"),
    "insights.section.hydrationInsight": ("HYDRATION INSIGHT", "ИНСАЙТ ПО ГИДРАТАЦИИ"),
    "insights.section.weeklyReflection": ("WEEKLY REFLECTION", "НЕДЕЛЬНАЯ РЕФЛЕКСИЯ"),
    # View
    "insights.view.screenTitle": ("Insights", "Инсайты"),
    "insights.view.screenSubtitle": ("Last 30 Days", "Последние 30 дней"),
    "insights.view.activityLoad": ("Activity load", "Нагрузка активности"),
    "insights.view.chart.30dAgo": ("30d ago", "30 дн. назад"),
    "insights.view.chart.15d": ("15d", "15 дн."),
    "insights.view.notEnoughDataYet": ("Not enough real data yet", "Пока недостаточно реальных данных"),
    "insights.view.confidence.highShort": ("High", "Высокая"),
    "insights.view.confidence.mediumShort": ("Medium", "Средняя"),
    "insights.view.confidence.withPercentFormat": ("%@ (%lld%%)", "%@ (%lld%%)"),
    "insights.view.chart.highLoad": ("High load", "Высокая нагрузка"),
    "insights.view.chart.lowLoad": ("Low load", "Низкая нагрузка"),
    "insights.view.chart.strongRecovery": ("Strong recovery", "Сильное восстановление"),
    "insights.view.chart.lowRecovery": ("Low recovery", "Низкое восстановление"),
    "insights.view.chart.proteinTarget": ("Protein target", "Цель по белку"),
    "insights.view.chart.consistentIntake": ("Consistent intake", "Стабильное потребление"),
    "insights.view.chart.belowTarget": ("Below target", "Ниже цели"),
    "insights.view.chart.high": ("High", "Высокий"),
    "insights.view.chart.low": ("Low", "Низкий"),
    "insights.view.hero.sleepScore": ("Sleep Score", "Показатель сна"),
    "insights.view.hero.recoveryScore": ("Recovery Score", "Показатель восстановления"),
    "insights.view.hero.sleepDuration": ("Sleep Duration", "Длительность сна"),
    "insights.view.hero.trainingLoad": ("Training Load", "Тренировочная нагрузка"),
    "insights.view.hero.nutritionSignal": ("Nutrition Signal", "Сигнал питания"),
    "insights.view.hero.hydrationSignal": ("Hydration Signal", "Сигнал гидратации"),
    "insights.view.hero.consistency": ("Consistency", "Стабильность"),
    "insights.view.hero.patternReadiness": ("Pattern Readiness", "Готовность паттерна"),
    "insights.view.hero.averageSuffix": ("%@ average", "%@ в среднем"),
    "insights.view.hero.scoreOutOf100Format": ("%lld / 100", "%lld / 100"),
    "insights.view.hero.sleepTargetGapFormat": ("Target: 7h • Gap: %@", "Цель: 7 ч • Разрыв: %@"),
    "insights.view.hero.aboveTargetFormat": ("Above target by +%lld", "Выше цели на +%lld"),
    "insights.view.hero.belowTargetFormat": ("Below target by %lld", "Ниже цели на %lld"),
    "insights.view.trend.noChange": ("→ No meaningful change detected", "→ Значимых изменений не обнаружено"),
    "insights.view.trend.buildsWithData": ("Trend builds with real data", "Тренд формируется по реальным данным"),
    "insights.view.trend.improving": ("↑ Improving over 30 days", "↑ Улучшение за 30 дней"),
    "insights.view.trend.declining": ("↓ Declining over 30 days", "↓ Снижение за 30 дней"),
    "insights.view.trend.stable": ("→ Stable over 30 days", "→ Стабильно за 30 дней"),
    "insights.view.driver.sleepDuration": ("Sleep Duration", "Длительность сна"),
    "insights.view.driver.trainingLoad": ("Training Load", "Тренировочная нагрузка"),
    "insights.view.driver.proteinConsistency": ("Protein Consistency", "Стабильность белка"),
    "insights.view.driver.recoveryConsistency": ("Recovery Consistency", "Стабильность восстановления"),
    "insights.view.driver.hydration": ("Hydration", "Гидратация"),
    "insights.view.driver.loggingConsistency": ("Logging Consistency", "Стабильность записей"),
    "insights.view.target.sleep7h": ("Target: 7h", "Цель: 7 ч"),
    "insights.view.target.protein6of7": ("Target: 6 of 7 days", "Цель: 6 из 7 дней"),
    "insights.view.target.stableWeeklyLoad": ("Target: stable weekly load", "Цель: стабильная недельная нагрузка"),
    "insights.view.target.recovery72": ("Target: 72+ recovery", "Цель: 72+ восстановление"),
    "insights.view.target.consistentIntake": ("Target: consistent intake", "Цель: стабильное потребление"),
    "insights.view.target.completeLogs": ("Target: complete logs", "Цель: полные записи"),
    "insights.view.expectedOutcomeFallback": ("The next insight should be based on a cleaner pattern.", "Следующий инсайт должен основываться на более чётком паттерне."),
    "insights.view.driverExplanation.sleepDecline": ("Recovery decline is most strongly associated with reduced sleep duration.", "Снижение восстановления сильнее всего связано с уменьшением длительности сна."),
    "insights.view.driverExplanation.sleepSupport": ("Average sleep is the strongest support signal in this trend.", "Средний сон — самый сильный поддерживающий сигнал в этом тренде."),
    "insights.view.driverExplanation.activityDecline": ("Recovery decline is most strongly associated with training load.", "Снижение восстановления сильнее всего связано с тренировочной нагрузкой."),
    "insights.view.driverExplanation.activitySupport": ("Training load is the strongest signal behind this trend.", "Тренировочная нагрузка — самый сильный сигнал за этим трендом."),
    "insights.view.driverExplanation.nutrition": ("Protein consistency is the strongest nutrition signal in this trend.", "Стабильность белка — самый сильный сигнал питания в этом тренде."),
    "insights.view.driverExplanation.recovery": ("Recovery consistency is the strongest signal in the 30-day pattern.", "Стабильность восстановления — самый сильный сигнал в 30-дневном паттерне."),
    "insights.view.driverExplanation.hydration": ("Hydration is the strongest support signal in this trend.", "Гидратация — самый сильный поддерживающий сигнал в этом тренде."),
    "insights.view.driverExplanation.missingData": ("Insights needs a cleaner 30-day pattern before naming a stronger driver.", "Инсайтам нужен более чёткий 30-дневный паттерн, прежде чем назвать более сильный фактор."),
    "insights.view.graph.comparison": ("Comparison", "Сравнение"),
    "insights.view.graph.distribution": ("Distribution", "Распределение"),
    "insights.view.graph.pairedSignals": ("Paired signals", "Парные сигналы"),
    "insights.view.graph.consistency": ("Consistency", "Стабильность"),
    "insights.view.graph.weeklyPattern": ("Weekly pattern", "Недельный паттерн"),
    "insights.view.graph.signalStrength": ("Signal strength", "Сила сигнала"),
    "insights.view.graph.contributors": ("contributors", "факторы"),
    "insights.view.graph.trendChange": ("Trend change", "Изменение тренда"),
    "insights.view.graph.monthlySleep": ("Monthly sleep trend", "Месячный тренд сна"),
    "insights.view.graph.monthlyRecovery": ("Monthly recovery trend", "Месячный тренд восстановления"),
    "insights.view.graph.monthlyTraining": ("Monthly training trend", "Месячный тренд тренировок"),
    "insights.view.graph.monthlyNutrition": ("Monthly nutrition trend", "Месячный тренд питания"),
    "insights.view.graph.monthlyHydration": ("Monthly hydration trend", "Месячный тренд гидратации"),
    "insights.view.graph.patternBuilding": ("Pattern building", "Формирование паттерна"),
    "insights.view.graphCaption.distribution": ("distribution", "распределение"),
    "insights.view.graphCaption.correlationFormat": ("%@ with %@", "%@ с %@"),
    "insights.view.graphCaption.consistencyFormat": ("%@ / %@", "%@ / %@"),
    "insights.view.graphCaption.weeklyPattern": ("weekly pattern", "недельный паттерн"),
    "insights.view.graphCaption.contributors": ("contributors", "факторы"),
    # VM — workload
    "insights.vm.workload.recoveryWeek": ("This looks like a recovery week, so training is unlikely to be the main stressor.", "Похоже на неделю восстановления, поэтому тренировки вряд ли являются главным стрессором."),
    "insights.vm.workload.lightWeek": ("This is a light training week, leaving room to build without forcing intensity.", "Лёгкая тренировочная неделя — есть запас для роста без форсирования интенсивности."),
    "insights.vm.workload.normalWeek": ("This looks like a normal training week, so recovery response matters more than volume alone.", "Обычная тренировочная неделя — реакция восстановления важнее одного только объёма."),
    "insights.vm.workload.productiveWeek": ("This has been a productive training week, enough to build fitness without looking excessive.", "Продуктивная тренировочная неделя — достаточно для роста формы без перегруза."),
    "insights.vm.workload.heavyWeek": ("This has been one of your heavier recent training weeks, so recovery needs to hold steady.", "Одна из более тяжёлых недавних недель — восстановление должно оставаться стабильным."),
    "insights.vm.workload.veryHighLoad": ("This is a very high load week, and recovery response should decide whether to push or back off.", "Очень высокая нагрузка — реакция восстановления должна определить, наращивать или снижать."),
    "insights.vm.progression.holdUntilRecovery": ("Hold volume steady until recovery rises before adding another hard session.", "Держите объём стабильным, пока восстановление не вырастет, прежде чем добавлять ещё одну тяжёлую сессию."),
    "insights.vm.progression.betterDistribution": ("The next level is better distribution: keep volume similar and spread hard efforts across the week.", "Следующий уровень — лучшее распределение: сохраните объём и распределите тяжёлые усилия по неделе."),
    "insights.vm.progression.controlledSession": ("The next level is one more controlled session or a small intensity bump, only if recovery stays stable.", "Следующий уровень — ещё одна контролируемая сессия или небольшой рост интенсивности, только если восстановление стабильно."),
    "insights.vm.progression.buildThreeHours": ("The next level is building toward three hours of weekly activity before chasing intensity.", "Следующий уровень — выйти на три часа еженедельной активности, прежде чем гнаться за интенсивностью."),
    # VM — learnings
    "insights.vm.learnings.absorbingWorkload.title": ("Recovery is absorbing your workload", "Восстановление поглощает вашу нагрузку"),
    "insights.vm.learnings.absorbingWorkload.textFormat": ("%@ Recovery stayed stable, suggesting your body is absorbing the workload well.", "%@ Восстановление оставалось стабильным — организм хорошо поглощает нагрузку."),
    "insights.vm.learnings.loadPressing.title": ("Training load is pressing recovery", "Тренировочная нагрузка давит на восстановление"),
    "insights.vm.learnings.loadPressing.textFormat": ("%@ Recovery is not keeping pace, so the issue looks like load management rather than motivation.", "%@ Восстановление не успевает — проблема скорее в управлении нагрузкой, чем в мотивации."),
    "insights.vm.learnings.recoveryStable.title": ("Recovery is your most stable signal", "Восстановление — ваш самый стабильный сигнал"),
    "insights.vm.learnings.recoveryWatch.title": ("Recovery is the signal to watch", "Восстановление — сигнал, за которым стоит следить"),
    "insights.vm.learnings.recoveryStable.text": ("Recovery has enough history and is holding steady, so changes in sleep or training can be interpreted more clearly.", "Достаточно истории восстановления, и оно держится стабильно — изменения сна или тренировок можно интерпретировать яснее."),
    "insights.vm.learnings.recoveryWatch.text": ("Recovery has enough history to be useful, but it is not yet stable enough to ignore.", "Истории восстановления достаточно для пользы, но оно ещё недостаточно стабильно, чтобы его игнорировать."),
    "insights.vm.learnings.sleepImproved.text": ("Sleep has improved recently, which may give recovery more room to stay strong.", "Сон недавно улучшился — это может дать восстановлению больше запаса."),
    "insights.vm.learnings.sleepBelowTarget.text": ("Sleep remains below target often enough that it is the clearest bottleneck to test next.", "Сон часто ниже цели — это самое явное узкое место для проверки."),
    "insights.vm.learnings.sleepConsistent.text": ("Sleep is consistent enough to support recovery rather than explain current problems.", "Сон достаточно стабилен, чтобы поддерживать восстановление, а не объяснять текущие проблемы."),
    "insights.vm.learnings.sleepLever.title": ("Sleep is the clearest recovery lever", "Сон — самый явный рычаг восстановления"),
    "insights.vm.learnings.sleepBase.title": ("Sleep is becoming a stable base", "Сон становится стабильной базой"),
    "insights.vm.learnings.nutritionUnclear.title": ("Nutrition patterns are not clear yet", "Паттерны питания пока неясны"),
    "insights.vm.learnings.nutritionUnclear.text": ("Nutrition has too few logged days to explain recovery changes. It should stay supporting context until logging is steadier.", "Слишком мало записанных дней питания, чтобы объяснить изменения восстановления. Пока записи не станут стабильнее, это лишь контекст."),
    "insights.vm.learnings.patternForming.title": ("The pattern is still forming", "Паттерн ещё формируется"),
    "insights.vm.learnings.patternForming.text": ("There is not enough overlapping sleep, recovery, training and nutrition data yet to make a personal discovery.", "Пока недостаточно пересекающихся данных о сне, восстановлении, тренировках и питании для личного открытия."),
    "insights.vm.learnings.adjacent.title": ("The supporting context is still forming", "Поддерживающий контекст ещё формируется"),
    "insights.vm.learnings.adjacent.text": ("The main story is clear enough to act on, but adjacent sleep, recovery, training or nutrition patterns need more overlap before they become separate discoveries.", "Главная история достаточно ясна для действий, но смежным паттернам сна, восстановления, тренировок или питания нужно больше пересечения, прежде чем они станут отдельными открытиями."),
    "insights.vm.learnings.shortSleep.title": ("Recovery drops most after short sleep", "Восстановление сильнее всего падает после короткого сна"),
    "insights.vm.learnings.shortSleep.textFormat": ("Days after 7h+ sleep average about +%lld recovery points compared with short-sleep nights.", "Дни после 7+ ч сна в среднем дают около +%lld баллов восстановления по сравнению с ночами короткого сна."),
    # VM — opportunity
    "insights.vm.opportunity.sleepBottleneck.title": ("Sleep is the next bottleneck to test", "Сон — следующее узкое место для проверки"),
    "insights.vm.opportunity.sleepBottleneck.text": ("Adding 30-45 minutes of sleep is more likely to improve recovery than adding another workout right now.", "Добавить 30–45 минут сна сейчас вероятнее улучшит восстановление, чем ещё одна тренировка."),
    "insights.vm.opportunity.proveLoad.title": ("Let recovery prove the load is working", "Дайте восстановлению подтвердить, что нагрузка работает"),
    "insights.vm.opportunity.proveLoad.text": ("The next improvement is likely to come from absorbing the current training load, not adding more volume.", "Следующее улучшение скорее придёт от усвоения текущей нагрузки, а не от добавления объёма."),
    "insights.vm.opportunity.nutritionVisible.title": ("Make nutrition visible enough to learn from", "Сделайте питание достаточно видимым для анализа"),
    "insights.vm.opportunity.nutritionVisible.text": ("More complete meal logging would show whether food is actually influencing recovery or just adding noise.", "Более полная запись блюд покажет, влияет ли еда на восстановление или только добавляет шум."),
    "insights.vm.opportunity.keepRhythm.title": ("Keep the rhythm steady", "Держите ритм стабильным"),
    "insights.vm.opportunity.keepRhythm.text": ("Recovery is already strong enough that the next useful lesson is which habit keeps it stable when training changes.", "Восстановление уже достаточно сильное — следующий полезный урок: какая привычка держит его стабильным при изменении тренировок."),
    # VM — weekly scores
    "insights.vm.weekly.consistentHistory": ("consistent history", "стабильная история"),
    "insights.vm.weekly.recentHistory": ("recent history", "недавняя история"),
    "insights.vm.weekly.connectHealth": ("connect Health", "подключите Здоровье"),
    "insights.vm.weekly.connectSleep": ("connect sleep", "подключите сон"),
    "insights.vm.weekly.fullRecentWeek": ("full recent week", "полная недавняя неделя"),
    "insights.vm.weekly.syncOrLog": ("sync or log", "синхронизируйте или запишите"),
    "insights.vm.weekly.proteinConsistent": ("protein consistent", "белок стабилен"),
    "insights.vm.weekly.loggingBuilding": ("logging building", "запись формируется"),
    "insights.vm.weekly.logMeals": ("log meals", "записывайте блюда"),
    # VM — recovery trend
    "insights.vm.trend.recoveryBuilding.title": ("Recovery history is still building", "История восстановления ещё формируется"),
    "insights.vm.trend.recoveryBuilding.subtitle": ("Insights needs more recent recovery data before comparing the last 7 days with your baseline.", "Инсайтам нужно больше недавних данных о восстановлении, прежде чем сравнивать последние 7 дней с базой."),
    "insights.vm.trend.recoveryBuilding.takeaway": ("Keep recovery logging steady to unlock the longer story.", "Ведите стабильную запись восстановления, чтобы открыть более длинную историю."),
    "insights.vm.trend.recoveryLosing.title": ("Recovery is losing momentum", "Восстановление теряет импульс"),
    "insights.vm.trend.recoveryLosing.takeaway": ("Hold volume until the recent average rebounds.", "Держите объём, пока недавнее среднее не восстановится."),
    "insights.vm.trend.recoveryRebounding.title": ("Recovery is rebounding", "Восстановление отскакивает"),
    "insights.vm.trend.recoveryRebounding.takeaway": ("Keep the rhythm steady and watch whether the rebound holds.", "Держите ритм стабильным и следите, сохранится ли отскок."),
    "insights.vm.trend.recoveryResilient.title": ("Recovery looks resilient", "Восстановление выглядит устойчивым"),
    "insights.vm.trend.recoveryStableNotHigh.title": ("Recovery is stable but not high", "Восстановление стабильно, но не высокое"),
    "insights.vm.trend.recoveryResilient.takeaway": ("The current rhythm is being absorbed.", "Текущий ритм усваивается."),
    "insights.vm.trend.recoveryStableNotHigh.takeaway": ("Use the next week to improve the base before adding load.", "Используйте следующую неделю для улучшения базы, прежде чем добавлять нагрузку."),
    "insights.vm.trend.recoveryCompareFormat": ("Recent 7 days average %lld vs %lld across the previous baseline. Latest is %lld.", "Среднее за последние 7 дней %lld против %lld по предыдущей базе. Последнее значение — %lld."),
    "insights.vm.trend.recoveryDaysFormat": ("Over the last %lld recovery days, latest recovery is %lld.", "За последние %lld дней восстановления последнее значение — %lld."),
    # VM — training & recovery trend
    "insights.vm.trend.trainingForming.title": ("Training rhythm is still forming", "Тренировочный ритм ещё формируется"),
    "insights.vm.trend.trainingForming.subtitle": ("Current activity is not yet high enough to compare against recovery in a meaningful way.", "Текущая активность ещё недостаточно высока для осмысленного сравнения с восстановлением."),
    "insights.vm.trend.trainingForming.takeaway": ("Build toward three hours of weekly activity before judging adaptation.", "Выйдите на три часа еженедельной активности, прежде чем оценивать адаптацию."),
    "insights.vm.trend.trainingMissingContext.title": ("Training volume is visible, but recovery context is missing", "Объём тренировок виден, но контекста восстановления не хватает"),
    "insights.vm.trend.trainingMissingContext.takeaway": ("Recovery history is needed before changing load.", "Нужна история восстановления, прежде чем менять нагрузку."),
    "insights.vm.trend.trainingKeepingUp.title": ("Recovery is keeping up with training", "Восстановление успевает за тренировками"),
    "insights.vm.trend.trainingKeepingUp.subtitleFormat": ("%@ Recovery remained stable, suggesting your body is absorbing the workload well.", "%@ Восстановление оставалось стабильным — организм хорошо поглощает нагрузку."),
    "insights.vm.trend.trainingLighterWeek.title": ("Training may need a lighter week", "Тренировкам может понадобиться более лёгкая неделя"),
    "insights.vm.trend.trainingLighterWeek.subtitleFormat": ("%@ Recovery is below target, so the workload may be outpacing adaptation.", "%@ Восстановление ниже цели — нагрузка может опережать адаптацию."),
    # VM — nutrition trend
    "insights.vm.trend.nutritionNotEnough.title": ("Not enough nutrition data", "Недостаточно данных о питании"),
    "insights.vm.trend.nutritionNotEnough.takeaway": ("Start with consistent meal logging.", "Начните со стабильной записи блюд."),
    "insights.vm.trend.proteinLimiting.title": ("Protein consistency is limiting recovery insight", "Стабильность белка ограничивает инсайты по восстановлению"),
    "insights.vm.trend.proteinLimiting.subtitleFormat": ("%lld days met protein target in the last 7 days.", "%lld дней с достигнутой целью по белку за последние 7 дней."),
    "insights.vm.trend.proteinLimiting.takeaway": ("Hit protein more consistently before changing training.", "Добивайтесь белка стабильнее, прежде чем менять тренировки."),
    "insights.vm.trend.nutritionSupporting.title": ("Nutrition is supporting recovery insight", "Питание поддерживает инсайты по восстановлению"),
    "insights.vm.trend.nutritionSupporting.proteinFormat": ("Protein was on target %lld days this week.", "Цель по белку достигнута %lld дней на этой неделе."),
    "insights.vm.trend.nutritionSupporting.mealsConsistent": ("Meal logging was consistent this week.", "Запись блюд была стабильной на этой неделе."),
    "insights.vm.trend.nutritionSupporting.takeaway": ("Keep meal logging steady while training changes.", "Держите запись блюд стабильной при изменении тренировок."),
    "insights.vm.trend.nutritionImproving.title": ("Nutrition consistency is improving", "Стабильность питания улучшается"),
    "insights.vm.trend.nutritionImproving.takeaway": ("Keep food logging steady while recovery history builds.", "Держите запись еды стабильной, пока формируется история восстановления."),
    # VM — hydration
    "insights.vm.hydration.waterEvidence": ("Water evidence", "Данные по воде"),
    "insights.vm.hydration.recoveryContext": ("Recovery context", "Контекст восстановления"),
    "insights.vm.hydration.unavailable.title": ("Hydration insight unavailable", "Инсайт по гидратации недоступен"),
    "insights.vm.hydration.cleanerSample.title": ("Hydration needs a cleaner sample", "Гидратации нужна более чистая выборка"),
    "insights.vm.hydration.cleanerSample.subtitle": ("The last 7 days have logs, but not enough contrast to compare recovery.", "За последние 7 дней есть записи, но недостаточно контраста для сравнения восстановления."),
    "insights.vm.hydration.notLimiter.title": ("Hydration is not the obvious limiter", "Гидратация — не очевидный ограничитель"),
    "insights.vm.hydration.notLimiter.subtitle": ("Recent paired logs do not show a meaningful recovery difference.", "Недавние парные записи не показывают значимой разницы в восстановлении."),
    "insights.vm.hydration.helping.title": ("Hydration may be helping recovery", "Гидратация может помогать восстановлению"),
    "insights.vm.hydration.notRecoveryLimiter.title": ("Hydration is not the recovery limiter", "Гидратация — не ограничитель восстановления"),
    "insights.vm.hydration.helping.subtitleFormat": ("In the last 7 days, higher-water days averaged +%lld recovery.", "За последние 7 дней дни с большим потреблением воды в среднем давали +%lld восстановления."),
    "insights.vm.hydration.notRecoveryLimiter.subtitle": ("Higher-water days did not improve recovery in this 7-day sample.", "Дни с большим потреблением воды не улучшили восстановление в этой 7-дневной выборке."),
    # VM — reflection
    "insights.vm.reflection.needsDays": ("Insights needs a few real logged days before it can compare patterns.", "Инсайтам нужно несколько реальных записанных дней, прежде чем сравнивать паттерны."),
    "insights.vm.reflection.coachPatternFormat": ("The strongest pattern supports the same theme Coach is watching now: %@. Use Insights for the pattern, Coach for the next immediate step.", "Самый сильный паттерн поддерживает ту же тему, за которой сейчас следит Тренер: %@. Используйте Инсайты для паттерна, Тренера — для следующего шага."),
    "insights.vm.reflection.clearestPatternFormat": ("%@ is the clearest pattern. The rest of the screen explains whether that signal is supported by training, nutrition and hydration consistency.", "%@ — самый явный паттерн. Остальная часть экрана объясняет, поддерживается ли этот сигнал стабильностью тренировок, питания и гидратации."),
    "insights.vm.reflection.domain.recovery": ("recovery", "восстановление"),
    "insights.vm.reflection.domain.sleep": ("sleep", "сон"),
    "insights.vm.reflection.domain.hydration": ("hydration", "гидратация"),
    "insights.vm.reflection.domain.nutrition": ("nutrition", "питание"),
    "insights.vm.reflection.domain.activity": ("activity", "активность"),
}


def make_entry(en: str, ru: str) -> dict:
    return {
        "extractionState": "manual",
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en}},
            "ru": {"stringUnit": {"state": "translated", "value": ru}},
        },
    }


def main() -> None:
    with XCSTRINGS.open(encoding="utf-8") as f:
        data = json.load(f)

    strings = data["strings"]
    added = 0
    skipped = 0
    for key, (en, ru) in TRANSLATIONS.items():
        if key in strings:
            skipped += 1
            continue
        strings[key] = make_entry(en, ru)
        added += 1

    with XCSTRINGS.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Added {added} keys, skipped {skipped} existing")
    print(f"Total keys in script: {len(TRANSLATIONS)}")


if __name__ == "__main__":
    main()
