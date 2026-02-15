# ANEMLBreezeASR 更新日誌

## [1.1.0] - 2025-02-15

### ✨ 新增功能

#### 🌍 多語言支援
- 新增語言選擇功能，支援 13 種語言
  - 亞洲語言：中文、日文、韓文、Hindi
  - 歐洲語言：English、Español、Français、Deutsch、Italiano、Português、Русский
  - 其他：العربية (阿拉伯文)
- 新增「自動偵測」選項，讓 Whisper 自動判斷影片語言

#### 🔄 自動翻譯
- 新增字幕翻譯功能
- 可將語音辨識結果翻譯成任何支援的語言
- 翻譯時保持原始時間碼不變
- 整合進 LLM 校正流程

#### 🎨 UI 改進
- 在「Generate Subtitles」頁面新增語言設定區塊
  - 影片語言選擇器（Picker）
  - 翻譯開關（Toggle）
  - 目標語言選擇器（條件顯示）
- 使用 GroupBox 組織 UI，更清晰易用

#### 💾 設定持久化
- 語言設定自動儲存至 UserDefaults
- 下次開啟應用程式時自動載入上次設定
- 獨立的語言設定管理（與 LLM 設定分離）

### 🔧 技術改進

#### 架構優化
- 新增 `LanguageSettings.swift` 模型
  - 定義 `SupportedLanguage` 枚舉
  - 管理翻譯狀態與目標語言
  - 自動生成翻譯 prompt

#### 服務更新
- `WhisperKitService`: 支援語言參數傳遞
- `LLMService`: 支援語言設定與翻譯 prompt
- `SettingsService`: 擴展支援語言設定的儲存/載入

#### ViewModel 更新
- `MainViewModel`: 整合語言設定
  - 載入並管理語言偏好
  - 傳遞語言參數至 Whisper
  - 傳遞翻譯設定至 LLM

### 📚 文件更新
- 更新 README.md：新增多語言與翻譯功能說明
- 更新 QUICKSTART.md：新增翻譯使用步驟
- 新增 FEATURES.md：詳細的功能說明與使用場景
- 新增 CHANGELOG.md：記錄版本更新

### 🐛 修復問題
- 無重大 bug 修復（新功能版本）

---

## [1.0.0] - 2025-02-15

### ✨ 初始版本

#### 核心功能
- 📹 影片檔案選擇與處理
- 🎤 WhisperKit 語音辨識（Whisper Large v3）
- 🤖 LLM 字幕校正（OpenAI-compatible）
- 📝 SRT 字幕生成與匯出
- 🔥 FFmpeg 字幕燒錄

#### UI 功能
- SwiftUI 原生 macOS 介面
- 三分頁設計：
  1. Generate Subtitles - 字幕生成
  2. Burn Subtitles - 字幕燒錄
  3. Settings - LLM 設定
- 即時進度顯示
- 錯誤提示與處理

#### 技術架構
- Swift Package Manager 專案結構
- MVVM 架構設計
- 服務層封裝（FFmpeg、WhisperKit、LLM、Subtitle）
- UserDefaults 設定持久化

#### 依賴套件
- WhisperKit 0.15.0
- SwiftSubtitles 2.2.0
- MacPaw OpenAI 0.4.7

#### 支援系統
- macOS 13.0 (Ventura) 或更高版本
- Apple Silicon 與 Intel Mac

#### 文件
- README.md - 完整使用說明
- QUICKSTART.md - 快速開始指南
- build-app.sh - 自動化編譯腳本
- .gitignore - Git 忽略設定

---

## 未來計劃

### v1.2.0 (計劃中)
- [ ] 批次處理多個影片
- [ ] 自訂 Whisper 模型選擇
- [ ] 字幕預覽功能
- [ ] 更多字幕格式支援（VTT, ASS）

### v1.3.0 (計劃中)
- [ ] 字幕樣式自訂（字體、大小、顏色）
- [ ] 內建字幕編輯器
- [ ] 拖放支援
- [ ] 快捷鍵設定

### v2.0.0 (長期計劃)
- [ ] 影片播放器整合
- [ ] 即時字幕顯示
- [ ] 雙語字幕支援
- [ ] 雲端同步功能
