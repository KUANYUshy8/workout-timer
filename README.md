# 運動計時器

間歇運動計時器。可以設定運動時間、休息時間、每回合動作數、回合數與回合間休息，有提示音、語音播報、震動、歷史紀錄和統計。

這個專案有兩個版本：

| | iPhone App（`ios/`） | 網頁版（根目錄） |
|---|---|---|
| 安裝方式 | 用 Mac 上的 Xcode 裝到 iPhone | Safari 打開網址後「加入主畫面」 |
| 鎖螢幕、切到其他 App 時 | 繼續倒數、響提示音，鎖定畫面會跳出目前階段 | 會暫停 |
| 換階段震動 | 有 | 無 |

---

## 安裝 iPhone App（免費 Apple ID）

需要：一台 Mac、一條 iPhone 傳輸線、iPhone 系統 iOS 17 以上。

### 第一次安裝

1. **安裝 Xcode**：在 Mac 的 App Store 搜尋「Xcode」並安裝（免費，檔案很大，要等一段時間）。已經裝過的話請更新到最新版，舊版 Xcode 可能不支援你 iPhone 的 iOS 版本。第一次打開時，如果問要不要安裝 iOS 元件，選安裝。
2. **下載專案**：在這個 GitHub 頁面點綠色的 **Code** → **Download ZIP**，解壓縮。
3. **打開專案**：進到解壓後的 `ios` 資料夾，雙擊 `WorkoutTimer.xcodeproj`。
4. **登入 Apple ID**：Xcode 選單 **Xcode → Settings → Accounts**，按左下角「+」→ Apple ID，登入你平常用的 Apple ID。
5. **選擇簽名團隊**：
   - 左側點最上面藍色的 **WorkoutTimer**，中間選 **TARGETS → WorkoutTimer**，再點上方的 **Signing & Capabilities**。
   - **Team** 選「你的名字 (Personal Team)」。
   - 如果下方出現紅字說 Bundle Identifier 不能用，把 **Bundle Identifier** 改成別的名字，例如 `com.你的名字.workouttimer`。
6. **接上 iPhone**：用傳輸線接上 Mac，iPhone 解鎖後選「信任這部電腦」。Xcode 視窗最上方中間的裝置選單選你的 iPhone。
7. **打開 iPhone 的開發者模式**：iPhone **設定 → 隱私權與安全性 → 開發者模式** → 打開，手機會重新開機。（這個選項要接上 Xcode 後才會出現。）
8. **安裝**：按 Xcode 左上角的 ▶︎ 按鈕。
9. **信任開發者**：第一次 iPhone 會說「不受信任的開發者」。到 **設定 → 一般 → VPN 與裝置管理**，點你的 Apple ID → **信任**。之後就能從主畫面打開「運動計時器」。

### 每 7 天要做一次

免費 Apple ID 安裝的 App 一週後會打不開。到時候把 iPhone 接上 Mac，在 Xcode 按 ▶︎ 重新安裝就好，**紀錄和設定都會保留**。

如果申請了 Apple 付費開發者帳號（每年 US$99），在第 5 步的 Team 改選付費帳號，安裝一次可以用一年。

### 第一次使用

- 按下開始時會詢問是否允許通知。允許後，鎖螢幕時會顯示現在是哪個階段。
- 手機開靜音（側邊靜音鍵）時，提示音仍會播放；音量請用音量鍵調整。

---

## 網頁版

網址：https://kuanyushy8.github.io/workout-timer/

用 iPhone Safari 打開，點分享按鈕 →「加入主畫面」，就能像 App 一樣從桌面開啟，離線也能用。

---

## 給開發者

- `ios/project.yml` 是專案設定（XcodeGen）。每次推送到 `main`，GitHub Actions 會在雲端 Mac 上產生 `WorkoutTimer.xcodeproj`、編譯一次確認沒有錯誤，並把產生的專案檔存回這個 repository。編譯結果放在 `ci-report` 分支。
- 網頁版是單一 `index.html`，搭配 `manifest.webmanifest` 與 `sw.js` 做成可離線的 PWA。
