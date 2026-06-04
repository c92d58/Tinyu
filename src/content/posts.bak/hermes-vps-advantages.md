---
title: '為什麼我在自己VPS跑 Hermes Agent'
description: '從模型靈活性、資料主權到自動化排程——完整分析為什麼將 Hermes Agent 部署在自己的 VPS 上是一項值得的投資'
date: 2026-06-01
tags: ['Hermes Agent', 'VPS', '自架部署', '開源', 'DevOps']
draft: false
---

如果你正在考慮是否要把 AI 代理放到自己的伺服器上，這篇文章會給你一個完整的評估框架。

## 一、模型自由：不再被綁在單一供應商

Cloud AI 服務最大的隱形成本不是錢，是**切換成本**。當你把 workflow 綁在 ChatGPT、Claude 或 Gemini 的特定功能上，哪天政策變了、價格漲了、功能拔了，你只能接受。

Hermes 架構的核心設計是 **Provider 抽象層**：

![](https://images.unsplash.com/photo-1518432031352-d6fc5c10da5a?q=80&w=2670&auto=format&fit=crop)

_不同 AI 服務連接示意_

```yaml
# config.yaml — 可以同時配置多個 provider
auxiliary:
  vision:
    provider: openai
    model: gpt-4o
  title_generation:
    provider: deepseek
    model: deepseek-chat
  mcp:
    provider: anthropic
    model: claude-sonnet-4-20250514
```

好處是什麼？

- **每個子任務用最適合的模型** — 簡單的標題生成用便宜的 deepseek，複雜的程式碼推理用 Claude，圖片辨識用 GPT-4o。不浪費 token 也不犧牲品質。
- **供應商故障不影響全局** — OpenAI 掛了？切到 Anthropic。Anthropic 超載？切到本地模型。**你的 service 不中斷。**
- **成本優化** — 用量少的月份不要訂閱，按 token 計費。跑 cron job 用便宜的推理模型，複雜任務再調用高階模型。

> 這在 SaaS 產品上做不到。你買 ChatGPT Plus，就是一個模型一種價格。自架 Hermes 讓你把模型當作資源池來調度。

## 二、資料主權：對話留在自己的機器上

這也許是自架最被低估的優勢。

當你透過網頁版 ChatGPT 或 Claude 處理工作，每一次對話——包括你貼進去的原始碼、伺服器 IP、資料庫結構、商業邏輯——都存放在別人的伺服器上。

![](https://images.unsplash.com/photo-1563013544-824ae1b704d3?q=80&w=2670&auto=format&fit=crop)

_資料安全與控制的視覺化示意_

Hermes 跑在你自己 VPS 上的時候：

- **所有對話記錄存在你的磁碟**，SQLite 資料庫就在 `/root/.hermes/` 底下。你可以備份、匯出、刪除，完全由你控制。
- **API 呼叫走你自己的 key**，流量經過 HTTPS 加密直達模型提供者。沒有任何中間服務看到你的請求內容。
- **可以接本地模型** — 如果你有敏感的內部文件分析需求，用 ollama 或 llama.cpp 在本機跑模型，資料完全不離開你的 VPS。

對於處理內部系統日誌、客戶資料、或公司原始碼的使用場景，這不是一個 nice-to-have，而是必要的合規前提。

## 三、永遠在線的排程系統（Cron as a Service）

雲端 AI 服務都是「你問我答」的模式。你需要手動打開網頁、輸入提示詞、等待回覆。這對於一次性任務沒問題，但對於**持續性運維**來說完全不夠。

Hermes 的 cron 系統把 AI 代理變成了一個**24/7 的背景服務**：

![](https://images.unsplash.com/photo-1517292987719-0369a794ec0f?q=80&w=2674&auto=format&fit=crop)

_時間排程與自動化的視覺化示意_

```bash
# 每天九點檢查伺服器健康
hermes cron create \
  --schedule "0 9 * * *" \
  --prompt "檢查磁碟用量、記憶體、CPU負載，超過閾值發警報" \
  --deliver telegram

# 每小時檢查 Fail2Ban 封禁狀態
hermes cron create \
  --schedule "0 * * * *" \
  --prompt "檢查 Fail2Ban 日誌，匯報最近一小時的封禁情況" \
  --deliver telegram
```

這些排程任務的價值在於：

1. **被動監控變成主動通知** — 不用每隔幾小時 SSH 進去 `df -h`，Hermes 會主動告訴你磁碟滿了。
2. **排程可以串接** — Job A 收集資料，Job B 分析結果，Job C 生成報告。全自動。
3. **輸出送到你需要的地方** — 可以送到 Telegram、郵件、本地檔案、或所有平台同時發送。

我實際在跑的 cron job 大概 10 個左右，從磁碟監控到部落格健康檢查，全部自動化。**這些事情在 ChatGPT 裡做不到，因為它不會一直開著等你。** 但在 VPS 上，這本來就是伺服器存在的意義。

## 四、工具生態鏈：Skill 系統的威力

SaaS AI 工具的功能上限由產品經理決定。Hermes 的功能上限由**你的想像力**決定。

Skill 系統是 Hermes 最強大的設計之一。它不像傳統 plugin 那樣需要寫程式碼——你可以用自然語言定義一個重複性工作流程，Hermes 會記住並且在下次自動套用。

![](https://images.unsplash.com/photo-1618401471353-b98afee0b2eb?q=80&w=2670&auto=format&fit=crop)

_系統架構與工具整合示意_

舉幾個我實際在用的例子：

- **`system-maintenance-cleanup`** — 完整清理 APT 快取、journald 日誌、Docker 垃圾、舊 kernel。一句指令，20 步驟全自動。
- **`debian-server-hardening`** — 掃描所有常見的安全弱點：開放埠、弱密碼、未更新套件。輸出風險矩陣。
- **`ufw-auto-ban-cron`** — 自動掃描 UFW 日誌，對超過閾值的 IP 執行 iptables 封禁。
- **`nano-pdf`** — 用自然語言指令編輯 PDF 內容（改錯字、更新標題）。

這些 skill 是可以互相組合的。你可以寫一個新的 skill「每週日執行完整安全檢查，生成報告發到 Telegram」，裡面呼叫三個現有的 skill。**系統越用越聰明，而不是越用越受限。**

## 五、Telegram 作為控制面

這是一個意外但極大的優勢。

當 Hermes 透過 Gateway 接上 Telegram，你的 VPS 就變成了一個**可以對話的後端**。

- **隨時隨地發指令** — 手機上打開 Telegram，輸入「幫我看一下伺服器狀態」，一秒鐘後收到回覆。不需要 SSH client、不需要 VPN、不需要記指令。
- **推播通知** — 磁碟告警直接出現在 Telegram 通知欄。比 email 即時，比 Slack 簡潔，比 PagerDuty 便宜。
- **檔案直接傳送** — 排程任務輸出的報表、圖片、log 壓縮檔，直接以媒體形式發到你的聊天室。

![](https://images.unsplash.com/photo-1611532736597-de2d4265fba3?q=80&w=2670&auto=format&fit=crop)

_即時通訊與系統管理的視覺化示意_

這把**私人伺服器**和**個人助理**之間的界線模糊了。VPS 不再只是一台需要 SSH 進去的機器——它是你的 AI 代理，存在於你的通訊軟體裡，隨時待命。

## 六、成本分析：真的比較划算嗎？

以下是實際比對（以我個人的用量為例）：

| 項目 | ChatGPT Plus | 自架 Hermes |
|------|-------------|------------|
| **月費** | $20 USD（固定） | $0（軟體免費開源） |
| **模型費用** | 已含在訂閱 | ~$5-15 USD（依用量，走 API） |
| **VPS 費用** | 無 | ~$5-15 USD（最低配即可） |
| **總計** | ~$20 USD | ~$10-30 USD |
| **功能彈性** | 固定功能集 | 無限擴展 |
| **資料控制** | 無 | 完全控制 |
| **排程能力** | 無 | 強大的 cron 系統 |
| **多模型支援** | 單一模型 | 任意模型組合 |

輕度使用者可能比 ChatGPT Plus 貴一點，但中度到重度使用者——尤其是需要多模型、排程任務、資料主權的人——**自架 Hermes 明顯划算**。而且越用，你的 skill 庫越豐富，系統的價值越高。

## 結語：VPS 是 Hermes 的最佳舞台

如果 Hermes 是你的 AI 代理，那麼 VPS 就是它的身體——一個永遠在線、完全可控、隨時擴展的執行環境。

Cloud AI 服務像是租房子：方便、不用操心維護，但你不能改格局、不能決定用哪種電器、房東隨時可能調整房租。

自架 Hermes 像是買房子：需要前期投入、需要自己維護管線，但**這是你的**。你可以決定一切——從用哪個型號、跑什麼任務、到資料怎麼儲存。

要不要踏出這一步？如果有一台 VPS 閒置在那，裝上 Hermes，一個下午就能讓它變成你的 24 小時 AI 助理。
