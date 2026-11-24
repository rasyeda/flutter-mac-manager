import AppKit
import FlutterMacManagerCore
import SwiftUI

struct PillBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }
}

struct HoverIconButton: View {
    let systemImage: String
    var tint: Color = .secondary
    var disabled: Bool = false
    let helpText: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(disabled ? .secondary.opacity(0.4) : (isHovering ? tint : tint.opacity(0.85)))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovering && !disabled ? tint.opacity(0.14) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(helpText)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct StorageBreakdownBar: View {
    let appBytes: Int64
    let dataBytes: Int64
    let derivedBytes: Int64

    private var total: Double {
        max(Double(appBytes + dataBytes + derivedBytes), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                let width = geo.size.width
                let appWidth = max(width * (Double(appBytes) / total), appBytes > 0 ? 4 : 0)
                let dataWidth = max(width * (Double(dataBytes) / total), dataBytes > 0 ? 4 : 0)
                let derivedWidth = max(width * (Double(derivedBytes) / total), derivedBytes > 0 ? 4 : 0)

                HStack(spacing: 2) {
                    if appBytes > 0 {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.accentColor.opacity(0.85))
                            .frame(width: min(appWidth, width))
                    }
                    if dataBytes > 0 {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.orange.opacity(0.85))
                            .frame(width: min(dataWidth, width))
                    }
                    if derivedBytes > 0 {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.purple.opacity(0.8))
                            .frame(width: min(derivedWidth, width))
                    }
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
            .background(Capsule().fill(Color.primary.opacity(0.06)))

            HStack(spacing: 10) {
                legendItem(color: .accentColor, label: "App", bytes: appBytes)
                if dataBytes > 0 {
                    legendItem(color: .orange, label: "Data", bytes: dataBytes)
                }
                if derivedBytes > 0 {
                    legendItem(color: .purple, label: "DerivedData", bytes: derivedBytes)
                }
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
    }

    private func legendItem(color: Color, label: String, bytes: Int64) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.85))
                .frame(width: 6, height: 6)
            Text("\(label) \(ByteFormatting.format(bytes))")
                .monospacedDigit()
        }
    }
}

extension DataLocationKind {
    var sfSymbol: String {
        switch self {
        case .container: return "shippingbox"
        case .applicationSupport: return "folder.badge.gearshape"
        case .preferences: return "slider.horizontal.3"
        case .caches: return "memorychip"
        case .savedState: return "clock.arrow.circlepath"
        case .httpStorages: return "network"
        case .derivedData: return "hammer"
        }
    }
}

enum PathFormatting {
    static func abbreviateHome(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
