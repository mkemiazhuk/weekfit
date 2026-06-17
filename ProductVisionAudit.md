# WeekFit Product Vision Audit

## Executive Summary

WeekFit has the ingredients of a strong product: Today aggregates the right domains, Coach has access to plan/load/recovery/nutrition context, Planner can represent intent, Meals can connect food to training, and Insights can explain trends. The product promise is right.

The hard truth: the current experience often feels like a premium dashboard with coaching language layered on top. It frequently tells the user that something is "steady", "building", "limited", or "supportive", but does not consistently answer the athlete's real question: "What should I do next, exactly, and why should I trust that?"

The biggest product gap is not missing data or missing features. It is decision closure. WeekFit needs to turn every major day state into one clear next move, one reason, and one thing to avoid.

## Product Positioning Audit

### Why Open WeekFit Every Day?

The strongest daily reason to open WeekFit should be:

> "Tell me how to handle today: train, adjust, recover, fuel, hydrate, or stand down."

Right now the app partially delivers that, but it competes with itself. Today shows rings and metrics. Coach shows narrative. Planner shows intent. Meals shows library/recommendations. Insights shows patterns but may not be reachable. The user has to assemble the answer across screens.

### Difference From Competitors

* Apple Health: WeekFit should not be another place to view rings, sleep, calories, and HealthKit stats. Its job is to interpret those signals against today's plan.
* Apple Fitness: WeekFit should not be a workout logging surface. Its job is to decide whether the planned work still makes sense.
* WHOOP / Athlytic: WeekFit should not only score readiness. Its advantage is combining readiness with explicit plans, meals, hydration, and actual completed workload.
* Oura: WeekFit should not only explain recovery. Its advantage is the training-day decision: what to do next, what to avoid, and how to adjust.

### Screen Verdicts

#### Today

* Value delivered: Broad daily status across activity, nutrition, recovery, Coach insight, quick actions, and plan context.
* Is value obvious: Partly. It looks useful, but it can read as "dashboard" before "decision assistant".
* Is value unique: Only when the Coach card is strong. Rings and metrics alone are not unique.
* Is value actionable: Mixed. Quick actions are immediate, but status cards require interpretation.
* Product risk: Today asks the user to inspect several signals instead of saying, "Your next move is X." The differentiated Coach value can feel secondary when metrics and Up Next appear before the strongest recommendation.
* Safe improvement: Put one "Do this next" Coach recommendation above the metric grid or make it the first line of the Today Coach card. Metrics should become evidence beneath the decision. Example: "Start with the planned walk, keep it under 30 min, and skip extra intensity because sleep has not arrived yet."

#### Coach

* Value delivered: The intended core value: reasoning from the day state.
* Is value obvious: Sometimes. Strong scenarios can feel coach-like, but fallback and stable states feel generic.
* Is value unique: Yes, if it truly combines plan, completed load, recovery, nutrition, hydration, and timing.
* Is value actionable: Inconsistent. Some actions are specific; others are abstract.
* Product risk: Coach sometimes sounds like a rule engine translating states into polished phrases.
* Safe improvement: Force every Coach state into the same human structure: "What happened / What matters now / Do this / Avoid this / Confidence."

#### Planner

* Value delivered: User intent and weekly structure.
* Is value obvious: Yes for planning, weaker for coaching.
* Is value unique: Only if Planner is actively reconciled with Health and Coach decisions.
* Is value actionable: Yes for adding activities, weak for deciding what to add.
* Product risk: Empty Planner makes the user invent a plan from scratch. The screen promises that Coach will adapt around the plan, but the plan itself does not yet show enough coach interpretation.
* Safe improvement: Add a tiny Coach note for the selected day: "Today is light enough for an easy walk" or "Protect tomorrow by keeping this easy." Add coach-assisted starter choices that do not require a full feature: "Plan a training day", "Plan a recovery day", "Add only meals/drinks today."

#### Meals

