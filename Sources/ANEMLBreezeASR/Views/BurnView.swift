import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct BurnView: View {
    @StateObject private var viewModel = BurnViewModel()

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Burn Subtitles into Video")
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
                            .disabled(viewModel.isProcessing)
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

            // SRT Selection
            GroupBox {
                VStack(spacing: 12) {
                    if let srtURL = viewModel.srtFileURL {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.green)
                            Text(srtURL.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Button("Change") {
                                selectSRTFile()
                            }
                            .disabled(viewModel.isProcessing)
                        }
                    } else {
                        Button("Select SRT File") {
                            selectSRTFile()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } label: {
                Label("Subtitle File", systemImage: "text.bubble.fill")
            }

            // Output Filename
            GroupBox {
                VStack(spacing: 12) {
                    TextField("Output filename (without extension)", text: $viewModel.outputFileName)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isProcessing)

                    if let video = viewModel.videoFile, !viewModel.outputFileName.isEmpty {
                        HStack {
                            Text("Will be saved as:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(viewModel.outputFileName).\(video.fileExtension)")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                }
            } label: {
                Label("Output Settings", systemImage: "square.and.arrow.down")
            }

            // Progress Section
            if viewModel.isProcessing {
                GroupBox {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Burning subtitles...")
                                .font(.headline)
                            Spacer()
                        }

                        ProgressView(value: viewModel.progress, total: 1.0)

                        Text("\(Int(viewModel.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } label: {
                    Label("Progress", systemImage: "hourglass")
                }
            }

            // Completion Message
            if viewModel.isCompleted {
                GroupBox {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Subtitles burned successfully!")
                            .foregroundColor(.green)
                        Spacer()
                    }
                } label: {
                    Label("Status", systemImage: "checkmark.circle")
                }
            }

            // Error Display
            if let error = viewModel.errorMessage {
                GroupBox {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
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
                Button("Burn Subtitles") {
                    Task {
                        await viewModel.burnSubtitles()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.videoFile == nil ||
                         viewModel.srtFileURL == nil ||
                         viewModel.outputFileName.isEmpty ||
                         viewModel.isProcessing)

                if viewModel.isCompleted || viewModel.errorMessage != nil {
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
        panel.message = "Select a video file"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.selectVideo(url: url)

            // Auto-fill output filename if empty
            if viewModel.outputFileName.isEmpty {
                let filename = url.deletingPathExtension().lastPathComponent
                viewModel.outputFileName = "\(filename)_with_subtitles"
            }
        }
    }

    private func selectSRTFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.srt]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select an SRT subtitle file"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.selectSRT(url: url)
        }
    }
}
