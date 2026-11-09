import XCTest
import SwiftUI
@testable import WeekFit

final class TodayQuickActionsLayoutTests: XCTestCase {

    private let columnSizes: [DynamicTypeSize] = [.large, .xLarge, .xxLarge, .xxxLarge]
    private let accessibilitySizes: [DynamicTypeSize] = [
        .accessibility1, .accessibility2, .accessibility3
    ]

    /// Point widths of the quick-action card content, after the 20pt screen inset and 16pt card padding.
    private let contentWidths: [(name: String, width: CGFloat)] = [
        ("iPhone SE / 13 mini 375pt", 303),
        ("iPhone 16 393pt", 321)
    ]

    func testVisibleCaptionsStayShortInEverySupportedLanguage() {
        let drink = [
            "en": "Log drink", "ru": "Напиток", "de": "Getränk", "es": "Bebida",
            "fr": "Boisson", "it": "Bevanda", "ja": "飲み物", "ko": "음료 기록",
            "pl": "Napój", "zh-Hans": "记录饮品"
        ]
        let food = [
            "en": "Log food", "ru": "Еда", "de": "Essen", "es": "Comida",
            "fr": "Repas", "it": "Pasto", "ja": "食事", "ko": "식사 기록",
            "pl": "Jedzenie", "zh-Hans": "记录饮食"
        ]
        let start = [
            "en": "Start", "ru": "Начать", "de": "Starten", "es": "Iniciar",
            "fr": "Démarrer", "it": "Avvia", "ja": "開始", "ko": "시작",
            "pl": "Zacznij", "zh-Hans": "开始"
        ]
        let session = [
            "en": "Session", "ru": "Сессия", "de": "Sitzung", "es": "Sesión",
            "fr": "Séance", "it": "Sessione", "ja": "セッション", "ko": "세션",
            "pl": "Sesja", "zh-Hans": "进行中"
        ]
        let startVoiceOver = [
            "en": "Start activity", "ru": "Начать активность", "de": "Aktivität starten",
            "fr": "Démarrer", "pl": "Rozpocznij aktywność"
        ]

        for language in AppLanguage.allCases {
            let code = language.rawValue
            let locale = Locale(identifier: code)
            XCTAssertEqual(WeekFitLocalizedString("today.quickActions.logDrink", locale: locale), drink[code])
            XCTAssertEqual(WeekFitLocalizedString("today.quickActions.logMeal", locale: locale), food[code])
            XCTAssertEqual(WeekFitLocalizedString("today.quickActions.startCaption", locale: locale), start[code])
            XCTAssertEqual(WeekFitLocalizedString("today.quickActions.viewSessionCaption", locale: locale), session[code])
            if let voiceOver = startVoiceOver[code] {
                XCTAssertEqual(
                    WeekFitLocalizedString("today.quickActions.startActivity", locale: locale),
                    voiceOver
                )
            }
        }

        XCTAssertEqual(
            WeekFitLocalizedString("today.quickActions.viewSession", locale: Locale(identifier: "ru")),
            "К сессии"
        )
    }

