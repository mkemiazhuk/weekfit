import Foundation

enum AppText {
    enum Common {
        enum Action {
            static let cancel: LocalizedStringResource = "common.action.cancel"
            static let delete: LocalizedStringResource = "common.action.delete"
            static let save: LocalizedStringResource = "common.action.save"
            static let done: LocalizedStringResource = "common.action.done"
            static let back: LocalizedStringResource = "common.action.back"
            static let close: LocalizedStringResource = "common.action.close"
            static let create: LocalizedStringResource = "common.action.create"
            static let edit: LocalizedStringResource = "common.action.edit"
            static let reset: LocalizedStringResource = "common.action.reset"
            static let usePhoto: LocalizedStringResource = "common.action.usePhoto"
        }

        enum Unit {
            static let score: LocalizedStringResource = "common.unit.score"
            static let minuteShort: LocalizedStringResource = "common.unit.minuteShort"
            static let minutesFormat: LocalizedStringResource = "common.unit.minutesFormat"
            static let gramFormat: LocalizedStringResource = "common.unit.gramFormat"
            static let caloriesFormat: LocalizedStringResource = "common.unit.caloriesFormat"
            static let countParenthesesFormat: LocalizedStringResource = "common.unit.countParenthesesFormat"
        }

        enum Tab {
            static let today: LocalizedStringResource = "common.tab.today"
            static let coach: LocalizedStringResource = "common.tab.coach"
            static let highlights: LocalizedStringResource = "common.tab.highlights"
            static let meals: LocalizedStringResource = "common.tab.meals"
            static let plan: LocalizedStringResource = "common.tab.plan"
        }
    }

    enum Login {
        static let brandFit: LocalizedStringResource = "login.brand.fit"
        static let heroTitleLine1: LocalizedStringResource = "login.hero.title.line1"
        static let heroTitleLine2: LocalizedStringResource = "login.hero.title.line2"
        static let heroSubtitle: LocalizedStringResource = "login.hero.subtitle"
        static let recoveryTitle: LocalizedStringResource = "login.card.recovery.title"
        static let recoveryValue: LocalizedStringResource = "login.card.recovery.value"
        static let recoverySubtitle: LocalizedStringResource = "login.card.recovery.subtitle"
        static let sleepTitle: LocalizedStringResource = "login.card.sleep.title"
        static let sleepValue: LocalizedStringResource = "login.card.sleep.value"
        static let sleepSubtitle: LocalizedStringResource = "login.card.sleep.subtitle"
        static let workoutTitle: LocalizedStringResource = "login.card.workout.title"
        static let workoutValue: LocalizedStringResource = "login.card.workout.value"
        static let workoutSubtitle: LocalizedStringResource = "login.card.workout.subtitle"
        static let openWeekFit: LocalizedStringResource = "login.action.openWeekFit"
        static let appleHealthNote: LocalizedStringResource = "login.note.appleHealth"
        static let connectWhenReady: LocalizedStringResource = "login.note.connectWhenReady"
        static let termsIntro: LocalizedStringResource = "login.terms.intro"
        static let termsOfService: LocalizedStringResource = "login.terms.service"
        static let termsAnd: LocalizedStringResource = "login.terms.and"
        static let privacyPolicy: LocalizedStringResource = "login.terms.privacy"
    }

    enum Today {
        static let title: LocalizedStringResource = "today.title"
        static let savedTab: LocalizedStringResource = "today.quickLog.tab.saved"
        static let snacksTab: LocalizedStringResource = "today.quickLog.tab.drinksSnacks"
        static let logFoodTitle: LocalizedStringResource = "today.quickLog.title.logFood"
        static let quickAddMealsSubtitle: LocalizedStringResource = "today.quickLog.subtitle.savedFoods"
        static let quickAddSnacksSubtitle: LocalizedStringResource = "today.quickLog.subtitle.drinksSnacks"
        static let noSavedFoodTitle: LocalizedStringResource = "today.quickLog.empty.savedFood.title"
        static let noSavedFoodMessage: LocalizedStringResource = "today.quickLog.empty.savedFood.message"
        static let openMealsLibrary: LocalizedStringResource = "today.quickLog.empty.savedFood.action"
        static let mealsSection: LocalizedStringResource = "today.quickLog.section.meals"
        static let foodsSection: LocalizedStringResource = "today.quickLog.section.foods"
        static let noQuickItemsTitle: LocalizedStringResource = "today.quickLog.empty.quickItems.title"
        static let noQuickItemsMessage: LocalizedStringResource = "today.quickLog.empty.quickItems.message"
        static let noDrinksTitle: LocalizedStringResource = "today.quickLog.empty.drinks.title"
        static let quickAddDrinksSubtitle: LocalizedStringResource = "today.quickLog.subtitle.drinks"
        static let drinksSection: LocalizedStringResource = "today.quickLog.section.drinks"
        static let snacksSection: LocalizedStringResource = "today.quickLog.section.snacks"
        static let eveningReviewReady: LocalizedStringResource = "today.eveningReview.ready"
        static let eveningReviewSubtitle: LocalizedStringResource = "today.eveningReview.subtitle"
        static let dailyStatusTitle: LocalizedStringResource = "today.status.title"
        static let dailyStatusSubtitle: LocalizedStringResource = "today.status.subtitle"
        static let connectAppleHealth: LocalizedStringResource = "today.health.connect.title"
        static let healthDescription: LocalizedStringResource = "today.health.connect.description"
        static let activityTitle: LocalizedStringResource = "today.status.activity"
        static let exerciseMetric: LocalizedStringResource = "today.status.metric.exercise"
        static let standMetric: LocalizedStringResource = "today.status.metric.stand"
        static let cardioMetric: LocalizedStringResource = "today.status.metric.cardio"
        static let nutritionTitle: LocalizedStringResource = "today.status.nutrition"
        static let recoveryTitle: LocalizedStringResource = "today.status.recovery"
        static let syncingHealth: LocalizedStringResource = "today.status.syncingHealth"
        static let loading: LocalizedStringResource = "today.status.loading"
        static let deepMetric: LocalizedStringResource = "today.status.metric.deep"
        static let upNextTitle: LocalizedStringResource = "today.upNext.title"
        static let currentSession: LocalizedStringResource = "today.upNext.currentSession"
        static let live: LocalizedStringResource = "today.upNext.live"
        static let noActivitiesPlanned: LocalizedStringResource = "today.upNext.empty"
        static let nutritionContext: LocalizedStringResource = "today.activity.context.nutrition"
        static let enduranceContext: LocalizedStringResource = "today.activity.context.endurance"
        static let recoveryContext: LocalizedStringResource = "today.activity.context.recovery"
        static let routineContext: LocalizedStringResource = "today.activity.context.routine"
        static let morningFuel: LocalizedStringResource = "today.activity.subtitle.morningFuel"
        static let energySupport: LocalizedStringResource = "today.activity.subtitle.energySupport"
        static let nutritionSupport: LocalizedStringResource = "today.activity.subtitle.nutritionSupport"
        static let trainingSession: LocalizedStringResource = "today.activity.subtitle.trainingSession"
        static let recoveryBlock: LocalizedStringResource = "today.activity.subtitle.recoveryBlock"
        static let hydrationSupport: LocalizedStringResource = "today.activity.subtitle.hydrationSupport"
        static let plannedActivity: LocalizedStringResource = "today.activity.subtitle.plannedActivity"
        static let pendingActionTitle: LocalizedStringResource = "today.pending.title"
        static let coachInsightLabel: LocalizedStringResource = "today.coachInsight.label"
        static let coachCardDoNowFormat: LocalizedStringResource = "today.coach.card.doNowFormat"
        static let coachCardAvoidFormat: LocalizedStringResource = "today.coach.card.avoidFormat"
        static let coachCardHighConfidence: LocalizedStringResource = "today.coach.card.highConfidence"
        static let coachCardModerateConfidence: LocalizedStringResource = "today.coach.card.moderateConfidence"
        static let coachCardLimitedConfidence: LocalizedStringResource = "today.coach.card.limitedConfidence"
        static let connectHealthInsights: LocalizedStringResource = "today.coachInsight.connectHealth"
        static let quickActionsTitle: LocalizedStringResource = "today.quickActions.title"
        static let logDrinks: LocalizedStringResource = "today.quickActions.logDrinks"
        static let logFood: LocalizedStringResource = "today.quickActions.logFood"
        static let mealsSnacks: LocalizedStringResource = "today.quickActions.mealsSnacks"
        static let startActivity: LocalizedStringResource = "today.quickActions.startActivity"
        static let workoutRecovery: LocalizedStringResource = "today.quickActions.workoutRecovery"
        static let verifyLogBlock: LocalizedStringResource = "today.verify.title"
        static let skippedAction: LocalizedStringResource = "today.verify.skipped"
        static let confirmLogAction: LocalizedStringResource = "today.verify.confirm"
        static let readyStatus: LocalizedStringResource = "today.recovery.ready"
        static let goodStatus: LocalizedStringResource = "today.recovery.good"
        static let okStatus: LocalizedStringResource = "today.recovery.ok"
        static let needRestStatus: LocalizedStringResource = "today.recovery.needRest"
        static let syncingStatus: LocalizedStringResource = "today.recovery.syncing"
        static let recoverySleepSyncPending: LocalizedStringResource = "today.recovery.sleepSyncPending"
    }

