import SwiftUI

// MARK: - Material You (M3) Tonal Palette

enum MaterialTheme {
    // Canvas & Surfaces (Soft, warm, light tones)
    static let surface = Color(hex: "#F9F9FB")
    static let surfaceVariant = Color(hex: "#F0F2F5")
    static let surfaceContainer = Color(hex: "#EAECEF")
    static let surfaceContainerHigh = Color(hex: "#E2E5E9")

    // Primary Accents (Soft slate-blue, calm and low contrast)
    static let primary = Color(hex: "#3E5C76")
    static let primaryContainer = Color(hex: "#D8E2EC")
    static let onPrimaryContainer = Color(hex: "#1D3547")

    // Secondary Accents (Warm neutral slate)
    static let secondary = Color(hex: "#5C6670")
    static let secondaryContainer = Color(hex: "#E5E9EC")
    static let onSecondaryContainer = Color(hex: "#262D33")

    // Semantic States (Soft pastels, never harsh)
    static let successContainer = Color(hex: "#E2F1E5")
    static let onSuccessContainer = Color(hex: "#1D542F")

    static let warningContainer = Color(hex: "#FEF2DE")
    static let onWarningContainer = Color(hex: "#7A4E00")

    static let errorContainer = Color(hex: "#FCE8E6")
    static let onErrorContainer = Color(hex: "#7C241D")

    // Typography Colors (Gentle charcoals, avoiding harsh pure black)
    static let textPrimary = Color(hex: "#1C1E21")
    static let textSecondary = Color(hex: "#4E545B")
    static let textTertiary = Color(hex: "#787F87")
}

// MARK: - Color Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Reusable Material You Components

/// Soft tonal card container with generous corner radius
struct MaterialCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaterialTheme.surfaceVariant)
        .foregroundColor(MaterialTheme.textPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Pill-shaped filter/toggle chip inspired by Material Design 3
struct MaterialChip: View {
    let title: String
    let isSelected: Bool
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? MaterialTheme.primaryContainer : MaterialTheme.surfaceVariant)
            .foregroundColor(isSelected ? MaterialTheme.onPrimaryContainer : MaterialTheme.textSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : MaterialTheme.surfaceContainerHigh, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Material You styled status badge
struct StatusBadge: View {
    let text: String
    var icon: String? = nil
    let style: BadgeStyle

    enum BadgeStyle {
        case success
        case warning
        case neutral
        case error

        var container: Color {
            switch self {
            case .success: return MaterialTheme.successContainer
            case .warning: return MaterialTheme.warningContainer
            case .neutral: return MaterialTheme.secondaryContainer
            case .error: return MaterialTheme.errorContainer
            }
        }

        var text: Color {
            switch self {
            case .success: return MaterialTheme.onSuccessContainer
            case .warning: return MaterialTheme.onWarningContainer
            case .neutral: return MaterialTheme.onSecondaryContainer
            case .error: return MaterialTheme.onErrorContainer
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(style.container)
        .foregroundColor(style.text)
        .clipShape(Capsule())
    }
}

/// Tonal Material Button
struct MaterialButton: View {
    let title: String
    var icon: String? = nil
    var isPrimary: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(isPrimary ? MaterialTheme.onPrimaryContainer : MaterialTheme.textPrimary)
                        .scaleEffect(0.9)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isPrimary ? MaterialTheme.primaryContainer : MaterialTheme.surfaceVariant)
            .foregroundColor(isPrimary ? MaterialTheme.onPrimaryContainer : MaterialTheme.textPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
