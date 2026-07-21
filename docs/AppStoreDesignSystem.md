# WeekFit App Store Design System

Version 1.0

Author: Principal Product Design System

---

## Mission

Create an App Store presentation that immediately communicates why WeekFit exists.

The screenshots should not explain the interface.

They should explain the transformation.

Every screenshot answers one user question.

Together they tell one story.

---

## Product

WeekFit AI

AI coach powered by Apple Health.

WeekFit combines

- Recovery
- Sleep
- HRV
- Activity
- Nutrition
- Daily Planning

into one intelligent recommendation.

Users no longer need to interpret data.

WeekFit tells them what to do today.

---

## Emotional Positioning

People don't buy tracking.

People buy confidence.

WeekFit sells confidence.

The emotional progression across screenshots should be

Confusion → Understanding → Confidence → Control → Trust → Daily habit

---

## Visual Philosophy

Imagine if Apple designed WHOOP.

Every screenshot should feel

- calm
- premium
- editorial
- minimal
- timeless

Never aggressive.

Never noisy.

Never overloaded.

---

## Inspirations

Apple Keynote · Apple Design Awards · WHOOP · Oura · Linear · Arc Browser · Raycast · Nothing · Apple Health

---

## Color System

| Token | Value |
|---|---|
| Background | `#050505` |
| Primary | `#FFFFFF` |
| Secondary | `#8E8E93` |
| Accent Gold | `#D8B15A` |
| Divider | `rgba(255,255,255,0.08)` |

---

## Typography

| Role | Size | Weight |
|---|---|---|
| Large headline | 56–64 px | Semibold |
| Subtitle | 24–28 px | Regular |
| Body | 18–20 px | Regular |

Never use more than two weights.

Whitespace is more important than decoration.

---

## Layout

| Element | Spec |
|---|---|
| Master canvas | 1080 × 1350 |
| ASC 6.7" | 1290 × 2796 (vertical reflow — do not stretch masters) |
| Phone | 40–45% |
| Text | 55–60% |

Large breathing space.

Nothing touches edges.

No overlapping.

---

## Iconography

Very limited. Simple. Monochrome. Apple style.

---

## Brand

WeekFit gold logo.

Never stretch.

Never add effects.

Never place inside circles.

Keep enough whitespace.

Logo on slides 1 and 6 only.

---

## Animation

None. These are static screenshots.

---

## Tone of Voice

Not motivational.

Not gym culture.

Not bodybuilding.

Sound like Apple.

Confident. Calm. Helpful. Intelligent.

---

## Storyboard (presentation-001)

| # | Emotion | Question | Headline | Subtitle | UI still |
|---|---|---|---|---|---|
| 1 | Confusion | What do I do with all this data? | Too much data. Too little clarity. | WeekFit turns Apple Health into one clear recommendation. | `today.jpg` |
| 2 | Understanding | What does today mean? | Your day, interpreted. | Sleep, recovery, and load — read as one story. | `recovery.jpg` |
| 3 | Confidence | What should I do today? | Know what to do next. | One intelligent recommendation. Not another dashboard. | `coach.jpg` |
| 4 | Control | How does the day fit together? | Plan and nutrition, aligned. | Meals and training that follow the same intent. | `plan.jpg` |
| 5 | Trust | Where does the intelligence come from? | Powered by Apple Health. | Recovery, sleep, HRV, activity, and nutrition — as one signal. | `activity.jpg` |
| 6 | Habit | Will this stick? | Confidence, every morning. | Open WeekFit. Know your day. | `coach.jpg` |

### Generate

```bash
python3 Scripts/generate_app_store_presentation.py
python3 Scripts/generate_app_store_presentation.py --format asc
```

- Masters: `web/public/app-store/presentation-001/`
- ASC uploads: `build/app-store-screenshots/presentation-001/`
