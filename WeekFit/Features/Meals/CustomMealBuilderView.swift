import SwiftUI
import UIKit
import OSLog

struct CustomMealBuilderView: View {
    private enum FocusedField: String {
        case name
        case servingGrams
        case calories
        case protein
        case carbs
        case fats
        case fiber
    }

    private struct Labels {
        let formTitle: String
        let formSubtitle: String
        let kcal: String
        let cancel: String
        let removePhoto: String
        let foodName: String
        let foodNamePlaceholder: String
        let calories: String
        let protein: String
        let carbs: String
        let fats: String
        let fiber: String
        let grams: String
        let requiredFieldsValidation: String
        let photoSaveFailedValidation: String
        let gramServingFormat: String
        let customMealBenefit: String
        let manualEntryBenefit: String
        let servingIngredient: String
        let gramValueFormat: String
    }

    let editingMeal: Meals?
    let existingMeals: [Meals]
    let onSave: (Meals) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: AppLanguageManager
    @FocusState private var focusedField: FocusedField?

    @State private var selectedImage: UIImage?
    @State private var selectedThumbnailImage: UIImage?
    @State private var pendingOriginalFilename: String?
    @State private var existingPreviewImage: UIImage?
    @State private var didRemovePhoto = false
    @State private var showCamera = false

    @State private var name: String
    @State private var servingGrams: String
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fats: String
    @State private var fiber: String
    @State private var validationMessage: String?
    @State private var didRequestExistingPreviewImage = false
    @State private var isAnalyzingPhoto = false
    /// Error / warning only — success feedback lives in the compact result card.
    @State private var barcodeLookupMessage: String?
    @State private var barcodeLookupTone: BarcodeLookupBannerTone = .neutral
    @State private var scannedBarcode: String?
    @State private var scannedNutritionDataSource: NutritionDataSource?
    /// Set only after a successful barcode import (including partial). Not derived from name alone.
    @State private var barcodeImportResult: BarcodeProductImportResult?
    /// Density used to rescale macros when serving grams change (photo/barcode baseline).
    @State private var nutritionDensity: CustomMealNutritionDensity?
    @State private var isScalingNutritionFromGrams = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum BarcodeLookupBannerTone {
        case neutral
        case warning
        case error
    }

    private struct BarcodeProductImportResult: Equatable {
        var productName: String
        var provider: NutritionDataSource?
        var basis: BarcodeNutritionBasis
        var isPartial: Bool
    }

    private let background = WeekFitTheme.appBackground
    private let cardBackground = WeekFitTheme.cardBackground
    private let elevatedCard = WeekFitTheme.elevatedCard
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    /// Create Food stays in the Meals visual family (meal green), not Coach purple.
    private let accent = WeekFitTheme.meal

    init(
        editingMeal: Meals? = nil,
        existingMeals: [Meals],
        onSave: @escaping (Meals) -> Void
    ) {
        self.editingMeal = editingMeal
        self.existingMeals = existingMeals
        self.onSave = onSave
        _name = State(initialValue: editingMeal?.title ?? "")
        _servingGrams = State(initialValue: "\(editingMeal?.servingGrams ?? 100)")
        _calories = State(initialValue: Self.fieldText(editingMeal?.calories))
        _protein = State(initialValue: Self.fieldText(editingMeal?.protein))
        _carbs = State(initialValue: Self.fieldText(editingMeal?.carbs))
        _fats = State(initialValue: Self.fieldText(editingMeal?.fats))
        _fiber = State(initialValue: Self.fieldText(editingMeal?.fiber))
        _existingPreviewImage = State(initialValue: nil)
        if let editingMeal {
            _nutritionDensity = State(
                initialValue: CustomMealNutritionDensity.from(
                    grams: max(editingMeal.servingGrams ?? 100, 1),
                    calories: editingMeal.calories,
                    protein: editingMeal.protein,
                    carbs: editingMeal.carbs,
                    fats: editingMeal.fats,
                    fiber: editingMeal.fiber
                )
            )
            if editingMeal.barcode != nil {
                _barcodeImportResult = State(
                    initialValue: BarcodeProductImportResult(
                        productName: editingMeal.title,
                        provider: editingMeal.nutritionDataSource,
                        basis: .per100g,
                        isPartial: false
                    )
                )
                _scannedBarcode = State(initialValue: editingMeal.barcode)
                _scannedNutritionDataSource = State(initialValue: editingMeal.nutritionDataSource)
            } else {
                _barcodeImportResult = State(initialValue: nil)
            }
        } else {
            _nutritionDensity = State(initialValue: nil)
            _barcodeImportResult = State(initialValue: nil)
        }
    }

