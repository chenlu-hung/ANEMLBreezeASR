import SwiftUI

struct SettingsView: View {
    @State private var settings = LLMSettings.default
    @State private var settingsService = SettingsService()
    @State private var showSaveConfirmation = false

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("LLM Settings")
                .font(.title)
                .fontWeight(.bold)

            ScrollView {
                VStack(spacing: 20) {
                    // API Configuration
                    GroupBox {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("API Key")
                                    .font(.headline)
                                SecureField("Enter your API key", text: $settings.apiKey)
                                    .textFieldStyle(.roundedBorder)
                                Text("支援 OpenAI 相容 API（如 Gemini、OpenAI、Ollama 等）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("API Endpoint")
                                    .font(.headline)
                                TextField("https://generativelanguage.googleapis.com/v1beta/openai", text: $settings.apiEndpoint)
                                    .textFieldStyle(.roundedBorder)
                                Text("Full URL including protocol and path (e.g., http://localhost:1234/v1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Model Name")
                                    .font(.headline)
                                TextField("gemini-2.5-flash", text: $settings.modelName)
                                    .textFieldStyle(.roundedBorder)
                                Text("模型名稱（如 gemini-2.5-flash、gpt-4o-mini、或本地模型名稱）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Label("API Configuration", systemImage: "network")
                    }

                    // System Prompt
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("System Prompt")
                                .font(.headline)

                            TextEditor(text: $settings.systemPrompt)
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 200)
                                .border(Color.secondary.opacity(0.2), width: 1)

                            Text("Instructions for the LLM on how to correct subtitles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Label("Prompt Configuration", systemImage: "text.alignleft")
                    }

                    // Save Confirmation
                    if showSaveConfirmation {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Settings saved successfully!")
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button("Reset to Defaults") {
                    settings = .default
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save Settings") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        settings = settingsService.loadSettings()
    }

    private func saveSettings() {
        do {
            try settingsService.saveSettings(settings)
            showSaveConfirmation = true

            // Hide confirmation after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSaveConfirmation = false
            }
        } catch {
            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Save Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
