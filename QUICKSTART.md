# ANEMLBreezeASR 快速開始指南

## 🚀 快速安裝（5 分鐘）

### 步驟 1: 安裝 FFmpeg

```bash
brew install ffmpeg
```

### 步驟 2: 編譯應用程式

```bash
cd /Users/chenlu-hung/Documents/Projects/ANEMLBreezeASR
./build-app.sh
```

### 步驟 3: 啟動應用程式

```bash
open build/ANEMLBreezeASR.app
```

或安裝到 Applications:

```bash
cp -r build/ANEMLBreezeASR.app /Applications/
```

---

## 📝 第一次使用

### 1. 生成字幕（無需 LLM）

如果不需要 LLM 校正，可以直接使用：

1. 開啟 ANEMLBreezeASR
2. 點擊「Generate Subtitles」分頁
3. 選擇影片檔案
4. 設定語言（選用）：
   - **影片語言**: 預設「自動偵測」即可
   - 如果辨識不準確，可手動選擇影片語言
5. 點擊「Start Processing」
6. 等待處理完成（首次會下載 Whisper 模型，約 1-2GB）
7. 點擊「Export SRT」儲存字幕

### 1.5. 翻譯字幕（需要 LLM）

如果想將字幕翻譯成其他語言：

1. 先在「Settings」設定 LLM API（參考下方）
2. 在「Generate Subtitles」頁面：
   - 選擇影片檔案
   - **影片語言**: 選擇原始語言（如「中文」）
   - **啟用翻譯**: 勾選
   - **翻譯為**: 選擇目標語言（如「English」）
3. 點擊「Start Processing」
4. 字幕會自動翻譯成目標語言

### 2. 設定 LLM（選用）

如果想使用 LLM 自動校正字幕：

#### 使用 OpenAI API

1. 切換到「Settings」分頁
2. 填入：
   - **API Key**: 您的 OpenAI API 金鑰
   - **API Endpoint**: `https://api.openai.com/v1`
   - **Model Name**: `gpt-4o-mini`
3. 點擊「Save Settings」

#### 使用本地 LLM (Ollama)

1. 先啟動 Ollama:
   ```bash
   ollama serve
   ```

2. 在 ANEMLBreezeASR Settings 填入：
   - **API Key**: 留空或任意值
   - **API Endpoint**: `http://localhost:11434/v1`
   - **Model Name**: `llama3` (或您的模型名稱)
3. 點擊「Save Settings」

### 3. 燒錄字幕到影片

1. 切換到「Burn Subtitles」分頁
2. 選擇影片檔案
3. 選擇 SRT 字幕檔案
4. 輸入輸出檔名（不含副檔名）
5. 點擊「Burn Subtitles」

---

## ⚡ 常用技巧

### 跳過 LLM 校正

如果 LLM API 未設定或失敗，ANEMLBreezeASR 會自動使用原始語音辨識結果。

### 編輯字幕

1. 匯出 SRT 後，用任何文字編輯器開啟
2. 修改字幕內容
3. 使用「Burn Subtitles」功能燒錄修改後的字幕

### 檢查 FFmpeg

```bash
which ffmpeg
# 應該顯示: /opt/homebrew/bin/ffmpeg 或類似路徑
```

### 清除模型快取（釋放空間）

```bash
rm -rf ~/.cache/whisperkit/
```

下次使用會重新下載模型。

---

## 🐛 疑難排解

### 問題：找不到 FFmpeg

**解決方案**:
```bash
brew install ffmpeg
```

### 問題：應用程式無法開啟

**解決方案**: macOS 安全性設定可能阻擋未簽名的應用程式
1. 前往「系統偏好設定」→「安全性與隱私權」
2. 點擊「仍要打開」

或使用指令:
```bash
xattr -cr build/ANEMLBreezeASR.app
```

### 問題：首次執行很慢

這是正常的！Whisper 模型第一次下載需要 5-10 分鐘（約 1-2GB）。
下載後會快取，之後就很快了。

### 問題：LLM 校正失敗

檢查：
1. API Key 是否正確
2. Endpoint 是否正確（包含 `/v1`）
3. 網路連線是否正常

如果失敗，應用程式會自動使用原始字幕。

---

## 📚 更多資訊

詳細文件請參閱 [README.md](README.md)
