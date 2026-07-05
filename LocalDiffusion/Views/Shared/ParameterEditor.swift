import SwiftUI

struct ParameterEditor: View {
    @Binding var parameters: GenerationParameters
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let sizePresets: [(String, Int, Int)] = [
        ("512 x 512", 512, 512),
        ("768 x 768", 768, 768),
        ("832 x 1216", 832, 1216),
        ("1024 x 1024", 1024, 1024)
    ]

    var body: some View {
        Section("Parameters") {
            Button {
                let currentPrompt = parameters.prompt
                let currentNegativePrompt = parameters.negativePrompt
                parameters = GenerationParameters(
                    prompt: currentPrompt,
                    negativePrompt: currentNegativePrompt
                )
            } label: {
                Label("Reset Defaults", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(SciFiSecondaryButtonStyle())

            stepsControl
            cfgControl
            seedControl
            sizePresetControl
            widthControl
            heightControl
            samplerControl
        }
        .listRowBackground(SciFiTheme.panel)
    }

    private var stepsControl: some View {
        Stepper(
            "Steps: \(parameters.steps)",
            value: $parameters.steps,
            in: GenerationParameters.minimumSteps...GenerationParameters.maximumSteps
        )
        .foregroundStyle(SciFiTheme.primaryText)
        .accessibilityLabel("Steps")
        .accessibilityValue("\(parameters.steps)")
    }

    private var cfgControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            parameterHeader(title: "CFG", value: cfgValueText)
            Slider(
                value: $parameters.cfgScale,
                in: GenerationParameters.minimumCFGScale...GenerationParameters.maximumCFGScale,
                step: 0.5
            )
            .tint(SciFiTheme.cyan)
            .accessibilityLabel("CFG Scale")
            .accessibilityValue(cfgValueText)
        }
        .foregroundStyle(SciFiTheme.primaryText)
    }

    @ViewBuilder
    private var seedControl: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                seedField
                randomizeSeedButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(SciFiTheme.primaryText)
        } else {
            HStack {
                seedField
                randomizeSeedButton
            }
            .foregroundStyle(SciFiTheme.primaryText)
        }
    }

    private var seedField: some View {
        TextField("Seed", value: $parameters.seed, format: .number)
            .keyboardType(.numberPad)
            .accessibilityLabel("Seed")
            .accessibilityValue("\(parameters.seed)")
    }

    @ViewBuilder
    private var randomizeSeedButton: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Button(action: randomizeSeed) {
                Label("Randomize Seed", systemImage: "dice")
            }
            .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.amber))
            .tint(SciFiTheme.amber)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
        } else {
            Button(action: randomizeSeed) {
                Label("Randomize Seed", systemImage: "dice")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(SciFiSecondaryButtonStyle(color: SciFiTheme.amber))
            .tint(SciFiTheme.amber)
            .frame(minWidth: 44, minHeight: 44)
        }
    }

    @ViewBuilder
    private var sizePresetControl: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text("Size")
                sizePresetMenu
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(SciFiTheme.primaryText)
        } else {
            HStack {
                Text("Size")
                Spacer()
                sizePresetMenu
            }
            .foregroundStyle(SciFiTheme.primaryText)
        }
    }

    private var sizePresetMenu: some View {
        Menu(currentSizeText) {
            ForEach(sizePresets, id: \.0) { preset in
                Button(preset.0) {
                    parameters.width = preset.1
                    parameters.height = preset.2
                }
            }
        }
        .tint(SciFiTheme.cyan)
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityLabel("Canvas size preset")
        .accessibilityValue(currentSizeText)
    }

    private var widthControl: some View {
        Stepper(
            "Width: \(parameters.width)",
            value: widthBinding,
            in: GenerationParameters.minimumDimension...GenerationParameters.maximumDimension,
            step: GenerationParameters.dimensionStep
        )
        .foregroundStyle(SciFiTheme.primaryText)
        .accessibilityLabel("Width")
        .accessibilityValue("\(parameters.width)")
    }

    private var heightControl: some View {
        Stepper(
            "Height: \(parameters.height)",
            value: heightBinding,
            in: GenerationParameters.minimumDimension...GenerationParameters.maximumDimension,
            step: GenerationParameters.dimensionStep
        )
        .foregroundStyle(SciFiTheme.primaryText)
        .accessibilityLabel("Height")
        .accessibilityValue("\(parameters.height)")
    }

    private var samplerControl: some View {
        Picker("Sampler", selection: samplerBinding) {
            ForEach(Sampler.allCases) { sampler in
                Text(sampler.rawValue).tag(sampler.rawValue)
            }
        }
        .tint(SciFiTheme.cyan)
        .accessibilityLabel("Sampler")
        .accessibilityValue(parameters.samplerRawValue)
    }

    @ViewBuilder
    private func parameterHeader(title: String, value: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(value)
                    .foregroundStyle(SciFiTheme.secondaryText)
            }
        } else {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .foregroundStyle(SciFiTheme.secondaryText)
            }
        }
    }

    private var cfgValueText: String {
        parameters.cfgScale.formatted(.number.precision(.fractionLength(1)))
    }

    private func randomizeSeed() {
        parameters.seed = Int.random(in: 0...Int(Int32.max))
    }

    private var currentSizeText: String {
        "\(parameters.width) x \(parameters.height)"
    }

    private var widthBinding: Binding<Int> {
        Binding(
            get: { parameters.width },
            set: { parameters.width = normalizedDimension($0) }
        )
    }

    private var heightBinding: Binding<Int> {
        Binding(
            get: { parameters.height },
            set: { parameters.height = normalizedDimension($0) }
        )
    }

    private func normalizedDimension(_ value: Int) -> Int {
        GenerationParameters.normalizedDimension(value)
    }

    private var samplerBinding: Binding<String> {
        Binding(
            get: { parameters.samplerRawValue },
            set: { parameters.samplerRawValue = $0 }
        )
    }
}

struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(SciFiTheme.cyan)
                .frame(width: 64, height: 64)
                .background(SciFiTheme.panelStrong, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(SciFiTheme.cyan.opacity(0.28), lineWidth: 1)
                }

            Text(title)
                .font(.headline)
                .foregroundStyle(SciFiTheme.primaryText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(SciFiTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .sciFiPanel()
    }
}

struct BottomTabBarClearance: View {
    var body: some View {
        LinearGradient(
            colors: [
                SciFiTheme.backgroundTop.opacity(0.02),
                SciFiTheme.backgroundBottom.opacity(0.96),
                SciFiTheme.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
            .frame(height: 132)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct BottomTabBarClearanceModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .compact {
            content.safeAreaInset(edge: .bottom) {
                BottomTabBarClearance()
            }
        } else {
            content
        }
    }
}

extension View {
    func bottomTabBarClearance() -> some View {
        modifier(BottomTabBarClearanceModifier())
    }
}

extension ByteCountFormatter {
    static func fileSizeString(_ bytes: Int64) -> String {
        string(fromByteCount: bytes, countStyle: .file)
    }
}

enum SciFiTheme {
    static let backgroundTop = Color(red: 0.025, green: 0.035, blue: 0.070)
    static let backgroundBottom = Color(red: 0.035, green: 0.070, blue: 0.080)
    static let panel = Color(red: 0.060, green: 0.080, blue: 0.110).opacity(0.92)
    static let panelStrong = Color(red: 0.075, green: 0.105, blue: 0.145).opacity(0.96)
    static let panelSoft = Color(red: 0.050, green: 0.065, blue: 0.090).opacity(0.72)
    static let stroke = Color.white.opacity(0.10)
    static let primaryText = Color(red: 0.930, green: 0.975, blue: 1.000)
    static let secondaryText = Color(red: 0.640, green: 0.740, blue: 0.800)
    static let cyan = Color(red: 0.200, green: 0.920, blue: 1.000)
    static let mint = Color(red: 0.300, green: 0.950, blue: 0.650)
    static let amber = Color(red: 1.000, green: 0.700, blue: 0.280)
    static let magenta = Color(red: 0.940, green: 0.360, blue: 0.900)
    static let danger = Color(red: 1.000, green: 0.350, blue: 0.390)
}

struct SciFiBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SciFiTheme.backgroundTop,
                    Color(red: 0.035, green: 0.045, blue: 0.078),
                    SciFiTheme.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            SciFiGrid()
                .stroke(SciFiTheme.cyan.opacity(0.08), lineWidth: 0.7)
                .mask(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}

private struct SciFiGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 34

        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }

        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }

        return path
    }
}

