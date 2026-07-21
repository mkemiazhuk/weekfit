import PhotosUI
import SwiftUI
import UIKit
import OSLog

struct ManualMealFormView: View {
    private enum FirstFocusProbe {
        static let usePlainInputRows = false
        static let hidePhotoPreview = false
        static let hidePhotoActions = false
        static let disableValidationScroll = false
    }

    private enum FocusedField: String {
        case name
        case servingGrams
        case calories
        case protein
        case carbs
        case fats
        case fiber
    }

    let editingMeal: Meals?
    let existingMeals: [Meals]
    let onSave: (Meals) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: AppLanguageManager
    @FocusState private var focusedField: FocusedField?

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedThumbnailImage: UIImage?
    @State private var pendingOriginalFilename: String?
    @State private var existingPreviewImage: UIImage?
    @State private var didRemovePhoto = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showPhotoSourcePicker = false

    @State private var name: String
    @State private var servingGrams: String
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fats: String
    @State private var fiber: String
    @State private var validationMessage: String?
    @State private var didRequestExistingPreviewImage = false

    private let background = WeekFitTheme.backgroundColor
    private let cardBackground = WeekFitTheme.cardBackground
    private let elevatedCard = WeekFitTheme.elevatedCard
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let accent = WeekFitTheme.meal