    enum Coach {
        enum State {
            static let overview: LocalizedStringResource = "coach.state.overview"
        }

        enum Card {
            static let myRead: LocalizedStringResource = "coach.card.myRead"
            static let recommendation: LocalizedStringResource = "coach.card.recommendation"
            static let watchOutFor: LocalizedStringResource = "coach.card.watchOutFor"
        }

        enum Action {
            static let keepRhythm: LocalizedStringResource = "coach.action.keepRhythm"
            static let avoidExtraIntensity: LocalizedStringResource = "coach.action.avoidExtraIntensity"
            static let protectSleep: LocalizedStringResource = "coach.action.protectSleep"
            static let keepRestEasy: LocalizedStringResource = "coach.action.keepRestEasy"
            static let finishWithEnergyLeft: LocalizedStringResource = "coach.action.finishWithEnergyLeft"
            static let followPlan: LocalizedStringResource = "coach.action.followPlan"
            static let staySteady: LocalizedStringResource = "coach.action.staySteady"
            static let keepPlanSimple: LocalizedStringResource = "coach.action.keepPlanSimple"
            static let stayConsistentFoodWaterMovement: LocalizedStringResource = "coach.action.stayConsistentFoodWaterMovement"
        }

        enum Fallback {
            static let keepNextStepSimple: LocalizedStringResource = "coach.fallback.keepNextStepSimple"
            static let normalDayWarning: LocalizedStringResource = "coach.fallback.normalDayWarning"
            static let noActiveGuidance: LocalizedStringResource = "coach.fallback.noActiveGuidance"
            static let noActiveFocus: LocalizedStringResource = "coach.fallback.noActiveFocus"
        }

        enum Status {
            static let currentTitle: LocalizedStringResource = "coach.status.current.title"
            static let currentSubtitle: LocalizedStringResource = "coach.status.current.subtitle"
        }

        enum Section {
            enum Title {
                static let whyThisMatters: LocalizedStringResource = "coach.section.title.whyThisMatters"
                static let planChallenge: LocalizedStringResource = "coach.section.title.planChallenge"
                static let sleepSupport: LocalizedStringResource = "coach.section.title.sleepSupport"
                static let recoverySupport: LocalizedStringResource = "coach.section.title.recoverySupport"
                static let hydrationSupport: LocalizedStringResource = "coach.section.title.hydrationSupport"
                static let fuelingSupport: LocalizedStringResource = "coach.section.title.fuelingSupport"
                static let planAdjustment: LocalizedStringResource = "coach.section.title.planAdjustment"
                static let trainingAdjustment: LocalizedStringResource = "coach.section.title.trainingAdjustment"
                static let sessionFocus: LocalizedStringResource = "coach.section.title.sessionFocus"
                static let dailyRhythm: LocalizedStringResource = "coach.section.title.dailyRhythm"
                static let fuelHydration: LocalizedStringResource = "coach.section.title.fuelHydration"
                static let settleIn: LocalizedStringResource = "coach.section.title.settleIn"
                static let coachInsight: LocalizedStringResource = "coach.section.title.coachInsight"
                static let stayWithIt: LocalizedStringResource = "coach.section.title.stayWithIt"
                static let recoveryEffect: LocalizedStringResource = "coach.section.title.recoveryEffect"
                static let whatToDoNext: LocalizedStringResource = "coach.section.title.whatToDoNext"
            }

