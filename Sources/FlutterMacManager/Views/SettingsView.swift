import AppKit
import FlutterMacManagerCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    state.showingSettings = false
                    Task { await state.refresh() }
                } label: {
                    Label("Done", systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("Settings")
                    .font(.system(size: 13.5, weight: .semibold))

                Spacer()

                Text("Done").opacity(0).font(.system(size: 12))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Scan roots section
                    settingsCard {
                        HStack {
                            Label("Project Scan Folders", systemImage: "folder.badge.gearshape")
                                .font(.system(size: 12.5, weight: .semibold))
                            Spacer()
                            Button {
                                pickFolder()
                            } label: {
                                Label("Add…", systemImage: "plus")
                            }
                            .controlSize(.small)
                        }

                        if state.settings.scanRoots.isEmpty {
                            Text("No project folders configured yet.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 5) {
                                ForEach(state.settings.scanRoots, id: \.self) { root in
                                    HStack(spacing: 8) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 11.5))
                                            .foregroundColor(.accentColor.opacity(0.85))
                                        Text(PathFormatting.abbreviateHome(root))
                                            .font(.system(size: 11.5))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Button {
                                            state.removeScanRoot(root)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Remove folder")
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.75))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                            }
                        }

                        HStack {
                            Spacer()
                            Button("Reset Default Folders") {
                                state.settings.scanRoots = ScanSettings.defaultScanRoots()
                            }
                            .font(.system(size: 11))
                            .buttonStyle(.borderless)
                            .foregroundColor(.secondary)
                        }
                    }

                    // Additional sources section
                    settingsCard {
                        Label("Discovery Sources", systemImage: "magnifyingglass.circle")
                            .font(.system(size: 12.5, weight: .semibold))

                        Toggle("Scan Xcode DerivedData", isOn: $state.settings.scanDerivedData)
                        Toggle("Scan /Applications & ~/Applications", isOn: $state.settings.scanApplications)
                    }

                    // Cleanup safety section
                    settingsCard {
                        Label("Cleanup Safety", systemImage: "shield.lefthalf.filled")
                            .font(.system(size: 12.5, weight: .semibold))

                        Toggle("Move to Trash instead of permanent delete", isOn: $state.settings.moveToTrashByDefault)

                        Text("Recommended: allows restoring removed builds or containers from Finder Trash.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
            }
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .font(.system(size: 12))
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Scan Folder"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            state.addScanRoot(url.path)
        }
    }
}