* Value delivered: Food library, logging, custom meals, and contextual recommendations.
* Is value obvious: Library value is obvious after setup; first-use value is weaker.
* Is value unique: Meal recommendations are unique only when tied clearly to today's training/recovery context.
* Is value actionable: Logging is actionable; recommendation copy is not always direct enough.
* Product risk: Meals can feel like a food database, not a coaching input. On first use, it asks the user to create a library before the "coach would pick this" value appears.
* Safe improvement: Explain recommendations in athlete terms: "Best before today's ride because it gives carbs without heavy fat." For empty state, show a sample "Coach would pick..." card, then ask the user to create the first reusable meal.

#### Insights / Highlights

* Value delivered: Long-term pattern interpretation.
* Is value obvious: The model is promising, but "baseline building" and "insufficient overlap" sound internal.
* Is value unique: Potentially yes, if it explains why recovery/load/nutrition are interacting.
* Is value actionable: Mixed. "Log consistently for 7 days" is actionable but not motivating.
* Product risk: Insights can feel like analytics work the user must wait for. If it is not reachable from the active tab shell, the whole trend-value promise disappears.
* Safe improvement: Either expose one "Insight of the day" on Today or re-enable the tab with a strong no-data state. Even with low data, show one useful takeaway: "No trend yet. This week, just make sleep + workouts visible so Coach can compare effort to recovery."

#### Profile / Health Setup

* Value delivered: Health connection, signal readiness, Apple Watch/workout/heart/sleep/sync state, and privacy reassurance.
* Is value obvious: Setup value is obvious; daily value is not.
* Is value unique: Only if setup copy explains that Health unlocks coaching decisions, not dashboards.
* Is value actionable: Yes, but it can feel like infrastructure work.
* Product risk: Health setup frames WeekFit as "connect data to see stats" instead of "connect data so Coach can tell you what to do next."
* Safe improvement: After connection, show outcome copy: "Your next Coach read will use sleep, workouts, and recovery," with one clear "Open Today" action.

## Coach Human Audit

### Product Rule

A real coach does not say "maintain consistency" or "support adaptation" unless they immediately translate it into behavior. WeekFit should not show abstract advice without a concrete athlete action.

### Ban List Unless Paired With A Concrete Move

These phrases should not appear as standalone Coach/Today recommendations:

* "Maintain consistency"
* "Protect recovery"
* "Support adaptation"
* "Preserve training quality"
* "Focus on hydration"
* "Monitor readiness"
* "Keep the day steady"
* "Build the baseline"

They can be section labels or internal concepts, but the user-facing sentence must include an amount, timing, intensity cap, named activity, or what to skip.

### Robotic Or Weak Wording

#### "Everything looks steady"

* Why it sounds robotic: It describes a state but not a decision. It could come from any wellness app.
* Trust issue: The user does not know what evidence made the day "steady".
* Human alternative: "Nothing needs changing right now. Follow the plan, and do not add extra work just to feel productive."

#### "Nothing requires attention right now. Stay active, hydrate well and maintain healthy routines."

* Why it sounds robotic: This is generic wellness advice. It gives three vague behaviors and no priority.
* Specificity: Low.
* Timing: Low.
* Practicality: Medium.
* Actionability: Low.
* Human alternative: "No adjustment needed. Keep today's plan as written; if you want extra movement, keep it easy and under 20 minutes."

#### "No immediate action is needed. Stay consistent and keep energy available for what's ahead."

* Why it sounds robotic: "Stay consistent" and "keep energy available" are not instructions.
* Human alternative: "Do not spend energy early. Eat normally, keep the next block easy, and save the push for the planned session."

#### "Focus on recovery, hydration and setting yourself up for tomorrow."

* Why it sounds robotic: It names themes, not actions.
* Human alternative: "Training is done. Eat a protein meal in the next hour, drink 500 ml over the next 30 minutes, and skip extra intensity tonight."

#### "Protect recovery"

* Why it sounds robotic: Coaches protect specific outcomes, not abstract recovery.
* Human alternative: "Make the next session easier, or move it. Today's work will land better if you stop adding load now."

#### "Protect the key session"

* Why it can work: It has a coach-like intent.
* Weakness: It needs the named session and a concrete behavior.
* Human alternative: "Save the legs for tomorrow's long ride. Keep tonight easy and skip anything that raises your heart rate for long."

#### "Keep the day steady"

* Why it sounds robotic: It is a mood, not a decision.
* Human alternative: "No change needed. Do the planned session, keep extras easy, and check recovery again tonight."