            enum Subtitle {
                static let dayLevelReason: LocalizedStringResource = "coach.section.subtitle.dayLevelReason"
                static let planChallengeSignals: LocalizedStringResource = "coach.section.subtitle.planChallengeSignals"
                static let sleepPreparation: LocalizedStringResource = "coach.section.subtitle.sleepPreparation"
                static let recovery: LocalizedStringResource = "coach.section.subtitle.recovery"
                static let hydration: LocalizedStringResource = "coach.section.subtitle.hydration"
                static let fueling: LocalizedStringResource = "coach.section.subtitle.fueling"
                static let planChallenge: LocalizedStringResource = "coach.section.subtitle.planChallenge"
                static let performance: LocalizedStringResource = "coach.section.subtitle.performance"
                static let activeSession: LocalizedStringResource = "coach.section.subtitle.activeSession"
                static let stable: LocalizedStringResource = "coach.section.subtitle.stable"
                static let breathingBefore: LocalizedStringResource = "coach.section.subtitle.breathingBefore"
                static let breathingInsightKeepInMind: LocalizedStringResource = "coach.section.subtitle.breathingInsightKeepInMind"
                static let breathingDuring: LocalizedStringResource = "coach.section.subtitle.breathingDuring"
                static let breathingAfterEffect: LocalizedStringResource = "coach.section.subtitle.breathingAfterEffect"
                static let breathingNext: LocalizedStringResource = "coach.section.subtitle.breathingNext"
                static let breathingInsightAfter: LocalizedStringResource = "coach.section.subtitle.breathingInsightAfter"
                static let recoveryWhy: LocalizedStringResource = "coach.section.subtitle.recoveryWhy"
                static let heatWhy: LocalizedStringResource = "coach.section.subtitle.heatWhy"
                static let fuelBefore: LocalizedStringResource = "coach.section.subtitle.fuelBefore"
                static let fuelDuring: LocalizedStringResource = "coach.section.subtitle.fuelDuring"
                static let fuelAfter: LocalizedStringResource = "coach.section.subtitle.fuelAfter"
                static let fuelStable: LocalizedStringResource = "coach.section.subtitle.fuelStable"
                static let sessionBefore: LocalizedStringResource = "coach.section.subtitle.sessionBefore"
                static let sessionDuring: LocalizedStringResource = "coach.section.subtitle.sessionDuring"
                static let sessionAfter: LocalizedStringResource = "coach.section.subtitle.sessionAfter"
                static let sessionStable: LocalizedStringResource = "coach.section.subtitle.sessionStable"
                static let recoveryBefore: LocalizedStringResource = "coach.section.subtitle.recoveryBefore"
                static let recoveryDuring: LocalizedStringResource = "coach.section.subtitle.recoveryDuring"
                static let recoveryAfter: LocalizedStringResource = "coach.section.subtitle.recoveryAfter"
                static let recoveryStable: LocalizedStringResource = "coach.section.subtitle.recoveryStable"
                static let heatBefore: LocalizedStringResource = "coach.section.subtitle.heatBefore"
                static let heatDuring: LocalizedStringResource = "coach.section.subtitle.heatDuring"
                static let heatAfter: LocalizedStringResource = "coach.section.subtitle.heatAfter"
                static let heatStable: LocalizedStringResource = "coach.section.subtitle.heatStable"
            }

            enum Item {
                static let sitOrLieComfortably: LocalizedStringResource = "coach.section.item.sitOrLieComfortably"
                static let letExhaleSlower: LocalizedStringResource = "coach.section.item.letExhaleSlower"
                static let doNotForceBreath: LocalizedStringResource = "coach.section.item.doNotForceBreath"
                static let keepBreathComfortable: LocalizedStringResource = "coach.section.item.keepBreathComfortable"
                static let makeExhaleGentle: LocalizedStringResource = "coach.section.item.makeExhaleGentle"
                static let returnCalmly: LocalizedStringResource = "coach.section.item.returnCalmly"
                static let heartRateSettles: LocalizedStringResource = "coach.section.item.heartRateSettles"
                static let stressMayFeelLower: LocalizedStringResource = "coach.section.item.stressMayFeelLower"
                static let recoveryModeEasier: LocalizedStringResource = "coach.section.item.recoveryModeEasier"
                static let keepScreensLow: LocalizedStringResource = "coach.section.item.keepScreensLow"
                static let continueEveningRoutine: LocalizedStringResource = "coach.section.item.continueEveningRoutine"
                static let avoidJumpingStress: LocalizedStringResource = "coach.section.item.avoidJumpingStress"
                static let drink300500Water: LocalizedStringResource = "coach.section.item.drink300500Water"
                static let keepDinnerProteinFocused: LocalizedStringResource = "coach.section.item.keepDinnerProteinFocused"
                static let avoidHeavyFoodBeforeSleep: LocalizedStringResource = "coach.section.item.avoidHeavyFoodBeforeSleep"
                static let drinkWaterIfNeeded: LocalizedStringResource = "coach.section.item.drinkWaterIfNeeded"
                static let walkComfortablePace: LocalizedStringResource = "coach.section.item.walkComfortablePace"
                static let keepBreathingRelaxed: LocalizedStringResource = "coach.section.item.keepBreathingRelaxed"
                static let moveSlowly: LocalizedStringResource = "coach.section.item.moveSlowly"
                static let avoidPainfulPositions: LocalizedStringResource = "coach.section.item.avoidPainfulPositions"
                static let focusRangeOfMotion: LocalizedStringResource = "coach.section.item.focusRangeOfMotion"
                static let keepFlowGentle: LocalizedStringResource = "coach.section.item.keepFlowGentle"
                static let avoidForcingDeepPositions: LocalizedStringResource = "coach.section.item.avoidForcingDeepPositions"
                static let finishCalmer: LocalizedStringResource = "coach.section.item.finishCalmer"
                static let keepHydrationSimple: LocalizedStringResource = "coach.section.item.keepHydrationSimple"
                static let moveGently: LocalizedStringResource = "coach.section.item.moveGently"
                static let avoidAddingLoad: LocalizedStringResource = "coach.section.item.avoidAddingLoad"
                static let drinkWaterBeforeHeat: LocalizedStringResource = "coach.section.item.drinkWaterBeforeHeat"
                static let mineralWaterElectrolytes: LocalizedStringResource = "coach.section.item.mineralWaterElectrolytes"
                static let keepFoodLight: LocalizedStringResource = "coach.section.item.keepFoodLight"
                static let keepSessionComfortable: LocalizedStringResource = "coach.section.item.keepSessionComfortable"
                static let exitIfDizzy: LocalizedStringResource = "coach.section.item.exitIfDizzy"
                static let doNotPushThroughStress: LocalizedStringResource = "coach.section.item.doNotPushThroughStress"
                static let drinkWaterSlowly: LocalizedStringResource = "coach.section.item.drinkWaterSlowly"
                static let keepEveningCalm: LocalizedStringResource = "coach.section.item.keepEveningCalm"
            }

            enum Info {
                static let breathingNotPerformance: LocalizedStringResource = "coach.section.info.breathingNotPerformance"
                static let protectRelaxedState: LocalizedStringResource = "coach.section.info.protectRelaxedState"
                static let heatRecovery: LocalizedStringResource = "coach.section.info.heatRecovery"
                static let recoveryWalk: LocalizedStringResource = "coach.section.info.recoveryWalk"
                static let recoveryStretching: LocalizedStringResource = "coach.section.info.recoveryStretching"
                static let recoveryYoga: LocalizedStringResource = "coach.section.info.recoveryYoga"
                static let recoveryDefault: LocalizedStringResource = "coach.section.info.recoveryDefault"
            }
        }
    }

    enum Meals {
        enum PhotoCrop {
            static let title: LocalizedStringResource = "meals.photoCrop.title"
            static let hint: LocalizedStringResource = "meals.photoCrop.hint"
        }
    }

