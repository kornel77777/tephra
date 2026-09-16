import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case record = "Record"
    case library = "Library"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .record: return "mic.circle"
        case .library: return "tray.full"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .record

    var body: some View {
        NavigationSplitView {
            List(AppTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.systemImage).tag(tab)
            }
            .navigationTitle("Lecture Recorder")
        } detail: {
            switch selectedTab {
            case .record:
                RecordingView()
            case .library:
                LibraryView()
            case .settings:
                SettingsView()
            }
        }
    }
}
