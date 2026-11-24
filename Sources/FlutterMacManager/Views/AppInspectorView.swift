import AppKit
import FlutterMacManagerCore
import SwiftUI

struct AppInspectorView: View {
    let app: FlutterMacApp
    let hasSharedContainer: Bool
    let onReveal: (URL) -> Void
    let onResetData: () -> Void
    let onCleanBuild: () -> Void

    @State private var copiedPath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Version \(app.versionSummary)", systemImage: "tag")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                if let pid = app.runningPID {
                    PillBadge(text: "Running · PID \(pid)", color: .green, icon: "circle.fill")
                } else {
                    Text(app.origin.rawValue)
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
            }

            StorageBreakdownBar(
                appBytes: app.appSizeBytes,
                dataBytes: app.dataSizeBytes,
                derivedBytes: app.derivedDataSizeBytes
            )

            VStack(spacing: 4) {
                locationRow(
                    title: "App Bundle",
                    icon: "app.dashed",
                    path: app.appURL.path,
                    size: app.appSizeBytes,
                    isReadable: true,
                    url: app.appURL
                )

                ForEach(app.derivedDataLocations) { loc in
                    locationRow(
                        title: loc.kind.rawValue,
                        icon: loc.kind.sfSymbol,
                        path: loc.url.path,
                        size: loc.sizeBytes,
                        isReadable: loc.isReadable,
                        url: loc.url
                    )
                }
            }

            if !app.dataLocations.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("LIBRARY DATA")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(.secondary)
                        if hasSharedContainer {
                            PillBadge(
                                text: "Shared across Debug & Profile",
                                color: .orange,
                                icon: "exclamationmark.triangle.fill"
                            )
                        }
                    }

                    VStack(spacing: 4) {
                        ForEach(app.dataLocations) { loc in
                            locationRow(
                                title: loc.kind.rawValue,
                                icon: loc.kind.sfSymbol,
                                path: loc.url.path,
                                size: loc.sizeBytes,
                                isReadable: loc.isReadable,
                                url: loc.url
                            )
                        }
                    }
                }
            } else {
                Text("No ~/Library data found for this bundle ID.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    onReveal(app.appURL)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .controlSize(.small)

                Spacer()

                Button(action: onResetData) {
                    Label("Reset Data…", systemImage: "arrow.counterclockwise")
                }
                .controlSize(.small)
                .disabled(app.dataLocations.isEmpty)

                Button(role: .destructive, action: onCleanBuild) {
                    Label("Clean Build…", systemImage: "trash")
                }
                .controlSize(.small)
            }
            .padding(.top, 2)
        }
    }

    private func locationRow(
        title: String,
        icon: String,
        path: String,
        size: Int64,
        isReadable: Bool,
        url: URL
    ) -> some View {
        HStack(alignment: .center, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Text(PathFormatting.abbreviateHome(path))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isReadable {
                Text(ByteFormatting.format(size))
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundColor(.secondary)
            } else {
                PillBadge(text: "No access", color: .orange)
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
                copiedPath = path
                Task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    if copiedPath == path { copiedPath = nil }
                }
            } label: {
                Image(systemName: copiedPath == path ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10.5))
                    .foregroundColor(copiedPath == path ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help("Copy path")

            Button {
                onReveal(url)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
        )
    }
}
