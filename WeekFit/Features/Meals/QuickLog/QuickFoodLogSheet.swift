import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import WeekFitPlanner

// MARK: - Accent

enum QuickFoodAccent {
    static let orange = Color(red: 0.92, green: 0.55, blue: 0.32)
    /// Former drinks CTA gold — now used on Food + circles and kcal chips.
    static let actionOrange = Color(red: 0.78, green: 0.58, blue: 0.28)
    static let green = Color(red: 0.38, green: 0.70, blue: 0.48)
    /// Soft frequent washes — matched intensity, warm vs leaf.
    static let warmWash = Color(red: 0.90, green: 0.80, blue: 0.68)
    static let leafWash = Color(red: 0.74, green: 0.82, blue: 0.72)

    /// Food + circles — always the former drinks gold/orange.
    static func action(isLight _: Bool) -> Color {
        actionOrange
    }

    /// Card wash only — CTA circles and kcal chips use `actionOrange`, not this.
    static func frequentColor(at index: Int, isLight _: Bool) -> Color {
        index == 0 ? warmWash : leafWash
    }

    /// kcal + flame chip — same gold as Food + / «add one», no per-item rainbow.
    static func meta(for _: String, isLight _: Bool) -> Color {
        actionOrange
    }

    static func frequentMeta(at _: Int, isLight _: Bool) -> Color {
        actionOrange
    }

    static func cardTop(for accent: Color, isLight: Bool) -> Color {
        guard isLight else { return accent.opacity(0.14) }
        return accent.opacity(0.08)
    }

    static func cardBottom(for accent: Color, isLight: Bool) -> Color {
        guard isLight else { return accent.opacity(0.05) }
        return accent.opacity(0.03)
    }
}

// MARK: - Models

struct QuickFoodFrequentSnackRow: Identifiable, Equatable {
    let row: QuickItemDisplayRow
    let badgeKey: String
    let badgeSymbol: String
    var id: String { row.id }
    var item: QuickItem { row.item }
}

struct QuickFoodFrequentMealRow: Identifiable, Equatable {
    let row: QuickMealDisplayRow
    let badgeKey: String
    let badgeSymbol: String
    var id: String { row.id }
}

// MARK: - Sheet

struct QuickFoodLogSheet: View {
    @Binding var selectedTab: QuickNutritionLogTab

    let mealRows: [QuickMealDisplayRow]
    let frequentMealRows: [QuickFoodFrequentMealRow]
    let recentMealRows: [QuickMealDisplayRow]

    let snackRows: [QuickItemDisplayRow]
    let frequentSnackRows: [QuickFoodFrequentSnackRow]
    let recentSnackRows: [QuickItemDisplayRow]

    let session: QuickLogSessionStore
    let logDate: Date
    let existingMeals: [Meals]
    let onClose: () -> Void
    let onOpenMealsTab: () -> Void
    let onMealPlus: (Meals) -> Void
    let onMealIncrement: (Meals) -> Void
    let onMealDecrement: (Meals) -> Void
    let onSnackPlus: (QuickItem) -> Void
    let onSnackIncrement: (QuickItem) -> Void
    let onSnackDecrement: (QuickItem) -> Void
    let onSaveLibraryMeal: (Meals) -> Void
    let onPhotoFoodLogged: () -> Void

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: AppLanguageManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var revealContent = false
    @State private var sortAscending = true
    @State private var photoCoordinator: PhotoFoodLogCoordinator?
    @State private var showPhotoCamera = false
    /// After capture, swap camera → analyzing inside the same fullScreenCover (no black gap).
    @State private var showCameraAnalyzing = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showPhotoFlow = false
    @State private var isPhotoLogging = false
    @State private var photoLogError: String?
    @State private var photoPreviewSeed: UIImage?
    @State private var showPhotoPaidPaywall = false
    @State private var photoPaywallInstanceID = UUID().uuidString
    /// Keep the selected photo so analysis can resume after a paid unlock.
    @State private var pendingPaidPhotoResume = false
    /// Camera / library intended after paywall when no photo is pending yet.
    @State private var pendingPhotoEntryIntent: PhotoEntryIntent?
    @State private var showLibraryPicker = false