    private let nutritionColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

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
    }
    
    var body: some View {
        let _ = languageManager.selectedLanguage
        let _ = Self.debugLog("body.render focus=\(focusedField?.rawValue ?? "nil") plainRows=\(FirstFocusProbe.usePlainInputRows) hidePhotoPreview=\(FirstFocusProbe.hidePhotoPreview) hidePhotoActions=\(FirstFocusProbe.hidePhotoActions)")

        ZStack {
            background.ignoresSafeArea()
            ambientBackground

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 18)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            if !FirstFocusProbe.hidePhotoPreview {
                                heroFoodCard
                            }

                            if FirstFocusProbe.usePlainInputRows {
                                plainInputRows
                            } else {
                                foodNameCard
                                servingSizeCard
                                nutritionSection
                            }

                            if let validationMessage {
                                Text(WeekFitLocalizedString(validationMessage))
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.red.opacity(0.84))
                                    .padding(.horizontal, 4)
                                    .id("validation")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 36)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: validationMessage) { _, newValue in
                        guard !FirstFocusProbe.disableValidationScroll else {
                            Self.debugLog("validation.scroll suppressed")
                            return
                        }

                        guard newValue != nil else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                            proxy.scrollTo("validation", anchor: .center)
                        }
                    }
                }
            }
        }
        .onAppear {
            requestExistingPreviewImageIfNeeded()
        }
        .onDisappear {
            releaseCapturedPhotoMemory(deletePendingOriginal: true)
        }
        .onChange(of: focusedField) { oldValue, newValue in
            Self.debugLog("focus.change \(oldValue?.rawValue ?? "nil") -> \(newValue?.rawValue ?? "nil")")
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Self.debugLog("onChange.selectedPhotoItem isNil=\(newItem == nil)")
            loadPhoto(newItem)
        }
        .onChange(of: name) { _, newValue in
            Self.debugLog("onChange.name length=\(newValue.count)")
        }
        .onChange(of: servingGrams) { _, newValue in
            Self.debugLog("onChange.servingGrams length=\(newValue.count)")
        }
        .onChange(of: calories) { _, newValue in
            Self.debugLog("onChange.calories length=\(newValue.count)")
        }
        .onChange(of: protein) { _, newValue in
            Self.debugLog("onChange.protein length=\(newValue.count)")
        }
        .onChange(of: carbs) { _, newValue in
            Self.debugLog("onChange.carbs length=\(newValue.count)")
        }
        .onChange(of: fats) { _, newValue in
            Self.debugLog("onChange.fats length=\(newValue.count)")
        }
        .onChange(of: fiber) { _, newValue in
            Self.debugLog("onChange.fiber length=\(newValue.count)")
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                Self.debugLog("camera.imageCaptured")
                processCapturedPhoto(image)
            }
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
        }
        .photosPicker(
            isPresented: $showPhotoLibrary,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .confirmationDialog(
            "",
            isPresented: $showPhotoSourcePicker,
            titleVisibility: .hidden
        ) {
            Button(WeekFitLocalizedString("meals.photo.take")) {
                openCamera()
            }

            Button(WeekFitLocalizedString("meals.photo.choose")) {
                showPhotoLibrary = true
            }

            Button(WeekFitLocalizedString("common.action.cancel"), role: .cancel) { }
        }
    }

    private var heroFoodCard: some View {
        HStack(spacing: 12) {
            heroMealCardImage
                .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 8) {
                Text(previewTitle)
                    .font(.system(size: 20.5, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.82 : 1.0))
                    .tracking(-0.45)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                MealNutritionSummaryStrip(
                    calories: intValue(calories),
                    protein: intValue(protein),
                    carbs: intValue(carbs),
                    fats: intValue(fats),
                    fiber: intValue(fiber),
                    accent: accent,
                    style: .embedded
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.whiteOpacity(0.030),
                            WeekFitTheme.cardSecondary.opacity(1.0),
                            cardBackground.opacity(1.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.075), lineWidth: 1)
        }
        .shadow(color: WeekFitTheme.cardShadow.opacity(0.62), radius: 13, y: 6)
    }

    private var ambientBackground: some View {
        RadialGradient(
            colors: [
                WeekFitTheme.whiteOpacity(0.018),
                Color.clear
            ],
            center: UnitPoint(x: 0.88, y: 0.02),
            startRadius: 24,
            endRadius: 300
        )
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 3) {
                Text(WeekFitLocalizedString(editingMeal == nil ? "meals.foodForm.title.create" : "meals.foodForm.title.edit"))
                    .font(.system(size: 18.5, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.35)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(WeekFitLocalizedString(editingMeal == nil ? "meals.foodForm.subtitle.create" : "meals.foodForm.subtitle.edit"))
                    .font(.system(size: 13.2, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Button { dismiss() } label: {
                    Text(WeekFitLocalizedString("common.action.cancel"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(textPrimary.opacity(0.88))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Button { save() } label: {
                    Text(WeekFitLocalizedString("common.action.save"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSaveEnabled ? accent : textSecondary.opacity(0.72))
                }
                .buttonStyle(.plain)
                .disabled(!isSaveEnabled)
            }
        }
        .frame(height: 46)
    }

    private var heroMealCardImage: some View {
        Button {
            showPhotoSourcePicker = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            elevatedCard.opacity(1.18),
                            cardBackground.opacity(1.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 94, height: 84)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(accent.opacity(0.88))

                        Text(WeekFitLocalizedString("meals.foodForm.photoBarcodeShort"))
                            .font(.system(size: 8.2, weight: .semibold, design: .rounded))
                            .foregroundStyle(textSecondary.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.085), lineWidth: 1)
        }
        .shadow(color: WeekFitTheme.cardShadow.opacity(0.35), radius: 8, y: 4)
        .contextMenu {
            if previewImage != nil {
                Button(WeekFitLocalizedString("meals.photo.remove"), role: .destructive) {
                    removePhoto()
                }
            }
        }
    }

    private var foodNameCard: some View {
        formSection(title: WeekFitLocalizedString("meals.foodName")) {
            VStack(alignment: .leading, spacing: 8) {
                premiumCard(height: 62, horizontalPadding: 16, surfaceOpacity: 1.25, borderOpacity: 0.070, cornerRadius: 18) {
                    TextField(WeekFitLocalizedString("meals.enterFoodName"), text: $name)
                        .font(.system(size: 16.8, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .tint(accent)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .name)
                        .onTapGesture {
                            Self.debugLog("tap.nameField")
                        }
                }

                Text(WeekFitLocalizedString("meals.manual.nameHint"))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.74))
                    .padding(.horizontal, 2)
            }
        }
    }

    private var servingSizeCard: some View {
        HStack {
            Text(WeekFitLocalizedString("meals.manual.nutritionPer"))
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.98))

            Spacer(minLength: 12)

            HStack(spacing: 5) {
                TextField("100", text: $servingGrams)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(0.88))
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .tint(accent)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 34)
                    .focused($focusedField, equals: .servingGrams)
                    .onTapGesture {
                        Self.debugLog("tap.servingGramsField")
                    }

                Text(WeekFitLocalizedString("common.unit.gramShort"))
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))

                Menu {
                    Button(WeekFitLocalizedString("common.unit.gramShort")) { }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(0.78))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(textPrimary.opacity(0.78))
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background {
                Capsule()
                    .fill(WeekFitTheme.whiteOpacity(0.050))
            }
            .overlay {
                Capsule()
                    .stroke(WeekFitTheme.whiteOpacity(0.070), lineWidth: 1)
            }
        }
        .padding(.top, 2)
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: nutritionColumns, spacing: 8) {
                nutritionCard(title: "meals.nutrition.calories", value: $calories, unit: "common.unit.kcal", icon: "flame.fill", color: WeekFitTheme.orange)
                nutritionCard(title: "meals.nutrition.protein", value: $protein, unit: "common.unit.gramShort", icon: "figure.strengthtraining.traditional", color: accent)
                nutritionCard(title: "meals.nutrition.carbs", value: $carbs, unit: "common.unit.gramShort", icon: "leaf.fill", color: Color(red: 0.95, green: 0.76, blue: 0.28))
                nutritionCard(title: "meals.nutrition.fats", value: $fats, unit: "common.unit.gramShort", icon: "drop.fill", color: WeekFitTheme.purple)
            }

            nutritionCard(title: "meals.nutrition.fiber", value: $fiber, unit: "common.unit.gramShort", icon: "circle.circle.fill", color: WeekFitTheme.green, isWide: true)
        }
    }

    private var plainInputRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(WeekFitLocalizedString("meals.enterFoodName"), text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .tint(accent)
                .submitLabel(.done)
                .focused($focusedField, equals: .name)
                .onTapGesture {
                    Self.debugLog("tap.nameField.plain")
                }

            TextField("100", text: $servingGrams)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .keyboardType(.numberPad)
                .tint(accent)
                .focused($focusedField, equals: .servingGrams)
                .onTapGesture {
                    Self.debugLog("tap.servingGramsField.plain")
                }

            TextField("0", text: $calories)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .keyboardType(.decimalPad)
                .tint(accent)
                .focused($focusedField, equals: .calories)
                .onTapGesture {
                    Self.debugLog("tap.caloriesField.plain")
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func nutritionCard(
        title: String,
        value: Binding<String>,
        unit: String,
        icon: String,
        color: Color,
        isWide: Bool = false
    ) -> some View {
        premiumCard(height: isWide ? 70 : 82, horizontalPadding: 14, surfaceOpacity: isWide ? 0.82 : 1.0, borderOpacity: isWide ? 0.052 : 0.065, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(color.opacity(0.70))
                        .frame(width: 14)

                    fieldLabel(title)
                }

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    TextField("0", text: value)
                        .font(.system(size: 16.8, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .tint(accent)
                        .focused($focusedField, equals: focusedField(for: title))
                        .onTapGesture {
                            Self.debugLog("tap.\(focusedField(for: title).rawValue)Field")
                        }

                    Text(WeekFitLocalizedString(unit))
                        .font(.system(size: 11.6, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.64))
                        .padding(.bottom, 2)
                }
            }
        }
    }

    private func premiumCard<Content: View>(
        height: CGFloat,
        horizontalPadding: CGFloat = 12,
        surfaceOpacity: Double = 1,
        borderOpacity: Double = 0.040,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WeekFitTheme.whiteOpacity(0.052 * surfaceOpacity),
                                WeekFitTheme.whiteOpacity(0.038 * surfaceOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(WeekFitTheme.whiteOpacity(borderOpacity), lineWidth: 1)
            }
    }

    private func formSection<Content: View>(
        title: String,
        optionalText: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title)
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(0.92))

                if let optionalText {
                    Text("(\(optionalText))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.62))
                }
            }

            content()
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(WeekFitLocalizedString(text))
            .font(.system(size: 13.2, weight: .semibold, design: .rounded))
            .foregroundStyle(textSecondary.opacity(0.76))
    }

    private var previewImage: UIImage? {
        if let image = selectedThumbnailImage {
            return image
        }

        return didRemovePhoto ? nil : existingPreviewImage
    }

    private var previewInitial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.first ?? "F").uppercased()
    }

    private var previewTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? WeekFitLocalizedString("meals.foodForm.preview.newFood") : trimmed
    }

    private func displayValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "0" : trimmed
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            let start = Self.debugStart("photoPicker.loadTransferable")
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                Self.debugEnd("photoPicker.loadTransferable.failed", start: start)
                return
            }
            Self.debugEnd("photoPicker.loadTransferable", start: start)

            let processingStart = Self.debugStart("photoPicker.processImage")
            DispatchQueue.global(qos: .userInitiated).async {
                autoreleasepool {
                    guard let storageImage = MealPhotoStore.downsampledImage(from: data) else {
                        Self.debugEnd("photoPicker.processImage.failed", start: processingStart)
                        return
                    }
                    let thumbnail = MealPhotoStore.thumbnailImage(
                        from: storageImage,
                        sideLength: MealPhotoStore.formPreviewPixelSize
                    )
                    let pendingFilename = try? MealPhotoStore.savePendingOriginal(storageImage)
                    Self.debugEnd("photoPicker.processImage", start: processingStart)

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
        Task {
            let result = await FoodPhotoNutritionAnalyzer.analyze(image)
            let estimate: FoodPhotoNutritionEstimate?
            switch result {
            case let .barcode(value, _):
                estimate = value
            case let .nutritionLabel(value):
                estimate = value
            case .failure:
                estimate = nil
            }

            guard let estimate else { return }

            let productImage = estimate.shouldReplacePhotoWithProductImage
                ? await FoodPhotoNutritionAnalyzer.downloadProductImage(from: estimate.productImageURL)
                : nil

            await MainActor.run {
                var didApply = false

                if estimate.applyIfPossible(
                    name: &name,
                    servingGrams: &servingGrams,
                    calories: &calories,
                    protein: &protein,
                    carbs: &carbs,
                    fats: &fats,
                    fiber: &fiber
                ) {
                    didApply = true
                }

                if let productImage,
                   applyDownloadedProductPhoto(productImage) {
                    didApply = true
                }

                if didApply {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
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
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showPhotoLibrary = true
            return
        }

        showCamera = true
    }

    private func removePhoto() {
        selectedPhotoItem = nil
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
            validationMessage = WeekFitLocalizedString("meals.foodForm.validation.requiredFields")
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
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
                    validationMessage = WeekFitLocalizedString("meals.foodForm.validation.photoSaveFailed")
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
                    subtitle: String(format: WeekFitLocalizedString("meals.value.gramServingFormat"), input.servingGrams),
                    imageName: editingMeal?.imageName ?? "",
                    type: editingMeal?.type ?? .balanced,
                    calories: input.calories,
                    protein: input.protein,
                    carbs: input.carbs,
                    fats: input.fats,
                    fiber: input.fiber,
                    benefits: editingMeal?.benefits ?? [
                        WeekFitLocalizedString("meals.foodForm.display.customMeal"),
                        WeekFitLocalizedString("meals.foodForm.display.manualEntry")
                    ],
                    ingredients: [
                        MealsIngredient(
                            name: WeekFitLocalizedString("meals.foodForm.display.serving"),
                            amount: String(format: WeekFitLocalizedString("common.unit.gramValueFormat"), input.servingGrams)
                        )
                    ],
                    suggestedTime: editingMeal?.suggestedTime ?? currentSuggestedTime,
                    builderImageItems: nil,
                    libraryKind: editingMeal?.libraryKind ?? .product,
                    creationMode: .manual,
                    servingGrams: input.servingGrams,
                    localPhotoFilename: persistedPhotos.originalFilename,
                    localPhotoThumbnailFilename: persistedPhotos.thumbnailFilename
                )

                validationMessage = nil
                releaseCapturedPhotoMemory(deletePendingOriginal: false)
                onSave(meal)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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

    private func requestExistingPreviewImageIfNeeded() {
        guard !didRequestExistingPreviewImage else { return }

        let filename = editingMeal?.displayPhotoFilename
        guard filename?.isEmpty == false else { return }

        didRequestExistingPreviewImage = true
        Self.debugLog("existingPreview.request filename=\(filename ?? "nil")")

        DispatchQueue.global(qos: .userInitiated).async {
            let start = Self.debugStart("existingPreview.loadImage")
            let image = MealPhotoStore.image(for: filename)
            Self.debugEnd("existingPreview.loadImage", start: start)

            DispatchQueue.main.async {
                Self.debugTimed("existingPreview.assign") {
                    existingPreviewImage = image
                }
            }
        }
    }

    private func focusedField(for title: String) -> FocusedField {
        switch title {
        case "meals.nutrition.calories":
            return .calories
        case "meals.nutrition.protein":
            return .protein
        case "meals.nutrition.carbs":
            return .carbs
        case "meals.nutrition.fats":
            return .fats
        case "meals.nutrition.fiber":
            return .fiber
        default:
            return .name
        }
    }

    private static let logger = Logger(subsystem: "WeekFit", category: "ManualMealFormView")

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

private struct CameraCaptureView: UIViewControllerRepresentable {
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
        let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
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
            parent.dismiss()
        }
    }
}