    enum Auth {
        enum Email {
            enum Title {
                static let signIn: LocalizedStringResource = "auth.email.title.signIn"
                static let createAccount: LocalizedStringResource = "auth.email.title.createAccount"
                static let resetPassword: LocalizedStringResource = "auth.email.title.resetPassword"
            }

            enum Subtitle {
                static let signIn: LocalizedStringResource = "auth.email.subtitle.signIn"
                static let createAccount: LocalizedStringResource = "auth.email.subtitle.createAccount"
                static let resetPassword: LocalizedStringResource = "auth.email.subtitle.resetPassword"
            }

            enum Button {
                static let signIn: LocalizedStringResource = "auth.email.button.signIn"
                static let createAccount: LocalizedStringResource = "auth.email.button.createAccount"
                static let resetPassword: LocalizedStringResource = "auth.email.button.resetPassword"
            }

            enum Field {
                static let email: LocalizedStringResource = "auth.email.field.email"
                static let password: LocalizedStringResource = "auth.email.field.password"
                static let confirmPassword: LocalizedStringResource = "auth.email.field.confirmPassword"
            }

            enum Link {
                static let forgotPassword: LocalizedStringResource = "auth.email.link.forgotPassword"
                static let createAccount: LocalizedStringResource = "auth.email.link.createAccount"
                static let signIn: LocalizedStringResource = "auth.email.link.signIn"
                static let backToSignIn: LocalizedStringResource = "auth.email.link.backToSignIn"
            }

            enum Error {
                static let invalidCredentials: LocalizedStringResource = "auth.email.error.invalidCredentials"
                static let emailAlreadyExists: LocalizedStringResource = "auth.email.error.emailAlreadyExists"
                static let invalidEmail: LocalizedStringResource = "auth.email.error.invalidEmail"
                static let weakPassword: LocalizedStringResource = "auth.email.error.weakPassword"
                static let userNotFound: LocalizedStringResource = "auth.email.error.userNotFound"
                static let network: LocalizedStringResource = "auth.email.error.network"
                static let appleCredentials: LocalizedStringResource = "auth.email.error.appleCredentials"
                static let passwordResetSent: LocalizedStringResource = "auth.email.success.passwordResetSent"
            }
        }
    }

    enum Nutrition {
        enum Macro {
            static let calories: LocalizedStringResource = "nutrition.macro.calories"
            static let protein: LocalizedStringResource = "nutrition.macro.protein"
            static let carbs: LocalizedStringResource = "nutrition.macro.carbs"
            static let fats: LocalizedStringResource = "nutrition.macro.fats"
            static let fiber: LocalizedStringResource = "nutrition.macro.fiber"
        }

        enum Details {
            static let title: LocalizedStringResource = "nutrition.details.title"
            static let scoreTitle: LocalizedStringResource = "nutrition.details.score.title"
            static let estimateNote: LocalizedStringResource = "nutrition.details.estimateNote"
            static let emptyTitle: LocalizedStringResource = "nutrition.details.empty.title"
            static let emptyMessage: LocalizedStringResource = "nutrition.details.empty.message"
            static let macroValueFormat: LocalizedStringResource = "nutrition.details.macro.valueFormat"
            static let mealCaloriesFormat: LocalizedStringResource = "nutrition.details.meal.caloriesFormat"
        }
    }

    enum Planner {
        static let weekOverview: LocalizedStringResource = "planner.weekOverview"
        static let buildYourDay: LocalizedStringResource = "planner.empty.title"
        static let buildYourDayMessage: LocalizedStringResource = "planner.empty.message"
        static let monthView: LocalizedStringResource = "planner.month.title"
        static let monthComing: LocalizedStringResource = "planner.month.coming"
        static let monthSourceOfTruth: LocalizedStringResource = "planner.month.sourceOfTruth"
        static let backToWeek: LocalizedStringResource = "planner.month.backToWeek"
        static let weeklyCoachNote: LocalizedStringResource = "planner.week.coachNote"
        static let confirmActivityTitle: LocalizedStringResource = "planner.confirm.title"
        static let confirmActivityMessageFormat: LocalizedStringResource = "planner.confirm.messageFormat"
        static let deleteLoggedActivityTitle: LocalizedStringResource = "planner.delete.logged.title"
        static let deleteMessageFormat: LocalizedStringResource = "planner.delete.messageFormat"
        static let timeConflictTitle: LocalizedStringResource = "planner.timeConflict.title"
        static let deleteActivityTitle: LocalizedStringResource = "planner.delete.title"
        static let deleteActivityMessage: LocalizedStringResource = "planner.delete.message"
        static let whenTitle: LocalizedStringResource = "planner.when.title"
        static let addOneHour: LocalizedStringResource = "planner.time.addOneHour"
        static let customTitle: LocalizedStringResource = "planner.duration.custom"
        static let customDurationTitle: LocalizedStringResource = "planner.duration.customTitle"
        static let customDurationSubtitle: LocalizedStringResource = "planner.duration.customSubtitle"
        static let durationPickerTitle: LocalizedStringResource = "planner.duration.pickerTitle"
        static let setDurationFormat: LocalizedStringResource = "planner.duration.setFormat"
        static let mealMacroSummaryFormat: LocalizedStringResource = "planner.meal.macroSummaryFormat"
    }

    enum Activity {
        enum Details {
            static let title: LocalizedStringResource = "activity.details.title"
            static let scoreTitle: LocalizedStringResource = "activity.details.score.title"
            static let timelineTitle: LocalizedStringResource = "activity.details.timeline.title"
            static let weekTitle: LocalizedStringResource = "activity.details.week.title"
            static let logTitle: LocalizedStringResource = "activity.details.log.title"
            static let heartRateTitle: LocalizedStringResource = "activity.details.heartRate.title"
            static let routeTitle: LocalizedStringResource = "activity.details.route.title"
            static let routeViewMap: LocalizedStringResource = "activity.route.viewMap"
            static let routeExpandHint: LocalizedStringResource = "activity.route.expandHint"
            static let zonesTitle: LocalizedStringResource = "activity.details.zones.title"
            static let emptyTitle: LocalizedStringResource = "activity.details.empty.title"
            static let emptyMessage: LocalizedStringResource = "activity.details.empty.message"
            static let sessionsFormat: LocalizedStringResource = "activity.details.sessionsFormat"
            static let averageHeartRateFormat: LocalizedStringResource = "activity.details.averageHeartRateFormat"
            static let maxHeartRateFormat: LocalizedStringResource = "activity.details.maxHeartRateFormat"
        }
    }

    enum Highlights {
        static let title: LocalizedStringResource = "highlights.title"
        static let last30Days: LocalizedStringResource = "highlights.range.last30Days"
        static let monthlyStory: LocalizedStringResource = "highlights.monthlyStory"
        static let loading: LocalizedStringResource = "highlights.loading"
    }