    func testCaptionsFitOneColumnThroughXXXLargeOnNarrowestPhones() {
        var failures: [String] = []
        for language in AppLanguage.allCases {
            let idle = visibleLabels(language, liveSession: false)
            let live = visibleLabels(language, liveSession: true)
            for size in columnSizes {
                for screen in contentWidths {
                    for label in idle {
                        let width = TodayQuickActionMetrics.labelWidth(label, dynamicTypeSize: size)
                        if width > screen.width / 3 - 2 {
                            failures.append(
                                "\(language.rawValue) \(size) \(screen.name) \"\(label)\" \(width)pt column"
                            )
                        }
                    }
                }
            }
            for size in columnSizes + accessibilitySizes + [.accessibility4, .accessibility5] {
                for screen in contentWidths {
                    let rowLimit = screen.width - 52 - 12
                    for label in idle + live {
                        let width = TodayQuickActionMetrics.labelWidth(label, dynamicTypeSize: size)
                        let fitsColumn = width <= screen.width / 3 - 2
                        if !fitsColumn && width > rowLimit {
                            failures.append(
                                "\(language.rawValue) \(size) \(screen.name) \"\(label)\" \(width)pt row"
                            )
                        }
                    }
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    @MainActor
    func testAccessibilitySizesStackWhenColumnsDoNotFit() throws {
        let french = visibleLabels(.french, liveSession: false)
        let narrow = TodayQuickActionMetrics.narrowestCardContentWidth
        XCTAssertFalse(
            TodayQuickActionMetrics.columnsFit(
                labels: french,
                contentWidth: narrow,
                dynamicTypeSize: .accessibility2
            )
        )

        let columns = try render(
            name: "ru-large-375",
            labels: visibleLabels(.russian, liveSession: false),
            voiceOver: ["Напиток", "Еда", "Начать активность"],
            width: narrow,
            typeSize: .large
        )
        XCTAssertLessThan(columns.fittedHeight, 150)

        let stacked = try render(
            name: "fr-ax2-375",
            labels: french,
            voiceOver: ["Boisson", "Repas", "Démarrer"],
            width: narrow,
            typeSize: .accessibility2
        )
        XCTAssertGreaterThan(stacked.fittedHeight, columns.fittedHeight + 80)

        let wideColumns = try render(
            name: "de-xxxl-393",
            labels: visibleLabels(.german, liveSession: false),
            voiceOver: ["Getränk", "Essen", "Aktivität starten"],
            width: 321,
            typeSize: .xxxLarge
        )
        XCTAssertLessThan(wideColumns.fittedHeight, 180)
    }

    private func visibleLabels(_ language: AppLanguage, liveSession: Bool) -> [String] {
        let locale = Locale(identifier: language.rawValue)
        let third = liveSession
            ? "today.quickActions.viewSessionCaption"
            : "today.quickActions.startCaption"
        return [
            WeekFitLocalizedString("today.quickActions.logDrink", locale: locale),
            WeekFitLocalizedString("today.quickActions.logMeal", locale: locale),
            WeekFitLocalizedString(third, locale: locale)
        ]
    }

    private struct RenderedBar {
        let image: UIImage
        let fittedHeight: CGFloat
    }

    @MainActor
    private func render(
        name: String,
        labels: [String],
        voiceOver: [String],
        width: CGFloat,
        typeSize: DynamicTypeSize
    ) throws -> RenderedBar {
        let icons = ["cup.and.saucer.fill", "fork.knife", "play.fill"]
        let ids = ["today.quickAction.drinks", "today.quickAction.food", "today.quickAction.activity"]
        let actions = labels.enumerated().map { index, label in
            TodayQuickActionItem(
                id: ids[index],
                icon: icons[index],
                label: label,
                accessibilityLabel: voiceOver[index],
                color: .blue,
                isEmphasized: false,
                liveIndicatorColor: nil,
                toastMessage: nil,
                accessibilityIdentifier: ids[index],
                action: {}
            )
        }
        let bar = TodayQuickActionsBar(actions: actions, isLight: true, textPrimary: .black)
            .environment(\.dynamicTypeSize, typeSize)
            .frame(width: width)
            .background(Color.white)
            .ignoresSafeArea()
        let host = UIHostingController(rootView: bar)
        host.safeAreaRegions = []
        host.traitOverrides.preferredContentSizeCategory = TodayQuickActionMetrics.contentSizeCategory(typeSize)
        let fitted = host.sizeThatFits(in: CGSize(width: width, height: 1200))
        host.view.bounds = CGRect(origin: .zero, size: CGSize(width: width, height: fitted.height))
        host.view.frame = host.view.bounds
        let window = UIWindow(frame: host.view.frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: host.view.bounds.size)
        let image = renderer.image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "quick-actions-\(name)"
        attachment.lifetime = XCTAttachment.Lifetime.keepAlways
        add(attachment)
        let directory = URL(fileURLWithPath: "/Users/maxk/Dev/WeekFit/.tmp/quick-actions", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? image.pngData()?.write(to: directory.appendingPathComponent("\(name).png"))

        return RenderedBar(image: image, fittedHeight: fitted.height)
    }
}
