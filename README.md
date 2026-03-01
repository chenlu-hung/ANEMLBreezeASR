# ANEMLBreezeASR - 自動字幕生成 macOS 應用程式

ANEMLBreezeASR 是一個原生 macOS SwiftUI 應用，可以自動為影片生成字幕、使用 LLM 校正字幕，並將字幕燒錄到影片中。

## 功能特色

- 📹 **支援多種影片格式**: MP4, MOV, AVI 等（支援批次多檔處理）
- 🎤 **語音辨識**: 使用 WhisperKit + Breeze ASR (Breeze-ASR-25) 模型進行 ASR，針對台灣中文優化
- 🌍 **多語言支援**: 支援 13 種語言（中文、英文、日文、韓文、西班牙文等）
- 🔄 **自動翻譯**: 使用 LLM 將字幕翻譯成其他語言
- 🤖 **LLM 校正**: 使用 OpenAI 或相容 API 自動校正字幕（自動分塊處理長字幕，推薦使用 Gemini 3 Flash）
- 📂 **批次處理**: 支援一次選取多個影片或 SRT 檔案依序批次處理
- 📝 **SRT 匯出**: 生成標準 SRT 字幕檔案
- 🔥 **字幕燒錄**: 將字幕永久嵌入影片中
- ⚙️ **彈性設定**: 支援自訂 LLM endpoint (OpenAI, 本地 LLM 等)

## 系統需求

- macOS 13.0 (Ventura) 或更高版本
- Apple Silicon (M1/M2/M3) 或 Intel Mac
- FFmpeg (必須安裝)
- 至少 4GB 可用磁碟空間（用於 Breeze ASR 模型，約 3GB）

## 安裝步驟

### 1. 安裝 FFmpeg

使用 Homebrew 安裝 FFmpeg:

```bash
brew install ffmpeg
```

