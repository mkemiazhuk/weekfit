# WeekFit Coach Visible State Audit

## Scope

This audits every visible Coach state family found in the current Coach rendering paths:

* `CoachFinalStoryOwner`: active, preparation, pacing, sustainable execution, fueling, hydration, post-activity, recovery, readiness, tomorrow, stable, hydration, fuel.
* V4 playbooks: endurance, strength, sauna/heat, recovery modalities, racket/other.
* Day-story states: recovery day, high-load day, overload day, performance day, protection day, rebuild/consistency/preparation day.
* Fallback states: settling/unavailable and Today card fallback.

Dynamic variants use activity names, time windows, or day context. The audit groups those variants by visible state family so it is complete without repeating identical logic for every possible activity title.

Scoring:

* Human: would a real coach say this?
* Trust: is the advice supported and explainable?
* Actionability: can the user act in the next 30 minutes?

## Coach Language Rules

Never use these as standalone visible recommendations:

* Maintain consistency
* Protect recovery
* Support adaptation
* Preserve training quality
* Focus on hydration
* Monitor readiness

Every rewritten recommendation below describes a real action.

---

## 1. Settling / Inputs Syncing

* Current Title: `Coach is settling`
* Current Assessment: `Waiting for recovery, sleep, and activity data.`
* Current Recommendation: None visible.
* Current Warning: None visible.
* Next 30-Minute Action: Connect or wait for Apple Health; if training is planned soon, keep the warm-up easy until sleep/recovery arrives.
* Mistake To Avoid: Do not show a dead loading state when the user needs a decision.
* Would A Real Coach Say This: No. A coach would explain what is unknown and what can still be decided.
* Can Be More Concrete: Yes.
* Domain Tie: recovery, sleep, activity, tomorrow's plan if present.
* Scores: Human 3/10, Trust 5/10, Actionability 2/10.
* Rewrite Assessment: Sleep and recovery have not arrived yet, so I cannot judge readiness from Health data.
* Rewrite Recommendation: If you have training in the next few hours, keep the first 10 minutes easy and decide intensity after warm-up.
* Rewrite Warning: Do not treat missing sleep data as either a green light or a red flag.

## 2. Stable / No Plan

* Current Title: `Everything looks steady` / `No need to change the plan`
* Current Assessment: `Nothing requires attention right now. Stay active, hydrate well and maintain healthy routines.`
* Current Recommendation: `Keep the normal rhythm and maintain the basics.`
* Current Warning: `Do not add extra structure where the day is already working.`
* Next 30-Minute Action: Either leave the day open or add one easy 20-30 minute walk.
* Mistake To Avoid: Do not add intensity just to make the day feel productive.
* Would A Real Coach Say This: Partly. The intent is right; the wording is too generic.
* Can Be More Concrete: Yes.
* Domain Tie: activity, recovery, nutrition, hydration.
* Scores: Human 5/10, Trust 6/10, Actionability 4/10.
* Rewrite Assessment: Nothing in today's plan asks for a training decision right now.
* Rewrite Recommendation: If you want movement, take a 20-30 minute easy walk; otherwise leave the day open.
* Rewrite Warning: Do not turn an open day into a hard session without a reason.

## 3. Stable / Plan Unchanged

* Current Title: `Today looks steady` / `Open day`
* Current Assessment: `Today looks steady. Nothing needs special attention now.`
* Current Recommendation: `Leave the plan unchanged today.`
* Current Warning: `Do not add intensity just to make the day feel productive.`
* Next 30-Minute Action: Follow the next planned item exactly as scheduled.
* Mistake To Avoid: Do not add extra volume around the planned work.
* Would A Real Coach Say This: Mostly yes, if the planned activity is named.
* Can Be More Concrete: Yes.
* Domain Tie: activity, recovery, planned workload.
* Scores: Human 7/10, Trust 7/10, Actionability 6/10.
* Rewrite Assessment: Your current plan still fits the day.
* Rewrite Recommendation: Do the next planned item as written and keep any extra movement easy.
* Rewrite Warning: Do not add extra intensity just because the day feels manageable.

## 4. Morning Missing Sleep With Later Workout

* Current Title: `Recovery will update after sleep sync` / activity-specific missing-sleep title.
* Current Assessment: `I’ll use plan and nutrition context until sleep data arrives.`
* Current Recommendation: Usually implied by support actions, not always closed.
* Current Warning: Avoid over-reading missing data, but the warning is not always visible.
* Next 30-Minute Action: Eat normally, start water early, leave the workout planned, and wait to decide intensity until warm-up.
* Mistake To Avoid: Do not downgrade or push the workout based only on missing sleep.
* Would A Real Coach Say This: Partly. The honesty is good; the decision is incomplete.
* Can Be More Concrete: Yes.
* Domain Tie: sleep, activity, nutrition, hydration.
* Scores: Human 6/10, Trust 8/10, Actionability 5/10.
* Rewrite Assessment: Sleep has not synced yet, so I will not judge readiness from recovery data.
* Rewrite Recommendation: Keep the later session on the plan, eat breakfast normally, start water early, and use the warm-up to choose intensity.
* Rewrite Warning: Do not treat missing sleep as proof that you are either ready or not ready.

## 5. Recovery Day