    enum Recovery {
        enum Details {
            static let title: LocalizedStringResource = "recovery.details.title"
            static let scoreTitle: LocalizedStringResource = "recovery.details.score.title"
            static let scoreExplanation: LocalizedStringResource = "recovery.details.score.explanation"
        }
    }

    enum Settings {
        enum Profile {
            static let title: LocalizedStringResource = "settings.profile.title"
            static let settingsSection: LocalizedStringResource = "settings.profile.section.settings"
            static let supportSection: LocalizedStringResource = "settings.profile.section.support"
            static let systemSection: LocalizedStringResource = "settings.profile.section.system"
            static let privacyDataSection: LocalizedStringResource = "settings.profile.section.privacyData"
            static let healthSystemFallback: LocalizedStringResource = "settings.profile.healthSystemFallback"
            static let recoverySystemActive: LocalizedStringResource = "settings.profile.recoverySystemActive"
            static let healthSetupNeeded: LocalizedStringResource = "settings.profile.healthSetupNeeded"
            static let appleHealthConnected: LocalizedStringResource = "settings.profile.appleHealthConnected"
            static let connectHealthPlanning: LocalizedStringResource = "settings.profile.connectHealthPlanning"
            static let healthSignal: LocalizedStringResource = "settings.profile.signal.health"
            static let adaptiveSignal: LocalizedStringResource = "settings.profile.signal.adaptive"
            static let privateSignal: LocalizedStringResource = "settings.profile.signal.private"
            static let connectedBadge: LocalizedStringResource = "settings.profile.badge.connected"
            static let setupBadge: LocalizedStringResource = "settings.profile.badge.setup"
            static let resetLocalData: LocalizedStringResource = "settings.profile.resetLocalData"
            static let resettingLocalData: LocalizedStringResource = "settings.profile.resettingLocalData"
            static let resetConfirmTitle: LocalizedStringResource = "settings.profile.resetConfirm.title"
            static let resetConfirmMessage: LocalizedStringResource = "settings.profile.resetConfirm.message"
            static let resetConfirmPrimary: LocalizedStringResource = "settings.profile.resetConfirm.primary"
            static let resetFailedTitle: LocalizedStringResource = "settings.profile.resetFailed.title"
            static let footerPrivacy: LocalizedStringResource = "settings.profile.footer.privacy"
            static let notificationsTitle: LocalizedStringResource = "settings.profile.item.notifications"
            static let notificationsSubtitle: LocalizedStringResource = "settings.profile.item.notifications.subtitle"
            static let healthSignalsTitle: LocalizedStringResource = "settings.profile.item.healthSignals"
            static let healthSignalsSubtitle: LocalizedStringResource = "settings.profile.item.healthSignals.subtitle"
            static let helpSupportTitle: LocalizedStringResource = "settings.profile.item.helpSupport"
            static let termsPrivacyTitle: LocalizedStringResource = "settings.profile.item.termsPrivacy"
            static let bodyGoalTitle: LocalizedStringResource = "settings.profile.bodyGoal.title"
        }

        enum BodyGoal {
            static let title: LocalizedStringResource = "settings.profile.bodyGoal.title"
            static let setupSubtitle: LocalizedStringResource = "settings.profile.bodyGoal.setupSubtitle"
            static let missingHealthNote: LocalizedStringResource = "settings.profile.bodyGoal.missingHealthNote"
            static let footerWithHealth: LocalizedStringResource = "settings.profile.bodyGoal.footerWithHealth"
            static let footerWithoutHealth: LocalizedStringResource = "settings.profile.bodyGoal.footerWithoutHealth"
        }

        enum Language {
            static let title: LocalizedStringResource = "settings.language.title"
            static let subtitle: LocalizedStringResource = "settings.language.subtitle"
            static let currentFormat: LocalizedStringResource = "settings.language.currentFormat"
            static let footer: LocalizedStringResource = "settings.language.footer"

            enum Option {
                static let english: LocalizedStringResource = "settings.language.option.english"
                static let russian: LocalizedStringResource = "settings.language.option.russian"
            }
        }

        enum ProfileEdit {
            static let title: LocalizedStringResource = "settings.profile.edit.title"
            static let headline: LocalizedStringResource = "settings.profile.edit.headline"
            static let localNote: LocalizedStringResource = "settings.profile.edit.localNote"
            static let nameField: LocalizedStringResource = "settings.profile.edit.nameField"
            static let namePlaceholder: LocalizedStringResource = "settings.profile.edit.namePlaceholder"
        }

        enum Notifications {
            static let title: LocalizedStringResource = "settings.notifications.title"
            static let activitySection: LocalizedStringResource = "settings.notifications.section.activity"
            static let wellnessSection: LocalizedStringResource = "settings.notifications.section.wellness"
            static let activityRemindersTitle: LocalizedStringResource = "settings.notifications.activityReminders.title"
            static let activityRemindersSubtitle: LocalizedStringResource = "settings.notifications.activityReminders.subtitle"
            static let completionCheckInsTitle: LocalizedStringResource = "settings.notifications.completionCheckIns.title"
            static let completionCheckInsSubtitle: LocalizedStringResource = "settings.notifications.completionCheckIns.subtitle"
            static let recoverySuggestionsTitle: LocalizedStringResource = "settings.notifications.recoverySuggestions.title"
            static let recoverySuggestionsSubtitle: LocalizedStringResource = "settings.notifications.recoverySuggestions.subtitle"
            static let hydrationRemindersTitle: LocalizedStringResource = "settings.notifications.hydrationReminders.title"
            static let hydrationRemindersSubtitle: LocalizedStringResource = "settings.notifications.hydrationReminders.subtitle"
            static let sleepWindDownTitle: LocalizedStringResource = "settings.notifications.sleepWindDown.title"
            static let sleepWindDownSubtitle: LocalizedStringResource = "settings.notifications.sleepWindDown.subtitle"
            static let footerNote: LocalizedStringResource = "settings.notifications.footerNote"
        }
    }

    enum Errors {}
}

func WeekFitLocalizedString(_ key: String, locale: Locale? = nil) -> String {
    let resolvedLocale = locale ?? WeekFitCurrentLocale()
    let resolved = WeekFitBundleLocalizedString(key, locale: resolvedLocale)
    WeekFitDebugLogLocalizationResolution(key: key, locale: resolvedLocale, resolved: resolved)
    return resolved
}

private func WeekFitBundleLocalizedString(_ key: String, locale: Locale) -> String {
    let languageCode = locale.language.languageCode?.identifier ?? locale.identifier

    if let languageBundlePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
       let languageBundle = Bundle(path: languageBundlePath) {
        let localized = languageBundle.localizedString(forKey: key, value: nil, table: nil)
        if localized != key {
            return localized
        }
    }

    let fallback = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    if fallback != key {
        return fallback
    }

    return key
}