或從 [FFmpeg 官網](https://ffmpeg.org/download.html) 下載安裝。

### 2. 編譯獨立應用程式

#### 方法一：使用自動化腳本（推薦）

```bash
cd /Users/chenlu-hung/Documents/Projects/ANEMLBreezeASR
./build-app.sh
```

這會建立 `build/ANEMLBreezeASR.app`，可以直接雙擊執行。

#### 方法二：安裝到 Applications 資料夾

```bash
./build-app.sh
cp -r build/ANEMLBreezeASR.app /Applications/
```

之後可以在 Launchpad 或 Applications 資料夾中找到 ANEMLBreezeASR。

#### 方法三：手動編譯（開發用）

```bash
swift build -c release
.build/release/ANEMLBreezeASR
```

### 3. 執行應用程式

雙擊 `build/ANEMLBreezeASR.app` 或從 Applications 資料夾啟動。

## 使用說明

### 生成字幕流程

1. **開啟應用程式**，切換到「生成字幕」分頁
2. **選擇影片檔案**
3. **設定語言選項**:
   - **影片語言**: 選擇影片的語言（預設「自動偵測」）
   - **啟用翻譯**: 如需將字幕翻譯成其他語言，勾選此選項
   - **翻譯為**: 選擇目標語言（如將中文影片翻譯成英文）
4. **點擊「Start Processing」**（可一次選取多個影片批次處理）:
   - 自動提取音訊 (轉為 16kHz WAV)
   - 使用 Breeze ASR 模型進行語音辨識（首次使用會下載模型，約 3GB；若已安裝 VibeTyping 則自動共用模型）
   - 使用 LLM 校正/翻譯字幕（需先設定 API）
   - 生成校正後的 SRT 檔案
5. 處理完成後可點擊「Show in Finder」查看輸出的字幕檔案

### 支援的語言

- 🌏 **亞洲語言**: 中文、日文、韓文、Hindi
- 🌍 **歐洲語言**: English、Español、Français、Deutsch、Italiano、Português、Русский
- 🌎 **其他**: العربية (阿拉伯文)
- 🤖 **自動偵測**: 讓 Whisper 自動判斷語言

### LLM 設定

切換到「設定」分頁進行設定:

#### Google Gemini（推薦）
- **API Key**: 您的 Google AI API 金鑰（從 [Google AI Studio](https://aistudio.google.com/apikey) 取得）
- **API Endpoint**: `https://generativelanguage.googleapis.com/v1beta/openai`
- **Model Name**: `gemini-3-flash`（推薦）或 `gemini-2.5-flash`

> 💡 **推薦使用 Gemini 3 Flash**：速度快、成本低，且字幕校正與翻譯品質優秀，非常適合批次處理大量字幕檔案。

#### OpenAI API
- **API Key**: 您的 OpenAI API 金鑰
- **API Endpoint**: `https://api.openai.com/v1`
- **Model Name**: `gpt-4o-mini` 或 `gpt-4o`

#### 本地 LLM（如 Ollama, LM Studio）
- **API Key**: 可留空或填入任意值
- **API Endpoint**: `http://localhost:1234/v1` （依您的本地服務調整）
- **Model Name**: 您的模型名稱（如 `llama3`）

#### System Prompt
自訂 LLM 的指令，預設會要求校正語法、標點符號，但保持原意。

### 燒錄字幕

1. 切換到「燒錄字幕」分頁
2. **選擇影片檔案**
3. **選擇 SRT 字幕檔案**
4. **輸入輸出檔名**（不含副檔名）
5. **點擊「Burn Subtitles」**
   - 字幕會永久燒錄到影片中
   - 輸出格式與輸入影片格式相同

## 專案架構

```
ANEMLBreezeASR/
├── Package.swift                 # SPM 設定檔
├── Sources/ANEMLBreezeASR/
│   ├── ANEMLBreezeASRApp.swift          # 應用程式入口
│   ├── Models/                  # 資料模型
│   ├── Services/                # 核心服務
│   │   ├── FFmpegService.swift       # FFmpeg 呼叫
│   │   ├── WhisperKitService.swift   # 語音辨識
│   │   ├── LLMService.swift          # LLM API
│   │   └── SubtitleService.swift     # SRT 處理
│   ├── ViewModels/              # MVVM 視圖模型
│   └── Views/                   # SwiftUI 介面
│       ├── ContentView.swift         # 主要 Tab 介面
│       ├── GenerateView.swift        # 字幕生成（批次）
│       ├── CorrectView.swift         # 字幕校正/翻譯（批次）
│       ├── BurnView.swift            # 字幕燒錄
│       └── SettingsView.swift        # 設定介面
```

## 技術棧

- **UI**: SwiftUI (macOS 13+)
- **ASR**: [WhisperKit](https://github.com/argmaxinc/WhisperKit) + [Breeze-ASR-25](https://huggingface.co/aoiandroid/Breeze-ASR-25_coreml) - 針對台灣中文優化的 CoreML 模型
- **LLM**: [MacPaw OpenAI](https://github.com/MacPaw/OpenAI) - OpenAI-compatible API client
- **字幕處理**: [SwiftSubtitles](https://github.com/dagronf/SwiftSubtitles) - SRT 讀寫
- **音訊/影片**: FFmpeg - 音訊提取與字幕燒錄

## 注意事項

1. **首次使用**: 第一次語音辨識時會下載 Breeze ASR 模型（約 3GB），請耐心等待。若已安裝 [VibeTyping](https://github.com/chenlu-hung/VibeTyping) 並下載過模型，會自動共用，無需重複下載
2. **LLM API**: 如不需要校正功能，可以不設定 LLM，會直接使用原始辨識結果
3. **FFmpeg 必須**: 請確保已安裝 FFmpeg，否則無法執行音訊提取與字幕燒錄
4. **進度追蹤**: 應用程式會顯示每個步驟的進度（包括 LLM 校正的分塊進度），請勿在處理過程中關閉應用程式
5. **長字幕自動分塊**: 較長的 SRT 字幕檔會自動分塊（每塊約 20k tokens）送至 LLM 處理，避免超過 context window 限制

## 常見問題

### Q: 首次啟動為何很慢？
A: 首次使用時會下載 Breeze ASR 模型（約 3GB），下載完成後會快取在 `~/Library/Application Support/ANEMLBreezeASR/HubCache/`。若已安裝 VibeTyping 並下載過相同模型，會自動偵測並共用，無需重複下載。

### Q: 支援哪些影片格式？
A: 支援 FFmpeg 能處理的所有格式，包括 MP4, MOV, AVI, MKV 等。

### Q: 可以不使用 LLM 校正嗎？
A: 可以，如果未設定 LLM API，會直接使用語音辨識的原始結果。

### Q: 如何使用本地 LLM？
A: 在 Settings 中設定您的本地 API endpoint（如 Ollama 的 `http://localhost:11434/v1`）和模型名稱即可。

### Q: 字幕不準確怎麼辦？
A: 可以匯出 SRT 後使用外部編輯器（如字幕編輯工具）修改，然後再使用「Burn Subtitles」功能燒錄到影片中。

## 授權

MIT License

## 貢獻

歡迎提交 Issue 或 Pull Request！