struct SciFiPanelModifier: ViewModifier {
    var isHighlighted = false

    func body(content: Content) -> some View {
        content
            .background(isHighlighted ? SciFiTheme.panelStrong : SciFiTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                SciFiTheme.cyan.opacity(isHighlighted ? 0.55 : 0.28),
                                SciFiTheme.magenta.opacity(isHighlighted ? 0.22 : 0.10),
                                SciFiTheme.stroke
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: SciFiTheme.cyan.opacity(isHighlighted ? 0.18 : 0.08), radius: 14, x: 0, y: 8)
    }
}

struct SciFiScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(SciFiBackground().ignoresSafeArea())
            .tint(SciFiTheme.cyan)
            .toolbarBackground(SciFiTheme.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func sciFiScreen() -> some View {
        modifier(SciFiScreenModifier())
    }

    func sciFiPanel(isHighlighted: Bool = false) -> some View {
        modifier(SciFiPanelModifier(isHighlighted: isHighlighted))
    }

    func sciFiListRow() -> some View {
        listRowBackground(SciFiTheme.panel)
            .listRowSeparatorTint(SciFiTheme.stroke)
            .foregroundStyle(SciFiTheme.primaryText)
    }
}

struct SciFiStatusPill: View {
    let title: String
    var systemImage: String
    var color: Color = SciFiTheme.cyan

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(titleLineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
            .overlay {
                Capsule().stroke(color.opacity(0.35), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
    }

    private var titleLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }
}

struct SciFiMetric: View {
    let title: String
    let value: String
    var systemImage: String
    var color: Color = SciFiTheme.cyan

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    metricIcon
                    metricCopy
                }
            } else {
                HStack(spacing: 10) {
                    metricIcon
                    metricCopy
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SciFiTheme.panelSoft, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private var metricIcon: some View {
        Image(systemName: systemImage)
            .font(.headline)
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }

    private var metricCopy: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(SciFiTheme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SciFiTheme.primaryText)
                .lineLimit(valueLineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var valueLineLimit: Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }
}

struct SciFiPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.black : SciFiTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                isEnabled ? LinearGradient(
                    colors: [SciFiTheme.cyan, SciFiTheme.mint],
                    startPoint: .leading,
                    endPoint: .trailing
                ) : LinearGradient(
                    colors: [SciFiTheme.panelSoft, SciFiTheme.panelSoft],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled ? SciFiTheme.cyan.opacity(0.35) : SciFiTheme.stroke, lineWidth: 1)
            }
            .opacity(configuration.isPressed && isEnabled ? 0.75 : 1)
            .shadow(
                color: SciFiTheme.cyan.opacity(isEnabled ? (configuration.isPressed ? 0.12 : 0.30) : 0),
                radius: 12,
                x: 0,
                y: 6
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .hoverEffect(.highlight, isEnabled: isEnabled)
    }
}

struct SciFiSecondaryButtonStyle: ButtonStyle {
    var color: Color = SciFiTheme.cyan
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let resolvedColor = isEnabled ? color : SciFiTheme.secondaryText

        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(resolvedColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(resolvedColor.opacity(configuration.isPressed && isEnabled ? 0.20 : 0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(resolvedColor.opacity(isEnabled ? 0.35 : 0.22), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .hoverEffect(.highlight, isEnabled: isEnabled)
    }
}
