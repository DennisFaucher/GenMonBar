import SwiftUI

struct SettingsView: View {
    @State private var widgets: [Widget] = ConfigStore.shared.config.widgets
    @State private var testing: [UUID: String] = [:]
    @State private var launchAtLogin = LoginItemManager.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach($widgets) { $widget in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField("🧪", text: $widget.emoji)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                            TextField("Command", text: $widget.command)
                                .font(.system(.body, design: .monospaced))
                            TextField("Every", value: $widget.interval, format: .number)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                            Text("sec").foregroundStyle(.secondary)
                            Toggle("", isOn: $widget.enabled).labelsHidden()
                            Button {
                                test(widget)
                            } label: {
                                Image(systemName: "play.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Run the command once and show its output")
                            Button {
                                widgets.removeAll { $0.id == widget.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                        }
                        if let preview = testing[widget.id] {
                            Text(preview)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Divider()
            HStack {
                Text("Config: \(ConfigStore.shared.configURL.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { newValue in
                        if !LoginItemManager.setEnabled(newValue) {
                            launchAtLogin = LoginItemManager.isEnabled
                        }
                    }
                Button {
                    widgets.append(Widget(emoji: "🔧", command: "", interval: 60))
                } label: {
                    Label("Add Widget", systemImage: "plus")
                }
                Button("Save") {
                    ConfigStore.shared.update { $0.widgets = widgets }
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(8)
        }
        .frame(minWidth: 540, minHeight: 380)
        .navigationTitle("GenMonBar")
    }

    private func test(_ widget: Widget) {
        testing[widget.id] = "Running…"
        WidgetRunner.run(widget.command) { result in
            if let error = result.error {
                testing[widget.id] = "⚠️ \(error)"
            } else {
                let out = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                testing[widget.id] = out.isEmpty ? "(no output)" : String(out.prefix(300))
            }
        }
    }
}
