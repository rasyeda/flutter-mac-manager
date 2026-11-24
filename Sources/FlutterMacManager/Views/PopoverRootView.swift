import AppKit
import FlutterMacManagerCore
import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ZStack {
            if state.showingSettings {
                SettingsView(state: state)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else if let pending = state.pendingRequest {
                CleanupConfirmView(state: state, request: pending)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: state.showingSettings)
        .animation(.easeInOut(duration: 0.16), value: state.pendingRequest?.id)
        .task {
            if state.lastScanDate == nil {
                await state.refresh()
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            summaryStrip
            Divider()
            filterBar
            if let banner = state.statusBanner {
                statusBannerView(banner)
            }
            Divider()
            appListSection
            Divider()
            footerBar
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.9), Color.blue.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)
                Image(systemName: "hammer.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Flutter macOS Manager")
                    .font(.system(size: 13.5, weight: .semibold))
                if let lastScan = state.lastScanDate {
                    Text("Scanned \(lastScan, style: .relative) ago")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("Debug & Profile build manager")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if state.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24, height: 24)
            } else {
                HoverIconButton(
                    systemImage: "arrow.clockwise",
                    tint: .primary,
                    helpText: "Rescan Flutter builds"
                ) {
                    Task { await state.refresh() }
                }
            }

            HoverIconButton(
                systemImage: "gearshape",
                tint: .primary,
                helpText: "Settings"
            ) {
                state.showingSettings = true
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var summaryStrip: some View {
        let debugCount = state.apps.filter { $0.mode == .debug }.count
        let profileCount = state.apps.filter { $0.mode == .profile }.count
        let runningCount = state.apps.filter { $0.isRunning }.count

        return HStack(spacing: 0) {
            statCell(
                title: "Builds",
                value: "\(state.apps.count)",
                subtitle: "\(debugCount)D · \(profileCount)P",
                accent: .accentColor
            )
            Divider().frame(height: 24)
            statCell(
                title: "Running",
                value: "\(runningCount)",
                subtitle: runningCount > 0 ? "Active" : "Idle",
                accent: runningCount > 0 ? .green : .secondary
            )
            Divider().frame(height: 24)
            statCell(
                title: "Footprint",
                value: ByteFormatting.format(state.totalBytes),
                subtitle: state.modeFilter == .all ? "All modes" : state.modeFilter.displayName,
                accent: .orange
            )
        }
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private func statCell(title: String, value: String, subtitle: String, accent: Color) -> some View {
        VStack(spacing: 1) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                if title == "Running" && value != "0" {
                    Circle().fill(accent).frame(width: 6, height: 6)
                }
                Text(value)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
            }
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("Search name, bundle ID, or path…", text: $state.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                if !state.searchText.isEmpty {
                    Button {
                        state.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            HStack {
                Picker("Mode", selection: $state.modeFilter) {
                    ForEach(BuildModeFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 215)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Picker("Sort", selection: $state.sortOrder) {
                        ForEach(AppSortOrder.allCases) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 92)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func statusBannerView(_ banner: StatusBanner) -> some View {
        HStack(spacing: 8) {
            Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(banner.isError ? .orange : .green)
            Text(banner.message)
                .font(.system(size: 11.5))
                .lineLimit(2)
            Spacer()
            Button {
                withAnimation { state.statusBanner = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background((banner.isError ? Color.orange : Color.green).opacity(0.12))
    }

    @ViewBuilder
    private var appListSection: some View {
        if state.isScanning && state.apps.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text("Scanning Flutter Debug & Profile builds…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.filteredApps.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: state.apps.isEmpty ? "macwindow.badge.plus" : "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.75))
                Text(state.apps.isEmpty ? "No Flutter Debug/Profile apps found" : "No matching builds")
                    .font(.system(size: 13.5, weight: .semibold))
                Text(state.apps.isEmpty
                     ? "Add your Flutter project directories in Settings or build one with `flutter build macos --debug`."
                     : "Try adjusting your search query or mode filter.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                if state.apps.isEmpty {
                    Button {
                        state.showingSettings = true
                    } label: {
                        Label("Configure Scan Folders", systemImage: "folder.badge.plus")
                    }
                    .controlSize(.small)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(state.filteredApps) { app in
                        AppRowView(
                            app: app,
                            isExpanded: state.expandedAppID == app.id,
                            hasSharedContainer: state.sharedBundleIDs.contains(app.bundleIdentifier),
                            onToggleExpand: {
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    state.expandedAppID = (state.expandedAppID == app.id) ? nil : app.id
                                }
                            },
                            onResetData: {
                                state.pendingRequest = .resetData(app)
                            },
                            onCleanBuild: {
                                state.pendingRequest = .cleanBuild(app)
                            },
                            onReveal: { url in
                                state.revealInFinder(url)
                            },
                            onQuitApp: {
                                state.quitApp(app)
                            }
                        )
                    }
                }
                .padding(12)
            }
        }
    }

    private var footerBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button("Older than 7 days…") {
                    state.pendingRequest = .cleanStale(days: 7)
                }
                Button("Older than 14 days…") {
                    state.pendingRequest = .cleanStale(days: 14)
                }
                Button("Older than 30 days…") {
                    state.pendingRequest = .cleanStale(days: 30)
                }
            } label: {
                Label("Clean Stale", systemImage: "sparkles")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(state.apps.isEmpty)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