    private var labels: Labels {
        Self.makeLabels(isEditing: editingMeal != nil)
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        formRoot
            .onAppear {
                requestExistingPreviewImageIfNeeded()
                applyUITestBarcodeFixtureIfNeeded()
            }
            .onDisappear {
                releaseCapturedPhotoMemory(deletePendingOriginal: true)
            }
            .onChange(of: focusedField) { oldValue, newValue in
                Self.debugLog("focus.change \(oldValue?.rawValue ?? "nil") -> \(newValue?.rawValue ?? "nil")")
            }
            .onChange(of: name) { _, newValue in
                Self.debugLog("onChange.name length=\(newValue.count)")
            }
            .onChange(of: servingGrams) { _, newValue in
                Self.debugLog("onChange.servingGrams length=\(newValue.count)")
                rescaleNutritionForServingGramsChange(newValue)
            }
            .onChange(of: calories) { _, _ in
                captureDensityAfterManualNutrientEdit(focused: .calories)
            }
            .onChange(of: protein) { _, _ in
                captureDensityAfterManualNutrientEdit(focused: .protein)
            }
            .onChange(of: carbs) { _, _ in
                captureDensityAfterManualNutrientEdit(focused: .carbs)
            }
            .onChange(of: fats) { _, _ in
                captureDensityAfterManualNutrientEdit(focused: .fats)
            }
            .onChange(of: fiber) { _, _ in
                captureDensityAfterManualNutrientEdit(focused: .fiber)
            }
            .fullScreenCover(isPresented: $showCamera) {
                // fullScreenCover works from inside a parent sheet; nested .sheet does not on iOS 17.
                CustomMealCameraCaptureView { image in
                    Self.debugLog("camera.imageCaptured")
                    processCapturedPhoto(image)
                }
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
            }
    }

