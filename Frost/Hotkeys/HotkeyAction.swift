//
//  HotkeyAction.swift
//  Frost
//

enum HotkeyAction: String, Codable, CaseIterable {
    // Menu Bar Sections
    case toggleHiddenSection = "ToggleHiddenSection"
    case toggleAlwaysHiddenSection = "ToggleAlwaysHiddenSection"

    // Menu Bar Items
    case searchMenuBarItems = "SearchMenuBarItems"

    // Other
    case enableFrostBar = "EnableFrostBar"
    case showSectionDividers = "ShowSectionDividers"
    case toggleApplicationMenus = "ToggleApplicationMenus"

    @MainActor
    func perform(appState: AppState) async {
        switch self {
        case .toggleHiddenSection:
            guard let section = appState.menuBarManager.section(withName: .hidden) else {
                return
            }
            section.toggle()
            // Prevent the section from automatically rehiding after mouse movement.
            if !section.isHidden {
                appState.preventShowOnHover()
            }
        case .toggleAlwaysHiddenSection:
            guard let section = appState.menuBarManager.section(withName: .alwaysHidden) else {
                return
            }
            section.toggle()
            // Prevent the section from automatically rehiding after mouse movement.
            if !section.isHidden {
                appState.preventShowOnHover()
            }
        case .searchMenuBarItems:
            await appState.menuBarManager.searchPanel.toggle()
        case .enableFrostBar:
            appState.settingsManager.generalSettingsManager.useFrostBar.toggle()
        case .showSectionDividers:
            appState.settingsManager.advancedSettingsManager.showSectionDividers.toggle()
        case .toggleApplicationMenus:
            appState.menuBarManager.toggleApplicationMenus()
        }
    }
}
