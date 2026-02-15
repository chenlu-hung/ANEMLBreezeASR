import SwiftUI
import AppKit

struct GenerateView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showExportPanel = false

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Generate Subtitles")
                .font(.title)
                .fontWeight(.bold)

            // Video Selection
            GroupBox {
                VStack(spacing: 12) {
                    if let video = viewModel.videoFile {
                        HStack {
                            Image(systemName: "video.fill")
                                .foregroundColor(.blue)
                            Text(video.fileName)
                                .lineLimit(1)
                            Spacer()
                            Button("Change") {
                                selectVideoFile()
                            }
                            .disabled(viewModel.state.isProcessing)
                        }
                    } else {
                        Button("Select Video File") {
                            selectVideoFile()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } label: {
                Label("Video File", systemImage: "video.circle")
            }

            // Language Settings
            GroupBox {
                VStack(spacing: 16) {
                    // Source Language
                    HStack {
                        Text("影片語言:")
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $viewModel.languageSettings.sourceLanguage) {
                            ForEach(SupportedLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(viewModel.state.isProcessing)
                    }

                    Divider()

                    // Translation Toggle
                    Toggle("啟用翻譯", isOn: $viewModel.languageSettings.enableTranslation)
                        .disabled(viewModel.state.isProcessing)

                    // Target Language (only when translation enabled)
                    if viewModel.languageSettings.enableTranslation {
                        HStack {
                            Text("翻譯為:")
                                .frame(width: 100, alignment: .leading)
                            Picker("", selection: Binding(
                                get: { viewModel.languageSettings.targetLanguage ?? .english },
                                set: { viewModel.languageSettings.targetLanguage = $0 }
                            )) {
                                ForEach(SupportedLanguage.allCases.filter { $0 != .auto }, id: \.self) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(viewModel.state.isProcessing)
                        }
                    }
                }
            } label: {
                Label("Language Settings", systemImage: "globe")
            }

            // Progress Section
            if viewModel.state.isProcessing || viewModel.state == .completed {
                GroupBox {
                    VStack(spacing: 16) {
                        // Status Text
                        HStack {
                            Text(viewModel.state.description)
                                .font(.headline)
                            Spacer()
                        }

                        // Progress Bar
                        if let progress = viewModel.state.progressValue {
                            ProgressView(value: progress, total: 1.0)
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if viewModel.state == .correctingWithLLM {
                            ProgressView()
                                .progressViewStyle(.linear)
                        }

                        // Segments Info
                        if !viewModel.transcriptionSegments.isEmpty {
                            HStack {
                                Text("Found \(viewModel.transcriptionSegments.count) segments")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                } label: {
                    Label("Processing Status", systemImage: "gearshape.2")
                }
            }

            // Error Display
            if case .error(let message) = viewModel.state {
                GroupBox {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(message)
                            .foregroundColor(.red)
                            .lineLimit(3)
                        Spacer()
                    }
                } label: {
                    Label("Error", systemImage: "xmark.circle")
                }
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 12) {
                Button("Start Processing") {
                    Task {
                        await viewModel.startProcessing()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.videoFile == nil || viewModel.state.isProcessing)

                if case .completed = viewModel.state {
                    Button("Export SRT") {
                        exportSRT()
                    }
                    .buttonStyle(.bordered)

                    Button("Reset") {
                        viewModel.reset()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(32)
    }

    private func selectVideoFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .avi]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a video file to generate subtitles"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.selectVideo(url: url)
        }
    }

    private func exportSRT() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.srt]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = viewModel.videoFile?.fileName.replacingOccurrences(of: ".\(viewModel.videoFile?.fileExtension ?? "")", with: ".srt") ?? "subtitles.srt"
        panel.message = "Save corrected SRT file"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try viewModel.exportSRT(to: url)
            } catch {
                // Show error alert
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}

// UTType extension for SRT files
import UniformTypeIdentifiers

extension UTType {
    static var srt: UTType {
        UTType(exportedAs: "public.srt")
    }
}