    private var foodAccent: Color { QuickFoodAccent.actionOrange }

    private enum PhotoEntryIntent: Equatable {
        case camera
        case library
    }

    private var inferredSlot: WeekFitMealSlot {
        MealLibraryPeriod.period(
            at: Calendar.current.component(.hour, from: Date())
        ).weekFitMealSlot
    }

    private var sortedMealRows: [QuickMealDisplayRow] {
        mealRows.sorted {
            let left = $0.meal.isFoodProduct ? $0.meal.title : $0.meal.localizedShortTitle
            let right = $1.meal.isFoodProduct ? $1.meal.title : $1.meal.localizedShortTitle
            return sortAscending
                ? left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                : left.localizedCaseInsensitiveCompare(right) == .orderedDescending
        }
    }

    private var sortedSnackRows: [QuickItemDisplayRow] {
        snackRows.sorted {
            sortAscending
                ? $0.item.localizedTitle.localizedCaseInsensitiveCompare($1.item.localizedTitle) == .orderedAscending
                : $0.item.localizedTitle.localizedCaseInsensitiveCompare($1.item.localizedTitle) == .orderedDescending
        }
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        VStack(spacing: 0) {
            QuickSheetPremiumHeader(
                title: WeekFitLocalizedString("today.quickActions.logFood"),
                subtitle: selectedTab == .meals
                    ? WeekFitLocalizedString("today.quickLog.subtitle.logYourFood")
                    : WeekFitLocalizedString("today.quickLog.subtitle.snacks"),
                onClose: onClose
            )

            QuickActionSheetSegmentedControl(
                segments: [
                    QuickActionSheetSegment(
                        id: QuickNutritionLogTab.meals.rawValue,
                        title: WeekFitLocalizedString("today.quickLog.section.meals"),
                        badgeCount: mealRows.count
                    ),
                    QuickActionSheetSegment(
                        id: QuickNutritionLogTab.snacks.rawValue,
                        title: WeekFitLocalizedString("today.quickLog.section.snacks"),
                        badgeCount: snackRows.count
                    )
                ],
                selection: Binding(
                    get: { selectedTab.rawValue },
                    set: { selectedTab = QuickNutritionLogTab(rawValue: $0) ?? .meals }
                ),
                selectedAccent: foodAccent
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 10)

            photoCaptureActions
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedTab {
                    case .meals:
                        mealsContent
                    case .snacks:
                        snacksContent
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
                .opacity(revealContent ? 1 : 0)
                .offset(y: revealContent ? 0 : 10)
            }
            .id(selectedTab)
        }
        .accessibilityIdentifier("sheet.quickFoodLog")
        .onAppear {
            PhotoFoodAnalytics.noteLogFoodOpened()
            revealContent = false
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.04)) {
                revealContent = true
            }
        }
        .onChange(of: selectedTab) { _, _ in
            revealContent = false
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                revealContent = true
            }
        }
        .photosPicker(
            isPresented: $showLibraryPicker,
            selection: $photoPickerItem,
            matching: .images
        )
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    beginPhotoAnalysis(image, method: .library)
                }
                photoPickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showPhotoCamera, onDismiss: {
            showCameraAnalyzing = false
        }) {
            ZStack {
                QuickActionSheetDesign.Color.sheetBackground(for: .food)
                    .ignoresSafeArea()

                if showCameraAnalyzing, let coordinator = photoCoordinator {
                    PhotoFoodFlowHost(
                        coordinator: coordinator,
                        previewImage: photoPreviewSeed ?? coordinator.lastImage,
                        isLogging: isPhotoLogging,
                        errorMessage: photoLogError,
                        onDismiss: { dismissPhotoFlow(fromCamera: true) },
                        onLog: { draft in commitPhotoLog(draft: draft) },
                        onRequestPaidSubscription: { presentPhotoPaidPaywall() }
                    )
                    .transition(.opacity)
                } else {
                    PhotoFoodCameraPicker(
                        onImage: { image in
                            beginPhotoAnalysis(image, method: .camera, presentAs: .cameraCover)
                        },
                        onCancel: {
                            showCameraAnalyzing = false
                            showPhotoCamera = false
                            photoPreviewSeed = nil
                        }
                    )
                    .ignoresSafeArea()
                }
            }
            .animation(.easeInOut(duration: 0.18), value: showCameraAnalyzing)
        }
        .sheet(isPresented: $showPhotoFlow) {
            if let coordinator = photoCoordinator {
                PhotoFoodFlowHost(
                    coordinator: coordinator,
                    previewImage: photoPreviewSeed ?? coordinator.lastImage,
                    isLogging: isPhotoLogging,
                    errorMessage: photoLogError,
                    onDismiss: { dismissPhotoFlow(fromCamera: false) },
                    onLog: { draft in commitPhotoLog(draft: draft) },
                    onRequestPaidSubscription: { presentPhotoPaidPaywall() }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .weekFitSheetChrome(
                    cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius,
                    background: QuickActionSheetDesign.Color.sheetBackground(for: .food)
                )
            } else {
                QuickActionSheetDesign.Color.sheetBackground(for: .food)
                    .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showPhotoPaidPaywall) {
            WeekFitPaywallView(
                source: .photoFood,
                currentTab: "meals",
                paywallInstanceID: photoPaywallInstanceID,
                allowsDismiss: true,
                requiresPaidSubscription: true,
                heroTitleKey: "today.photoLog.paywall.title",
                heroSubtitleKey: "today.photoLog.paywall.subtitle"
            )
            .environmentObject(subscriptionManager)
            .environment(\.weekFitPalette, palette)
        }
        .onChange(of: subscriptionManager.accessState) { _, _ in
            guard subscriptionManager.canUseCloudPhotoNutritionAnalysis else { return }
            showPhotoPaidPaywall = false
            if pendingPaidPhotoResume {
                pendingPaidPhotoResume = false
                pendingPhotoEntryIntent = nil
                resumePendingPhotoAnalysis()
            } else if pendingPhotoEntryIntent != nil {
                resumePendingPhotoEntryIntent()
            }
        }
        .onChange(of: showPhotoPaidPaywall) { _, isPresented in
            guard isPresented == false else { return }
            guard subscriptionManager.canUseCloudPhotoNutritionAnalysis else {
                // Dismissed without unlock — drop entry intent; keep photo resume only if flow still open.
                if photoCoordinator?.lastImage == nil {
                    pendingPhotoEntryIntent = nil
                    pendingPaidPhotoResume = false
                }
                return
            }
            if pendingPaidPhotoResume {
                pendingPaidPhotoResume = false
                pendingPhotoEntryIntent = nil
                resumePendingPhotoAnalysis()
            } else if pendingPhotoEntryIntent != nil {
                resumePendingPhotoEntryIntent()
            }
        }
    }

    // MARK: - Photo capture

    private var photoCaptureActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            aiNutritionAssistantCard
            barcodeScanRow
        }
    }

    private var aiNutritionAssistantCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(foodAccent)
                    .accessibilityHidden(true)

                Text(WeekFitLocalizedString("today.photoLog.aiAssistant.title"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(WeekFitLocalizedString("today.photoLog.aiAssistant.badge"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.35)
                    .textCase(.uppercase)
                    .foregroundStyle(foodAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(foodAccent.opacity(palette.isLight ? 0.14 : 0.22))
                    )
                    .accessibilityLabel(WeekFitLocalizedString("today.photoLog.aiAssistant.badge"))
            }

            Text(WeekFitLocalizedString("today.photoLog.aiAssistant.benefit"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    requestAIPhotoCapture(intent: .camera)
                } label: {
                    Label {
                        Text(WeekFitLocalizedString("today.photoLog.aiAssistant.takePhoto"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } icon: {
                        Image(systemName: "camera.fill")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 10)
                    .background(Capsule(style: .continuous).fill(foodAccent))
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("quickFood.ai.takePhoto")

                Button {
                    requestAIPhotoCapture(intent: .library)
                } label: {
                    Label {
                        Text(WeekFitLocalizedString("today.photoLog.aiAssistant.choosePhoto"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } icon: {
                        Image(systemName: "photo.on.rectangle")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(foodAccent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 10)
                    .background(
                        Capsule(style: .continuous)
                            .strokeBorder(foodAccent.opacity(0.45), lineWidth: 1)
                    )
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("quickFood.ai.choosePhoto")
            }

            Text(WeekFitLocalizedString(aiAccessCaptionKey))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .standard, accent: foodAccent, cornerRadius: 20)
    }

    private var aiAccessCaptionKey: String {
        if subscriptionManager.hasVerifiedPaidSubscriptionProof {
            return "today.photoLog.aiAssistant.included"
        }
        if subscriptionManager.hasPhotoAIFreeTrialRemaining {
            return "today.photoLog.aiAssistant.freeTrialAvailable"
        }
        return "today.photoLog.aiAssistant.requiresSubscription"
    }

    private var barcodeScanRow: some View {
        Button {
            openBarcodeCamera()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(WeekFitTheme.secondaryText.opacity(palette.isLight ? 0.08 : 0.14))
                    )

                Text(WeekFitLocalizedString("today.photoLog.capture.scanBarcode"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .weekFitPremiumCard(emphasis: .compact, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quickFood.scanBarcode")
    }

    private func requestAIPhotoCapture(intent: PhotoEntryIntent) {
        if subscriptionManager.canUseCloudPhotoNutritionAnalysis {
            openAIPhotoCapture(intent: intent)
            return
        }
        pendingPhotoEntryIntent = intent
        pendingPaidPhotoResume = false
        presentPhotoPaidPaywall()
    }

    private func openAIPhotoCapture(intent: PhotoEntryIntent) {
        switch intent {
        case .camera:
            openCamera()
        case .library:
            showLibraryPicker = true
        }
    }

    private func resumePendingPhotoEntryIntent() {
        guard let intent = pendingPhotoEntryIntent else { return }
        pendingPhotoEntryIntent = nil
        openAIPhotoCapture(intent: intent)
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // Simulator / no camera — open the library picker instead.
            showLibraryPicker = true
            return
        }
        showPhotoCamera = true
    }

    private func openBarcodeCamera() {
        openCamera()
    }

    private enum PhotoPresentation {
        case cameraCover
        case sheet
    }

    private func beginPhotoAnalysis(
        _ image: UIImage,
        method: PhotoFoodCaptureMethod,
        presentAs: PhotoPresentation? = nil
    ) {
        let coordinator = photoCoordinator ?? PhotoFoodLogCoordinator(
            mealSlot: inferredSlot,
            logDate: logDate,
            canUseCloudPhotoNutritionAnalysis: { [subscriptionManager] in
                subscriptionManager.canUseCloudPhotoNutritionAnalysis
            }
        )
        if coordinator.isAnalysisInFlight {
            return
        }
        coordinator.mealSlot = inferredSlot
        coordinator.logDate = logDate
        photoCoordinator = coordinator
        photoLogError = nil
        pendingPaidPhotoResume = false
        // Seed preview + start analysis before presentation so the first frame isn’t empty.
        photoPreviewSeed = image
        coordinator.analyzePhoto(image, method: method)

        let presentation = presentAs ?? (method == .camera ? .cameraCover : .sheet)
        switch presentation {
        case .cameraCover:
            showCameraAnalyzing = true
            showPhotoCamera = true
            showPhotoFlow = false
        case .sheet:
            showCameraAnalyzing = false
            showPhotoFlow = true
        }
    }

    private func presentPhotoPaidPaywall() {
        if photoCoordinator?.lastImage != nil {
            pendingPaidPhotoResume = true
            pendingPhotoEntryIntent = nil
        }
        photoPaywallInstanceID = UUID().uuidString
        showPhotoPaidPaywall = true
    }

    private func resumePendingPhotoAnalysis() {
        guard let coordinator = photoCoordinator, coordinator.lastImage != nil else { return }
        guard subscriptionManager.canUseCloudPhotoNutritionAnalysis else { return }
        if coordinator.isAnalysisInFlight { return }
        // Keep the existing presentation (camera cover or sheet) and re-run analysis.
        if showPhotoCamera {
            showCameraAnalyzing = true
        } else {
            showPhotoFlow = true
        }
        photoLogError = nil
        coordinator.retryAnalysis()
    }

    private func dismissPhotoFlow(fromCamera: Bool) {
        if let coordinator = photoCoordinator, coordinator.isAnalysisInFlight {
            coordinator.cancelAnalysis()
        }
        showPhotoFlow = false
        showCameraAnalyzing = false
        if fromCamera {
            showPhotoCamera = false
        }
        // Dropping the flow abandons resume unless paywall is still open with a pending photo.
        if showPhotoPaidPaywall == false {
            pendingPaidPhotoResume = false
            photoPreviewSeed = nil
            photoCoordinator?.reset()
        }
    }

    private func commitPhotoLog(draft: PhotoFoodLogDraft) {
        guard !isPhotoLogging else { return }
        isPhotoLogging = true
        photoLogError = nil
        do {
            _ = try PhotoFoodDiaryLogger.log(
                draft: draft,
                modelContext: modelContext,
                existingMeals: existingMeals,
                onSaveLibraryMeal: onSaveLibraryMeal
            )
            isPhotoLogging = false
            showPhotoFlow = false
            showCameraAnalyzing = false
            showPhotoCamera = false
            photoPreviewSeed = nil
            photoCoordinator?.reset()
            onPhotoFoodLogged()
        } catch PhotoFoodDiaryLogger.LogError.duplicateInFlight {
            isPhotoLogging = false
            photoLogError = WeekFitLocalizedString("today.photoLog.error.duplicate")
        } catch {
            isPhotoLogging = false
            photoLogError = WeekFitLocalizedString("today.photoLog.error.saveFailed")
        }
    }

    // MARK: Meals

    @ViewBuilder
    private var mealsContent: some View {
        if mealRows.isEmpty {
            emptyMeals
        } else {
            if !frequentMealRows.isEmpty {
                sectionHeader(WeekFitLocalizedString("today.quickLog.section.frequentlyUsed"))
                    .padding(.top, 2)

                QuickSheetHorizontalCarousel(verticalPadding: 6) {
                    ForEach(Array(frequentMealRows.enumerated()), id: \.element.id) { index, frequent in
                        let profile = QuickLogNutritionProfile.from(meal: frequent.row.meal)
                        let selection = session.selection(for: frequent.id)
                        QuickFoodFrequentCard(
                            title: frequent.row.meal.isFoodProduct
                                ? frequent.row.meal.title
                                : frequent.row.meal.localizedShortTitle,
                            subtitle: frequentMealSubtitle(frequent.row),
                            calories: frequent.row.meal.calories,
                            accent: QuickFoodAccent.frequentColor(at: index, isLight: palette.isLight),
                            metaAccent: QuickFoodAccent.frequentMeta(at: index, isLight: palette.isLight),
                            selection: selection,
                            displayQuantity: selection.effectivePortions(for: profile),
                            badgeKey: frequent.badgeKey,
                            badgeSymbol: frequent.badgeSymbol,
                            onPlusTap: { onMealPlus(frequent.row.meal) },
                            onIncrement: { onMealIncrement(frequent.row.meal) },
                            onDecrement: { onMealDecrement(frequent.row.meal) }
                        ) {
                            QuickFoodCircularMealThumb(
                                row: frequent.row,
                                size: QuickActionSheetDesign.RecommendedCard.mediaHeight
                            )
                        }
                        .zIndex(selection.isExpanded ? 1 : 0)
                    }
                }
                .padding(.horizontal, -18)
            }

            allHeader(
                title: WeekFitLocalizedString("today.quickLog.section.allMeals")
            )

            LazyVStack(spacing: 8) {
                ForEach(sortedMealRows) { row in
                    mealLibraryRow(row)
                }
            }
        }
    }

    // MARK: Snacks

    @ViewBuilder
    private var snacksContent: some View {
        if snackRows.isEmpty {
            emptySnacks
        } else {
            if !frequentSnackRows.isEmpty {
                sectionHeader(WeekFitLocalizedString("today.quickLog.section.frequentlyUsed"))
                    .padding(.top, 2)

                QuickSheetHorizontalCarousel(verticalPadding: 6) {
                    ForEach(Array(frequentSnackRows.enumerated()), id: \.element.id) { index, frequent in
                        let profile = QuickLogNutritionProfile.from(item: frequent.item)
                        let selection = session.selection(for: frequent.id)
                        QuickFoodFrequentCard(
                            title: frequent.item.localizedTitle,
                            subtitle: frequent.item.localizedServingSizeDescription,
                            calories: frequent.item.calories,
                            accent: QuickFoodAccent.frequentColor(at: index, isLight: palette.isLight),
                            metaAccent: QuickFoodAccent.frequentMeta(at: index, isLight: palette.isLight),
                            selection: selection,
                            displayQuantity: selection.effectivePortions(for: profile),
                            badgeKey: frequent.badgeKey,
                            badgeSymbol: frequent.badgeSymbol,
                            onPlusTap: { onSnackPlus(frequent.item) },
                            onIncrement: { onSnackIncrement(frequent.item) },
                            onDecrement: { onSnackDecrement(frequent.item) }
                        ) {
                            QuickFoodCircularSnackThumb(
                                row: frequent.row,
                                size: QuickActionSheetDesign.RecommendedCard.mediaHeight
                            )
                        }
                        .zIndex(selection.isExpanded ? 1 : 0)
                    }
                }
                .padding(.horizontal, -18)
            }

            allHeader(
                title: WeekFitLocalizedString("today.quickLog.section.allSnacks")
            )

            LazyVStack(spacing: 8) {
                ForEach(sortedSnackRows) { row in
                    snackLibraryRow(row)
                }
            }
        }
    }

    private func frequentMealSubtitle(_ row: QuickMealDisplayRow) -> String {
        let raw = row.meal.isFoodProduct
            ? row.meal.servingDescription
            : row.meal.localizedDisplaySubtitle
        return raw.replacingOccurrences(
            of: #"\s*\(\d+\s*g\)"#,
            with: "",
            options: .regularExpression
        )
    }

    // MARK: Rows

    private func mealLibraryRow(_ row: QuickMealDisplayRow) -> some View {
        let profile = QuickLogNutritionProfile.from(meal: row.meal)
        let selection = session.selection(for: row.id)
        let meta = QuickFoodAccent.meta(for: row.id, isLight: palette.isLight)
        return HStack(spacing: 12) {
            QuickFoodCircularMealThumb(row: row, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.meal.isFoodProduct ? row.meal.title : row.meal.localizedShortTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)

                Text(row.meal.isFoodProduct ? row.meal.servingDescription : row.meal.localizedDisplaySubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                QuickFoodCaloriePill(calories: row.meal.calories, accent: meta, style: .list)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            QuickAddQuantityControl(
                quantity: selection.effectivePortions(for: profile),
                isExpanded: selection.isExpanded,
                isSelected: selection.isSelected,
                accentColor: QuickFoodAccent.actionOrange,
                chrome: .softOutline,
                onPlusTap: { onMealPlus(row.meal) },
                onIncrement: { onMealIncrement(row.meal) },
                onDecrement: { onMealDecrement(row.meal) }
            )
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 72)
        .quickSheetFloatingCard(
            cornerRadius: 18,
            fill: palette.isLight ? Color.white : WeekFitTheme.cardBackground,
            stroke: palette.isLight ? Color.black.opacity(0.07) : WeekFitTheme.whiteOpacity(0.08),
            isLight: palette.isLight
        )
    }

    private func snackLibraryRow(_ row: QuickItemDisplayRow) -> some View {
        let profile = QuickLogNutritionProfile.from(item: row.item)
        let selection = session.selection(for: row.id)
        let meta = QuickFoodAccent.meta(for: row.id, isLight: palette.isLight)
        return HStack(spacing: 12) {
            QuickFoodCircularSnackThumb(row: row, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.item.localizedTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)

                Text(row.item.localizedServingSizeDescription)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                QuickFoodCaloriePill(calories: row.item.calories, accent: meta, style: .list)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            QuickAddQuantityControl(
                quantity: selection.effectivePortions(for: profile),
                isExpanded: selection.isExpanded,
                isSelected: selection.isSelected,
                accentColor: QuickFoodAccent.actionOrange,
                chrome: .softOutline,
                onPlusTap: { onSnackPlus(row.item) },
                onIncrement: { onSnackIncrement(row.item) },
                onDecrement: { onSnackDecrement(row.item) }
            )
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 72)
        .quickSheetFloatingCard(
            cornerRadius: 18,
            fill: palette.isLight ? Color.white : WeekFitTheme.cardBackground,
            stroke: palette.isLight ? Color.black.opacity(0.07) : WeekFitTheme.whiteOpacity(0.08),
            isLight: palette.isLight
        )
    }

    // MARK: Chrome

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
    }

    private func allHeader(title: String) -> some View {
        HStack {
            sectionHeader(title)
            Spacer(minLength: 8)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                sortAscending.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(
                        WeekFitLocalizedString(
                            sortAscending ? "today.quickLog.sort.az" : "today.quickLog.sort.za"
                        )
                    )
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.72))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    private var emptyMeals: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(foodAccent.opacity(0.85))
            Text(WeekFitLocalizedString("today.photoLog.empty.title"))
                .font(QuickActionSheetDesign.Typography.emptyTitle)
                .foregroundStyle(WeekFitTheme.primaryText)
            Text(WeekFitLocalizedString("today.photoLog.empty.message"))
                .font(QuickActionSheetDesign.Typography.emptyMessage)
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button {
                    requestAIPhotoCapture(intent: .camera)
                } label: {
                    Text(WeekFitLocalizedString("today.photoLog.aiAssistant.takePhoto"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(foodAccent))
                }
                .buttonStyle(.plain)

                Button {
                    requestAIPhotoCapture(intent: .library)
                } label: {
                    Text(WeekFitLocalizedString("today.photoLog.aiAssistant.choosePhoto"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(foodAccent)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Capsule().strokeBorder(foodAccent.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)

            Button(action: onOpenMealsTab) {
                Text(WeekFitLocalizedString("today.quickLog.empty.savedFood.action"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WeekFitTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var emptySnacks: some View {
        VStack(spacing: 10) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(QuickFoodAccent.green.opacity(0.7))
            Text(WeekFitLocalizedString("today.quickLog.empty.quickItems.title"))
                .font(QuickActionSheetDesign.Typography.emptyTitle)
            Text(WeekFitLocalizedString("today.quickLog.empty.quickItems.message"))
                .font(QuickActionSheetDesign.Typography.emptyMessage)
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Frequent card (Drinks Recommended layout)

private struct QuickFoodFrequentCard<Thumb: View>: View {
    let title: String
    let subtitle: String
    let calories: Int
    let accent: Color
    let metaAccent: Color
    let selection: QuickLogSelection
    let displayQuantity: Double
    var badgeKey: String? = nil
    var badgeSymbol: String? = nil
    let onPlusTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    @ViewBuilder let thumb: () -> Thumb

    @Environment(\.weekFitPalette) private var palette

    private var cardWidth: CGFloat { QuickActionSheetDesign.RecommendedCard.width }
    private var cardHeight: CGFloat { QuickActionSheetDesign.RecommendedCard.minHeight }
    private var cardRadius: CGFloat { QuickActionSheetDesign.RecommendedCard.cornerRadius }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                if let badgeKey {
                    QuickSheetPhotoSafeBadge(
                        title: WeekFitLocalizedString(badgeKey),
                        systemImage: badgeSymbol,
                        accent: accent
                    )
                }
            }
            .frame(
                minHeight: QuickActionSheetDesign.RecommendedCard.badgeRowMinHeight,
                alignment: .topTrailing
            )

            thumb()
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: QuickActionSheetDesign.RecommendedCard.mediaHeight)
                .padding(.top, QuickActionSheetDesign.RecommendedCard.badgeToMedia)

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.top, QuickActionSheetDesign.RecommendedCard.mediaToTitle)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.68))
                    .lineLimit(1)
                    .padding(.top, 2)
            }

            Spacer(minLength: QuickActionSheetDesign.Row.contentSpacing)

            QuickRecommendedMetaActionRow {
                QuickFoodCaloriePill(calories: calories, accent: metaAccent, style: .frequent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .opacity(selection.isExpanded ? 0 : 1)
                    .accessibilityHidden(selection.isExpanded)
            } action: {
                QuickAddQuantityControl(
                    quantity: displayQuantity,
                    isExpanded: selection.isExpanded,
                    isSelected: selection.isSelected,
                    accentColor: QuickFoodAccent.actionOrange,
                    chrome: .solidFilled,
                    density: .compact,
                    collapsedVisualSize: QuickActionSheetDesign.RecommendedCard.actionVisualSize,
                    onPlusTap: onPlusTap,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement
                )
                .frame(
                    minWidth: QuickActionSheetDesign.RecommendedCard.actionHitSize,
                    minHeight: QuickActionSheetDesign.RecommendedCard.actionHitSize
                )
            }
        }
        .padding(QuickActionSheetDesign.RecommendedCard.padding)
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .background {
            QuickSheetChrome.elevatedTileBackground(
                cornerRadius: cardRadius,
                accent: accent,
                isLight: palette.isLight
            )
        }
    }
}

// MARK: - Calorie pill

private struct QuickFoodCaloriePill: View {
    enum Style { case frequent, list }

    let calories: Int
    let accent: Color
    let style: Style

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        style == .frequent
                            ? WeekFitTheme.secondaryText.opacity(0.55)
                            : accent
                    )

                Text(QuickLogLocalizedNutrition.calories(calories))
                    .font(.system(size: style == .frequent ? 12 : 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.78))
            }
        .padding(.horizontal, style == .list ? 8 : 0)
        .padding(.vertical, style == .list ? 4 : 0)
        .background {
            if style == .list {
                Capsule()
                    .fill(QuickSheetChrome.metaBadgeFill(isLight: palette.isLight))
            }
        }
    }
}

// MARK: - Circular thumbs

private struct QuickFoodCircularMealThumb: View {
    let row: QuickMealDisplayRow
    let size: CGFloat
    /// Keep the circular slot; enlarge plate + food art for readability (~+30% vs prior 1.22).
    private static let plateContentScale: CGFloat = 1.22 * 1.30
    private static let productImageScale: CGFloat = 1.30

    var body: some View {
        Group {
            if row.isFoodProduct {
                AsyncMealPhotoView(filename: row.localPhotoFilename) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(Self.productImageScale)
                    } else {
                        placeholder
                    }
                }
            } else if !row.sortedBuilderImageItems.isEmpty {
                BuiltMealPlateView(
                    items: row.sortedBuilderImageItems,
                    plateSize: size,
                    itemScale: 0.62,
                    offsetScale: 0.22,
                    plateOpacity: 0.42,
                    shadowOpacity: 0,
                    layoutMode: .compactPreview
                )
                // Crop plate rim; enlarge plate + food together (~+30%).
                .scaleEffect(Self.plateContentScale)
            } else if row.usesAssetImage {
                Image(row.meal.imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .scaleEffect(Self.productImageScale)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(WeekFitTheme.whiteOpacity(0.06))
            Image(systemName: "fork.knife")
                .font(.system(size: size * 0.28, weight: .semibold))
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.55))
        }
    }
}

private struct QuickFoodCircularSnackThumb: View {
    let row: QuickItemDisplayRow
    let size: CGFloat
    /// Product art only — keeps the circular slot size while reading ~30% larger.
    private static let productImageScale: CGFloat = 1.30

    var body: some View {
        Group {
            if row.usesAssetImage {
                Image(row.item.imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(size * 0.10)
                    .scaleEffect(Self.productImageScale)
            } else {
                ZStack {
                    Circle().fill(WeekFitTheme.whiteOpacity(0.06))
                    Image(systemName: row.item.icon)
                        .font(.system(size: size * 0.28, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.55))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