#### "Build the baseline first"

* Why it sounds technical: Users do not wake up wanting a baseline. They want to know whether the app is useful today.
* Human alternative: "I need a few more days before I can call a trend. For today, log sleep, one meal, water, and any workout."

#### "Insufficient overlap"

* Why it sounds developer-focused: It exposes analytics terminology.
* Human alternative: "Not enough days line up yet. Log sleep + training together for a few more days and I can compare recovery to workload."

#### "Best match for the current Coach focus"

* Why it sounds system-generated: It references the app's internal model, not the athlete's need.
* Human alternative: "Best fit before today's session: enough carbs, not too heavy."

#### "Recovery-friendly choice that keeps the day controlled"

* Why it sounds vague: It does not say what makes the meal recovery-friendly.
* Human alternative: "Good recovery meal: high protein, lighter fat, easy to digest tonight."

#### "Recovery will update after sleep sync. I’ll use plan and nutrition context until sleep data arrives."

* Why it sounds incomplete: It is honest, but it stops before the decision. The athlete still does not know what to do before sleep arrives.
* Human alternative: "Sleep has not synced yet, so I will not judge readiness. Keep the 18:00 strength session planned, eat breakfast normally, start water early, and decide intensity after warm-up."

#### "The next load matters more than separate food or water reminders"

* Why it sounds abstract: It correctly avoids making food/water primary, but it hides the actual instruction.
* Human alternative: "Ride starts soon. Have 20-40 g quick carbs, sip 300-500 ml, bring a bottle, and keep the first 15 minutes easy."

#### "Leave tomorrow for tomorrow"

* Why it sounds vague: It gestures at restraint without naming the behavior.
* Human alternative: "You are done for today. No more training, keep dinner simple, dim screens, and get to bed on time."

## Trust Audit

### Trust Standard

WeekFit should only recommend an action when it can explain:

* The signal: what data changed or is missing.
* The consequence: why that matters for today.
* The action: what to do now.
* The confidence: how certain the app is.

### Trust Risks

#### Missing Sleep Blocks Or Weakens The Coach Too Much

* Trust problem: When sleep is missing, Coach can settle or fall back instead of saying what it knows and what it does not know.
* Why trust is reduced: Silence feels broken; generic guidance feels guessed.
* Better confidence language: "Sleep has not synced yet, so I am not using recovery to judge intensity. Based on your plan, keep the first session easy until sleep arrives."

#### "Steady" Claims Need Evidence

* Trust problem: "Steady" can mean no data, stable data, or no intervention.
* Why trust is reduced: The same word can hide very different confidence levels.
* Better confidence language:
  * "High confidence: recovery, sleep, and plan all line up."
  * "Limited confidence: no sleep yet, but no completed load or hard session is visible."

#### Hydration And Food Can Sound Random

* Trust problem: If Coach says water or food without showing the gap, it feels like generic wellness advice.
* Why trust is reduced: Users already know water and food matter.
* Better confidence language: "Water is 0.4 L against a 2.6 L target by afternoon, so drink 500 ml before the session. This is support, not the main decision."

#### Insights Uses Internal Analytics Language

* Trust problem: "No dominant insight", "baseline", "coverage", and "overlap" sound like analytics machinery.
* Why trust is reduced: Users feel the product is grading its own data pipeline, not coaching them.
* Better confidence language: "I cannot compare trends yet because sleep and training have not overlapped enough days."

#### Today Rings Can Imply False Precision

* Trust problem: Recovery, nutrition, and activity rings can look authoritative even when key data is missing or default goals are used.
* Why trust is reduced: A polished number without data provenance can feel misleading.
* Better confidence language: Show "Waiting for sleep" or "Using manual logs only" directly in the card.

## Actionability Audit

### Scoring Guide

* Specificity: Does it say exactly what?
* Timing: Does it say when?
* Practicality: Can an athlete do it now?
* Actionability: Is the next step unambiguous?

### Vague Recommendation Scores

#### "Stay active, hydrate well and maintain healthy routines"

* Specificity: 1/5
* Timing: 0/5
* Practicality: 3/5
* Actionability: 1/5
* Replace with: "Keep any extra movement easy and under 20 minutes. Drink 400-600 ml over the next hour."