* Current Title: `Recovery leads today` / `Let recovery do the work` / `Keep the day restorative`
* Current Assessment: `Today is a recovery day: the value comes from lowering stress, not proving capacity.`
* Current Recommendation: `Keep the rest of the day easy` / `Choose recovery work only.`
* Current Warning: `Trying to turn every day into a training day.`
* Next 30-Minute Action: Do only easy movement or mobility, capped at 20-30 minutes.
* Mistake To Avoid: Do not turn recovery movement into training.
* Would A Real Coach Say This: Yes, but the recommendation should name a cap.
* Can Be More Concrete: Yes.
* Domain Tie: recovery, activity, sleep if evening.
* Scores: Human 8/10, Trust 8/10, Actionability 7/10.
* Rewrite Assessment: Today should lower stress, not prove fitness.
* Rewrite Recommendation: Keep movement to an easy 20-30 minute walk or 5-10 minutes of mobility.
* Rewrite Warning: Stop before breathing, pace, or effort starts to feel like training.

## 6. High-Load Day

* Current Title: `Protect today’s work` / `The work is in the bank` / `Recovery is the next win`
* Current Assessment: `Today has become a high-load day.`
* Current Recommendation: `Shift the rest of the day toward recovery and keep movement optional.`
* Current Warning: `Turning a good training day into an overreach.`
* Next 30-Minute Action: Stop training work; start cooldown, fluids, and next-meal protein.
* Mistake To Avoid: Do not add another hard block because there is time left.
* Would A Real Coach Say This: Mostly yes, though "protect" is weaker than a real action.
* Can Be More Concrete: Yes.
* Domain Tie: activity, recovery, nutrition, hydration, sleep.
* Scores: Human 7/10, Trust 8/10, Actionability 6/10.
* Rewrite Assessment: You already have enough training load in the day.
* Rewrite Recommendation: End hard work now, walk 5-10 minutes easy, and get protein plus fluids at the next meal.
* Rewrite Warning: Do not add another hard session or extra volume tonight.

## 7. Overload Day

* Current Title: `Stop adding load` / `Let the day end here`
* Current Assessment: `The story of the day has shifted from building fitness to managing overload.`
* Current Recommendation: `Do not add another session tonight.`
* Current Warning: `Treating more fatigue as more fitness.`
* Next 30-Minute Action: Cancel or replace remaining training with easy recovery work.
* Mistake To Avoid: Do not complete the calendar just because it is written down.
* Would A Real Coach Say This: Yes. This is one of the stronger states.
* Can Be More Concrete: Yes.
* Domain Tie: activity, recovery, sleep, tomorrow's plan.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: Today has crossed from useful load into fatigue management.
* Rewrite Recommendation: Cancel the remaining training or replace it with a 10-20 minute easy walk.
* Rewrite Warning: Do not turn calendar completion into extra fatigue.

## 8. Performance Day / Key Session Later

* Current Title: `Protect the key session`
* Current Assessment: `The day is organized around one important session, so everything else should support that work.`
* Current Recommendation: `Keep the day pointed at [session]. Eat normally, keep fluids steady, and let the first block confirm readiness.`
* Current Warning: `Spending energy before the session you actually care about.`
* Next 30-Minute Action: Remove extra activity, finish normal fueling, prepare kit/route/bottles.
* Mistake To Avoid: Do not spend legs or focus before the key session.
* Would A Real Coach Say This: Partly. The concept is coach-like; "support" is abstract.
* Can Be More Concrete: Yes.
* Domain Tie: activity, nutrition, hydration, recovery.
* Scores: Human 7/10, Trust 8/10, Actionability 6/10.
* Rewrite Assessment: Today is built around the planned key session.
* Rewrite Recommendation: Keep the next 30 minutes quiet: finish normal food, prep bottles/kit, and skip extra movement.
* Rewrite Warning: Do not use warm-up time or waiting time as a second workout.

## 9. Tomorrow Protection / Hard Workout Tomorrow

* Current Title: `Protect tomorrow` / `Save the quality for tomorrow`
* Current Assessment: `Tomorrow's demand makes freshness more valuable than squeezing in extra load.`
* Current Recommendation: `Keep the rest of today quiet, finish the basics, and preserve freshness for tomorrow.`
* Current Warning: `Spending tomorrow’s freshness tonight.`
* Next 30-Minute Action: Stop extra activity, prep tomorrow's bottles/carbs/kit, and set bedtime.
* Mistake To Avoid: Do not chase today's optional work at the cost of tomorrow's session.
* Would A Real Coach Say This: Yes, but the title is a slogan until it names the action.
* Can Be More Concrete: Yes.
* Domain Tie: tomorrow's plan, sleep, nutrition, hydration, activity.
* Scores: Human 7/10, Trust 8/10, Actionability 7/10.
* Rewrite Assessment: Tomorrow's hard session is the priority now.
* Rewrite Recommendation: Prep bottles, carbs, and kit in the next 30 minutes, then keep the evening easy.
* Rewrite Warning: Do not spend energy tonight that tomorrow's session needs.

## 10. Readiness / Low Recovery Poor Readiness

* Current Title: `Start easy today` / `Reduce today's intensity` / `Downgrade today`
* Current Assessment: Recovery or sleep is reducing today's margin.
* Current Recommendation: `Reduce intensity by one level` / `Start 10-15 minutes easier` / `Reassess after warm-up.`
* Current Warning: `Safety beats completing the session` or similar caution.
* Next 30-Minute Action: Start warm-up easier than planned, then decide whether to shorten or downgrade.
* Mistake To Avoid: Do not use motivation as proof of readiness.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Already fairly concrete; can name the planned activity.
* Domain Tie: recovery, sleep, activity.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: Recovery is lowering the ceiling for today's planned work.
* Rewrite Recommendation: Start 10-15 minutes easier than planned and decide after warm-up whether to shorten the session.
* Rewrite Warning: Do not force the original intensity if breathing, legs, or control feel off.

