//
//  GeneralSettingsManager.swift
//  Frost
//

import Combine
import Foundation

@MainActor
final class GeneralSettingsManager: ObservableObject {
    /// A Boolean value that indicates whether the Frost icon
    /// should be shown.
    @Published var showFrostIcon = true

    /// An icon to show in the menu bar, with a different image
    /// for when items are visible or hidden.
    @Published var frostIcon: ControlItemImageSet = .defaultFrostIcon

    /// The last user-selected custom Frost icon.
    @Published var lastCustomFrostIcon: ControlItemImageSet?

    /// A Boolean value that indicates whether custom Frost icons
    /// should be rendered as template images.
    @Published var customFrostIconIsTemplate = false

    /// A Boolean value that indicates whether to show hidden items
    /// in a separate bar below the menu bar.
    @Published var useFrostBar = false

    /// The location where the Frost Bar appears.
    @Published var frostBarLocation: FrostBarLocation = .dynamic

    /// A Boolean value that indicates whether the hidden section
    /// should be shown when the mouse pointer clicks in an empty
    /// area of the menu bar.
    @Published var showOnClick = true

    /// A Boolean value that indicates whether the hidden section
    /// should be shown when the mouse pointer hovers over an
    /// empty area of the menu bar.
    @Published var showOnHover = false

    /// A Boolean value that indicates whether the hidden section
    /// should be shown or hidden when the user scrolls in the
    /// menu bar.
    @Published var showOnScroll = true

    /// The offset to apply to the menu bar item spacing and padding.
    @Published var itemSpacingOffset: Double = 0

    /// A Boolean value that indicates whether the hidden section
    /// should automatically rehide.
    @Published var autoRehide = true

    /// A strategy that determines how the auto-rehide feature works.
    @Published var rehideStrategy: RehideStrategy = .smart

    /// A time interval for the auto-rehide feature when its rule
    /// is ``RehideStrategy/timed``.
    @Published var rehideInterval: TimeInterval = 15

    /// Encoder for properties.
    private let encoder = JSONEncoder()

    /// Decoder for properties.
    private let decoder = JSONDecoder()

    /// Storage for internal observers.
    private var cancellables = Set<AnyCancellable>()

    /// The shared app state.
    private(set) weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }

    func performSetup() {
        loadInitialState()
        configureCancellables()
    }

    private func loadInitialState() {
        Defaults.ifPresent(key: .showFrostIcon, assign: &showFrostIcon)
        Defaults.ifPresent(key: .customFrostIconIsTemplate, assign: &customFrostIconIsTemplate)
        Defaults.ifPresent(key: .useFrostBar, assign: &useFrostBar)
        Defaults.ifPresent(key: .showOnClick, assign: &showOnClick)
        Defaults.ifPresent(key: .showOnHover, assign: &showOnHover)
        Defaults.ifPresent(key: .showOnScroll, assign: &showOnScroll)
        Defaults.ifPresent(key: .itemSpacingOffset, assign: &itemSpacingOffset)
        Defaults.ifPresent(key: .autoRehide, assign: &autoRehide)
        Defaults.ifPresent(key: .rehideInterval, assign: &rehideInterval)

        Defaults.ifPresent(key: .frostBarLocation) { rawValue in
            if let location = FrostBarLocation(rawValue: rawValue) {
                frostBarLocation = location
            }
        }
        Defaults.ifPresent(key: .rehideStrategy) { rawValue in
            if let strategy = RehideStrategy(rawValue: rawValue) {
                rehideStrategy = strategy
            }
        }

        if let data = Defaults.data(forKey: .frostIcon) {
            do {
                frostIcon = try decoder.decode(ControlItemImageSet.self, from: data)
            } catch {
                Logger.generalSettingsManager.error("Error decoding Frost icon: \(error)")
            }
            if case .custom = frostIcon.name {
                lastCustomFrostIcon = frostIcon
            }
        }
    }

    private func configureCancellables() {
        var c = Set<AnyCancellable>()

        $showFrostIcon
            .receive(on: DispatchQueue.main)
            .sink { showFrostIcon in
                Defaults.set(showFrostIcon, forKey: .showFrostIcon)
            }
            .store(in: &c)

        $frostIcon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frostIcon in
                guard let self else {
                    return
                }
                if case .custom = frostIcon.name {
                    lastCustomFrostIcon = frostIcon
                }
                do {
                    let data = try encoder.encode(frostIcon)
                    Defaults.set(data, forKey: .frostIcon)
                } catch {
                    Logger.generalSettingsManager.error("Error encoding Frost icon: \(error)")
                }
            }
            .store(in: &c)

        $customFrostIconIsTemplate
            .receive(on: DispatchQueue.main)
            .sink { isTemplate in
                Defaults.set(isTemplate, forKey: .customFrostIconIsTemplate)
            }
            .store(in: &c)

        $useFrostBar
            .receive(on: DispatchQueue.main)
            .sink { useFrostBar in
                Defaults.set(useFrostBar, forKey: .useFrostBar)
            }
            .store(in: &c)

        $frostBarLocation
            .receive(on: DispatchQueue.main)
            .sink { location in
                Defaults.set(location.rawValue, forKey: .frostBarLocation)
            }
            .store(in: &c)

        $showOnClick
            .receive(on: DispatchQueue.main)
            .sink { showOnClick in
                Defaults.set(showOnClick, forKey: .showOnClick)
            }
            .store(in: &c)

        $showOnHover
            .receive(on: DispatchQueue.main)
            .sink { showOnHover in
                Defaults.set(showOnHover, forKey: .showOnHover)
            }
            .store(in: &c)

        $showOnScroll
            .receive(on: DispatchQueue.main)
            .sink { showOnScroll in
                Defaults.set(showOnScroll, forKey: .showOnScroll)
            }
            .store(in: &c)

        $itemSpacingOffset
            .receive(on: DispatchQueue.main)
            .sink { [weak appState] offset in
                Defaults.set(offset, forKey: .itemSpacingOffset)
                appState?.spacingManager.offset = Int(offset)
            }
            .store(in: &c)

        $autoRehide
            .receive(on: DispatchQueue.main)
            .sink { autoRehide in
                Defaults.set(autoRehide, forKey: .autoRehide)
            }
            .store(in: &c)

        $rehideStrategy
            .receive(on: DispatchQueue.main)
            .sink { strategy in
                Defaults.set(strategy.rawValue, forKey: .rehideStrategy)
            }
            .store(in: &c)

        $rehideInterval
            .receive(on: DispatchQueue.main)
            .sink { interval in
                Defaults.set(interval, forKey: .rehideInterval)
            }
            .store(in: &c)

        cancellables = c
    }
}

// MARK: GeneralSettingsManager: BindingExposable
extension GeneralSettingsManager: BindingExposable { }

// MARK: - Logger
private extension Logger {
    static let generalSettingsManager = Logger(category: "GeneralSettingsManager")
}
