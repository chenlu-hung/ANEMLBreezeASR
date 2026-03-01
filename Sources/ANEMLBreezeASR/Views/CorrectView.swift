import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CorrectView: View {
    @StateObject private var viewModel = CorrectViewModel()

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("校正/翻譯字幕")
                .font(.title)
                .fontWeight(.bold)

            // SRT File Selection
            GroupBox {
                VStack(spacing: 12) {
                    if viewModel.hasFiles {
                        ForEach(Array(viewModel.srtFiles.enumerated()), id: \.element.id) { index, file in
                            HStack(spacing: 8) {
                                fileStatusIcon(for: file, at: index)
                                Text(file.fileName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                        }
                        HStack {
                            Spacer()
                            Button("重新選擇") {
                                selectSRTFiles()
                            }
                            .disabled(viewModel.state.isProcessing)
                        }
                    } else {
                        Button("選擇 SRT 檔案") {
                            selectSRTFiles()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } label: {
                Label(
                    viewModel.srtFiles.count > 1
                        ? "SRT Files (\(viewModel.srtFiles.count) 個檔案)"
                        : "SRT File",
                    systemImage: "doc.circle"
                )
            }

            // Language Settings
            GroupBox {
                VStack(spacing: 16) {
                    // Source Language
                    HStack {
                        Text("字幕語言:")
                            .frame(width: 100, alignment: .leading)
                        Picker("", selection: $viewModel.languageSettings.sourceLanguage) {
                            ForEach(SupportedLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(viewModel.state.isProcessing)
                    }

                    // Translation Toggle
                    Toggle("啟用翻譯", isOn: Binding(
                        get: { viewModel.languageSettings.enableTranslation },
                        set: { newValue in
                            viewModel.languageSettings.enableTranslation = newValue
                            if newValue && viewModel.languageSettings.targetLanguage == nil {
                                viewModel.languageSettings.targetLanguage = .english
                            }
                        }
                    ))
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
            if viewModel.state.isProcessing || viewModel.state == .completed || !viewModel.statusMessages.isEmpty {
                GroupBox {
                    VStack(spacing: 12) {
                        // Batch progress description
                        if viewModel.srtFiles.count > 1 && viewModel.state.isProcessing {
                            HStack {
                                Text(viewModel.batchProgressDescription)
                                    .font(.headline)
                                Spacer()
                            }
                        } else {
                            HStack {
                                Text(viewModel.state.description)
                                    .font(.headline)
                                Spacer()
                            }
                        }

                        // Progress Bar
                        if let progress = viewModel.state.progressValue {
                            ProgressView(value: progress, total: 1.0)
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Status History
                        if !viewModel.statusMessages.isEmpty {
                            Divider()
                            ScrollViewReader { proxy in
                                ScrollView(.vertical, showsIndicators: true) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(Array(viewModel.statusMessages.enumerated()), id: \.offset) { index, message in
                                            Text(message)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .id(index)
                                        }
                                    }
                                    .padding(.trailing, 4)
                                }
                                .frame(height: min(CGFloat(viewModel.statusMessages.count) * 20, 120))
                                .onChange(of: viewModel.statusMessages.count) { _ in
                                    withAnimation {
                                        if let last = viewModel.statusMessages.indices.last {
                                            proxy.scrollTo(last, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Label("Processing Status", systemImage: "gearshape.2")
                }
            }

            // Error Display (only for global errors like LLM not configured)
            if case .error(let message) = viewModel.state, !viewModel.hasFiles || viewModel.successCount == 0 {
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

            // Output Files
            if case .completed = viewModel.state {
                GroupBox {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.srtFiles.filter({ $0.isCompleted })) { file in
                                if let correctedURL = file.correctedURL {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundColor(.green)
                                        Text("校正檔：\(correctedURL.lastPathComponent)")
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Button("Show in Finder") {
                                            NSWorkspace.shared.activateFileViewerSelecting([correctedURL])
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                                if let translatedURL = file.translatedURL {
                                    HStack {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundColor(.blue)
                                        Text("翻譯檔：\(translatedURL.lastPathComponent)")
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Button("Show in Finder") {
                                            NSWorkspace.shared.activateFileViewerSelecting([translatedURL])
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                            }

                            // Show failed files
                            ForEach(viewModel.srtFiles.filter({ $0.isFailed })) { file in
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("\(file.fileName)：\(file.error ?? "未知錯誤")")
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }

                            // Summary for multi-file
                            if viewModel.srtFiles.count > 1 {
                                Divider()
                                Text("\(viewModel.successCount)/\(viewModel.srtFiles.count) 檔案處理成功")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                } label: {
                    Label("Output Files", systemImage: "folder")
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button("開始校正") {
                    Task {
                        await viewModel.startCorrection()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.hasFiles || viewModel.state.isProcessing)

                if case .completed = viewModel.state {
                    Button("選擇新檔案") {
                        selectSRTFiles()
                    }
                    .buttonStyle(.bordered)
                }

                if case .error = viewModel.state {
                    Button("選擇其他檔案") {
                        selectSRTFiles()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(32)
    }

    private func fileStatusIcon(for file: SRTFileResult, at index: Int) -> some View {
        Group {
            if file.isFailed {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            } else if file.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if viewModel.state.isProcessing && index == viewModel.currentFileIndex {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
    }

    private func selectSRTFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.srt]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "選擇一個或多個 SRT 字幕檔進行校正/翻譯"

        if panel.runModal() == .OK, !panel.urls.isEmpty {
            viewModel.selectSRTs(urls: panel.urls)
        }
    }
}