## 11. Hydration Primary / Hydration Behind

* Current Title: `Hydration needs attention now` / `Bring fluid intake back on track`
* Current Assessment: `Fluid intake is falling behind the workload.`
* Current Recommendation: `Drink 300-500 ml during the next 20 minutes` or `Start with 300-500 ml`.
* Current Warning: `Do not try to catch up with one large drink` / dehydration reduces quality.
* Next 30-Minute Action: Drink 300-500 ml gradually.
* Mistake To Avoid: Do not chug a large amount or treat water as the whole workout decision.
* Would A Real Coach Say This: Yes when tied to activity/heat/workload; no if shown without evidence.
* Can Be More Concrete: Already concrete; should always show why.
* Domain Tie: hydration, activity, heat, recovery.
* Scores: Human 8/10, Trust 7/10, Actionability 9/10.
* Rewrite Assessment: Fluid intake is behind what the next block requires.
* Rewrite Recommendation: Drink 300-500 ml over the next 20-30 minutes, using small sips.
* Rewrite Warning: Do not chug to catch up or ignore fuel if the session also needs carbs.

## 12. Fuel Primary / Fuel Behind

* Current Title: `Fuel is still missing` / `Pre-workout carbs` / `Protect energy availability`
* Current Assessment: Energy or carbs are behind the session demand.
* Current Recommendation: `Consume 30-60 g carbohydrates within the next 15 minutes` or `Eat normally at your next meal`.
* Current Warning: `Do not wait for hunger before fueling.`
* Next 30-Minute Action: Eat 30-60 g carbs if training soon or plan a normal carb-containing meal if not close.
* Mistake To Avoid: Do not treat water as a replacement for fuel.
* Would A Real Coach Say This: Yes, especially during endurance.
* Can Be More Concrete: Already concrete; timing should always be visible.
* Domain Tie: nutrition, activity, hydration.
* Scores: Human 8/10, Trust 8/10, Actionability 9/10.
* Rewrite Assessment: The session needs usable energy, and food is behind the demand.
* Rewrite Recommendation: Eat 30-60 g quick carbs in the next 15 minutes if training is close; otherwise include carbs in the next meal.
* Rewrite Warning: Do not wait for hunger before starting fuel on a long or hard session.

## 13. Hydration + Fuel Conflict

* Current Title: `Hydration is improving` / `Fuel is still missing`
* Current Assessment: Hydration has started, but food/carbs are still limiting.
* Current Recommendation: Drink plus add carbs, often split across support rows.
* Current Warning: `Treating water as enough when the ride still needs quick fuel.`
* Next 30-Minute Action: Add 30-60 g carbs now and sip, not chug, water.
* Mistake To Avoid: Do not solve the whole session with water.
* Would A Real Coach Say This: Yes when rendered as a single decision.
* Can Be More Concrete: Yes if Today card collapses it into one instruction.
* Domain Tie: nutrition, hydration, activity.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: Water is started, but it will not replace the fuel this session needs.
* Rewrite Recommendation: Eat 30-60 g carbs now and sip 300-500 ml over the next 20 minutes.
* Rewrite Warning: Do not chug water and skip carbs before a hard or long session.

## 14. Activity Preparation / Short Endurance

* Current Title: `Start controlled`
* Current Assessment: `This is short enough to execute well if readiness stays stable.`
* Current Recommendation: `Start 10 minutes easy, then decide if planned effort fits.`
* Current Warning: `Do not rush the opening minutes.`
* Next 30-Minute Action: Begin warm-up and hold the first 10 minutes easy.
* Mistake To Avoid: Do not start at target pace immediately.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Already concrete.
* Domain Tie: activity, recovery.
* Scores: Human 9/10, Trust 8/10, Actionability 9/10.
* Rewrite Assessment: This session can work if the opening block stays controlled.
* Rewrite Recommendation: Keep the first 10 minutes easy, then choose whether the planned effort fits.
* Rewrite Warning: Do not turn the warm-up into a fitness test.

## 15. Activity Preparation / Endurance Four-Plus Hours Away

* Current Title: `Build toward the long ride` / `Build toward the endurance session`
* Current Assessment: The session is still several hours away and recovery is not blocking it.
* Current Recommendation: `Plan the carb meal; finish it 2-3 hours before the session.`
* Current Warning: `Do not add a second workout before the important session.`
* Next 30-Minute Action: Plan the carb meal and prep bottles/route.
* Mistake To Avoid: Do not add extra training before the key session.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Yes, name the actual meal/amount if available.
* Domain Tie: activity, nutrition, hydration.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: The endurance session is still hours away, so preparation matters more than effort now.
* Rewrite Recommendation: Plan the carb meal, prep bottles, and keep the next 30 minutes low-effort.
* Rewrite Warning: Do not add another workout before the main session.

## 16. Activity Preparation / Endurance Two-To-Four Hours Away

