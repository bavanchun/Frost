//
//  GeneralSettingsPane.swift
//  Frost
//

import LaunchAtLogin
import SwiftUI

struct GeneralSettingsPane: View {
    @EnvironmentObject var appState: AppState
    @State private var isImportingCustomFrostIcon = false
    @State private var isPresentingError = false
    @State private var presentedError: LocalizedErrorWrapper?
    @State private var isApplyingOffset = false
    @State private var tempItemSpacingOffset: CGFloat = 0 // Temporary state for the slider

    private var manager: GeneralSettingsManager {
        appState.settingsManager.generalSettingsManager
    }

    private var itemSpacingOffset: LocalizedStringKey {
        localizedOffsetString(for: manager.itemSpacingOffset)
    }

    private func localizedOffsetString(for offset: CGFloat) -> LocalizedStringKey {
        switch offset {
        case -16:
            return LocalizedStringKey("none")
        case 0:
            return LocalizedStringKey("default")
        case 16:
            return LocalizedStringKey("max")
        default:
            return LocalizedStringKey(offset.formatted())
        }
    }

    private var rehideIntervalKey: LocalizedStringKey {
        let formatted = manager.rehideInterval.formatted()
        if manager.rehideInterval == 1 {
            return LocalizedStringKey(formatted + " second")
        } else {
            return LocalizedStringKey(formatted + " seconds")
        }
    }

    private var hasSpacingSliderValueChanged: Bool {
        tempItemSpacingOffset != manager.itemSpacingOffset
    }

    private var isActualOffsetDifferentFromDefault: Bool {
        manager.itemSpacingOffset != 0
    }

    var body: some View {
        FrostForm {
            FrostSection {
                launchAtLogin
            }
            FrostSection {
                frostIconOptions
            }
            FrostSection {
                frostBarOptions
            }
            FrostSection {
                showOnClick
                showOnHover
                showOnScroll
            }
            FrostSection {
                autoRehideOptions
            }
            FrostSection {
                spacingOptions
            }
        }
        .alert(isPresented: $isPresentingError, error: presentedError) {
            Button("OK") {
                presentedError = nil
                isPresentingError = false
            }
        }
    }

    @ViewBuilder
    private var launchAtLogin: some View {
        LaunchAtLogin.Toggle()
    }

    @ViewBuilder
    private func menuItem(for imageSet: ControlItemImageSet) -> some View {
        Label {
            Text(imageSet.name.rawValue)
        } icon: {
            if let nsImage = imageSet.hidden.nsImage(for: appState) {
                switch imageSet.name {
                case .custom:
                    Image(size: CGSize(width: 18, height: 18)) { context in
                        context.draw(
                            Image(nsImage: nsImage),
                            in: context.clipBoundingRect
                        )
                    }
                default:
                    Image(nsImage: nsImage)
                }
            }
        }
    }

