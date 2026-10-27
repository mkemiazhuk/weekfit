# Coach / food recognition locale chain (fixture audit)

## Food photo recognition

1. **App setting** → `AppLanguage` / `WeekFitCurrentAppLanguage().rawValue`
2. **Client request** → `PhotoFoodRecognitionClient.recognitionLocaleIdentifier()` sends `locale` on `POST /v1/food/photo-analyze` (`PhotoFoodAPIContract`)
3. **Backend** → `recognition.mjs` `validateInput` → `resolveOutputLanguage(locale)` → `{ code, name }` for en/ru/zh-Hans/fr/pl/es/de/ja/it/ko
4. **Prompt** → `FOOD_INSTRUCTIONS(language)` + user line `App UI language: ${name} (${code})`
5. **Response** → JSON labels expected in that language; validated by schema (not by language detector)

**Verified without paid calls:** `backend/food-photo-recognize/service.test.mjs` (locale normalize + Russian/Chinese prompt language lock with mocked OpenAI).

**Not verified live:** actual model output quality per language (requires paid recognition).

## AI Coach evening summary

1. **App setting** → locale on summary input (`CoachEveningSummaryInputBuilder` / coordinator `locale`)
2. **Backend** → `coach-summary.mjs` `normalizeLocale` + `LANGUAGE LOCK` in prompt; retry on `hasEnglishLanguageLeak`
3. **Cache key** includes `locale` + prompt version

**Verified without paid calls:** locale normalize + English-leak heuristics in module; fixture script `scripts/eval-coach-summary-fixture.mjs` exists but needs `OPENAI_API_KEY` (skipped in this audit).

**Not verified live:** end-to-end Coach summary prose for all 10 languages.

## In-app Coach copy (non-LLM)

`CoachCoordinator` stores `languageCode` on today-insight cache; `WeekFitTrilingual` / `CoachStringOverrideResolver` / `CoachCopyPack` resolve against app language. No network.