* Current Title: `Set up the endurance session`
* Current Assessment: The session is the main training demand later today.
* Current Recommendation: `Finish fueling for a controlled start, then keep activity low.`
* Current Warning: `Do not turn the waiting time into extra training.`
* Next 30-Minute Action: Finish the main meal/top-up and reduce unnecessary movement.
* Mistake To Avoid: Do not use waiting time for extra activity.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Yes, include carb range if known.
* Domain Tie: nutrition, hydration, activity.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: The main training demand is close enough that preparation should replace extra work.
* Rewrite Recommendation: Finish your fueling now, keep movement low, and have bottles ready before the final hour.
* Rewrite Warning: Do not add an extra workout while waiting.

## 17. Activity Preparation / Endurance 60-120 Minutes Away

* Current Title: `Move into preparation mode`
* Current Assessment: The main work is close; keep the next steps simple.
* Current Recommendation: `Check bottles and take small sips.`
* Current Warning: `Do not force a full meal this close to the start.`
* Next 30-Minute Action: Check bottles/kit and take small sips; use only light carbs if hungry.
* Mistake To Avoid: Do not eat a heavy meal.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Yes, include a light-carb example.
* Domain Tie: activity, hydration, nutrition.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: The final prep window is open, so small choices matter more than big changes.
* Rewrite Recommendation: Check bottles and kit, sip water, and use a banana or gel only if you are hungry.
* Rewrite Warning: Do not force a full meal this close to the start.

## 18. Activity Preparation / Endurance 15-60 Minutes Away

* Current Title: `Be fresh at the start`
* Current Assessment: The meal window has passed; focus on final hydration, kit, and calm start.
* Current Recommendation: `Finish final hydration. Small sips only.`
* Current Warning: `Do not try to fix fueling with a full meal now.`
* Next 30-Minute Action: Sip water, check equipment, and start light warm-up if close enough.
* Mistake To Avoid: Do not chug water or eat a full meal.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Already concrete.
* Domain Tie: hydration, nutrition, activity.
* Scores: Human 9/10, Trust 8/10, Actionability 9/10.
* Rewrite Assessment: The meal window is closed; now the goal is a calm start.
* Rewrite Recommendation: Take small sips, check equipment, and begin an easy warm-up 10-15 minutes before start.
* Rewrite Warning: Do not try to fix late fueling with a full meal or last-minute chugging.

## 19. Activity Preparation / Endurance Under 15 Minutes

* Current Title: `Start the warm-up now`
* Current Assessment: The session is about to start; the useful choices are execution choices now.
* Current Recommendation: `Start warm-up now. Keep the first 10-15 minutes easy.`
* Current Warning: `Do not chase intensity from the first minutes.`
* Next 30-Minute Action: Start the warm-up and keep the first 10-15 minutes easy.
* Mistake To Avoid: Do not chase intensity immediately.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Already concrete.
* Domain Tie: activity, hydration.
* Scores: Human 9/10, Trust 9/10, Actionability 10/10.
* Rewrite Assessment: The start is close enough that execution matters more than prep.
* Rewrite Recommendation: Start warm-up now and keep the first 10-15 minutes easy.
* Rewrite Warning: Do not chase intensity in the opening minutes.

## 20. Active Activity / Generic Execution

* Current Title: `Keep effort repeatable` / activity-specific in-progress title.
* Current Assessment: The useful job now is repeatable execution.
* Current Recommendation: `Keep effort repeatable` / `Finish with reserve.`
* Current Warning: Do not turn one good block into a harder plan.
* Next 30-Minute Action: Hold current sustainable effort and back off if breathing/form worsens.
* Mistake To Avoid: Do not escalate pace because one segment feels good.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Yes, use 10-minute blocks.
* Domain Tie: activity, recovery.
* Scores: Human 7/10, Trust 7/10, Actionability 7/10.
* Rewrite Assessment: You are in the work now; the goal is controlled execution.
* Rewrite Recommendation: Hold the next 10 minutes at a repeatable effort and back off if breathing or form changes.
* Rewrite Warning: Do not turn one good block into a harder session.

## 21. Active Activity / Stop Or Do Not Continue

* Current Title: `I would not continue today` / `Recovery is limiting...`
* Current Assessment: Recovery, sleep, or accumulated load makes continuing the active session a poor trade.
* Current Recommendation: Hold the next block controlled or stop, depending severity.
* Current Warning: Do not add effort until breathing and form settle.
* Next 30-Minute Action: Stop the hard part now, cool down 5-10 minutes, and switch to recovery.
* Mistake To Avoid: Do not keep pushing because the session is already started.
* Would A Real Coach Say This: Yes, if stated directly.
* Can Be More Concrete: Yes, it should say stop, downgrade, or cap effort.
* Domain Tie: activity, recovery, sleep.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: Continuing hard work now is more likely to add fatigue than fitness.
* Rewrite Recommendation: Stop the hard block, cool down 5-10 minutes, and end the session easy.
* Rewrite Warning: Do not keep pushing just because the workout has already started.

## 22. Pacing Execution / Opening Block

* Current Title: `Settle into the effort`
* Current Assessment: The session has started; let breathing, legs, and heart rate settle.
* Current Recommendation: `Keep the next 10 minutes easy.`
* Current Warning: `Do not test fitness in the opening block.`
* Next 30-Minute Action: Keep the next 10 minutes easy, then reassess.
* Mistake To Avoid: Do not test fitness early.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Already concrete.
* Domain Tie: activity, recovery.
* Scores: Human 9/10, Trust 9/10, Actionability 10/10.
* Rewrite Assessment: The opening block should settle your breathing and legs.
* Rewrite Recommendation: Keep the next 10 minutes easy, then reassess pace.
* Rewrite Warning: Do not test fitness before the body settles.

