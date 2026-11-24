import FlutterMacManagerCore
import SwiftUI

struct CleanupConfirmView: View {
    @ObservedObject var state: AppState
    let request: PendingCleanupRequest

    @State private var keepPreferences: Bool = false
    @State private var includeAppData: Bool = false
    @State private var stopRunningApps: Bool = true
    @State private var isExecuting: Bool = false

    private var plan: CleanupPlan {
        let moveToTrash = state.settings.moveToTrashByDefault
        switch request {
        case .resetData(let app):
            return state.cleanupService.makeResetDataPlan(
                for: app,
                keepPreferences: keepPreferences,
                moveToTrash: moveToTrash
            )
        case .cleanBuild(let app):
            return state.cleanupService.makeCleanBuildPlan(
                for: app,
                includeAppData: includeAppData,
                moveToTrash: moveToTrash
            )
        case .cleanStale(let days):
            return state.cleanupService.makeCleanStalePlan(
                from: state.apps,
                olderThanDays: days,
                includeAppData: includeAppData,
                moveToTrash: moveToTrash
            )
        }
    }

    var body: some View {
        let currentPlan = plan

        VStack(spacing: 0) {
            HStack {
                Button {
                    state.pendingRequest = nil
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .disabled(isExecuting)

                Spacer()

                Text(currentPlan.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                // Balance spacing
                Text("Back").opacity(0).font(.system(size: 12))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                // Safety mode banner
                HStack(spacing: 8) {
                    Image(systemName: currentPlan.moveToTrash ? "trash.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(currentPlan.moveToTrash ? .blue : .red)
                    Text(currentPlan.moveToTrash
                         ? "Items will be moved to macOS Trash and can be restored from Finder."
                         : "Permanent delete is enabled in Settings. Removed items cannot be undone.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((currentPlan.moveToTrash ? Color.blue : Color.red).opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Options card
                VStack(alignment: .leading, spacing: 7) {
                    switch request {
                    case .resetData:
                        Toggle("Keep Preferences (.plist)", isOn: $keepPreferences)
                    case .cleanBuild, .cleanStale:
                        Toggle("Also reset app data (Containers, Caches, Preferences)", isOn: $includeAppData)
                    }

                    if !currentPlan.runningApps.isEmpty {
                        Toggle(
                            "Quit \(currentPlan.runningApps.count) running app(s) before cleanup",
                            isOn: $stopRunningApps
                        )
                        .foregroundColor(.orange)
                    }
                }
                .font(.system(size: 12))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if currentPlan.items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.75))
                        Text("Nothing to remove")
                            .font(.subheadline.weight(.semibold))
                        Text("No matching files or folders were found for this action.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack {
                        Text("\(currentPlan.items.count) ITEM\(currentPlan.items.count == 1 ? "" : "S")")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Reclaim \(ByteFormatting.format(currentPlan.totalBytes))")
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 2)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 5) {
                            ForEach(currentPlan.items) { item in
                                HStack(alignment: .center, spacing: 8) {
                                    Image(systemName: item.kind?.sfSymbol ?? "app.dashed")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.red.opacity(0.85))
                                        .frame(width: 18)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.label)
                                            .font(.system(size: 11.5, weight: .medium))
                                            .lineLimit(1)
                                        Text(PathFormatting.abbreviateHome(item.url.path))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer()

                                    Text(ByteFormatting.format(item.sizeBytes))
                                        .font(.system(size: 10.5).monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }
                        }
                    }
                }
            }
            .padding(12)

            Divider()

            HStack {
                Button("Cancel") {
                    state.pendingRequest = nil
                }
                .disabled(isExecuting)

                Spacer()

                if isExecuting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }

                Button(role: .destructive) {
                    isExecuting = true
                    Task {
                        await state.execute(plan: currentPlan, stopRunningApps: stopRunningApps)
                        isExecuting = false
                    }
                } label: {
                    Label(
                        currentPlan.moveToTrash ? "Move to Trash" : "Delete Permanently",
                        systemImage: currentPlan.moveToTrash ? "trash" : "xmark.bin"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(currentPlan.items.isEmpty || isExecuting)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}
