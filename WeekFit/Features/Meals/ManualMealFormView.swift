import PhotosUI
import SwiftUI
import UIKit

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
    @FocusState private var focusedField: FocusedField?

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedThumbnailImage: UIImage?
    @State private var existingPreviewImage: UIImage?
    @State private var didRemovePhoto = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false

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
        let _ = Self.debugLog("body.render focus=\(focusedField?.rawValue ?? "nil") plainRows=\(FirstFocusProbe.usePlainInputRows) hidePhotoPreview=\(FirstFocusProbe.hidePhotoPreview) hidePhotoActions=\(FirstFocusProbe.hidePhotoActions)")

        ZStack {
            background.ignoresSafeArea()
            ambientBackground

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            if !FirstFocusProbe.hidePhotoPreview {
                                heroFoodCard
                            }

                            if !FirstFocusProbe.hidePhotoActions {
                                photoActions
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
                        .padding(.horizontal, 16)
                        .padding(.bottom, 96)
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
        .dynamicTypeSize(.medium)
        .preferredColorScheme(.dark)
        .onAppear {
            Self.debugTimed("onAppear") {
                requestExistingPreviewImageIfNeeded()
            }
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
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                Self.debugLog("camera.imageCaptured")
                processCapturedPhoto(image)
            }
            .ignoresSafeArea()
        }
        .photosPicker(
            isPresented: $showPhotoLibrary,
            selection: $selectedPhotoItem,
            matching: .images
        )
    }

    private var heroFoodCard: some View {
        let _ = Self.debugLog("render.heroFoodCard focus=\(focusedField?.rawValue ?? "nil")")

        return HStack(spacing: 12) {
            heroMealCardImage
                .frame(width: 78, height: 62)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? WeekFitLocalizedString("meals.foodName") : name)
                        .font(.system(size: 17.2, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary.opacity(name.isEmpty ? 0.70 : 0.98))
                        .tracking(-0.35)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(WeekFitLocalizedString("meals.addAPhotoOfYourFood"))
                        .font(.system(size: 12.4, weight: .medium))
                        .foregroundStyle(textSecondary.opacity(0.56))
                        .lineLimit(1)
                }

                macroSummaryRow
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 86)
        .background {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            WeekFitTheme.cardSecondary.opacity(0.97),
                            cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(Color.white.opacity(0.035), lineWidth: 1)
        }
        .shadow(color: WeekFitTheme.meal.opacity(0.035), radius: 12, y: 5)
    }

    private var macroSummaryRow: some View {
        let _ = Self.debugLog("render.macroSummaryRow focus=\(focusedField?.rawValue ?? "nil")")

        return HStack(spacing: 0) {
            Text(String(format: WeekFitLocalizedString("meals.value.kcalStringFormat"), caloriesDisplay))
                .font(.system(size: 11.2, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.9))
                .frame(maxWidth: .infinity)

            macroDivider
            macroText("\(WeekFitLocalizedString("nutrition.macro.protein.short")) \(String(format: WeekFitLocalizedString("common.unit.gramStringFormat"), proteinDisplay))")
            macroDivider
            macroText("\(WeekFitLocalizedString("nutrition.macro.carbs.short")) \(String(format: WeekFitLocalizedString("common.unit.gramStringFormat"), carbsDisplay))")
            macroDivider
            macroText("\(WeekFitLocalizedString("nutrition.macro.fats.short")) \(String(format: WeekFitLocalizedString("common.unit.gramStringFormat"), fatsDisplay))")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .frame(height: 20)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.030))
        }
    }

    private func macroText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.4, weight: .semibold, design: .monospaced))
            .foregroundStyle(textSecondary.opacity(0.6))
            .frame(maxWidth: .infinity)
    }

    private var macroDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(width: 1, height: 10)
    }
    private var ambientBackground: some View {
        WeekFitTheme.mealsAmbient
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private var header: some View {
        let _ = Self.debugLog("render.header focus=\(focusedField?.rawValue ?? "nil")")

        return HStack(spacing: 12) {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.045))
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.065), lineWidth: 1)
                        }

                    Image(systemName: "xmark")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(0.92))
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(WeekFitLocalizedString(editingMeal == nil ? "meals.foodForm.title.create" : "meals.foodForm.title.edit"))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.75)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(WeekFitLocalizedString(editingMeal == nil ? "meals.foodForm.subtitle.create" : "meals.foodForm.subtitle.edit"))
                    .font(.system(size: 13.2, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            Button { save() } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.14),
                                    Color.white.opacity(0.09)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Circle()
                                .stroke(isSaveEnabled ? accent.opacity(0.18) : Color.white.opacity(0.065), lineWidth: 1)
                        }

                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSaveEnabled ? accent.opacity(0.85) : textSecondary.opacity(0.42))
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .disabled(!isSaveEnabled)
            .scaleEffect(isSaveEnabled ? 1.0 : 0.96)
        }
        .padding(.bottom, 2)
    }

    private var heroMealCardImage: some View {
        let _ = Self.debugLog("render.heroMealCardImage focus=\(focusedField?.rawValue ?? "nil")")

        return CustomFoodVisualView(
            image: previewImage,
            placeholderInitial: previewInitial,
            size: 62,
            imageScale: 0.68,
            fallbackSystemImage: "fork.knife"
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    private var photoActions: some View {
        let _ = Self.debugLog("render.photoActions focus=\(focusedField?.rawValue ?? "nil")")

        return ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.030))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.040), lineWidth: 1)
                }

            HStack(spacing: 0) {
                photoControlButton(title: "meals.photo.take", icon: "camera.fill") {
                    openCamera()
                }

                Rectangle()
                    .fill(Color.white.opacity(0.050))
                    .frame(width: 1, height: 22)

                photoControlButton(title: "meals.photo.choose", icon: "photo.on.rectangle") {
                    showPhotoLibrary = true
                }

                if previewImage != nil {
                    Rectangle()
                        .fill(Color.white.opacity(0.050))
                        .frame(width: 1, height: 22)

                    photoControlButton(title: "meals.photo.remove", icon: "trash") {
                        removePhoto()
                    }
                }
            }
        }
        .frame(height: 42)
    }

    private func photoControlButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))

                Text(WeekFitLocalizedString(title))
                    .font(.system(size: 13.2, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.78))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var foodNameCard: some View {
        let _ = Self.debugLog("render.foodNameCard focus=\(focusedField?.rawValue ?? "nil")")

        return premiumCard(height: 58, surfaceOpacity: 0.92, borderOpacity: 0.040) {
            HStack(spacing: 12) {
                cardIcon("fork.knife", color: accent)

                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel("meals.foodName")

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
            }
        }
    }

    private var servingSizeCard: some View {
        let _ = Self.debugLog("render.servingSizeCard focus=\(focusedField?.rawValue ?? "nil")")

        return premiumCard(height: 80, surfaceOpacity: 0.92, borderOpacity: 0.040) {
            HStack(spacing: 12) {
                cardIcon("scalemass.fill", color: WeekFitTheme.purple)

                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel("meals.servingSize")

                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        TextField("100", text: $servingGrams)
                            .font(.system(size: 18.5, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                            .tint(accent)
                            .focused($focusedField, equals: .servingGrams)
                            .onTapGesture {
                                Self.debugLog("tap.servingGramsField")
                            }

                        Spacer(minLength: 8)

                        Menu {
                            Button(WeekFitLocalizedString("common.unit.gramShort")) { }
                        } label: {
                            HStack(spacing: 8) {
                                Text(WeekFitLocalizedString("common.unit.gramShort"))
                                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(textPrimary.opacity(0.78))
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(Capsule().fill(Color.white.opacity(0.032)))
                        }
                    }

                    Text(WeekFitLocalizedString("meals.nutritionValuesArePer100g"))
                        .font(.system(size: 11.8, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.56))
                }
            }
        }
    }

    private var nutritionSection: some View {
        let _ = Self.debugLog("render.nutritionSection focus=\(focusedField?.rawValue ?? "nil")")

        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(WeekFitLocalizedString("meals.nutrition"))
                    .font(.system(size: 18.5, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(WeekFitLocalizedString("meals.per100g"))
                    .font(.system(size: 13.2, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.58))
            }

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
        let _ = Self.debugLog("render.plainInputRows focus=\(focusedField?.rawValue ?? "nil")")

        return VStack(alignment: .leading, spacing: 10) {
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
        let _ = Self.debugLog("render.nutritionCard.\(focusedField(for: title).rawValue) focus=\(focusedField?.rawValue ?? "nil")")

        return premiumCard(height: 62, horizontalPadding: 11, surfaceOpacity: 0.72, borderOpacity: 0.032, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(color.opacity(0.48))
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
                        .foregroundStyle(textSecondary.opacity(0.44))
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
                                Color.white.opacity(0.040 * surfaceOpacity),
                                Color.white.opacity(0.030 * surfaceOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
            }
    }

    private func cardIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.035))
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.035), lineWidth: 1)
                }

            Image(systemName: systemName)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(color.opacity(0.54))
        }
        .frame(width: 34, height: 34)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(WeekFitLocalizedString(text))
            .font(.system(size: 13.2, weight: .semibold, design: .rounded))
            .foregroundStyle(textSecondary.opacity(0.58))
    }

    private var previewImage: UIImage? {
        let _ = Self.debugLog("computed.previewImage selectedThumb=\(selectedThumbnailImage != nil) existing=\(existingPreviewImage != nil) removed=\(didRemovePhoto)")

        if let image = selectedThumbnailImage {
            return image
        }

        return didRemovePhoto ? nil : existingPreviewImage
    }

    private var previewInitial: String {
        let _ = Self.debugLog("computed.previewInitial nameLength=\(name.count)")

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.first ?? "F").uppercased()
    }

    private var caloriesDisplay: String { displayValue(calories) }
    private var proteinDisplay: String { displayValue(protein) }
    private var carbsDisplay: String { displayValue(carbs) }
    private var fatsDisplay: String { displayValue(fats) }

    private func displayValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "0" : trimmed
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            let start = Self.debugStart("photoPicker.loadTransferable")
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                Self.debugEnd("photoPicker.loadTransferable.failed", start: start)
                return
            }
            Self.debugEnd("photoPicker.loadTransferable", start: start)

            let processingStart = Self.debugStart("photoPicker.processImage")
            let normalized = image.normalizedForPhotoStorage()
            let thumbnail = MealPhotoStore.thumbnailImage(from: normalized)
            Self.debugEnd("photoPicker.processImage", start: processingStart)

            await MainActor.run {
                selectedImage = normalized
                selectedThumbnailImage = thumbnail
                didRemovePhoto = false
            }
        }
    }

    private func processCapturedPhoto(_ image: UIImage) {
        Self.debugTimed("camera.processImage") {
            let normalized = image.normalizedForPhotoStorage()
            selectedImage = normalized
            selectedThumbnailImage = MealPhotoStore.thumbnailImage(from: normalized)
            didRemovePhoto = false
        }
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
        selectedImage = nil
        selectedThumbnailImage = nil
        didRemovePhoto = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var isSaveEnabled: Bool {
        let _ = Self.debugLog("computed.isSaveEnabled")
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

        let originalPhotoFilename: String?
        let thumbnailPhotoFilename: String?

        do {
            if let selectedImage {
                let photoSaveStart = Self.debugStart("photo.savePhotoSet")
                let photoSet = try MealPhotoStore.savePhotoSet(selectedImage)
                Self.debugEnd("photo.savePhotoSet", start: photoSaveStart)
                originalPhotoFilename = photoSet.originalFilename
                thumbnailPhotoFilename = photoSet.thumbnailFilename
                let photoDeleteStart = Self.debugStart("photo.deleteOldPhotoSet")
                MealPhotoStore.deletePhotoSet(
                    originalFilename: editingMeal?.localPhotoFilename,
                    thumbnailFilename: editingMeal?.localPhotoThumbnailFilename
                )
                Self.debugEnd("photo.deleteOldPhotoSet", start: photoDeleteStart)
            } else if didRemovePhoto {
                let photoDeleteStart = Self.debugStart("photo.deletePhotoSet")
                MealPhotoStore.deletePhotoSet(
                    originalFilename: editingMeal?.localPhotoFilename,
                    thumbnailFilename: editingMeal?.localPhotoThumbnailFilename
                )
                Self.debugEnd("photo.deletePhotoSet", start: photoDeleteStart)
                originalPhotoFilename = nil
                thumbnailPhotoFilename = nil
            } else {
                originalPhotoFilename = editingMeal?.localPhotoFilename
                thumbnailPhotoFilename = editingMeal?.localPhotoThumbnailFilename
            }
        } catch {
            validationMessage = WeekFitLocalizedString("meals.foodForm.validation.photoSaveFailed")
            Self.debugEnd("save.photoFailed", start: saveStart)
            return
        }

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
            localPhotoFilename: originalPhotoFilename,
            localPhotoThumbnailFilename: thumbnailPhotoFilename
        )

        validationMessage = nil
        onSave(meal)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Self.debugEnd("save.success", start: saveStart)
        dismiss()
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
        didRequestExistingPreviewImage = true

        let filename = editingMeal?.displayPhotoFilename
        guard filename?.isEmpty == false else { return }

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

    private static func debugLog(_ message: String) -> Void {
        #if DEBUG
        print("[ManualMealFormTiming] \(message)")
        #endif
    }

    private static func debugStart(_ label: String) -> CFAbsoluteTime {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        print("[ManualMealFormTiming] \(label) start")
        return start
        #else
        return 0
        #endif
    }

    private static func debugEnd(_ label: String, start: CFAbsoluteTime) {
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        print(String(format: "[ManualMealFormTiming] %@ end %.1fms", label, elapsed))
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

