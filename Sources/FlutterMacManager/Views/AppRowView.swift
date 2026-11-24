import AppKit
import FlutterMacManagerCore
import SwiftUI

struct AppRowView: View {
    let app: FlutterMacApp
    let isExpanded: Bool
    let hasSharedContainer: Bool
    let onToggleExpand: () -> Void
    let onResetData: () -> Void
    let onCleanBuild: () -> Void
    let onReveal: (URL) -> Void
    let onQuitApp: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 34, height: 34)
                    if app.isRunning {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color(nsColor: .controlBackgroundColor), lineWidth: 2)
                            )
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        PillBadge(
                            text: app.mode.displayName,
                            color: app.mode == .debug ? .orange : .blue
                        )

                        if app.origin == .derivedData {
                            PillBadge(text: "DerivedData", color: .purple)
                        }
                    }

                    Text(app.bundleIdentifier.isEmpty ? app.appURL.lastPathComponent : app.bundleIdentifier)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(ByteFormatting.format(app.appSizeBytes), systemImage: "shippingbox")
                        if app.dataSizeBytes > 0 {
                            Label(ByteFormatting.format(app.dataSizeBytes), systemImage: "internaldrive")
                        }
                        Label {
                            Text(app.lastModified, style: .relative)
                        } icon: {
                            Image(systemName: "clock")
                        }
                    }
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundColor(.secondary)
                    .labelStyle(.titleAndIcon)
                }

                Spacer(minLength: 4)

                HStack(spacing: 2) {
                    if app.isRunning {
                        HoverIconButton(
                            systemImage: "stop.circle.fill",
                            tint: .orange,
                            helpText: "Quit running app",
                            action: onQuitApp
                        )
                    }

                    HoverIconButton(
                        systemImage: "arrow.counterclockwise",
                        tint: .primary,
                        disabled: app.dataLocations.isEmpty,
                        helpText: app.dataLocations.isEmpty ? "No app data found" : "Reset app data",
                        action: onResetData
                    )

                    HoverIconButton(
                        systemImage: "trash",
                        tint: .red,
                        helpText: "Clean build",
                        action: onCleanBuild
                    )

                    HoverIconButton(
                        systemImage: isExpanded ? "chevron.up" : "chevron.down",
                        tint: .secondary,
                        helpText: isExpanded ? "Hide details" : "Inspect details",
                        action: onToggleExpand
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggleExpand)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)

            if isExpanded {
                Divider()
                    .padding(.horizontal, 10)
                AppInspectorView(
                    app: app,
                    hasSharedContainer: hasSharedContainer,
                    onReveal: onReveal,
                    onResetData: onResetData,
                    onCleanBuild: onCleanBuild
                )
                .padding(10)
                .background(Color.primary.opacity(0.02))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    isExpanded
                        ? Color.accentColor.opacity(0.35)
                        : (isHovered ? Color.primary.opacity(0.16) : Color.primary.opacity(0.08)),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.06 : 0.02), radius: isHovered ? 4 : 1, y: 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