## 23. Sustainable Execution / Endurance Ongoing

* Current Title: `Build a steady rhythm`
* Current Assessment: The warm-up window is over; repeatable effort and regular intake matter.
* Current Recommendation: `Take carbs every 20-30 minutes.`
* Current Warning: `Do not wait for hunger before starting the fueling schedule.`
* Next 30-Minute Action: Take carbs now if due and set a 20-30 minute repeat rhythm.
* Mistake To Avoid: Do not wait for hunger or thirst.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Yes, include grams.
* Domain Tie: activity, nutrition, hydration.
* Scores: Human 9/10, Trust 9/10, Actionability 9/10.
* Rewrite Assessment: Warm-up is over, so the session now needs rhythm and scheduled intake.
* Rewrite Recommendation: Take 30-60 g carbs now if due, then repeat every 20-30 minutes.
* Rewrite Warning: Do not wait for hunger before fueling.

## 24. Fueling During Activity

* Current Title: `Protect energy availability`
* Current Assessment: `You are spending energy faster than you are replacing it.`
* Current Recommendation: `Consume 30-60 g carbohydrates within the next 15 minutes.`
* Current Warning: `Waiting for hunger is already too late in a long session.`
* Next 30-Minute Action: Eat 30-60 g carbs within 15 minutes.
* Mistake To Avoid: Do not wait for hunger.
* Would A Real Coach Say This: Yes, except title could be less abstract.
* Can Be More Concrete: Recommendation is concrete; title can be simpler.
* Domain Tie: nutrition, activity, hydration.
* Scores: Human 8/10, Trust 9/10, Actionability 10/10.
* Rewrite Assessment: You are burning energy faster than you are replacing it.
* Rewrite Recommendation: Eat 30-60 g carbs within the next 15 minutes.
* Rewrite Warning: Do not wait for hunger in a long session.

## 25. Hydration During Activity

* Current Title: `Bring fluid intake back on track`
* Current Assessment: `Fluid intake is falling behind the workload.`
* Current Recommendation: `Drink 300-500 ml during the next 20 minutes.`
* Current Warning: `Catching up later is harder than steady drinking now.`
* Next 30-Minute Action: Drink 300-500 ml over the next 20 minutes.
* Mistake To Avoid: Do not wait until obvious thirst or chug later.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Already concrete.
* Domain Tie: hydration, activity.
* Scores: Human 9/10, Trust 9/10, Actionability 10/10.
* Rewrite Assessment: Fluid intake is behind the workload.
* Rewrite Recommendation: Drink 300-500 ml over the next 20 minutes in small sips.
* Rewrite Warning: Do not wait until thirst forces a catch-up drink.

## 26. Post-Endurance Short

* Current Title: `Close the session cleanly`
* Current Assessment: This was controlled endurance work, not a full recovery demand by itself.
* Current Recommendation: `Cool down 5-10 minutes easy.`
* Current Warning: `Do not add extra volume just because the session felt good.`
* Next 30-Minute Action: Cool down 5-10 minutes and return to normal food/fluid.
* Mistake To Avoid: Do not add extra volume.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Already concrete.
* Domain Tie: activity, recovery.
* Scores: Human 8/10, Trust 8/10, Actionability 9/10.
* Rewrite Assessment: This was controlled work, not a reason to add more.
* Rewrite Recommendation: Cool down 5-10 minutes easy and return to normal meals and fluids.
* Rewrite Warning: Do not add extra volume because the session felt good.

## 27. Post-Endurance Medium

* Current Title: `Start recovery now`
* Current Assessment: This session was meaningful enough to deserve recovery support.
* Current Recommendation: `Add 25-40 g protein before the next hour ends.`
* Current Warning: `Do not stack extra intensity onto this session.`
* Next 30-Minute Action: Start cooldown and plan 25-40 g protein within 60 minutes.
* Mistake To Avoid: Do not add another intense block.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Add fluid amount.
* Domain Tie: recovery, nutrition, hydration, activity.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: This session was enough load to start the recovery window.
* Rewrite Recommendation: Walk or spin easy for 5-10 minutes, then get 25-40 g protein within the hour.
* Rewrite Warning: Do not stack another hard block onto this session.

## 28. Post-Endurance Long

* Current Title: `The main work is complete`
* Current Assessment: `This long session created meaningful training stress.`
* Current Recommendation: `Eat 25-40 g protein and 60-100 g carbs within the next hour.`
* Current Warning: `Do not add another hard session today.`
* Next 30-Minute Action: Begin recovery meal/fluid process immediately.
* Mistake To Avoid: Do not delay the first recovery meal or add intensity.
* Would A Real Coach Say This: Yes. This is one of the strongest states.
* Can Be More Concrete: Add fluid amount if not shown nearby.
* Domain Tie: activity, recovery, nutrition, hydration, sleep.
* Scores: Human 9/10, Trust 9/10, Actionability 10/10.
* Rewrite Assessment: The long session is the main training load for today.
* Rewrite Recommendation: Within the next hour, eat 25-40 g protein with 60-100 g carbs and drink 500-750 ml gradually.
* Rewrite Warning: Do not add another hard session today.

## 29. Strength Before / During