func WeekFitCurrentLocale() -> Locale {
    WeekFitLocalizationCache.current.locale
}

func WeekFitWarmLocalizationCache() {
    WeekFitLocalizationCache.refreshFromStorage()
}

func WeekFitSetCurrentLanguage(_ language: AppLanguage) {
    WeekFitLocalizationCache.update(language: language)
}

func WeekFitShortWeekdayMonthDay(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = WeekFitCurrentLocale()
    formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
    return formatter.string(from: date)
}

func WeekFitDisplayString(_ value: String) -> String {
    guard value.contains(".") else { return value }

    let localized = WeekFitLocalizedString(value)
    return localized == value ? value : localized
}

func WeekFitCoachRuntimeLocalizedString(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return value }

    let isRussian = WeekFitCurrentLocale().identifier.hasPrefix("ru")
    if let pair = WeekFitCoachRuntimeCopy[trimmed] {
        return WeekFitCoachHumanizedText(isRussian ? WeekFitRussianCoachText(pair.ru) : pair.en)
    }

    let localized = WeekFitLocalizedString(value)
    let cleaned = isRussian ? WeekFitRussianCoachText(localized) : localized
    return WeekFitCoachHumanizedText(cleaned)
}

private let WeekFitCoachRuntimeCopy: [String: (en: String, ru: String)] = {
    let copies: [(en: String, ru: String, aliases: [String])] = [
        (
            "My Assessment",
            "Моя оценка",
            ["My Read"]
        ),
        (
            "My Recommendation",
            "Что сделать",
            []
        ),
        (
            "Be Careful With",
            "Чего избегать",
            []
        ),
        (
            "Why",
            "Почему это важно",
            []
        ),
        (
            "Keep the day flexible",
            "Оставьте день гибким",
            []
        ),
        (
            "Keep recovery easy",
            "Восстанавливайтесь спокойно",
            ["Восстанавливайтесь легко"]
        ),
        (
            "Eat normally at next meal",
            "Поешьте нормально в следующий прием пищи",
            ["Ешьте нормально в следующий прием пищи"]
        ),
        (
            "Small session logged",
            "Легкая активность записана",
            []
        ),
        (
            "The day is open enough to stay simple.",
            "День остается спокойным — не усложняйте его.",
            ["День достаточно свободный, чтобы оставить его простым."]
        ),
        (
            "Control today's ride",
            "Не гонитесь за цифрами",
            []
        ),
        (
            "Control today's run",
            "Не гонитесь за цифрами",
            []
        ),
        (
            "Control today's upper body session",
            "Не гонитесь за цифрами",
            []
        ),
        (
            "Control today's tennis session",
            "Не гонитесь за цифрами",
            []
        ),
        (
            "Control today's squash session",
            "Не гонитесь за цифрами",
            []
        ),
        (
            "Today's ride should stay below your normal ceiling.",
            "Сегодня лучше держать нагрузку ниже привычного максимума.",
            []
        ),
        (
            "Recovery does not support productive hard running today.",
            "Сегодня лучше держать нагрузку ниже привычного максимума.",
            []
        ),
        (
            "Today's session should prioritize quality over load.",
            "Сегодня лучше держать нагрузку ниже привычного максимума.",
            []
        ),
        (
            "Recovery does not support long high-intensity rallies today.",
            "Сегодня лучше держать нагрузку ниже привычного максимума.",
            []
        ),
        (
            "Squash places high demands on movement and recovery. Today's ceiling is lower than normal.",
            "Сегодня лучше держать нагрузку ниже привычного максимума.",
            []
        ),
        (
            "Protect the main effort",
            "Почему это важно",
            ["Защитите главное усилие"]
        ),
        (
            "Why this matters",
            "Почему это важно",
            []
        ),
        (
            "Fluids are lower than this point of the day usually needs. Rehydrating helps protect energy and readiness.",
            "Сегодня жидкости меньше, чем обычно требуется к этому времени дня. Восполнение воды поможет сохранить энергию и готовность.",
            []
        ),
        (
            "Fuel is behind for the current demand. Eating normally now supports steady energy without changing the whole plan.",
            "Энергии сейчас меньше, чем нужно для текущей нагрузки. Нормальный прием пищи поможет держать день ровным без смены плана.",
            []
        ),
        (
            "Sleep was not bad, but the body still needs recovery. Extra load now is likely to bring less benefit.",
            "Сон был неплохим, но организму всё ещё нужно восстановление. Дополнительная нагрузка сейчас принесёт меньше пользы.",
            []
        ),
        (
            "The current workout is already creating enough load. The useful move now is keeping quality until the finish.",
            "Текущая тренировка уже создаёт нужную нагрузку. Важно сохранить качество до её завершения.",
            []
        ),
        (
            "Control the session",
            "Контролируйте тренировку",
            []
        ),
        (
            "The workout is already live. Movement quality, technique, and reserve matter more than max effort now.",
            "Тренировка уже идет. Сейчас важнее качество движения, техника и запас, а не максимум.",
            []
        ),
        (
            "Start calmly, keep form clean, and finish with reserve.",
            "Начните спокойно, держите технику чистой и завершите с запасом.",
            []
        ),
        (
            "Do not increase load or pace if technique starts to break down.",
            "Не повышайте вес или темп, если техника начинает проседать.",
            []
        ),
        (
            "During a strength session, the best signal is stable movement and controlled effort. That gives you training value without adding unnecessary stress.",
            "Во время силовой тренировки лучший сигнал — стабильное движение и контроль усилия. Это помогает получить пользу без лишнего стресса.",
            []
        ),
        (
            "Keep this run easy",
            "Не форсируйте бег",
            []
        ),
        (
            "The run is already live. Keep effort easy, avoid adding intensity, and finish with reserve.",
            "Тренировка уже началась. Держите бег легким, не добавляйте интенсивность и завершите с запасом.",
            []
        ),
        (
            "The run is already live. Recovery is shaping the effort ceiling, so easy pacing and reserve matter most now.",
            "Бег уже идет. Восстановление влияет на темп, поэтому сейчас важнее легкий ход и запас.",
            []
        ),
        (
            "Do not turn this run into extra training load.",
            "Не добавляйте лишнюю нагрузку в этот бег.",
            []
        ),
        (
            "Load has already accumulated today, so recovery affects the effort ceiling but does not replace the current workout.",
            "Сегодня уже накопилась нагрузка, поэтому восстановление влияет на темп, но не заменяет текущую тренировку.",
            []
        ),
        (
            "Keep an easy pace",
            "Держите легкий темп",
            []
        ),
        (
            "Stay conversational",
            "Оставайтесь в разговорном усилии",
            []
        ),
        (
            "Shorten if needed",
            "Сократите при необходимости",
            []
        ),
        (
            "Better to finish fresh than chase volume",
            "Лучше закончить свежим, чем добрать объем",
            []
        ),
        (
            "Finish with reserve",
            "Завершите с запасом",
            []
        ),
        (
            "Make recovery easier to start",
            "Сделайте восстановление легче",
            []
        ),
        (
            "Protect tomorrow's ride",
            "Защитите завтрашнюю поездку",
            []
        ),
        (
            "Today's load is already banked, and tomorrow has a long 3.5-hour ride planned.",
            "Сегодня нагрузка уже накопилась, а завтра запланирована длинная велотренировка на 3.5 часа.",
            []
        ),
        (
            "Restore fluids, eat normally, and close the evening calmly so you can start tomorrow with reserve.",
            "Сейчас важнее восстановить жидкость, нормально поесть и завершить вечер спокойно, чтобы завтра стартовать с запасом.",
            []
        ),
        (
            "Do not add intensity tonight — it can take capacity away from tomorrow's ride.",
            "Не добавляйте интенсивность сегодня вечером — это может забрать ресурс у завтрашней поездки.",
            []
        ),
        (
            "A long ride needs freshness, fluids, and energy before it starts. The evening before matters more than doing extra work today.",
            "Длинная велотренировка требует свежести, воды и энергии заранее. Вечер до неё влияет на качество старта сильнее, чем еще одна нагрузка сегодня.",
            []
        ),
        (
            "Restore fluids",
            "Восстановите жидкость",
            []
        ),
        (
            "Sip gradually instead of catching up at once",
            "Пейте постепенно, без резкого догоняния",
            []
        ),
        (
            "Eat normally",
            "Закройте питание",
            []
        ),
        (
            "A real meal is better than random snacking",
            "Нормальная еда важнее случайного перекуса",
            []
        ),
        (
            "Prepare for sleep",
            "Готовьтесь ко сну",
            []
        ),
        (
            "Tomorrow's start depends on tonight",
            "Завтрашний старт зависит от сегодняшнего вечера",
            []
        ),
        (
            "The next workout will go better if you arrive settled instead of spending energy too early.",
            "Следующая тренировка пройдет лучше, если подойти к ней спокойно и не тратить силы заранее.",
            []
        ),
        (
            "Tomorrow carries real demand. Saving energy today protects the next training day.",
            "Завтра есть значимая нагрузка. Если сохранить силы сегодня, следующий тренировочный день пройдет лучше.",
            []
        ),
        (
            "The day does not need a correction right now. A steady rhythm is more useful than adding another task.",
            "Сейчас день не требует коррекции. Ровный ритм полезнее, чем ещё одна задача.",
            []
        ),
        (
            "The useful move now is making the evening quieter so sleep can do its job.",
            "Сейчас полезнее сделать вечер спокойнее, чтобы сон действительно сработал на восстановление.",
            []
        ),
        (
            "WORKOUT",
            "ТРЕНИРОВКА",
            []
        ),
        (
            "GET READY",
            "ПОДГОТОВКА",
            []
        ),
        (
            "RECOVERY",
            "ВОССТАНОВЛЕНИЕ",
            []
        ),
        (
            "HYDRATION",
            "ВОДА",
            []
        ),
        (
            "NUTRITION",
            "ПИТАНИЕ",
            []
        ),
        (
            "TOMORROW",
            "ЗАВТРА",
            []
        ),
        (
            "EVENING",
            "ВЕЧЕР",
            []
        ),
        (
            "ON TRACK",
            "ВСЕ ПО ПЛАНУ",
            []
        ),
        (
            "Control today's workout",
            "Не гонитесь за цифрами",
            []
        ),
        (
            "Keep the effort comfortable and finish with control.",
            "Держите комфортный темп и спокойно доведите тренировку до конца.",
            []
        ),
        (
            "The current workout is already creating enough load.",
            "Текущая тренировка уже создает достаточную нагрузку.",
            []
        ),
        (
            "Prepare for training",
            "Подготовьтесь к тренировке",
            []
        ),
        (
            "Keep the next step simple and arrive ready.",
            "Не усложняйте следующий шаг и подойдите к тренировке готовым.",
            []
        ),
        (
            "Recovery comes next",
            "Сейчас восстановление",
            []
        ),
        (
            "The training signal is already in. Recovery now matters more than adding load.",
            "Тренировочный стимул уже получен. Сейчас восстановление важнее дополнительной нагрузки.",
            []
        ),
        (
            "Eat normally, drink steadily, and keep the rest of the day easy.",
            "Поешьте нормально, пейте ровно и оставьте остаток дня спокойным.",
            []
        ),
        (
            "Today is better for recovery",
            "Сегодня лучше восстановиться",
            []
        ),
        (
            "Your body will get more from recovery than from extra load right now.",
            "Сейчас организму полезнее восстановление, чем дополнительная нагрузка.",
            []
        ),
        (
            "Keep movement light and let recovery lead the day.",
            "Держите движение легким и дайте восстановлению вести день.",
            []
        ),
        (
            "Bring fluids back up",
            "Восполните воду",
            []
        ),
        (
            "Fluids are lower than this point of the day usually needs.",
            "Жидкости сейчас меньше, чем обычно нужно к этому времени дня.",
            []
        ),
        (
            "Drink steadily now so energy and readiness stay stable.",
            "Пейте ровно сейчас, чтобы энергия и готовность оставались стабильными.",
            []
        ),
        (
            "Eat normally at the next meal",
            "Поешьте нормально в следующий прием пищи",
            []
        ),
        (
            "Food is behind the demand of the day.",
            "Питание сейчас отстает от нагрузки дня.",
            []
        ),
        (
            "A normal meal now supports steady energy without changing the whole plan.",
            "Нормальный прием пищи поддержит энергию без смены всего плана.",
            []
        ),
        (
            "Save energy for tomorrow",
            "Сохраните силы на завтра",
            []
        ),
        (
            "Tomorrow has enough demand that adding load today would make it harder.",
            "Завтра будет достаточно нагрузки, и лишняя нагрузка сегодня сделает ее тяжелее.",
            []
        ),
        (
            "Keep the rest of today easy so tomorrow's training stays useful.",
            "Оставьте остаток дня спокойным, чтобы завтрашняя тренировка была полезной.",
            []
        ),
        (
            "Make the evening quieter",
            "Сделайте вечер спокойнее",
            []
        ),
        (
            "The most useful move now is letting the day come down.",
            "Сейчас полезнее дать дню спокойно завершиться.",
            []
        ),
        (
            "Keep the evening calm so sleep can do its job.",
            "Сохраните спокойный вечер, чтобы сон сработал на восстановление.",
            []
        ),
        (
            "No need to change the plan",
            "Сегодня нет причин менять план",
            []
        ),
        (
            "The main signals do not ask for a correction right now.",
            "Главные сигналы сейчас не требуют коррекции.",
            []
        ),
        (
            "Stay with the plan and keep the basics steady.",
            "Оставьте план как есть и держите базовые привычки ровно.",
            []
        ),
        (
            "Support readiness",
            "Поддержите готовность",
            []
        ),
        (
            "Drinks are behind for this point of the day.",
            "Жидкости сейчас меньше, чем обычно нужно к этому времени дня.",
            []
        )
    ]

    var result: [String: (en: String, ru: String)] = [:]
    for copy in copies {
        let pair = (en: copy.en, ru: copy.ru)
        result[copy.en] = pair
        result[copy.ru] = pair
        for alias in copy.aliases {
            result[alias] = pair
        }
    }
    return result
}()