#### "Focus on recovery, hydration and setting yourself up for tomorrow"

* Specificity: 2/5
* Timing: 1/5
* Practicality: 3/5
* Actionability: 2/5
* Replace with: "Eat 25-35 g protein within 60 minutes, drink 500 ml gradually, and skip hard efforts tonight."

#### "Keep the day steady"

* Specificity: 1/5
* Timing: 0/5
* Practicality: 3/5
* Actionability: 1/5
* Replace with: "Do the plan as written. Do not add extra intensity unless Coach sees a clear reason."

#### "Build the baseline first"

* Specificity: 2/5
* Timing: 2/5
* Practicality: 4/5
* Actionability: 3/5
* Replace with: "For the next 7 days, log sleep, one meal, water, and every workout. That is enough to unlock your first trend."

#### "Best match for the current Coach focus"

* Specificity: 1/5
* Timing: 1/5
* Practicality: 3/5
* Actionability: 2/5
* Replace with: "Best before today's workout: enough carbs, lighter fat, easy to digest."

### Stronger Existing Action Patterns

WeekFit already has some useful concrete language:

* "Drink 500-750ml water"
* "Drink 750-1000ml water"
* "Add 25-30g protein"
* "Leave 1-2 reps in reserve"
* "Walk for a few minutes"
* "Cap it at 20 minutes very easy"

These are the right direction. The issue is consistency. Specific guidance should be the default, not the exception.

## What Happens Next Audit

### Workout Completed

* Current likely guidance: "The main work is done", "eat protein, drink water", "avoid extra load."
* Usefulness: Good intent, but too often not quantified.
* Missing opportunity: Make the recovery window explicit.
* Better next step: "Within 60 minutes: eat 25-35 g protein. Drink 500 ml gradually. No hard work for the rest of today."

### Walk Completed

* Current likely guidance: Walk can be treated as easy movement and day may be stable.
* Usefulness: Good, especially if it avoids overcalling recovery load.
* Missing opportunity: Tell the user whether the walk changes the plan.
* Better next step: "That counts as easy movement, not training stress. Keep the rest of the plan unchanged."

### Long Ride Completed

* Current likely guidance: Refill fluids, keep next block easy, let body settle.
* Usefulness: Directionally right.
* Missing opportunity: Long endurance work needs carbs, fluids, and a time window.
* Better next step: "In the next hour: 25-35 g protein, carbs with the next meal, and 500-750 ml fluids. Keep the next 3-4 hours easy."

### Strength Workout Completed

* Current likely guidance: Eat protein, drink water, let HR settle.
* Usefulness: Good but generic.
* Missing opportunity: Distinguish heavy strength from light strength.
* Better next step: "Eat 25-35 g protein within 60 minutes. If legs feel heavy later, replace extra cardio with a short walk."

### Sauna Completed

* Current likely guidance: Drink slowly, keep day calm.
* Usefulness: Good safety framing.
* Missing opportunity: Be specific about fluid and heat recovery.
* Better next step: "Cool down first, then drink 500 ml over 30-45 minutes. Avoid another heat or hard training block tonight."

### Hydration Goal Completed

* Current likely guidance: Today logs water in small increments and can show brief progress feedback. There is no strong visible "goal completed" coaching moment.
* Usefulness: Timely feedback exists, but it is not coaching.
* Missing opportunity: Tell the user to stop chasing water and shift back to normal thirst.
* Better next step: "Hydration is covered. Drink to thirst now; do not force extra water. Add electrolytes only around heat or heavy sweat."

### Recovery Day

* Current likely guidance: Keep day restorative / recovery leads today.
* Usefulness: Good concept.
* Missing opportunity: Recovery day needs boundaries and modality-specific variants. A walk, mobility session, sauna, and no-plan recovery day should not all sound identical.
* Better next step: "Today's win is restraint: easy walk or mobility only, no intervals, no extra sets, stop while you feel better than when you started."

### End Of Day

* Current likely guidance: Close calmly, protect sleep, no extra tasks.
* Usefulness: Good tone, but often too generic.
* Missing opportunity: End-of-day should summarize what was completed, name tomorrow's first constraint if relevant, and close the loop.
* Better next step: "Training is done. No more training tonight, prep tomorrow's kit, keep food light, and treat sleep as the next workout."