* Current Title: `Keep strength controlled`
* Current Assessment: `Form and reserve matter more than forcing load today.`
* Current Recommendation: `Leave 1-2 reps in reserve.`
* Current Warning: `Do not add sloppy volume.`
* Next 30-Minute Action: Use warm-up sets, keep 1-2 reps in reserve, stop if technique breaks.
* Mistake To Avoid: Do not chase load at the cost of form.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Already concrete.
* Domain Tie: activity, recovery, tomorrow's plan if relevant.
* Scores: Human 9/10, Trust 8/10, Actionability 9/10.
* Rewrite Assessment: The useful strength work today depends on clean reps, not more weight.
* Rewrite Recommendation: Keep 1-2 reps in reserve on work sets and stop a set when technique changes.
* Rewrite Warning: Do not add volume if form starts to slip.

## 30. Strength Post

* Current Title: `Recover from strength`
* Current Assessment: `Strength work needs protein, fluids, and no extra hard blocks today.`
* Current Recommendation: `Target 25-40 g protein in the next meal.`
* Current Warning: `Do not add sloppy volume.`
* Next 30-Minute Action: Cool down 5-10 minutes and plan the next meal with 25-40 g protein.
* Mistake To Avoid: Do not add accessories or another hard session after the main work.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Yes, add mobility/soreness guidance.
* Domain Tie: nutrition, hydration, recovery, activity.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: The strength work is done; now the goal is to come down and feed it.
* Rewrite Recommendation: Walk 5-10 minutes, drink 300-700 ml over the next hour, and get 25-40 g protein at the next meal.
* Rewrite Warning: Do not add extra sets or another hard workout today.

## 31. Sauna / Heat Before

* Current Title: `Make sauna easier`
* Current Assessment: `Sauna adds stress even when it feels relaxing.`
* Current Recommendation: `Drink 300-500 ml water over the next hour before sauna.`
* Current Warning: `Do not go in dry or try to tolerate fatigue.`
* Next 30-Minute Action: Drink 300-500 ml gradually before heat.
* Mistake To Avoid: Do not enter sauna dehydrated or push discomfort.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Already concrete.
* Domain Tie: hydration, recovery, sleep, tomorrow's plan.
* Scores: Human 9/10, Trust 9/10, Actionability 10/10.
* Rewrite Assessment: Sauna is a stressor even when it feels relaxing.
* Rewrite Recommendation: Drink 300-500 ml gradually before you go in.
* Rewrite Warning: Do not start sauna dehydrated or stay in to prove toughness.

## 32. Sauna / Heat During

* Current Title: `Keep heat conservative`
* Current Assessment: `Heat is the load right now, not training.`
* Current Recommendation: `Exit before fatigue appears.`
* Current Warning: `Do not stack extra heat stress today.`
* Next 30-Minute Action: Keep the session comfortable and leave before fatigue/dizziness.
* Mistake To Avoid: Do not stay longer to chase a number.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Yes, include "leave now if dizzy."
* Domain Tie: hydration, recovery, sleep.
* Scores: Human 8/10, Trust 9/10, Actionability 9/10.
* Rewrite Assessment: Heat is the stressor right now.
* Rewrite Recommendation: Keep the session comfortable and leave before fatigue, dizziness, or pressure builds.
* Rewrite Warning: Do not extend heat exposure to hit a time target.

## 33. Sauna / Heat Post

* Current Title: `Recover from heat`
* Current Assessment: Sauna can help relaxation, but fluid loss still has to be replaced.
* Current Recommendation: `Drink 300-700 ml gradually.`
* Current Warning: `Do not add hard work after heat exposure.`
* Next 30-Minute Action: Cool down, then drink 300-700 ml gradually.
* Mistake To Avoid: Do not add hard training or more heat.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Add cooling sequence.
* Domain Tie: hydration, recovery, sleep, activity.
* Scores: Human 8/10, Trust 9/10, Actionability 9/10.
* Rewrite Assessment: Sauna is done, but the fluid cost still needs replacing.
* Rewrite Recommendation: Cool down first, then drink 300-700 ml gradually over the next hour.
* Rewrite Warning: Do not add hard training or another heat block today.

## 34. Recovery Modality Before / During

* Current Title: `Use walk/mobility/yoga as support` / `Keep walk relaxed`
* Current Assessment: This is useful recovery work, not a training target.
* Current Recommendation: `Keep it easy` / `Stay conversational`.
* Current Warning: `Do not turn this into training.`
* Next 30-Minute Action: Keep the movement conversational and stop before it feels like work.
* Mistake To Avoid: Do not chase pace, range, sweat, or strain.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Yes, add time cap by modality.
* Domain Tie: recovery, activity.
* Scores: Human 8/10, Trust 8/10, Actionability 7/10.
* Rewrite Assessment: This movement should leave you fresher, not tired.
* Rewrite Recommendation: Keep it conversational and cap it at 20-30 minutes unless the plan says less.
* Rewrite Warning: Do not chase pace, range, sweat, or strain.

## 35. Recovery Modality Post / Walk Complete

* Current Title: `Walk supported recovery` / `Movement supported recovery`
* Current Assessment: `This helped recovery without adding meaningful training strain.`
* Current Recommendation: `Do nothing extra.`
* Current Warning: `Do not count this as the main workout.`
* Next 30-Minute Action: Let it count; return to the plan without adding more.
* Mistake To Avoid: Do not dismiss it as useless or escalate into training.
* Would A Real Coach Say This: Mostly yes, but it can feel dismissive.
* Can Be More Concrete: Yes.
* Domain Tie: recovery, activity.
* Scores: Human 7/10, Trust 8/10, Actionability 6/10.
* Rewrite Assessment: That walk counts as recovery movement, not training stress.
* Rewrite Recommendation: Let it count and keep the next block easy.
* Rewrite Warning: Do not add more activity just because the walk felt easy.

