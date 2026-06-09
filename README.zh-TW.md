# cloc-studio

[English](README.md) | 中文

`cloc-studio` 是一款 macOS 桌面 App，用來執行並檢視 [`cloc`](https://github.com/AlDanial/cloc) 的程式碼行數統計報告。

<img src="assets/AppIcon-1024.png" alt="cloc-studio icon" width="160" />

它提供視覺化流程，讓你選擇原始碼檔案或資料夾、套用常見的 `cloc` 篩選條件，並把結果複製成方便貼到筆記、文件或報告中的格式。獨立 App 版本會內建 `vendor/cloc`，因此打包後的 `.app` 不需要使用者另外安裝 `cloc`。

## 截圖

### 總覽

![cloc-studio overview](docs/images/overview-main.png)

### 結果

![cloc-studio execution result](docs/images/execution-result.png)

## 功能

- 使用選擇器或拖放方式選取多個檔案或資料夾。
- 透過原生 SwiftUI macOS 介面執行 `cloc --json`。
- 依照語言、副檔名、目錄、最大檔案大小、git 範圍與唯一性檢查進行篩選。
- 可切換語言層級與檔案層級的統計明細。
- 可選擇在統計前自動解壓縮壓縮檔，包含 `.zip` 裡還有另一個 `.zip` 的巢狀壓縮檔。
- 檢視檔案數、程式碼行數、註解行數、空白行數與耗時等總覽資訊。
- 將明細複製為純文字、Markdown、TSV，或適合貼到 Word 的 HTML 表格內容。
- 建立內建 `vendor/cloc` 執行檔的獨立 `.app`。

支援自動解壓縮的格式包含 `.zip`、`.tar`、`.tgz`、`.tar.gz`、`.tbz`、`.tbz2`、`.tar.bz2`、`.txz` 與 `.tar.xz`。

## 系統需求

- macOS 13 或更新版本。
- Xcode command line tools，或具備 Swift 6.1 相容工具鏈的 Xcode。

## 使用方式

1. 開啟 `cloc-studio`。
2. 選取或拖入一個或多個檔案、資料夾，或支援的壓縮檔。
3. 視需要設定篩選條件。
4. 如果需要在統計前展開壓縮檔，啟用 **Auto extract archives**。
5. 點擊 **Run cloc**。
6. 依需要複製表格或摘要結果。

啟用自動解壓縮時，壓縮檔會先解到暫存資料夾，再交給 `cloc` 統計。執行完成或失敗後，暫存解壓縮資料夾會被移除。

## 本機開發

```bash
swift build
swift run cloc-studio
```

開發時可以指定本機的 `cloc` 執行檔：

```bash
CLOC_STUDIO_LOCAL_CLOC=/absolute/path/to/cloc swift run cloc-studio
```

執行測試：

```bash
swift test
```

## 打包 App

```bash
./scripts/package_app.sh
```

打包腳本會：

- 建置 release binary。
- 產生 App icon assets。
- 依照 `vendor/cloc.sha256` 驗證 `vendor/cloc`。
- 將 `vendor/cloc` 打包到 `Contents/Resources/cloc`。
- 預設使用 ad-hoc identity 簽署 App。
- 建立 `dist/cloc-studio.app` 與 `dist/cloc-studio.zip`。

你可以用以下方式覆寫 bundle version：

```bash
VERSION=0.1.0 ./scripts/package_app.sh
```

## 如果 macOS 阻擋開啟 App

如果 Gatekeeper 阻擋下載的 build，請先確認 App 來源可信，再移除 quarantine attribute：

```bash
xattr -d com.apple.quarantine /path/to/cloc-studio.app
```

如果需要處理巢狀檔案：

```bash
xattr -dr com.apple.quarantine /path/to/cloc-studio.app
```

## Attribution

`cloc-studio` 是 **cloc** 的 GUI wrapper。**cloc** 由 Al Danial 與其他 contributors 維護。`cloc-studio` 並不取代 `cloc`，而是在 upstream 的統計引擎與語言判斷邏輯之上，提供 macOS 介面。

- Upstream project: https://github.com/AlDanial/cloc
- Upstream tool name: `cloc` (Count Lines of Code)
- Bundled runtime in this repo: `vendor/cloc`

重新散布 `cloc-studio` 時，請保留此 attribution。

## License and Compliance

`cloc` 依 GNU GPL 授權散布（依 upstream notices，為 GPL v2 or later）。由於此 App 會內建並重新散布 `cloc`，`cloc-studio` 的 release 必須遵守 GPL 義務。

分享 binary（`.app`、`.zip`）時，請確認：

- 包含 upstream `cloc` 的 copyright 與 license notices。
- 提供重新散布版本對應的 source code，包含任何修改。
- 告知接收者 `cloc` 採 GPL 授權，以及 source code 可從何處取得。

公開 release 前，請檢查 upstream `LICENSE` 與 `cloc` script header 中的 notices。

此 repository 包含：

- `LICENSE`（upstream GPL text）
- `NOTICE`（upstream attribution 與 bundled-component notice）