private func WeekFitRussianCoachText(_ text: String) -> String {
    var result = text
    let replacements: [(String, String)] = [
        ("Cycling", "Велотренировка"),
        ("cycling", "велотренировка"),
        ("Ride", "Велотренировка"),
        ("ride", "велотренировка"),
        ("Running", "Бег"),
        ("running", "бег"),
        ("Run", "Бег"),
        ("run", "бег"),
        ("Walk", "Прогулка"),
        ("walk", "прогулка"),
        ("Walking", "Прогулка"),
        ("walking", "прогулка"),
        ("Strength", "Силовая тренировка"),
        ("strength", "силовая тренировка"),
        ("Upper Body", "Верх тела"),
        ("upper body", "верх тела"),
        ("Core", "Кор"),
        ("core", "кор"),
        ("Breathing", "Дыхание"),
        ("breathing", "дыхание"),
        ("Sauna", "Сауна"),
        ("sauna", "сауна"),
        ("Stretching", "Растяжка"),
        ("stretching", "растяжка"),
        ("Cottage Cheese", "Творог"),
        ("cottage cheese", "творог"),
        ("Greek Yogurt", "Греческий йогурт"),
        ("greek yogurt", "греческий йогурт")
    ]

    for replacement in replacements {
        result = result.replacingOccurrences(of: replacement.0, with: replacement.1)
    }

    result = result
        .replacingOccurrences(of: "Защитите главное усилие", with: "Почему это важно")
        .replacingOccurrences(of: "главного усилия", with: "качества движения")
        .replacingOccurrences(of: "главное усилие", with: "качество движения")
        .replacingOccurrences(of: "Активная фаза", with: "Тренировка")
        .replacingOccurrences(of: "АКТИВНАЯ ФАЗА", with: "ТРЕНИРОВКА")
        .replacingOccurrences(of: "Поддержите восстановление", with: "Восстанавливайтесь спокойно")
        .replacingOccurrences(of: "Защитите адаптацию", with: "Дайте работе усвоиться")
        .replacingOccurrences(of: "сессия", with: "тренировка")
        .replacingOccurrences(of: "Сессия", with: "Тренировка")

    return result
}

