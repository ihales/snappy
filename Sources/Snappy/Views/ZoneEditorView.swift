import AppKit
import SwiftUI

struct ZoneEditorView: View {
    @Binding var zone: SnapZone
    let shortcutHasConflict: Bool

    private var currentDisplayWidth: Double {
        Double(NSScreen.main?.frame.width ?? 0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                TextField("Hotspot name", text: $zone.name)
                    .font(.title2.weight(.semibold))
                    .textFieldStyle(.plain)

                DisplayPreviewView(zone: $zone)
                    .frame(height: 220)

                Text("Drag the orange drop zone around the edge. Drag the blue frame or its corner handles to set the resulting window frame.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                    GridRow {
                        SectionLabel(title: "Drop zone", subtitle: "Fixed-depth activation area along a display edge")
                        HStack(spacing: 14) {
                            Picker("Edge", selection: $zone.activationEdge) {
                                ForEach(SnapEdge.allCases) { edge in
                                    Text(edge.title).tag(edge)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)

                            NumberField(label: "At", value: $zone.activationPosition, suffix: "%")
                        }
                    }

                    Divider().gridCellColumns(2)

                    GridRow {
                        SectionLabel(
                            title: "Keyboard shortcut",
                            subtitle: "Press after the global leader shortcut"
                        )
                        ShortcutKeyField(value: $zone.shortcutKey)
                    }

                    if shortcutHasConflict {
                        GridRow {
                            Color.clear.frame(width: 230, height: 1)
                            Label("This key is also assigned to another hotspot.", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Divider().gridCellColumns(2)

                    GridRow {
                        SectionLabel(title: "Window position", subtitle: "Destination from the usable area’s top-left")
                        PercentagePair(
                            firstLabel: "X",
                            firstValue: $zone.targetX,
                            secondLabel: "Y",
                            secondValue: $zone.targetY
                        )
                    }

                    GridRow {
                        SectionLabel(title: "Window size", subtitle: "Destination size")
                        PercentagePair(
                            firstLabel: "W",
                            firstValue: $zone.targetWidth,
                            secondLabel: "H",
                            secondValue: $zone.targetHeight
                        )
                    }

                    Divider().gridCellColumns(2)

                    GridRow {
                        SectionLabel(title: "Display widths", subtitle: "Use 0 for no limit; values are logical points")
                        HStack(spacing: 14) {
                            NumberField(label: "Min", value: $zone.minimumDisplayWidth, suffix: "pt")
                            NumberField(label: "Max", value: $zone.maximumDisplayWidth, suffix: "pt")
                        }
                    }
                }

                Label {
                    Text(widthSummary)
                } icon: {
                    Image(systemName: zone.isAvailable(forDisplayWidth: currentDisplayWidth) ? "checkmark.circle.fill" : "minus.circle.fill")
                        .foregroundStyle(zone.isAvailable(forDisplayWidth: currentDisplayWidth) ? .green : .secondary)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var widthSummary: String {
        let formattedWidth = currentDisplayWidth.formatted(.number.precision(.fractionLength(0)))
        if zone.isAvailable(forDisplayWidth: currentDisplayWidth) {
            return "Active on the current \(formattedWidth)-point display"
        }
        return "Inactive on the current \(formattedWidth)-point display"
    }
}

private struct ShortcutKeyField: View {
    @Binding var value: String?

    var body: some View {
        HStack(spacing: 8) {
            Text("⌃⌥E then")
                .foregroundStyle(.secondary)
            TextField("—", text: textBinding)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.body.monospaced().weight(.semibold))
                .frame(width: 48)
            if value != nil {
                Button("Clear") {
                    value = nil
                }
                .buttonStyle(.link)
            }
            Text("Letter or number")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { value?.uppercased() ?? "" },
            set: { newValue in
                value = SnapZone.normalizedShortcutKey(String(newValue.suffix(1)))
            }
        )
    }
}

private struct SectionLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).fontWeight(.medium)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 230, alignment: .leading)
    }
}

private struct PercentagePair: View {
    let firstLabel: String
    @Binding var firstValue: Double
    let secondLabel: String
    @Binding var secondValue: Double

    var body: some View {
        HStack(spacing: 14) {
            NumberField(label: firstLabel, value: $firstValue, suffix: "%")
            NumberField(label: secondLabel, value: $secondValue, suffix: "%")
        }
    }
}

private struct NumberField: View {
    let label: String
    @Binding var value: Double
    let suffix: String

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .foregroundStyle(.secondary)
            TextField(
                label,
                value: $value,
                format: .number.precision(.fractionLength(0...1))
            )
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .frame(width: 72)
            Text(suffix)
                .foregroundStyle(.secondary)
        }
    }
}
