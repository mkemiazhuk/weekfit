# WeekFit — App Store Listing Copy

> Draft texts for App Store Connect. Adjust tone before submit.  
> **Bundle:** `com.weekfit.app` · **Category:** Health & Fitness

---

## App Name

**WeekFit**

---

## Subtitle (30 chars max)

**EN:** `Daily coach & fitness plan`  
**RU:** `Коуч и план на каждый день`

---

## Promotional Text (170 chars, updatable without review)

**EN:**
```
Your day, interpreted. WeekFit connects Apple Health to a calm daily Coach, meal guidance, and a visual plan — all on your phone.
```

**RU:**
```
Ваш день — с пониманием. WeekFit связывает Apple Health с ежедневным коучем, питанием и наглядным планом — всё на телефоне.
```

---

## Description

### English

```
WeekFit is a calm daily fitness companion that reads your Apple Health data and turns it into a clear plan for today.

WHAT YOU GET

• Today — your day at a glance: recovery, upcoming activities, and quick actions
• Coach — one leading recommendation that adapts to sleep, load, and what's on your schedule
• Plan — visual timeline for workouts, meals, and daily rhythm
• Meals — library and suggestions aligned with your Coach focus

BUILT AROUND APPLE HEALTH

WeekFit uses sleep, activity, heart rate, workouts, and nutrition from Apple Health to personalize guidance. Your data stays on your device. No account required to start.

DESIGNED FOR CLARITY

No noisy dashboards. One story per moment — whether you're preparing for a ride, recovering after a hard session, or winding down for tomorrow.

OPTIONAL PERMISSIONS

• Apple Health — personalize Coach and sync completed workouts
• Camera — add photos to custom foods (optional)
• Location — adjust Night Comfort theme at local sunset (optional)

WeekFit does not provide medical advice. Always consult a professional for health decisions.

Support: support@weekfit.app
```

### Russian

```
WeekFit — спокойный ежедневный фитнес-компаньон, который читает данные Apple Health и превращает их в понятный план на сегодня.

ЧТО ВНУТРИ

• Сегодня — обзор дня: восстановление, ближайшие активности и быстрые действия
• Коуч — одна главная рекомендация с учётом сна, нагрузки и расписания
• План — визуальная лента тренировок, приёмов пищи и ритма дня
• Питание — библиотека и подсказки в контексте фокуса Коуча

НА ОСНОВЕ APPLE HEALTH

WeekFit использует сон, активность, пульс, тренировки и питание из Apple Health для персонализации. Данные остаются на устройстве. Для старта аккаунт не нужен.

БЕЗ ШУМА

Один смысл на момент — подготовка к тренировке, восстановление после нагрузки или спокойное завершение дня.

РАЗРЕШЕНИЯ (ПО ЖЕЛАНИЮ)

• Apple Health — персонализация Коуча и синхронизация тренировок
• Камера — фото к пользовательским продуктам
• Геолокация — тема Night Comfort по местному закату

WeekFit не ставит медицинских диагнозов. По вопросам здоровья обращайтесь к специалисту.

Поддержка: support@weekfit.app
```

---

## Keywords (100 chars, comma-separated, no spaces after commas)

**EN:** `fitness,coach,planner,health,workout,nutrition,recovery,apple health,training,wellness`

**RU:** `фитнес,коуч,план,здоровье,тренировка,питание,восстановление,apple health,спорт`

---

## What's New (1.0 launch)

**EN:**
```
Welcome to WeekFit 1.0.

• Daily Coach that adapts to your sleep, recovery, and schedule
• Visual day plan with Apple Health workout sync
• Meals library with Coach-aligned suggestions
• English and Russian
```

**RU:**
```
Добро пожаловать в WeekFit 1.0.

• Ежедневный Коуч с учётом сна, восстановления и расписания
• Визуальный план дня с синхронизацией тренировок из Apple Health
• Библиотека питания с подсказками от Коуча
• Английский и русский языки
```

---

## Review Notes (paste into App Store Connect)

```
WeekFit is a local-first fitness planner with a daily Coach powered by Apple Health.

TEST PATH (no account required):
1. Launch app → tap "Open WeekFit" on the login screen.
2. When prompted, grant Apple Health read access (sleep, workouts, activity, heart rate, nutrition).
3. Explore tabs: Today, Coach, Meals, Plan.
4. Optional: add a planned workout in Plan, complete a workout in Apple Health or Fitness app, return to WeekFit to see sync.

PERMISSIONS:
• HealthKit — core feature; personalizes Coach and syncs completed workouts.
• Camera — optional; custom food photos only.
• Location (When In Use) — optional; Night Comfort theme at local sunset.

NOT INCLUDED IN 1.0:
• No subscriptions or in-app purchases.
• No cloud account (Sign in with Apple is not required).
• No Apple Watch companion app (completed workouts sync via HealthKit).

WeekFit does not provide medical advice.

Demo account: not required.
Support: support@weekfit.app
```

---

## Screenshot Scenes (recommended order)

| # | Screen | Caption idea (EN) |
|---|--------|-------------------|
| 1 | Today + Coach insight | Your day, interpreted |
| 2 | Coach tab — prep window | Know what to do next |
| 3 | Plan timeline | See your whole day |
| 4 | Meals + recommendation | Eat in context |
| 5 | Health connect | Powered by Apple Health |
| 6 | Recovery / Today header | Recovery at a glance |
| 7 | Live / completed activity | Stays in sync |
| 8 | Profile / settings | Your recovery system |

Use `COACH_SCREENSHOT_REVIEW_CHECKLIST.md` before capturing.

---

## URLs (custom domain: weekfit.app)

Hosted via GitHub Pages on the custom domain `weekfit.app`. After merging to `main`, enable **GitHub Pages → Source: GitHub Actions**, set the custom domain to `weekfit.app`, and configure DNS (see below).

| URL | Purpose |
|-----|---------|
| https://weekfit.app/privacy.html | **Privacy Policy URL** (App Store Connect) |
| https://weekfit.app/support.html | **Support URL** (App Store Connect) |

Source files: `docs/legal/` (includes `CNAME`). Workflow: `.github/workflows/deploy-legal-pages.yml`.

### DNS setup (apex domain `weekfit.app`)

At the domain registrar, point the apex to GitHub Pages:

- `A` → `185.199.108.153`
- `A` → `185.199.109.153`
- `A` → `185.199.110.153`
- `A` → `185.199.111.153`
- `AAAA` → `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`
- (optional) `CNAME` `www` → `mkemiazhuk.github.io`

Enable **Enforce HTTPS** in repo Pages settings once the certificate is issued.

### Email `support@weekfit.app`

Set up a mailbox or forwarding for `support@weekfit.app` (e.g. registrar email forwarding, iCloud+ Custom Domain, or Google Workspace). Add the required `MX` (and `SPF`/`DKIM`) records. This address is used in the app, privacy/support pages, and App Store Connect — it must be live before review.

Suggested Privacy Policy sections:
1. Data collected (Health, optional camera/location)
2. Local storage only — no cloud sync in 1.0
3. No third-party analytics in 1.0
4. Contact: support@weekfit.app
5. Not medical advice disclaimer

---

## App Privacy (Connect questionnaire hints)

| Data type | Collected? | Linked to user? | Tracking? |
|-----------|------------|-----------------|-----------|
| Health & Fitness | Yes (HealthKit) | No (local) | No |
| Photos (camera) | Optional | No | No |
| Precise/Coarse Location | Optional (approx) | No | No |
| Contact Info | No | — | No |
| Identifiers | No | — | No |

Tracking: **No** (`NSPrivacyTracking = false` in manifest)