## 36. Racket / Court Load

* Current Title: `Control the court load`
* Current Assessment: Racket sessions can become hard through repeated accelerations.
* Current Recommendation: `Cap repeated sprints.`
* Current Warning: `Do not let competition override recovery.`
* Next 30-Minute Action: Keep the hardest rallies selective and slow down between points.
* Mistake To Avoid: Do not make every point all-out.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Yes, add between-point behavior.
* Domain Tie: activity, recovery, hydration if long/sweaty.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: Court work becomes hard because of repeated accelerations.
* Rewrite Recommendation: Choose your hard rallies, slow down between points, and sip water on breaks.
* Rewrite Warning: Do not make every point all-out.

## 37. Breathing / Downshift

* Current Title: `Calm start` / `Evening downshift` / `Stay present`
* Current Assessment: Use the session to calm the mind or transition toward recovery.
* Current Recommendation: Sit/lie comfortably, slow exhale, do not force breath.
* Current Warning: Avoid jumping back into stress.
* Next 30-Minute Action: Do 5-10 minutes of easy breathing.
* Mistake To Avoid: Do not turn breathing into a performance task.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Yes, add duration.
* Domain Tie: recovery, sleep, stress.
* Scores: Human 8/10, Trust 7/10, Actionability 8/10.
* Rewrite Assessment: This is a downshift, not a workout.
* Rewrite Recommendation: Do 5-10 minutes lying or seated, making the exhale slower than the inhale.
* Rewrite Warning: Do not force deep breaths or treat calm as a score to hit.

## 38. Sleep Priority / Evening Wind-Down

* Current Title: `Protect sleep tonight` / `Wind down`
* Current Assessment: The evening should close calmly and not add extra tasks.
* Current Recommendation: Prepare for sleep / keep evening calm.
* Current Warning: Do not add load because the day looks calm.
* Next 30-Minute Action: Stop training, dim screens, prep tomorrow basics, keep dinner simple.
* Mistake To Avoid: Do not add another task or session late.
* Would A Real Coach Say This: Partly. The idea is right; wording needs behavior.
* Can Be More Concrete: Yes.
* Domain Tie: sleep, recovery, tomorrow's plan, nutrition.
* Scores: Human 6/10, Trust 7/10, Actionability 5/10.
* Rewrite Assessment: The training day is closed.
* Rewrite Recommendation: In the next 30 minutes, prep tomorrow basics, dim screens, and keep food simple.
* Rewrite Warning: Do not add training, extra chores, or late stimulation now.

## 39. Evening Reset / Catch-Up Pressure

* Current Title: `Evening reset` / `Close the day` / `Protect the night`
* Current Assessment: Have a normal dinner, sip fluids gradually, and do not chase the whole day at once.
* Current Recommendation: Sleep beats target chasing.
* Current Warning: Do not chase late calories, protein, hydration, or movement.
* Next 30-Minute Action: Eat a normal dinner if hungry, sip lightly, and start the bedtime path.
* Mistake To Avoid: Do not panic-fill missed targets late at night.
* Would A Real Coach Say This: Yes, but "sleep beats target chasing" needs a concrete next move.
* Can Be More Concrete: Yes.
* Domain Tie: sleep, nutrition, hydration, tomorrow's plan.
* Scores: Human 8/10, Trust 8/10, Actionability 7/10.
* Rewrite Assessment: It is late enough that catch-up behavior now has a cost.
* Rewrite Recommendation: If hungry, eat a normal dinner; sip fluids gradually; then move toward bed.
* Rewrite Warning: Do not chase every missed target tonight.

## 40. Hydration Complete

* Current Title: Hydration target reached / logged water feedback.
* Current Assessment: Goal is complete, usually as progress rather than Coach story.
* Current Recommendation: Not consistently visible.
* Current Warning: Not visible.
* Next 30-Minute Action: Drink to thirst only.
* Mistake To Avoid: Do not force extra water.
* Would A Real Coach Say This: Current state is status, not coaching.
* Can Be More Concrete: Yes.
* Domain Tie: hydration, activity/heat if present.
* Scores: Human 4/10, Trust 7/10, Actionability 4/10.
* Rewrite Assessment: Hydration is covered for now.
* Rewrite Recommendation: Drink to thirst for the next few hours.
* Rewrite Warning: Do not force extra water unless heat or heavy sweating returns.

## 41. Meal / Fuel Covered

* Current Title: `Meal is in` / `Food is covered` / `Fuel is covered`
* Current Assessment: Food has started or is adequate.
* Current Recommendation: Eat normally at next meal or no extra food needed.
* Current Warning: Do not chase water/calories now, depending branch.
* Next 30-Minute Action: Do nothing extra unless workout timing requires fuel.
* Mistake To Avoid: Do not eat just to satisfy a metric if training does not need it.
* Would A Real Coach Say This: Partly.
* Can Be More Concrete: Yes, tie to activity timing.
* Domain Tie: nutrition, activity, recovery.
* Scores: Human 6/10, Trust 7/10, Actionability 5/10.
* Rewrite Assessment: Food is covered for the current training window.
* Rewrite Recommendation: Do not add food now unless the next hard session starts within 90 minutes.
* Rewrite Warning: Do not chase calories when the plan does not need more fuel yet.

## 42. Good Day To Train / Opportunity Day