    private var formRoot: some View {
        ZStack {
            background.ignoresSafeArea()
            ambientBackground

            VStack(spacing: 12) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                formScrollContent
            }
        }
        .accessibilityIdentifier("meals.foodForm")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(WeekFitLocalizedString("common.action.done")) {
                    focusedField = nil
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
        }
    }

    private var formScrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    barcodeImportSection {
                        focusFoodName(using: proxy)
                    }
                    barcodeLookupBanner
                    foodNameSection
                        .id("foodName")
                    nutritionSection

                    if let validationMessage {
                        validationMessageView(validationMessage)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
                .animation(barcodeCardAnimation, value: showsBarcodeResultCard)
                .animation(barcodeCardAnimation, value: isAnalyzingPhoto)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: validationMessage) { _, newValue in
                Self.debugLog("onChange.validationMessage isNil=\(newValue == nil)")
                guard newValue != nil else { return }

                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    proxy.scrollTo("validation", anchor: .center)
                }
            }
        }
    }

    private var showsBarcodeResultCard: Bool {
        barcodeImportResult != nil && !isAnalyzingPhoto
    }

    private var barcodeCardAnimation: Animation? {
        reduceMotion ? .easeInOut(duration: 0.01) : .easeInOut(duration: 0.25)
    }

    private func barcodeImportSection(onEnterManually: @escaping () -> Void) -> some View {
        Group {
            if showsBarcodeResultCard, let result = barcodeImportResult {
                barcodeResultCard(result)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                                removal: .opacity
                            )
                    )
            } else {
                barcodeActionCard(onEnterManually: onEnterManually)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .opacity,
                                removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                            )
                    )
            }
        }
    }

    private func focusFoodName(using proxy: ScrollViewProxy) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            proxy.scrollTo("foodName", anchor: .center)
        }
        focusedField = .name
    }

    private func validationMessageView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.red.opacity(0.84))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .id("validation")
    }

    private var ambientBackground: some View {
        WeekFitTheme.mealsAmbient
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var header: some View {
        WeekFitDetailScreenHeader(
            title: labels.formTitle,
            subtitle: labels.formSubtitle,
            titleSize: 22,
            titleTracking: -0.35,
            titleColor: textPrimary,
            subtitleColor: textSecondary.opacity(0.72),
            titleDesign: .rounded,
            spacing: 12
        ) {
            CreateFoodCircleHeaderButton(
                systemName: "chevron.left",
                accessibilityLabelText: WeekFitLocalizedString("common.action.back"),
                isEnabled: true,
                filledAccent: nil
            ) {
                dismiss()
            }
        } trailing: {
            CreateFoodCircleHeaderButton(
                systemName: "checkmark",
                accessibilityLabelText: WeekFitLocalizedString("common.action.save"),
                isEnabled: isSaveEnabled,
                filledAccent: accent
            ) {
                save()
            }
        }
    }

    private var barcodeLookupBanner: some View {
        Group {
            // Loading is shown inside the before-scan CTA.
            // Success/partial barcode feedback lives in the result card.
            // Neutral = product photo kept for manual nutrition entry.
            if !isAnalyzingPhoto,
               barcodeImportResult == nil,
               let barcodeLookupMessage {
                lookupBanner(text: barcodeLookupMessage, tone: barcodeLookupTone)
            }
        }
    }

    private func lookupBanner(text: String, tone: BarcodeLookupBannerTone) -> some View {
        let foreground: Color
        let backgroundTone: Color

        switch tone {
        case .neutral:
            foreground = textSecondary.opacity(0.82)
            backgroundTone = WeekFitTheme.whiteOpacity(0.040)
        case .warning:
            foreground = WeekFitTheme.orange.opacity(0.92)
            backgroundTone = WeekFitTheme.orange.opacity(0.10)
        case .error:
            foreground = Color.red.opacity(0.84)
            backgroundTone = Color.red.opacity(0.10)
        }

        return Text(text)
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundTone)
            }
            .accessibilityIdentifier("meals.foodForm.lookupBanner")
    }

    private func beginBarcodeRescan() {
        openCamera()
    }

    private func barcodeResultCard(_ result: BarcodeProductImportResult) -> some View {
        HStack(alignment: .center, spacing: 14) {
            barcodeResultImage

            VStack(alignment: .leading, spacing: 5) {
                Text(
                    result.isPartial
                        ? WeekFitLocalizedString("meals.foodForm.barcodeResult.partialStatus")
                        : WeekFitLocalizedString("meals.foodForm.barcodeResult.found")
                )
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    result.isPartial
                        ? WeekFitTheme.orange.opacity(0.92)
                        : WeekFitTheme.green.opacity(0.92)
                )

                Text(result.productName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(providerDisplayName(result.provider))
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundStyle(textSecondary.opacity(0.78))

                        if !result.isPartial {
                            Text(WeekFitLocalizedString("meals.foodForm.barcodeResult.reviewHint"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(textSecondary.opacity(0.62))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: beginBarcodeRescan) {
                        HStack(spacing: 3) {
                            Text(WeekFitLocalizedString("meals.foodForm.barcodeResult.change"))
                                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(accent.opacity(0.95))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CreateFoodPressableButtonStyle())
                    .accessibilityIdentifier("meals.foodForm.barcodeResult.change")
                    .accessibilityLabel(WeekFitLocalizedString("meals.foodForm.barcodeResult.scanAnother"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(barcodeResultAccessibilityLabel(result))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .weekFitPremiumCard(emphasis: .standard, cornerRadius: 24)
        .accessibilityIdentifier("meals.foodForm.barcodeResult")
    }

    private var barcodeResultImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.22),
                            accent.opacity(0.10),
                            WeekFitTheme.whiteOpacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 78, height: 78)
                    .clipped()
            } else {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
        }
        .frame(width: 78, height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.08), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func barcodeResultAccessibilityLabel(_ result: BarcodeProductImportResult) -> String {
        let status = result.isPartial
            ? WeekFitLocalizedString("meals.foodForm.barcodeResult.partialStatus")
            : WeekFitLocalizedString("meals.foodForm.barcodeResult.found")
        return "\(status). \(result.productName). \(providerDisplayName(result.provider))"
    }

    private func providerDisplayName(_ provider: NutritionDataSource?) -> String {
        switch provider {
        case .openFoodFacts, .openFoodFactsCache:
            return WeekFitLocalizedString("meals.barcode.source.openFoodFacts")
        case .usda:
            return WeekFitLocalizedString("meals.barcode.source.usda")
        case .nutritionLabelOCR:
            return WeekFitLocalizedString("meals.barcode.source.nutritionLabel")
        case .manual, .none:
            return WeekFitLocalizedString("meals.barcode.source.unknown")
        }
    }

    private func barcodeActionCard(onEnterManually: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                barcodeHeroIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(WeekFitLocalizedString("meals.foodForm.scanBarcode.title"))
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.2)

                    Text(WeekFitLocalizedString("meals.foodForm.scanBarcode.subtitle"))
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            Button {
                beginBarcodeRescan()
            } label: {
                HStack(spacing: 8) {
                    if isAnalyzingPhoto {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(
                        isAnalyzingPhoto
                            ? WeekFitLocalizedString("meals.barcode.analyzing")
                            : WeekFitLocalizedString("meals.foodForm.scanBarcode.button")
                    )
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.white.opacity(0.96))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(isAnalyzingPhoto ? 0.72 : 0.92))
                }
            }
            .buttonStyle(CreateFoodPressableButtonStyle())
            .disabled(isAnalyzingPhoto)
            .accessibilityIdentifier("meals.foodForm.scanBarcode")
            .accessibilityLabel(
                isAnalyzingPhoto
                    ? WeekFitLocalizedString("meals.barcode.analyzing")
                    : WeekFitLocalizedString("meals.foodForm.scanBarcode.button")
            )

            CreateFoodOrDivider()

            Button(action: onEnterManually) {
                Text(WeekFitLocalizedString("meals.foodForm.enterManually"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 40)
            }
            .buttonStyle(CreateFoodPressableButtonStyle())
            .disabled(isAnalyzingPhoto)
            .accessibilityIdentifier("meals.foodForm.enterManually")
        }
        .padding(16)
        .weekFitPremiumCard(emphasis: .standard, accent: accent, cornerRadius: 22)
        .accessibilityElement(children: .contain)
    }

    private var barcodeHeroIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.28),
                            accent.opacity(0.12),
                            WeekFitTheme.whiteOpacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }

            if isAnalyzingPhoto {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.42))
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var foodNameSection: some View {
        let hasImport = barcodeImportResult != nil
        let showHint = !hasImport && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(alignment: .leading, spacing: hasImport ? 8 : 10) {
            Text(labels.foodName)
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.90))

            TextField(labels.foodNamePlaceholder, text: $name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .submitLabel(.done)
                .tint(accent)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 46)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(WeekFitTheme.whiteOpacity(0.045))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(WeekFitTheme.whiteOpacity(0.06), lineWidth: 1)
                        }
                }
                .focused($focusedField, equals: .name)
                .accessibilityIdentifier("meals.foodForm.nameField")

            if showHint {
                Text(WeekFitLocalizedString("meals.foodForm.name.hint"))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.70))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, hasImport ? 14 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .standard, accent: accent, cornerRadius: 22)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var nutritionSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(WeekFitLocalizedString("meals.nutrition"))
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.15)

                Image(systemName: "info.circle")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.55))
                    .accessibilityLabel(WeekFitLocalizedString("meals.nutrition"))
                    .accessibilityHint(WeekFitLocalizedString("meals.nutrition.basis.infoHint"))

                Spacer(minLength: 8)

                servingSelector
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            compactDivider
                .padding(.horizontal, 16)

            nutritionDisplayRow(
                title: labels.calories,
                value: $calories,
                unit: labels.kcal,
                icon: "flame.fill",
                color: WeekFitTheme.orange,
                field: .calories,
                showsDivider: true
            )

            nutritionDisplayRow(
                title: labels.protein,
                value: $protein,
                unit: labels.grams,
                icon: "figure.strengthtraining.traditional",
                color: WeekFitTheme.meal,
                field: .protein,
                showsDivider: true
            )

            nutritionDisplayRow(
                title: labels.carbs,
                value: $carbs,
                unit: labels.grams,
                icon: "leaf.fill",
                color: Color(red: 0.95, green: 0.76, blue: 0.28),
                field: .carbs,
                showsDivider: true
            )

            nutritionDisplayRow(
                title: labels.fats,
                value: $fats,
                unit: labels.grams,
                icon: "drop.fill",
                color: WeekFitTheme.purple,
                field: .fats,
                showsDivider: true
            )

            nutritionDisplayRow(
                title: labels.fiber,
                value: $fiber,
                unit: labels.grams,
                icon: "circle.circle.fill",
                color: WeekFitTheme.green,
                field: .fiber,
                showsDivider: false
            )
        }
        .weekFitPremiumCard(emphasis: .standard, accent: accent, cornerRadius: 22)
    }

    private var nutritionBasisDisplayLabel: String {
        String(
            format: WeekFitLocalizedString("meals.nutrition.basis.perGramsFormat"),
            displayValue(servingGrams)
        )
    }

    private var servingSelector: some View {
        HStack(spacing: 4) {
            Text(WeekFitLocalizedString("meals.nutrition.basis.perPrefix"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.88))
                .accessibilityHidden(true)

            TextField("100", text: $servingGrams)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.92))
                .keyboardType(.numberPad)
                .submitLabel(.done)
                .tint(accent)
                .multilineTextAlignment(.trailing)
                .frame(width: 40, height: 30)
                .focused($focusedField, equals: .servingGrams)
                .accessibilityLabel(WeekFitLocalizedString("meals.nutrition.basis.a11yLabel"))
                .accessibilityValue(nutritionBasisDisplayLabel)
                .accessibilityHint(WeekFitLocalizedString("meals.foodForm.serving.a11yHint"))

            Text(labels.grams)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.82))
                .accessibilityHidden(true)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(textSecondary.opacity(0.62))
                .accessibilityHidden(true)
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(height: 34)
        .background {
            Capsule()
                .fill(WeekFitTheme.whiteOpacity(0.055))
        }
        .overlay {
            Capsule()
                .stroke(WeekFitTheme.whiteOpacity(0.075), lineWidth: 1)
        }
    }

    private func nutritionDisplayRow(
        title: String,
        value: Binding<String>,
        unit: String,
        icon: String,
        color: Color,
        field: FocusedField,
        showsDivider: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(color.opacity(0.92))
                    .frame(width: 26, height: 26)
                    .background {
                        Circle()
                            .fill(color.opacity(0.14))
                    }
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(0.92))

                Spacer(minLength: 8)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    TextField("0", text: value)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .tint(accent)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64, alignment: .trailing)
                        .focused($focusedField, equals: field)
                        .accessibilityLabel(title)
                        .accessibilityValue("\(displayValue(value.wrappedValue)) \(unit)")

                    Text(unit)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.64))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)

            if showsDivider {
                compactDivider
                    .padding(.leading, 52)
                    .padding(.trailing, 16)
            }
        }
    }

    private var compactDivider: some View {
        Rectangle()
            .fill(WeekFitTheme.whiteOpacity(0.055))
            .frame(height: 1)
    }


    private var previewImage: UIImage? {
        if let image = selectedThumbnailImage {
            return image
        }

        return didRemovePhoto ? nil : existingPreviewImage
    }

    private func displayValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "0" : trimmed
    }

    private func processCapturedPhoto(_ image: UIImage) {
        let processingStart = Self.debugStart("camera.processImage")
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                let storageImage = MealPhotoStore.downsampledImage(from: image)
                let thumbnail = MealPhotoStore.thumbnailImage(
                    from: storageImage,
                    sideLength: MealPhotoStore.formPreviewPixelSize
                )
                let pendingFilename = try? MealPhotoStore.savePendingOriginal(storageImage)
                Self.debugEnd("camera.processImage", start: processingStart)

                DispatchQueue.main.async {
                    selectedThumbnailImage = thumbnail
                    pendingOriginalFilename = pendingFilename
                    selectedImage = nil
                    didRemovePhoto = false
                    analyzePhotoForNutrition(storageImage)
                }
            }
        }
    }

    private func analyzePhotoForNutrition(_ image: UIImage) {
        guard !isAnalyzingPhoto else { return }

        isAnalyzingPhoto = true
        barcodeLookupMessage = nil
        // Avoid showing a stale success card while a new lookup is in flight.
        barcodeImportResult = nil

        // Vision work runs off the main actor inside FoodPhotoNutritionAnalyzer.
        Task {
            let result = await FoodPhotoNutritionAnalyzer.analyze(image)
            isAnalyzingPhoto = false
            handlePhotoAnalysisResult(result)
        }
    }

    @MainActor
    private func handlePhotoAnalysisResult(_ result: FoodPhotoAnalysisResult) {
        switch result {
        case let .barcode(estimate, lookup):
            ProductAnalytics.barcodeScanSucceeded(source: .meals)
            applyBarcodeEstimate(estimate, lookup: lookup)

        case let .nutritionLabel(estimate):
            scannedBarcode = nil
            scannedNutritionDataSource = estimate.dataSource
            barcodeImportResult = nil
            applyEstimate(estimate)

        case let .failure(failure):
            barcodeImportResult = nil
            switch failure {
            case .noContent:
                // Product photo without barcode/label — keep the shot and continue manually.
                if previewImage != nil {
                    setBarcodeLookupMessage(
                        WeekFitLocalizedString("meals.foodForm.photoKept.manualNutrition"),
                        tone: .neutral
                    )
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else {
                    ProductAnalytics.barcodeScanFailed(source: .meals, reason: .barcodeNotRecognized)
                    setBarcodeLookupMessage(
                        WeekFitLocalizedString("meals.barcode.notFound"),
                        tone: .error
                    )
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }

            case let .barcode(lookup):
                scannedBarcode = lookup.barcode
                scannedNutritionDataSource = nil
                let reason: BarcodeScanFailureReason
                switch lookup.status {
                case .notFound:
                    reason = .productNotFound
                case .offline:
                    reason = .network
                case .partial, .found:
                    reason = .unknown
                }
                ProductAnalytics.barcodeScanFailed(source: .meals, reason: reason)
                setBarcodeLookupMessage(
                    barcodeFailureMessage(for: lookup),
                    tone: lookup.status == .offline ? .warning : .error
                )
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
        }
    }

    @MainActor
    private func applyBarcodeEstimate(
        _ estimate: FoodPhotoNutritionEstimate,
        lookup: BarcodeFoodLookupResult
    ) {
        scannedBarcode = estimate.barcode
        scannedNutritionDataSource = estimate.dataSource

        Task {
            let productImage = estimate.shouldReplacePhotoWithProductImage
                ? await FoodPhotoNutritionAnalyzer.downloadProductImage(from: estimate.productImageURL)
                : nil

            let preparedPhoto: (thumbnail: UIImage, pendingFilename: String?)? = await withCheckedContinuation { continuation in
                guard let productImage else {
                    continuation.resume(returning: nil)
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let prepared = FoodPhotoNutritionAnalyzer.preparedMealPhoto(from: productImage)
                    continuation.resume(returning: (prepared.thumbnail, prepared.pendingFilename))
                }
            }

            await MainActor.run {
                let didApply = applyEstimate(estimate)

                let resolvedName = lookup.displayName
                    ?? estimate.name
                    ?? name.trimmingCharacters(in: .whitespacesAndNewlines)
                let displayName = resolvedName.isEmpty
                    ? WeekFitLocalizedString("meals.foodForm.preview.newFood")
                    : resolvedName

                withAnimation(barcodeCardAnimation) {
                    barcodeImportResult = BarcodeProductImportResult(
                        productName: displayName,
                        provider: lookup.provider ?? estimate.dataSource,
                        basis: lookup.basis,
                        isPartial: lookup.status == .partial
                    )
                    barcodeLookupMessage = nil
                }

                if let preparedPhoto {
                    if let pendingOriginalFilename {
                        MealPhotoStore.delete(filename: pendingOriginalFilename)
                    }
                    selectedThumbnailImage = preparedPhoto.thumbnail
                    pendingOriginalFilename = preparedPhoto.pendingFilename
                    selectedImage = nil
                    didRemovePhoto = false
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else if didApply {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }

    @MainActor
    @discardableResult
    private func applyEstimate(_ estimate: FoodPhotoNutritionEstimate) -> Bool {
        let didApply = estimate.applyIfPossible(
            name: &name,
            servingGrams: &servingGrams,
            calories: &calories,
            protein: &protein,
            carbs: &carbs,
            fats: &fats,
            fiber: &fiber
        )

        if didApply {
            // Lock density to the estimate baseline (usually per 100 g).
            // Later gram edits scale from this — never from rounded intermediate fields.
            captureNutritionDensityFromFields()
        }

        return didApply
    }

    /// Scale all macros by the same factor as grams / baseline grams.
    /// Density is immutable here so typing `2` → `23` → `230` cannot zero-out protein.
    private func rescaleNutritionForServingGramsChange(_ rawGrams: String) {
        guard !isScalingNutritionFromGrams else { return }
        let grams = intValue(rawGrams)
        guard grams > 0 else { return }

        if nutritionDensity == nil {
            captureNutritionDensityFromFields()
        }
        guard let density = nutritionDensity else { return }

        let scaled = density.scaled(toGrams: grams)
        isScalingNutritionFromGrams = true
        calories = Self.fieldText(scaled.calories)
        protein = Self.fieldText(scaled.protein)
        carbs = Self.fieldText(scaled.carbs)
        fats = Self.fieldText(scaled.fats)
        fiber = Self.fieldText(scaled.fiber)
        // onChange handlers for macros can run after this stack frame —
        // keep the guard up until the next turn of the run loop.
        DispatchQueue.main.async {
            isScalingNutritionFromGrams = false
        }
    }

    /// Only re-lock density when the user is actively editing a nutrient field
    /// (not when grams-driven scaling writes the macro text fields).
    private func captureDensityAfterManualNutrientEdit(focused expected: FocusedField) {
        guard !isScalingNutritionFromGrams else { return }
        guard focusedField == expected else { return }
        captureNutritionDensityFromFields()
    }

    private func captureNutritionDensityFromFields() {
        let grams = intValue(servingGrams)
        guard grams > 0 else { return }
        if let density = CustomMealNutritionDensity.from(
            grams: grams,
            calories: intValue(calories),
            protein: intValue(protein),
            carbs: intValue(carbs),
            fats: intValue(fats),
            fiber: intValue(fiber)
        ) {
            nutritionDensity = density
        }
    }

    private func barcodeFailureMessage(for lookup: BarcodeFoodLookupResult) -> String {
        switch lookup.status {
        case .offline:
            return WeekFitLocalizedString("meals.barcode.offline")
        case .notFound, .partial, .found:
            return WeekFitLocalizedString("meals.barcode.notFound")
        }
    }

    private func setBarcodeLookupMessage(_ message: String, tone: BarcodeLookupBannerTone) {
        barcodeLookupMessage = message
        barcodeLookupTone = tone
    }

    private func applyDownloadedProductPhoto(_ image: UIImage) -> Bool {
        let prepared = FoodPhotoNutritionAnalyzer.preparedMealPhoto(from: image)

        if let pendingOriginalFilename {
            MealPhotoStore.delete(filename: pendingOriginalFilename)
        }

        selectedThumbnailImage = prepared.thumbnail
        pendingOriginalFilename = prepared.pendingFilename
        selectedImage = nil
        didRemovePhoto = false
        return true
    }

    private func openCamera() {
        Self.debugLog("openCamera.request")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            Self.debugLog("openCamera.unavailable")
            ProductAnalytics.barcodeScanFailed(source: .meals, reason: .cameraUnavailable)
            setBarcodeLookupMessage(
                WeekFitLocalizedString("meals.foodForm.cameraUnavailable"),
                tone: .error
            )
            return
        }

        ProductAnalytics.barcodeScanStarted(source: .meals)
        showCamera = true
    }

    private func removePhoto() {
        Self.debugLog("removePhoto")
        releaseCapturedPhotoMemory(deletePendingOriginal: true)
        didRemovePhoto = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func releaseCapturedPhotoMemory(deletePendingOriginal: Bool) {
        selectedImage = nil
        selectedThumbnailImage = nil
        existingPreviewImage = nil
        if deletePendingOriginal, let pendingOriginalFilename {
            MealPhotoStore.delete(filename: pendingOriginalFilename)
        }
        pendingOriginalFilename = nil
    }

    private var isSaveEnabled: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard intValue(servingGrams) > 0 else { return false }

        return [
            intValue(calories),
            intValue(protein),
            intValue(carbs),
            intValue(fats),
            intValue(fiber)
        ].contains { $0 > 0 }
    }

    private func save() {
        let saveStart = Self.debugStart("save")
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        guard isSaveEnabled else {
            validationMessage = labels.requiredFieldsValidation
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            ProductAnalytics.foodLoggingFailed(method: .manual, source: .meals, reason: .invalidInput)
            Self.debugEnd("save.invalidDisabled", start: saveStart)
            return
        }

        let input = CustomMealFormInput(
            name: name,
            servingGrams: intValue(servingGrams),
            calories: intValue(calories),
            protein: intValue(protein),
            carbs: intValue(carbs),
            fats: intValue(fats),
            fiber: intValue(fiber)
        )

        let validationStart = Self.debugStart("validation")
        let validationResult = CustomMealValidation.validationMessage(
            for: input,
            existingMeals: existingMeals,
            excludingID: editingMeal?.id
        )
        Self.debugEnd("validation", start: validationStart)

        if let message = validationResult {
            validationMessage = message
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            Self.debugEnd("save.validationFailed", start: saveStart)
            return
        }

        let pendingPhotoFilename = pendingOriginalFilename
        let fallbackSelectedImage = selectedImage
        let shouldRemovePhoto = didRemovePhoto
        let existingOriginalFilename = editingMeal?.localPhotoFilename
        let existingThumbnailFilename = editingMeal?.localPhotoThumbnailFilename

        Task {
            let photoSaveStart = Self.debugStart("photo.persistSavedPhotoFilenames")
            let persistedPhotos: (originalFilename: String?, thumbnailFilename: String?)
            do {
                persistedPhotos = try await Task.detached(priority: .userInitiated) {
                    try MealPhotoStore.persistSavedPhotoFilenames(
                        pendingOriginalFilename: pendingPhotoFilename,
                        selectedImage: fallbackSelectedImage,
                        didRemovePhoto: shouldRemovePhoto,
                        existingOriginalFilename: existingOriginalFilename,
                        existingThumbnailFilename: existingThumbnailFilename
                    )
                }.value
                Self.debugEnd("photo.persistSavedPhotoFilenames", start: photoSaveStart)
            } catch {
                await MainActor.run {
                    validationMessage = labels.photoSaveFailedValidation
                    ProductAnalytics.foodLoggingFailed(method: .manual, source: .meals, reason: .saveFailed)
                    Self.debugEnd("save.photoFailed", start: saveStart)
                }
                return
            }

            await MainActor.run {
                pendingOriginalFilename = nil
                selectedImage = nil

                let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)

                let meal = Meals(
                    id: editingMeal?.id ?? "custom_meal_\(UUID().uuidString)",
                    title: trimmedName,
                    subtitle: String(format: labels.gramServingFormat, input.servingGrams),
                    imageName: editingMeal?.imageName ?? "",
                    type: editingMeal?.type ?? .balanced,
                    calories: input.calories,
                    protein: input.protein,
                    carbs: input.carbs,
                    fats: input.fats,
                    fiber: input.fiber,
                    benefits: editingMeal?.benefits ?? [
                        labels.customMealBenefit,
                        labels.manualEntryBenefit
                    ],
                    ingredients: [
                        MealsIngredient(
                            name: labels.servingIngredient,
                            amount: String(format: labels.gramValueFormat, input.servingGrams)
                        )
                    ],
                    suggestedTime: editingMeal?.suggestedTime ?? currentSuggestedTime,
                    builderImageItems: nil,
                    libraryKind: editingMeal?.libraryKind ?? .product,
                    creationMode: .manual,
                    servingGrams: input.servingGrams,
                    localPhotoFilename: persistedPhotos.originalFilename,
                    localPhotoThumbnailFilename: persistedPhotos.thumbnailFilename,
                    barcode: scannedBarcode ?? editingMeal?.barcode,
                    nutritionDataSource: scannedNutritionDataSource ?? editingMeal?.nutritionDataSource
                )

                validationMessage = nil
                releaseCapturedPhotoMemory(deletePendingOriginal: false)
                onSave(meal)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                ProductAnalytics.foodLoggingCompleted(
                    method: scannedBarcode == nil ? .manual : .barcode,
                    source: .meals
                )
                Self.debugEnd("save.success", start: saveStart)
                dismiss()
            }
        }
    }

    private var currentSuggestedTime: String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 6...10:  return "08:30"
        case 11...14: return "13:00"
        case 15...17: return "16:30"
        default:      return "19:00"
        }
    }

    private func intValue(_ value: String) -> Int {
        Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private static func fieldText(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }

    private static func makeLabels(isEditing: Bool) -> Labels {
        Labels(
            formTitle: WeekFitLocalizedString(isEditing ? "meals.foodForm.title.edit" : "meals.foodForm.title.create"),
            formSubtitle: WeekFitLocalizedString(isEditing ? "meals.foodForm.subtitle.edit" : "meals.foodForm.subtitle.create"),
            kcal: WeekFitLocalizedString("common.unit.kcal"),
            cancel: WeekFitLocalizedString("common.action.cancel"),
            removePhoto: WeekFitLocalizedString("meals.photo.remove"),
            foodName: WeekFitLocalizedString("meals.foodName"),
            foodNamePlaceholder: WeekFitLocalizedString("meals.enterFoodName"),
            calories: WeekFitLocalizedString("meals.nutrition.calories"),
            protein: WeekFitLocalizedString("meals.nutrition.protein"),
            carbs: WeekFitLocalizedString("meals.nutrition.carbs"),
            fats: WeekFitLocalizedString("meals.nutrition.fats"),
            fiber: WeekFitLocalizedString("meals.nutrition.fiber"),
            grams: WeekFitLocalizedString("common.unit.gramShort"),
            requiredFieldsValidation: WeekFitLocalizedString("meals.foodForm.validation.requiredFields"),
            photoSaveFailedValidation: WeekFitLocalizedString("meals.foodForm.validation.photoSaveFailed"),
            gramServingFormat: WeekFitLocalizedString("meals.value.gramServingFormat"),
            customMealBenefit: WeekFitLocalizedString("meals.foodForm.display.customMeal"),
            manualEntryBenefit: WeekFitLocalizedString("meals.foodForm.display.manualEntry"),
            servingIngredient: WeekFitLocalizedString("meals.foodForm.display.serving"),
            gramValueFormat: WeekFitLocalizedString("common.unit.gramValueFormat")
        )
    }

    private func requestExistingPreviewImageIfNeeded() {
        guard !didRequestExistingPreviewImage else { return }

        let filename = editingMeal?.displayPhotoFilename
        guard filename?.isEmpty == false else { return }

        didRequestExistingPreviewImage = true
        Self.debugLog("existingPreview.request filename=\(filename ?? "nil")")

        DispatchQueue.global(qos: .userInitiated).async {
            let loadStart = Self.debugStart("existingPreview.loadImage")
            let image = MealPhotoStore.image(for: filename)
            Self.debugEnd("existingPreview.loadImage", start: loadStart)

            DispatchQueue.main.async {
                Self.debugTimed("existingPreview.assign") {
                    existingPreviewImage = image
                }
            }
        }
    }

    private func applyUITestBarcodeFixtureIfNeeded() {
        #if DEBUG
        guard WeekFitUITestSupport.isActive else { return }
        let args = ProcessInfo.processInfo.arguments

        if args.contains("-create-food-fixture-barcode-loading") {
            isAnalyzingPhoto = true
            barcodeImportResult = nil
            barcodeLookupMessage = nil
            return
        }

        if args.contains("-create-food-fixture-barcode-failure") {
            barcodeImportResult = nil
            setBarcodeLookupMessage(
                WeekFitLocalizedString("meals.barcode.notFound"),
                tone: .error
            )
            return
        }

        let isPartial = args.contains("-create-food-fixture-barcode-partial")
        let isSuccess = args.contains("-create-food-fixture-barcode-success") || isPartial
        guard isSuccess else { return }

        name = "Tarczynski — Ham Frankfurters"
        servingGrams = "100"
        calories = isPartial ? "268" : "268"
        protein = isPartial ? "" : "14"
        carbs = isPartial ? "" : "2"
        fats = isPartial ? "22" : "22"
        fiber = isPartial ? "" : "0"
        scannedBarcode = "5901234123457"
        scannedNutritionDataSource = .openFoodFacts
        barcodeLookupMessage = nil
        barcodeImportResult = BarcodeProductImportResult(
            productName: "Tarczynski — Ham Frankfurters",
            provider: .openFoodFacts,
            basis: .per100g,
            isPartial: isPartial
        )
        captureNutritionDensityFromFields()
        #endif
    }

    private static let logger = Logger(subsystem: "WeekFit", category: "CustomMealBuilderView")

    private static func debugLog(_ message: String) -> Void {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }

    private static func debugStart(_ label: String) -> CFAbsoluteTime {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        logger.debug("\(label, privacy: .public) start")
        return start
        #else
        return 0
        #endif
    }

    private static func debugEnd(_ label: String, start: CFAbsoluteTime) {
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.debug("\(String(format: "%@ end %.1fms", label, elapsed), privacy: .public)")
        #endif
    }

    private static func debugTimed(_ label: String, _ work: () -> Void) {
        #if DEBUG
        let start = debugStart(label)
        work()
        debugEnd(label, start: start)
        #else
        work()
        #endif
    }
}

private struct CreateFoodCircleHeaderButton: View {
    let systemName: String
    let accessibilityLabelText: String
    let isEnabled: Bool
    /// When non-nil and enabled, fills the circle with accent (save). Nil = translucent back style.
    let filledAccent: Color?
    let action: () -> Void

    private let size: CGFloat = 52

    var body: some View {
        Button {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                if let filledAccent, isEnabled {
                    Circle()
                        .fill(filledAccent.opacity(0.96))
                        .overlay {
                            Circle()
                                .stroke(WeekFitTheme.whiteOpacity(0.12), lineWidth: 1)
                        }
                        .shadow(color: filledAccent.opacity(0.28), radius: 10, y: 4)
                } else {
                    Circle()
                        .fill(WeekFitTheme.whiteOpacity(isEnabled ? 0.055 : 0.035))
                        .overlay {
                            Circle()
                                .stroke(WeekFitTheme.whiteOpacity(0.075), lineWidth: 1)
                        }
                }

                Image(systemName: systemName)
                    .font(.system(size: systemName == "checkmark" ? 17 : 15, weight: .bold))
                    .foregroundStyle(
                        filledAccent != nil && isEnabled
                            ? Color.white.opacity(0.96)
                            : WeekFitTheme.primaryText.opacity(isEnabled ? 0.92 : 0.38)
                    )
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(CreateFoodPressableButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityAddTraits(isEnabled ? .isButton : [.isButton])
        .accessibilityValue(saveAccessibilityValue)
    }

    private var saveAccessibilityValue: String {
        guard filledAccent != nil else { return "" }
        return isEnabled
            ? WeekFitLocalizedString("meals.foodForm.save.enabledA11y")
            : WeekFitLocalizedString("meals.foodForm.save.disabledA11y")
    }
}

private struct CreateFoodOrDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(WeekFitTheme.whiteOpacity(0.08))
                .frame(height: 1)

            Text(WeekFitLocalizedString("meals.foodForm.orDivider"))
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.55))
                .tracking(0.8)

            Rectangle()
                .fill(WeekFitTheme.whiteOpacity(0.08))
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct CreateFoodPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct CustomMealCameraCaptureView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CustomMealCameraCaptureView

        init(parent: CustomMealCameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }

            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            ProductAnalytics.barcodeScanCancelled(source: .meals)
            parent.dismiss()
        }
    }
}
