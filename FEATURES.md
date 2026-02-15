# ANEMLBreezeASR 功能詳細說明

## 🌍 多語言功能

### 支援的語言列表

ANEMLBreezeASR 支援以下 13 種語言：

| 語言 | 代碼 | 顯示名稱 |
|------|------|----------|
| 自動偵測 | auto | 自動偵測 |
| 中文 | zh | 中文 |
| 英文 | en | English |
| 日文 | ja | 日本語 |
| 韓文 | ko | 한국어 |
| 西班牙文 | es | Español |
| 法文 | fr | Français |
| 德文 | de | Deutsch |
| 義大利文 | it | Italiano |
| 葡萄牙文 | pt | Português |
| 俄文 | ru | Русский |
| 阿拉伯文 | ar | العربية |
| 印度文 | hi | हिन्दी |

---

## 📝 使用場景

### 場景 1: 單純語音辨識（無翻譯）

**適用情況**: 影片語言與所需字幕語言相同

**步驟**:
1. 選擇影片
2. **影片語言**: 選擇影片的語言（或使用「自動偵測」）
3. **啟用翻譯**: 保持關閉
4. 開始處理

**範例**:
- 中文影片 → 中文字幕
- English 影片 → English 字幕

---

### 場景 2: 語音辨識 + 字幕校正

**適用情況**: 需要改善字幕的語法、標點符號等

**步驟**:
1. 在「Settings」設定 LLM API
2. 選擇影片
3. **影片語言**: 選擇影片的語言
4. **啟用翻譯**: 保持關閉
5. 開始處理

**效果**:
- 修正語法錯誤
- 改善標點符號
- 調整大小寫
- 保持原始語言

---

### 場景 3: 語音辨識 + 翻譯

**適用情況**: 需要將字幕翻譯成其他語言

**步驟**:
1. 在「Settings」設定 LLM API
2. 選擇影片
3. **影片語言**: 選擇影片的原始語言
4. **啟用翻譯**: ✅ 勾選
5. **翻譯為**: 選擇目標語言
6. 開始處理

**範例應用**:
- 中文影片 → English 字幕
- English 影片 → 中文字幕
- 日文影片 → 中文字幕
- 法文影片 → English 字幕

---

## 🔄 翻譯工作流程

當啟用翻譯功能時，ANEMLBreezeASR 的處理流程如下：

```
影片
  ↓
提取音訊 (16kHz WAV)
  ↓
Whisper 語音辨識 (原始語言)
  ↓
生成原始語言字幕 (SRT)
  ↓
LLM 校正 + 翻譯
  ↓
生成目標語言字幕 (SRT)
  ↓
匯出
```

---

## 💡 使用技巧

### 提高辨識準確度

1. **指定語言**: 如果自動偵測不準確，手動選擇影片語言
2. **清晰音訊**: 確保影片音訊清晰，背景噪音較少
3. **標準口音**: Whisper 對標準口音的辨識效果較好

### 翻譯品質優化

1. **選擇強大的 LLM**: 使用 GPT-4o 而非 GPT-4o-mini
2. **調整 System Prompt**: 在 Settings 中自訂翻譯風格
3. **分段處理**: 長影片可以分段處理，避免上下文過長

### 自訂 System Prompt 範例

#### 正式翻譯
```
You are a professional subtitle translator. Translate the subtitles to {target_language}
with formal and professional tone. Maintain technical accuracy and timing structure.
```

#### 口語化翻譯
```
You are a subtitle translator. Translate the subtitles to {target_language}
with natural, conversational tone. Make it easy to understand for general audience.
```

#### 技術文件翻譯
```
You are a technical subtitle translator. Translate the subtitles to {target_language}
preserving all technical terms, code examples, and specialized vocabulary.
```

---

## ⚙️ 進階配置

### 語言設定儲存

語言設定會自動儲存在 UserDefaults 中，下次開啟應用程式時會自動載入上次的設定。

### 支援的 LLM

翻譯功能支援所有 OpenAI-compatible API：

- **OpenAI**: GPT-4o, GPT-4o-mini, GPT-4 Turbo
- **本地 LLM**: Ollama (llama3, mistral 等)
- **其他服務**: Claude via proxy, Gemini via proxy

---

## 🎯 常見問題

### Q1: 自動偵測會選擇哪種語言？

Whisper 會根據音訊內容自動判斷語言，支援 99 種語言。如果影片包含多種語言，會選擇主要語言。

### Q2: 可以同時生成多種語言的字幕嗎？

目前一次只能翻譯成一種語言。如需多種語言，請分別執行多次：
1. 第一次：中文 → English
2. 第二次：中文 → 日本語

### Q3: 翻譯會保留時間碼嗎？

是的，翻譯只會改變文字內容，時間碼（start/end time）保持不變。

### Q4: 不使用 LLM 可以翻譯嗎？

不行。翻譯功能需要 LLM API。但語音辨識本身不需要 LLM。

### Q5: 支援方言嗎？

Whisper 對標準語言的支援較好。方言可能需要選擇對應的標準語言：
- 台灣國語 → 中文
- 粵語 → 中文 (效果可能不佳)
- 美式英文/英式英文 → English

---

## 🔧 技術細節

### Whisper 語言支援

ANEMLBreezeASR 使用 Whisper Large v3 模型，原生支援以下語言的語音辨識：

- 完整列表: https://github.com/openai/whisper#available-models-and-languages
- 支援超過 99 種語言
- 對高資源語言（英文、中文、西班牙文等）支援最佳

### LLM 翻譯機制

翻譯時，ANEMLBreezeASR 會在 System Prompt 中添加：

```
Additionally, translate all subtitles to {target_language}.
Maintain the SRT format and timing, but replace the text with the translated version.
```

LLM 會理解並執行翻譯，同時保持 SRT 格式不變。

---

## 📊 效能參考

| 操作 | 時間估計 (10分鐘影片) |
|------|----------------------|
| 音訊提取 | ~30 秒 |
| 語音辨識 | ~2-5 分鐘 |
| LLM 校正 | ~30-60 秒 |
| LLM 翻譯 | ~1-2 分鐘 |
| 字幕燒錄 | ~5-10 分鐘 |

**總計**: 約 10-20 分鐘（視 LLM API 速度而定）

---

## 🌟 最佳實踐

1. **先測試短片**: 用 1-2 分鐘的短片測試語言設定
2. **驗證辨識**: 檢查原始字幕是否準確，再進行翻譯
3. **分段處理**: 超過 30 分鐘的長影片建議分段
4. **人工校對**: 翻譯後建議人工檢查重要內容
5. **保存原始檔**: 保留原始 SRT 檔案以備不時之需
