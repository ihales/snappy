import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var snapEngine: SnapEngine
    @AppStorage("snappingEnabled") private var snappingEnabled = true
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("hotspotLengthPercent") private var hotspotLength = 30.0

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable window snapping", isOn: $snappingEnabled)
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            }

            Section("Drop zones") {
                HStack {
                    Text("Edge length")
                    Spacer()
                    Slider(value: $hotspotLength, in: 4...100, step: 1)
                        .frame(width: 180)
                    Text("\(hotspotLength, format: .number.precision(.fractionLength(0)))%")
                        .monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                }

                Text("All drop zones extend 64 points into the display. Move each zone in the visual editor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard") {
                HStack {
                    Text("Activate Snappy mode")
                    Spacer()
                    Text("⌃⌥E")
                        .font(.body.monospaced().weight(.semibold))
                }

                Text("Press a hotspot’s assigned letter or number to snap the focused window. Arrow keys move it between displays; Escape cancels.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                HStack {
                    Label(
                        snapEngine.accessibilityGranted ? "Accessibility granted" : "Accessibility required",
                        systemImage: snapEngine.accessibilityGranted ? "checkmark.circle.fill" : "hand.raised.fill"
                    )
                    .foregroundStyle(snapEngine.accessibilityGranted ? .green : .orange)
                    Spacer()
                    if !snapEngine.accessibilityGranted {
                        Button("Grant Access") {
                            snapEngine.requestAccessibilityAccess()
                        }
                        Button("Open Settings") {
                            snapEngine.openAccessibilitySettings()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 440)
    }
}
