import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case record = "Record"
    case library = "Library"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .record: return "waveform.circle.fill"
        case .library: return "square.stack.3d.up.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .record

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                Group {
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
            .toolbarBackground(.hidden, for: .windowToolbar)
        }
        .background(Theme.background)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundStyle(Theme.accent)
                    .glow(Theme.accent, radius: 6)
                Text("LECTURE REC")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 14)

            ForEach(AppTab.allCases) { tab in
                sidebarRow(tab)
            }

            Spacer()
        }
        .frame(minWidth: 190)
        .background(Theme.background)
    }

    private func sidebarRow(_ tab: AppTab) -> some View {
        let isSelected = tab == selectedTab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                Text(tab.rawValue)
                    .font(.system(.body, design: .rounded, weight: isSelected ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Theme.surfaceElevated : .clear)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.accent)
                        .frame(width: 3, height: 16)
                        .offset(x: -14)
                        .glow(Theme.accent, radius: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 1)
    }
}
