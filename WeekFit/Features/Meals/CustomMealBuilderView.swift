import PhotosUI
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
        let takePhoto: String
        let choosePhoto: String
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
    private let labels: Labels

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusedField?

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedThumbnailImage: UIImage?
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

    init(
        editingMeal: Meals? = nil,
        existingMeals: [Meals],
        onSave: @escaping (Meals) -> Void
    ) {
        self.editingMeal = editingMeal
        self.existingMeals = existingMeals
        self.onSave = onSave
        labels = Self.makeLabels(isEditing: editingMeal != nil)

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
        let _ = Self.debugLog("body.render focus=\(focusedField?.rawValue ?? "nil")")

        ZStack {
            background.ignoresSafeArea()
            ambientBackground

            VStack(spacing: 12) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            heroPreviewCard
                            editableFields

                            if let validationMessage {
                                Text(validationMessage)
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.red.opacity(0.84))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                                    .id("validation")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
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
        }
        .onAppear {
            requestExistingPreviewImageIfNeeded()
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
            CustomMealCameraCaptureView { image in
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
        .confirmationDialog(
            "",
            isPresented: $showPhotoSourcePicker,
            titleVisibility: .hidden
        ) {
            Button(labels.takePhoto) {
                openCamera()
            }

            Button(labels.choosePhoto) {
                showPhotoLibrary = true
            }

            Button(labels.cancel, role: .cancel) { }
        }
    }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.065), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 340
            )

            RadialGradient(
                colors: [WeekFitTheme.orange.opacity(0.032), .clear],
                center: .bottomLeading,
                startRadius: 80,
                endRadius: 380
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.012),
                    .clear,
                    Color.black.opacity(0.13)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.045))
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.065), lineWidth: 1)
                        }

                    Image(systemName: "chevron.left")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(0.92))
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(labels.formTitle)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.75)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(labels.formSubtitle)
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            Button {
                save()
            } label: {
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
                                .stroke(
                                    isSaveEnabled ? accent.opacity(0.18) : Color.white.opacity(0.065),
                                    lineWidth: 1
                                )
                        }

                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(
                            isSaveEnabled
                            ? accent.opacity(0.85)
                            : textSecondary.opacity(0.42)
                        )
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .disabled(!isSaveEnabled)
            .scaleEffect(isSaveEnabled ? 1.0 : 0.96)
            .animation(.spring(response: 0.25, dampingFraction: 0.82), value: isSaveEnabled)
        }
        .padding(.bottom, 2)
    }

    private var heroPreviewCard: some View {
        HStack(spacing: 13) {
            heroImageButton

            VStack(alignment: .leading, spacing: 8) {
                Text(previewTitle)
                    .font(.system(size: 20.5, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.82 : 1.0))
                    .tracking(-0.45)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(caloriesDisplay)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .tracking(-0.25)

                    Text(labels.kcal)
                        .font(.system(size: 12.2, weight: .semibold, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.82))
                        .padding(.bottom, 2)
                }

                macroSummaryLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 122)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            elevatedCard.opacity(0.96),
                            cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.065),
                            Color.white.opacity(0.014),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
        .shadow(color: WeekFitTheme.cardShadow.opacity(0.66), radius: 14, y: 7)
    }

    private var heroImageButton: some View {
        Button {
            showPhotoSourcePicker = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.030),
                                WeekFitTheme.cardSecondary.opacity(1.0),
                                cardBackground.opacity(1.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipped()
                } else {
                    VStack(spacing: 7) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(textPrimary.opacity(0.82))

                        Image(systemName: "photo")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(textSecondary.opacity(0.72))
                    }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 1)
        }
        .shadow(color: WeekFitTheme.cardShadow.opacity(0.35), radius: 8, y: 4)
        .contextMenu {
            if previewImage != nil {
                Button(labels.removePhoto, role: .destructive) {
                    removePhoto()
                }
            }
        }
    }

    private var macroSummaryLine: some View {
        HStack(spacing: 6) {
            heroMacroLabel(
                "P",
                value: proteinDisplay
            )

            heroMacroSeparator

            heroMacroLabel(
                "C",
                value: carbsDisplay
            )

            heroMacroSeparator

            heroMacroLabel(
                "F",
                value: fatsDisplay
            )
        }
        .font(.system(size: 13.6, weight: .semibold, design: .rounded))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private func heroMacroLabel(_ label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(textPrimary.opacity(0.94))

            Text("\(value)g")
                .foregroundStyle(textSecondary.opacity(0.86))
        }
    }

    private var heroMacroSeparator: some View {
        Text("|")
            .foregroundStyle(textSecondary.opacity(0.42))
    }

    private var editableFields: some View {
        VStack(spacing: 12) {
            foodNameSection
            nutritionSection
        }
    }

    private var foodNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(labels.foodName)
                .font(.system(size: 13.2, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.76))

            TextField(labels.foodNamePlaceholder, text: $name)
                .font(.system(size: 17.2, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .submitLabel(.done)
                .tint(accent)
                .focused($focusedField, equals: .name)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 86)
        .background {
            compactSectionBackground(cornerRadius: 22)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            focusedField = .name
        }
    }

    private var nutritionSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Nutrition")
                    .font(.system(size: 17.4, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.28)

                Spacer()

                servingSelector
            }
            .padding(.horizontal, 16)
            .frame(height: 50)

            compactDivider
                .padding(.horizontal, 16)

            nutritionRow(
                title: labels.calories,
                value: $calories,
                unit: labels.kcal,
                icon: "flame.fill",
                color: WeekFitTheme.orange,
                focusedField: .calories
            )

            compactDivider
                .padding(.leading, 58)

            nutritionRow(
                title: labels.protein,
                value: $protein,
                unit: labels.grams,
                icon: "figure.strengthtraining.traditional",
                color: accent,
                focusedField: .protein
            )

            compactDivider
                .padding(.leading, 58)

            nutritionRow(
                title: labels.carbs,
                value: $carbs,
                unit: labels.grams,
                icon: "leaf.fill",
                color: Color(red: 0.95, green: 0.76, blue: 0.28),
                focusedField: .carbs
            )

            compactDivider
                .padding(.leading, 58)

            nutritionRow(
                title: labels.fats,
                value: $fats,
                unit: labels.grams,
                icon: "drop.fill",
                color: WeekFitTheme.purple,
                focusedField: .fats
            )

            compactDivider
                .padding(.leading, 58)

            nutritionRow(
                title: labels.fiber,
                value: $fiber,
                unit: labels.grams,
                icon: "circle.circle.fill",
                color: WeekFitTheme.green,
                focusedField: .fiber
            )
        }
        .background {
            compactSectionBackground(cornerRadius: 24)
        }
    }

    private var servingSelector: some View {
        HStack(spacing: 5) {
            TextField("100", text: $servingGrams)
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.92))
                .keyboardType(.numberPad)
                .submitLabel(.done)
                .tint(accent)
                .multilineTextAlignment(.trailing)
                .frame(width: 42)
                .focused($focusedField, equals: .servingGrams)

            Text(labels.grams)
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.84))

            Image(systemName: "chevron.down")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(textSecondary.opacity(0.62))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.050))
        }
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.070), lineWidth: 1)
        }
        .contentShape(Capsule())
        .onTapGesture {
            focusedField = .servingGrams
        }
    }

    private func nutritionRow(
        title: String,
        value: Binding<String>,
        unit: String,
        icon: String,
        color: Color,
        focusedField: FocusedField
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(color.opacity(0.78))
                .frame(width: 30, height: 30)
                .background {
                    Circle()
                        .fill(color.opacity(0.085))
                }

            Text(title)
                .font(.system(size: 15.4, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.94))

            Spacer(minLength: 8)

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                TextField("0", text: value)
                    .font(.system(size: 16.2, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
                    .tint(accent)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 62)
                    .focused($focusedField, equals: focusedField)

                Text(unit)
                    .font(.system(size: 11.6, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.64))
                    .padding(.bottom, 2)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .contentShape(Rectangle())
        .onTapGesture {
            self.focusedField = focusedField
        }
    }

    private var compactDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.055))
            .frame(height: 1)
    }

    private func compactSectionBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.046),
                        Color.white.opacity(0.030)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.045), lineWidth: 1)
            }
            .shadow(color: WeekFitTheme.cardShadow.opacity(0.44), radius: 10, y: 5)
    }

    private var previewImage: UIImage? {
        if let image = selectedThumbnailImage {
            return image
        }

        return didRemovePhoto ? nil : existingPreviewImage
    }

    private var previewTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New Food" : trimmed
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
            let loadStart = Self.debugStart("photoPicker.loadTransferable")
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                Self.debugEnd("photoPicker.loadTransferable.failed", start: loadStart)
                return
            }
            Self.debugEnd("photoPicker.loadTransferable", start: loadStart)

            let processingStart = Self.debugStart("photoPicker.processImage")
            DispatchQueue.global(qos: .userInitiated).async {
                let normalized = image.normalizedForPhotoStorage()
                let thumbnail = MealPhotoStore.thumbnailImage(from: normalized)
                Self.debugEnd("photoPicker.processImage", start: processingStart)

                DispatchQueue.main.async {
                    selectedImage = normalized
                    selectedThumbnailImage = thumbnail
                    didRemovePhoto = false
                }
            }
        }
    }

    private func processCapturedPhoto(_ image: UIImage) {
        let processingStart = Self.debugStart("camera.processImage")
        DispatchQueue.global(qos: .userInitiated).async {
            let normalized = image.normalizedForPhotoStorage()
            let thumbnail = MealPhotoStore.thumbnailImage(from: normalized)
            Self.debugEnd("camera.processImage", start: processingStart)

            DispatchQueue.main.async {
                selectedImage = normalized
                selectedThumbnailImage = thumbnail
                didRemovePhoto = false
            }
        }
    }

    private func openCamera() {
        Self.debugLog("openCamera.request")
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            Self.debugLog("openCamera.fallbackToLibrary")
            showPhotoLibrary = true
            return
        }

        showCamera = true
    }

    private func removePhoto() {
        Self.debugLog("removePhoto")
        selectedPhotoItem = nil
        selectedImage = nil
        selectedThumbnailImage = nil
        didRemovePhoto = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        guard isSaveEnabled else {
            validationMessage = labels.requiredFieldsValidation
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
            validationMessage = labels.photoSaveFailedValidation
            Self.debugEnd("save.photoFailed", start: saveStart)
            return
        }

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

    private static func makeLabels(isEditing: Bool) -> Labels {
        Labels(
            formTitle: WeekFitLocalizedString(isEditing ? "meals.foodForm.title.edit" : "meals.foodForm.title.create"),
            formSubtitle: WeekFitLocalizedString(isEditing ? "meals.foodForm.subtitle.edit" : "meals.foodForm.subtitle.create"),
            kcal: WeekFitLocalizedString("common.unit.kcal"),
            takePhoto: WeekFitLocalizedString("meals.photo.take"),
            choosePhoto: WeekFitLocalizedString("meals.photo.choose"),
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
            parent.dismiss()
        }
    }
}
