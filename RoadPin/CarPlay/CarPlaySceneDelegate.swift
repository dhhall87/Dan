import CarPlay
import UIKit

/// The CarPlay screen: a grid with the four zones (or one big button) plus "+1 mi back",
/// and a "Recent" tab listing the latest pins.
///
/// CarPlay only allows Apple's templates for this kind of app, so the grid stands in for the
/// four-column phone layout. Apple also doesn't allow RoadPin to use the microphone while CarPlay is
/// connected, so CarPlay taps save the pin right away and notes come from Siri
/// ("Hey Siri, drop a RoadPin" or "Hey Siri, name my last RoadPin").
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPTabBarTemplateDelegate {
    private static let gridTitle = "RoadPin"

    private var scene: CPTemplateApplicationScene?
    private var interfaceController: CPInterfaceController?
    private var gridTemplate: CPGridTemplate?
    private var listTemplate: CPListTemplate?
    private var shownMode: PinMode?
    private var settingsObserver: NSObjectProtocol?
    private var titleReset: Task<Void, Never>?

    // MARK: CPTemplateApplicationSceneDelegate

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        scene = templateApplicationScene
        self.interfaceController = interfaceController
        CarPlayState.isConnected = true
        PinStore.purgeExpired()
        LocationTracker.shared.start()

        let grid = CPGridTemplate(title: Self.gridTitle, gridButtons: makeGridButtons())
        grid.tabTitle = "Drop"
        grid.tabImage = UIImage(systemName: "mappin.and.ellipse")

        let list = CPListTemplate(title: "Recent", sections: [])
        list.tabTitle = "Recent"
        list.tabImage = UIImage(systemName: "list.bullet")
        list.emptyViewTitleVariants = ["No pins yet"]
        list.emptyViewSubtitleVariants = ["Tap a zone, or say “Hey Siri, drop a RoadPin”"]

        gridTemplate = grid
        listTemplate = list
        refreshList()

        let tabs = CPTabBarTemplate(templates: [grid, list])
        tabs.delegate = self
        interfaceController.setRootTemplate(tabs, animated: false, completion: nil)

        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.settingsChanged() }
        }
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        CarPlayState.isConnected = false
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        settingsObserver = nil
        titleReset?.cancel()
        gridTemplate = nil
        listTemplate = nil
        self.interfaceController = nil
        scene = nil
    }

    // MARK: CPTabBarTemplateDelegate

    func tabBarTemplate(_ tabBarTemplate: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        if selectedTemplate === listTemplate {
            refreshList()
        }
    }

    // MARK: Grid

    private var iconScale: CGFloat {
        interfaceController?.carTraitCollection.displayScale ?? 2
    }

    private func makeGridButtons() -> [CPGridButton] {
        let mode = AppSettings.mode
        shownMode = mode
        let scale = iconScale
        var buttons: [CPGridButton] = []
        switch mode {
        case .zones:
            for zone in RoadZone.allCases {
                buttons.append(CPGridButton(titleVariants: [zone.title], image: CarPlayIcons.zone(zone, scale: scale)) { [weak self] _ in
                    Task { @MainActor in await self?.drop(zone: zone) }
                })
            }
        case .oneButton:
            buttons.append(CPGridButton(titleVariants: ["Drop Pin"], image: CarPlayIcons.symbol("mappin.and.ellipse", scale: scale)) { [weak self] _ in
                Task { @MainActor in await self?.drop(zone: nil) }
            })
        }
        buttons.append(CPGridButton(titleVariants: ["+1 mi back", "+1 mi"], image: CarPlayIcons.symbol("arrow.uturn.backward", scale: scale)) { [weak self] _ in
            Task { @MainActor in await self?.addMileBack() }
        })
        return buttons
    }

    private func settingsChanged() {
        guard let gridTemplate, AppSettings.mode != shownMode else { return }
        gridTemplate.updateGridButtons(makeGridButtons())
    }

    private func drop(zone: RoadZone?) async {
        showTitle("Saving…")
        if await PinRecorder.shared.dropPin(zone: zone, origin: .carPlay) != nil {
            showTitle("✓ Saved" + (zone.map { " · \($0.title)" } ?? ""))
        } else {
            showTitle("No GPS signal · not saved")
        }
        refreshList()
    }

    private func addMileBack() async {
        if let pin = await PinRecorder.shared.addMileBack(origin: .carPlay) {
            showTitle("✓ \(Pin.formatMiles(pin.milesBack)) back · tap again for more")
        } else {
            showTitle("No GPS signal · not saved")
        }
        refreshList()
    }

    /// Briefly shows a confirmation in the grid's title bar, then goes back to "RoadPin".
    private func showTitle(_ text: String) {
        gridTemplate?.updateTitle(text)
        titleReset?.cancel()
        titleReset = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.gridTemplate?.updateTitle(Self.gridTitle)
        }
    }

    // MARK: Recent list

    private func refreshList() {
        guard let listTemplate else { return }
        let items: [CPListItem] = PinStore.recentPins(limit: 12).map { pin in
            let item = CPListItem(text: pin.title, detailText: detailText(for: pin))
            item.handler = { [weak self] _, completion in
                self?.navigate(to: pin)
                completion()
            }
            return item
        }
        listTemplate.updateSections([CPListSection(items: items)])
    }

    private func detailText(for pin: Pin) -> String {
        var parts = [pin.createdAt.formatted(date: .omitted, time: .shortened)]
        if !pin.whereSummary.isEmpty { parts.append(pin.whereSummary) }
        if !pin.placeName.isEmpty { parts.append(pin.placeName) }
        return parts.joined(separator: " · ")
    }

    /// Tapping a recent pin starts directions back to it in the driver's maps app.
    private func navigate(to pin: Pin) {
        scene?.open(MapLinks.directions(to: pin, in: AppSettings.preferredMaps), options: nil, completionHandler: nil)
    }
}