    @ViewBuilder
    private var frostIconOptions: some View {
        Toggle("Show Frost icon", isOn: manager.bindings.showFrostIcon)
            .annotation {
                if !manager.showFrostIcon {
                    Text("You can still access Frost's settings by right-clicking an empty area in the menu bar")
                }
            }
        if manager.showFrostIcon {
            FrostMenu("Frost icon") {
                Picker("Frost icon", selection: manager.bindings.frostIcon) {
                    ForEach(ControlItemImageSet.userSelectableFrostIcons) { imageSet in
                        Button {
                            manager.frostIcon = imageSet
                        } label: {
                            menuItem(for: imageSet)
                        }
                        .tag(imageSet)
                    }
                    if let lastCustomFrostIcon = manager.lastCustomFrostIcon {
                        Button {
                            manager.frostIcon = lastCustomFrostIcon
                        } label: {
                            menuItem(for: lastCustomFrostIcon)
                        }
                        .tag(lastCustomFrostIcon)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()

                Divider()

                Button("Choose image…") {
                    isImportingCustomFrostIcon = true
                }
            } title: {
                menuItem(for: manager.frostIcon)
            }
            .annotation("Choose a custom icon to show in the menu bar")
            .fileImporter(
                isPresented: $isImportingCustomFrostIcon,
                allowedContentTypes: [.image]
            ) { result in
                do {
                    let url = try result.get()
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        let data = try Data(contentsOf: url)
                        manager.frostIcon = ControlItemImageSet(name: .custom, image: .data(data))
                    }
                } catch {
                    presentedError = LocalizedErrorWrapper(error)
                    isPresentingError = true
                }
            }

            if case .custom = manager.frostIcon.name {
                Toggle("Apply system theme to icon", isOn: manager.bindings.customFrostIconIsTemplate)
                    .annotation("Display the icon as a monochrome image matching the system appearance")
            }
        }
    }

    @ViewBuilder
    private var frostBarOptions: some View {
        useFrostBar
        if manager.useFrostBar {
            frostBarLocationPicker
        }
    }

    @ViewBuilder
    private var useFrostBar: some View {
        Toggle("Use Frost Bar", isOn: manager.bindings.useFrostBar)
            .annotation("Show hidden menu bar items in a separate bar below the menu bar")
    }

    @ViewBuilder
    private var frostBarLocationPicker: some View {
        FrostPicker("Location", selection: manager.bindings.frostBarLocation) {
            ForEach(FrostBarLocation.allCases) { location in
                Text(location.localized).tag(location)
            }
        }
        .annotation {
            switch manager.frostBarLocation {
            case .dynamic:
                Text("The Frost Bar's location changes based on context")
            case .mousePointer:
                Text("The Frost Bar is centered below the mouse pointer")
            case .frostIcon:
                Text("The Frost Bar is centered below the Frost icon")
            }
        }
    }

    @ViewBuilder
    private var showOnClick: some View {
        Toggle("Show on click", isOn: manager.bindings.showOnClick)
            .annotation("Click inside an empty area of the menu bar to show hidden menu bar items")
    }

    @ViewBuilder
    private var showOnHover: some View {
        Toggle("Show on hover", isOn: manager.bindings.showOnHover)
            .annotation("Hover over an empty area of the menu bar to show hidden menu bar items")
    }

    @ViewBuilder
    private var showOnScroll: some View {
        Toggle("Show on scroll", isOn: manager.bindings.showOnScroll)
            .annotation("Scroll or swipe in the menu bar to toggle hidden menu bar items")
    }

    @ViewBuilder
    private var spacingOptions: some View {
        FrostLabeledContent {
            FrostSlider(
                localizedOffsetString(for: tempItemSpacingOffset),
                value: $tempItemSpacingOffset,
                in: -16...16,
                step: 2
            )
            .disabled(isApplyingOffset)
        } label: {
            FrostLabeledContent {
                Button("Apply") {
                    applyOffset()
                }
                .help("Apply the current spacing")
                .disabled(isApplyingOffset || !hasSpacingSliderValueChanged)

                if isApplyingOffset {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5)
                        .frame(width: 15, height: 15)
                } else {
                    Button {
                        resetOffsetToDefault()
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to the default spacing")
                    .disabled(isApplyingOffset || !isActualOffsetDifferentFromDefault)
                }
            } label: {
                HStack {
                    Text("Menu bar item spacing")
                    BetaBadge()
                }
            }
        }
        .annotation(
            "Applying this setting will relaunch all apps with menu bar items. Some apps may need to be manually relaunched.",
            spacing: 2
        )
        .annotation(spacing: 10, font: .callout.bold()) {
            FrostGroupBox {
                Label {
                    Text("Note: You may need to log out and back in for this setting to apply properly.")
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            tempItemSpacingOffset = manager.itemSpacingOffset
        }
    }

    @ViewBuilder
    private var rehideStrategyPicker: some View {
        FrostPicker("Strategy", selection: manager.bindings.rehideStrategy) {
            ForEach(RehideStrategy.allCases) { strategy in
                Text(strategy.localized).tag(strategy)
            }
        }
        .annotation {
            switch manager.rehideStrategy {
            case .smart:
                Text("Menu bar items are rehidden using a smart algorithm")
            case .timed:
                Text("Menu bar items are rehidden after a fixed amount of time")
            case .focusedApp:
                Text("Menu bar items are rehidden when the focused app changes")
            }
        }
    }

    @ViewBuilder
    private var autoRehideOptions: some View {
        Toggle("Automatically rehide", isOn: manager.bindings.autoRehide)
        if manager.autoRehide {
            if case .timed = manager.rehideStrategy {
                VStack {
                    rehideStrategyPicker
                    FrostSlider(
                        rehideIntervalKey,
                        value: manager.bindings.rehideInterval,
                        in: 0...30,
                        step: 1
                    )
                }
            } else {
                rehideStrategyPicker
            }
        }
    }

    /// Apply menu bar spacing offset.
    private func applyOffset() {
        isApplyingOffset = true
        manager.itemSpacingOffset = tempItemSpacingOffset
        Task {
            do {
                try await appState.spacingManager.applyOffset()
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
            isApplyingOffset = false
        }
    }

    /// Reset menu bar spacing offset to default.
    private func resetOffsetToDefault() {
        tempItemSpacingOffset = 0
        manager.itemSpacingOffset = tempItemSpacingOffset
        applyOffset()
    }
}