### Tomorrow Has A Hard Workout

* Current likely guidance: Protect tomorrow, save quality.
* Usefulness: Strong concept.
* Missing opportunity: It needs today's concrete constraint, and endurance days should prompt practical prep.
* Better next step: "Tomorrow's hard session is the priority. Stop chasing today, skip extra activity, prep bottles/carbs now, and get to bed on time."

## Cognitive Load Audit

### Today

* Cognitive load: High.
* Why: Activity, nutrition, recovery, sleep, HRV, RHR, Coach, plan, quick actions, and details all compete.
* User burden: The user must decide which metric matters.
* Fix: One top decision should dominate. Secondary cards should explain, not compete.

### Coach

* Cognitive load: Medium-high.
* Why: Titles, assessments, recommendations, warnings, reasons, support actions, and status cards can repeat intent.
* User burden: The user must infer primary vs supporting advice.
* Fix: Show one primary action, one avoid, and at most two supporting signals.

### Meals

* Cognitive load: Medium.
* Why: Library, food products, custom meals, recommendations, macros, portions, and creation flows are useful but setup-heavy.
* User burden: First food log requires understanding saved items vs quick log vs create.
* Fix: First-use path should say, "Log something now" before "build your library."

### Planner

* Cognitive load: Medium.
* Why: The timeline is understandable, but empty state asks the user to design the day.
* User burden: New users must know what to plan.
* Fix: Add suggested day templates or starter prompts.

### Insights

* Cognitive load: High when data is missing.
* Why: "Baseline", "coverage", "overlap", and "confidence" require interpretation.
* User burden: The user must understand why the product is not ready.
* Fix: Translate analytics into coaching: "I need X days before I can compare Y."

## Premium Experience Audit

### Feels Premium

* Dark visual system.
* Integrated domains: training, recovery, food, hydration, plan.
* Coach concept is differentiated when final story works.
* Planner + Health reconciliation can become a premium trust feature.

### Feels Unfinished Or Technical

* "Insufficient overlap"
* "No dominant insight"
* "Build the baseline first"
* "Data coverage"
* "Trust meter"
* "Sync pending"
* Raw localization keys in Activity detail if visible
* Debug wording in Profile
* Missing Health data states that sound like loading rather than coaching

### Premium Alternatives

* "Insufficient overlap" -> "Not enough days line up yet"
* "No dominant insight" -> "No clear pattern yet"
* "Build the baseline first" -> "Give me a few more days to learn your normal"
* "Data coverage" -> "What I can trust"
* "Trust meter" -> "Confidence"
* "Sync pending" -> "Waiting for Apple Health"
* "Low coverage" -> "I need more history before I call this a trend"
* "Debug" -> hide from consumer Profile unless explicitly in developer mode

## Daily Decision Audit

### Recovery Day

* What happened: Often not explicit enough.
* What is happening: Recovery may own the day.
* What to do next: Needs duration and intensity boundaries.
* What to avoid: Should explicitly prevent "turning recovery into training."
* Product verdict: Good concept, needs stronger coaching constraints.

### No Activities Planned

* What happened: Nothing planned.
* What is happening: Open day.
* What to do next: Current guidance risks becoming generic wellness.
* What to avoid: Avoid adding intensity just to feel productive.
* Product verdict: Needs a "no plan" decision, not a weak dashboard state.

### Morning

* What happened: Sleep may or may not have arrived.
* What is happening: The day is being set.
* What to do next: Should not start with food/water warnings unless severe.
* What to avoid: Do not over-interpret missing Apple Health sleep.
* Product verdict: Missing-sleep handling is the trust-critical morning case.

### Afternoon

* What happened: Load and nutrition are now meaningful.
* What is happening: The day is either on track, underfueled, overloaded, or preparing.
* What to do next: Should be highly specific: adjust session, drink amount, eat timing, or leave plan.
* What to avoid: Do not show all rings equally.
* Product verdict: Best opportunity for WeekFit to beat Apple Health.

### Evening