private func WeekFitCoachHumanizedText(_ text: String) -> String {
    var result = text
    let replacements: [(String, String)] = [
        ("Recovery is the main constraint behind this recommendation.", "Recovery is the main reason for this recommendation."),
        ("Fuel is still light for this effort.", "Food still needs attention before this effort."),
        ("Fuel is still part of the preparation job.", "Food is still part of preparation."),
        ("Hydration is improving. Fuel is still the missing piece", "Hydration is improving. Food is still the missing piece"),
        ("Lower the later ceiling", "Make the later workout easier"),
        ("Lower tomorrow's ceiling", "Make tomorrow easier"),
        ("Lower the ceiling", "Make the plan easier"),
        ("Hold the planned ceiling", "Keep the planned effort"),
        ("Start below your ceiling", "Start easier than usual"),
        ("Let readiness set the ceiling", "Let readiness set the effort"),
        ("Let this session set the ceiling", "Let this workout set the effort"),
        ("Let the warm-up set the ceiling", "Let the warm-up set the effort"),
        ("Let body feedback set the ceiling", "Let body feedback set the effort"),
        ("set the ceiling", "set the effort"),
        ("sets the ceiling", "sets the effort"),
        ("normal ceiling", "usual effort"),
        ("today's ceiling", "today's effort"),
        ("the ceiling", "the effort"),
        ("ceiling", "effort"),
        ("limiting factors", "main things to support"),
        ("limiting factor", "main thing to support"),
        ("limiter", "main signal"),
        ("constraint", "main signal"),
        ("Constraint", "Main signal"),
        ("Снизьте завтрашний потолок", "Сделайте завтра легче"),
        ("Снизьте потолок", "Сделайте план легче"),
        ("снизьте потолок", "сделайте план легче"),
        ("задает потолок", "задает темп"),
        ("задать потолок", "задать темп"),
        ("потолок нагрузки", "темп нагрузки"),
        ("потолок", "темп"),
        ("лимитирующие факторы", "главные сигналы"),
        ("лимитирующий фактор", "главный сигнал")
    ]

    for replacement in replacements {
        result = result.replacingOccurrences(of: replacement.0, with: replacement.1)
    }

    return result
}

private func WeekFitDebugLogLocalizationResolution(key: String, locale: Locale, resolved: String) {
    #if DEBUG
    let logLocalizationResolution = false
    guard logLocalizationResolution else { return }

    guard key == "coach.humanDecision.time.calmEvening.title" ||
          key == "coach.humanDecision.time.calmEvening.recommendation" ||
          key == "coach.humanDecision.time.calmEvening.careful" ||
          key == "coach.card.myRead" ||
          key == "coach.card.recommendation" ||
          key == "coach.card.watchOutFor" ||
          key == "coach.primaryActions" ||
          key == "coach.doTheseNext" ||
          key == "coach.why" ||
          key == "coach.whatToDo" ||
          key == "common.tab.today" ||
          key == "common.tab.coach" ||
          key == "common.tab.meals" ||
          key == "common.tab.plan"
    else {
        return
    }

    let language = WeekFitLocalizationCache.current.languageCode
    print("[WeekFitLocalization] language=\(language) locale=\(locale.identifier) key=\(key) resolved=\"\(resolved)\"")
    #endif
}

private enum WeekFitLocalizationCache {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var cachedLanguageCode: String = AppLanguage.english.rawValue
    private nonisolated(unsafe) static var cachedLocale: Locale = Locale(identifier: AppLanguage.english.localeIdentifier)

    static var current: (languageCode: String, locale: Locale) {
        lock.lock()
        defer { lock.unlock() }
        return (cachedLanguageCode, cachedLocale)
    }

    static func refreshFromStorage() {
        let storedLanguageCode = UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.english.rawValue

        let resolvedLanguage = AppLanguage(rawValue: storedLanguageCode) ?? .english
        update(language: resolvedLanguage)
    }

    static func update(language: AppLanguage) {
        let locale = Locale(identifier: language.localeIdentifier)

        lock.lock()
        defer { lock.unlock() }
        cachedLanguageCode = language.rawValue
        cachedLocale = locale
    }
}