* Current Title: `Good day to train` / `Strong recovery day`
* Current Assessment: Recovery is one of the better windows and today can absorb training.
* Current Recommendation: Choose one useful block.
* Current Warning: There is nothing to force.
* Next 30-Minute Action: Pick one session goal, start easy for 10 minutes, and do not add a second session.
* Mistake To Avoid: Do not turn a good-readiness day into too many sessions.
* Would A Real Coach Say This: Partly. The idea is right but "choose one useful block" is vague.
* Can Be More Concrete: Yes.
* Domain Tie: recovery, activity, sleep.
* Scores: Human 7/10, Trust 8/10, Actionability 7/10.
* Rewrite Assessment: Sleep and recovery are good enough to train if you want a session today.
* Rewrite Recommendation: Choose one block only, start easy for 10 minutes, then build if the body confirms it.
* Rewrite Warning: Do not add multiple sessions just because today looks good.

## 43. Plan Cancel / Replace

* Current Title: `Adjust today's plan` / `Reduce the plan`
* Current Assessment: The remaining training no longer fits the day.
* Current Recommendation: Cancel or replace the remaining training.
* Current Warning: Do not treat a scheduled workout as work you still need to complete.
* Next 30-Minute Action: Delete, move, or replace the planned session with a 10-20 minute easy recovery block.
* Mistake To Avoid: Do not obey the calendar after the day has changed.
* Would A Real Coach Say This: Yes.
* Can Be More Concrete: Yes, the replacement should be named.
* Domain Tie: activity, recovery, sleep, completed load.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: The remaining planned workout no longer fits today's load.
* Rewrite Recommendation: Move it, skip it, or replace it with 10-20 minutes easy walking.
* Rewrite Warning: Do not complete the workout just because it is still on the calendar.

## 44. Plan Downgrade / Adjust

* Current Title: `Lower today's ceiling` / `Adjust the remaining plan`
* Current Assessment: The session can stay, but the original intensity does not fit.
* Current Recommendation: Keep only the version that supports recovery / lower the ceiling.
* Current Warning: Schedule-over-body variants.
* Next 30-Minute Action: Set an easy cap before starting and commit to stopping if warm-up is flat.
* Mistake To Avoid: Do not begin with the original hard target.
* Would A Real Coach Say This: Yes, but "supports recovery" is abstract.
* Can Be More Concrete: Yes.
* Domain Tie: activity, recovery, sleep.
* Scores: Human 8/10, Trust 8/10, Actionability 8/10.
* Rewrite Assessment: The workout can stay only if the ceiling comes down.
* Rewrite Recommendation: Cap it at easy effort for 20-30 minutes, and stop if the first 10 minutes feel flat.
* Rewrite Warning: Do not start at the original intensity and hope it improves.

## 45. Pending Action Required / Missed Planned Slot

* Current Title: `Pending Action Required`
* Current Assessment: `Your slot '%@' needs confirmation. Tap to update your metrics.`
* Current Recommendation: Tap to confirm, skip, or update the activity.
* Current Warning: Not visible.
* Next 30-Minute Action: Confirm whether the planned activity happened.
* Mistake To Avoid: Do not leave stale planned work unresolved because Coach may read it as pending.
* Would A Real Coach Say This: No. It sounds like task management, not coaching.
* Can Be More Concrete: Yes.
* Domain Tie: activity, recovery, planner trust.
* Scores: Human 4/10, Trust 7/10, Actionability 8/10.
* Rewrite Assessment: I need to know whether this planned activity happened before I judge the rest of the day.
* Rewrite Recommendation: Mark it done, skipped, or moved now.
* Rewrite Warning: Do not leave it pending if you want Coach to read today's load correctly.

## 46. Today Coach Card Fallback

* Current Title: final-story badge/title/subtitle or fallback sync text.
* Current Assessment: Summary of Coach state, but primary action may require opening Coach.
* Current Recommendation: Not always visible on the card.
* Current Warning: Not visible on the card.
* Next 30-Minute Action: Should mirror Coach's primary action directly on Today.
* Mistake To Avoid: Do not make the user tap Coach to learn the action.
* Would A Real Coach Say This: No if it only summarizes.
* Can Be More Concrete: Yes.
* Domain Tie: all domains depending state.
* Scores: Human 5/10, Trust 6/10, Actionability 4/10.
* Rewrite Assessment: Show the current Coach assessment in one plain sentence.
* Rewrite Recommendation: Show `Do now: [one exact action]` directly on Today.
* Rewrite Warning: Show `Avoid: [one exact mistake]` when the state is cautionary.

## Summary: Strongest Current States

* Long endurance completion is the best current Coach state because it includes protein, carbs, timing, and a clear avoid.
* Hydration and fueling during endurance are strong because they name amounts and timing.
* Strength during and post states are good because they include reps-in-reserve, protein, cooldown, and fluid amounts.
* Sauna states are strong because they frame heat as stress and give concrete fluid guidance.

## Summary: Weakest Current States

* Stable/no-plan states are too passive.
* Today card fallback can summarize without giving the action.
* Sleep-sync states are honest but do not close the next decision.
* Hydration-complete is status feedback, not coaching.
* Evening wind-down still uses phrases like "protect sleep" without always naming the behavior.

## Required Product Contract

Every visible Coach state should render:

* Assessment: one sentence explaining what is happening.
* Recommendation: one sentence naming the exact action for the next 30 minutes.
* Warning: one sentence naming the exact mistake to avoid.

If a state cannot produce those three sentences, it should not appear as Coach guidance.