* What happened: Most work is done.
* What is happening: Sleep and recovery matter.
* What to do next: Close the day, no extra load, prep tomorrow if needed.
* What to avoid: Avoid new tasks or generic "maintain routine" language.
* Product verdict: Strong potential, but should be more decisive.

### Before Workout

* What happened: A planned activity is near.
* What is happening: Preparation window.
* What to do next: Warm-up timing, effort cap, food/fluid if needed.
* What to avoid: Avoid turning warm-up into testing fitness.
* Product verdict: Current copy is directionally good but often lacks timing.

### During Workout

* What happened: Activity is active.
* What is happening: Execution.
* What to do next: Control effort, fuel/hydrate only if relevant.
* What to avoid: Surges, chasing speed, technique breakdown.
* Product verdict: Some of the most coach-like copy exists here.

### After Workout

* What happened: Load is complete.
* What is happening: Recovery window.
* What to do next: Protein/fluid/rest timing.
* What to avoid: Another hard session or extra intensity.
* Product verdict: Strong opportunity; needs consistent quantified actions.

### Heavy Training Day

* What happened: Meaningful load.
* What is happening: The day has enough signal.
* What to do next: Stop adding load, recover, fuel.
* What to avoid: Turning volume into intensity.
* Product verdict: This is where WeekFit can be most valuable.

### Light Training Day

* What happened: Low stress.
* What is happening: Maintenance.
* What to do next: Keep plan, optional easy movement.
* What to avoid: Making a light day harder without reason.
* Product verdict: Needs to reassure without sounding generic.

### Sleep-Deprived Day

* What happened: Sleep short or missing.
* What is happening: Readiness confidence is lower.
* What to do next: Lower ceiling, start easy, postpone hard work if needed.
* What to avoid: Treating motivation as readiness.
* Product verdict: Critical trust state. Must be calm and specific.

### High-Readiness Day

* What happened: Signals support training.
* What is happening: Plan can proceed.
* What to do next: Execute planned work, not random extra load.
* What to avoid: Overreaching because readiness is high.
* Product verdict: Should avoid "green means do more."

### Low-Readiness Day

* What happened: Recovery/sleep/load signal is constrained.
* What is happening: Training ceiling lower.
* What to do next: Reduce, replace, shorten, or move work.
* What to avoid: Completing the calendar at any cost.
* Product verdict: Needs one clear adjustment, not a caution banner.

## Coach Architecture Reality Check

From the user perspective, Coach currently behaves like three things at different times:

* A real coach when it names a specific activity, constrains intensity, and tells the user what to avoid.
* A rule engine when it translates states into abstractions like "protect recovery", "keep the day steady", or "build the baseline".
* A dashboard when it waits for data, shows rings/statuses, or reports conditions without closing the decision.

The most important reality check: a coach remembers the day. If the user completed a workout, logged water, or has a hard session tomorrow, the next message should feel like it knows that exact sequence. If Coach says the same kind of "steady" advice before and after those events, trust will drop.

## Final Product Verdict

### Product Strengths

* The product domain is strong: training, recovery, nutrition, hydration, and planning belong together.
* Planner intent plus Apple Health completion is a real differentiator if trust is high.
* Coach has access to enough context to become meaningfully better than Apple Health or a pure readiness app.
* Some activity-specific copy already sounds coach-like, especially effort caps and post-session warnings.
* The premium dark UI gives the product a serious, athlete-oriented feel.

### Product Weaknesses

* WeekFit too often reports state instead of closing a decision.
* Abstract coaching language weakens trust.
* Missing data states feel like product limitations rather than calm coaching constraints.
* Today can feel like a dashboard because multiple cards compete for attention.
* Meals and Insights have real intelligence, but the current copy can make them feel generic or internal.
* First-time users may not see enough useful value before Health and logging history exist.

### Biggest Missed Opportunities

* Using Planner intent as the main difference from WHOOP/Athlytic: "your readiness relative to what you planned."
* Turning completed workouts into timed recovery windows.
* Treating tomorrow's hard workout as a concrete constraint on tonight.
* Filling unglamorous transitions: hydration complete, easy walk complete, and end-of-day closure.
* Explaining confidence when sleep/recovery is missing instead of settling or hiding.
* Connecting meal recommendations to exact training context in human language.
* Making Insights useful before full trends by explaining what can and cannot be trusted.

## Top 10 Improvements

### 1. Make Coach Always Produce One Clear Next Move

* User value: Very high.
* Effort: Medium.
* Retention impact: Very high.
* Trust impact: Very high.
* Scope: Existing Coach output structure.
* Example: "Do the planned walk, cap it at 30 minutes easy, and skip extra intensity."

### 2. Add Confidence Language For Missing Or Partial Data

* User value: Very high.
* Effort: Medium.
* Retention impact: High.
* Trust impact: Very high.
* Scope: Missing sleep, missing Health, partial permission, low history.
* Example: "Limited confidence: sleep has not synced, so I am using plan + completed load only."

### 3. Replace Abstract Coach Phrases With Athlete Actions

* User value: High.
* Effort: Low-medium.
* Retention impact: High.
* Trust impact: High.
* Scope: Copy and tests.
* Replace "protect recovery" with "skip extra intensity tonight."

### 4. Turn Post-Workout States Into Recovery Windows

* User value: High.
* Effort: Medium.
* Retention impact: High.
* Trust impact: High.
* Scope: Existing workout completion + nutrition/hydration signals.
* Example: "Within 60 minutes: 25-35 g protein and 500 ml fluids."

### 5. Make Today Start With The Decision, Not The Dashboard

* User value: High.
* Effort: Medium.
* Retention impact: High.
* Trust impact: Medium-high.
* Scope: Today hierarchy.
* Example top line: "Do now: 300-500 ml water + normal breakfast" or "Best next move: keep today's run easy."

### 6. Make "No Plan" Useful

* User value: High for new users.
* Effort: Low-medium.
* Retention impact: High.
* Trust impact: Medium.
* Scope: Today/Coach/Planner empty state.
* Example: "No plan today. Add one easy movement block or leave it open; do not chase load without a reason." In Planner, offer tiny starter plans such as "Recovery day: walk + hydration + dinner protein."

### 7. Make Meal Recommendations Explain The Athletic Reason

* User value: Medium-high.
* Effort: Low-medium.
* Retention impact: Medium-high.
* Trust impact: Medium-high.
* Scope: Existing recommendation copy.
* Example: "Best before the ride because it has carbs without heavy fat."

### 8. Make Insights Speak Like A Coach, Not An Analytics Tool

* User value: Medium-high.
* Effort: Medium.
* Retention impact: Medium.
* Trust impact: High.
* Scope: Existing empty/fallback/story copy.
* Example: "I need three more days where sleep and training overlap before I call this a trend."

### 9. Reduce Today/Coach Duplication

* User value: Medium.
* Effort: Medium.
* Retention impact: Medium.
* Trust impact: Medium.
* Scope: Presentation hierarchy.
* Principle: One primary decision, supporting signals below.

### 10. Fill The Small Transition Moments

* User value: Medium-high.
* Effort: Low-medium.
* Retention impact: Medium.
* Trust impact: Medium.
* Scope: Existing completion/hydration/evening states.
* Example: "Hydration covered. Drink to thirst now." "Good walk. Let it count as recovery." "Training is done. Prep tomorrow and stop adding load."

## One Thing To Fix First

Fix Coach's decision closure.

If only one thing improves this month, every Coach-visible state should answer:

* What happened?
* What matters now?
* What exactly should I do next?
* What should I avoid?
* How confident is WeekFit, and why?

This is the highest-leverage fix because it changes WeekFit from a dashboard into a coach without requiring a redesign or large new feature. The data model and UI already contain most of the ingredients. The product simply needs to stop short of abstraction and finish the coaching sentence.

### Minimum Implementation Slice

* Add a required `nextMove` and `avoidMove` contract to visible Coach output.
* Add a `confidenceCopy` field for missing/partial data.
* Replace generic phrases in the top Coach states.
* Add tests for:
  * no plan
  * missing sleep morning
  * before workout
  * after workout
  * evening no activities left
  * tomorrow hard workout
  * low-readiness day
  * hydration/fuel conflict

### Definition Of Done

WeekFit passes this simple read test:

> A user can open Today or Coach, read one card in under 10 seconds, and know exactly what to do next, why it matters, and what not to do.
