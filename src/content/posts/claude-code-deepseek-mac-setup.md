---
title: 'Mac 終端機新手包：安裝並用 Claude Code + DeepSeek 寫程式'
description: '從零開始，在 Mac 終端機安裝 Claude Code，並串接中國 DeepSeek API 做為程式開發助手——最適閤中文使用者的 CI 級 AI 開發環境設定指南'
date: 2026-06-11
tags: ['AI', 'Claude', 'DeepSeek', 'Mac', '開發工具', '教學']
draft: true
---

如果你是一個開發者，最近一定被「AI 寫程式」的新聞轟炸。Claude Code、GitHub Copilot、Cursor——但你可能不知道的是，這些工具大多能**自己選擇模型**，不一定要綁在美國的 AI 服務上。這篇文章會帶你：在 Mac 終端機安裝 Claude Code、串接中國的 DeepSeek API、寫一個實際的程式任務來測試。全程只要打指令，不用離開終端機。

- 在 Mac 終端機安裝 Claude Code
- 串接中國的 DeepSeek API
- 寫一個實際的程式任務來測試

## 一、先開啟你的終端機

Mac 的終端機在 `應用程式 → 工具程式 → 終端機`，或者直接按 `Cmd + 空白鍵` 搜尋「終端機」。開啟後你會看到一個黑底白字的視窗，顯示類似：

```
你的Mac名稱:~ 你的使用者名稱$
```

這就是你的命令列環境。接下來的所有操作都在這裡進行。

## 二、安裝 Node.js（Claude Code 需要它）

Claude Code 是基於 Node.js 開發的，所以要先用 **nvm** 安裝 Node.js。

### 2.1 安裝 nvm

nvm（Node Version Manager）可以讓你在 Mac 上安裝並管理多個 Node.js 版本。貼上這行指令後按 Enter：

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
```

跑完之後，關掉終端機再重開（`Cmd + Q` 完全退出再開啟），或者執行這行讓設定立刻生效：

```bash
source ~/.zshrc
```

### 2.2 用 nvm 安裝 Node.js

```bash
nvm install 22
```

這會下載並編譯 Node.js 22 的最新穩定版。跑完後確認版本：

```bash
node -v
# 應該顯示 v22.x.x
```

## 三、安裝 Claude Code

Claude Code 是 Anthropic 推出的命令列 AI 程式設計工具，但它的設計比你想像的更開放——你可以讓它用**任何相容的 API**。安裝指令：

```bash
npm install -g @anthropic-ai/claude-code
```

安裝完成後測試：

```bash
claude --version
```

如果看到版本號，表示安裝成功。

## 四、設定 DeepSeek API

Claude Code 預設用 Anthropic 的官方 API（需要美國手機驗證，對中國使用者不友善）。透過一個代理層，可以讓它串接到 DeepSeek 的 API。

### 4.1 註冊 DeepSeek 帳號並取得 API Key

1. 前往 [platform.deepseek.com](https://platform.deepseek.com) 註冊
2. 登入後點選左側「API Keys」
3. 點「建立 API Key」，複製那串以 `sk-` 開頭的金鑰（**關掉視窗後就再也看不到了**）
4. 至少充值 10 元人民幣（DeepSeek 極度便宜，10 元可以用很久）

### 4.2 設定環境變數

在終端機執行：

```bash
echo 'export DEEPSEEK_API_KEY="sk-你的API金鑰"' >> ~/.zshrc
source ~/.zshrc
```

把 `sk-你的API金鑰` 換成你剛才複製的那一串。

## 五、讓 Claude Code 使用 DeepSeek

Claude Code 支援 `ANTHROPIC_BASE_URL` 環境變數來改變 API 端點。我們需要一個**轉發層**，因為 Claude Code 的通訊格式跟 DeepSeek 不完全相同。可以用 **one-api** 或 **new-api** 這類開源專案，但最簡單的方式是用一個輕量的 Python 指令碼。

### 5.1 安裝 Python 依賴

Mac 已內建 Python 3，直接安裝套件：

```bash
pip3 install flask requests
```

### 5.2 建立轉發伺服器

用以下內容建立一個檔案 `~/claude-proxy.py`：

```python
from flask import Flask, request, jsonify
import requests
import json

app = Flask(__name__)
DEEPSEEK_API_KEY = "sk-你的API金鑰"
DEEPSEEK_BASE = "https://api.deepseek.com"

@app.route('/v1/messages', methods=['POST'])
def proxy_messages():
    data = request.get_json()
    
    # 將 Claude 格式轉換為 DeepSeek 格式
    system = ""
    messages = []
    
    for msg in data.get('messages', []):
        if msg['role'] == 'assistant' and msg.get('type') == 'tool_use':
            messages.append({
                "role": "assistant",
                "content": json.dumps(msg)
            })
        elif msg['role'] == 'user':
            content = []
            for c in msg.get('content', []):
                if isinstance(c, dict) and c.get('type') == 'tool_result':
                    content.append({
                        "type": "text",
                        "text": f"[Tool Result: {c.get('tool_use_id', 'unknown')}]\n{c.get('content', '')}"
                    })
                elif isinstance(c, dict):
                    content.append(c)
                else:
                    content.append({"type": "text", "text": str(c)})
            messages.append({"role": "user", "content": content})
        elif msg['role'] == 'system':
            system = msg.get('content', '')
        else:
            messages.append({"role": msg['role'], "content": msg.get('content', '')})
    
    payload = {
        "model": "deepseek-chat",
        "messages": messages,
        "system": system or None,
        "max_tokens": data.get('max_tokens', 4096),
        "temperature": data.get('temperature', 0.7),
        "stream": False
    }
    
    headers = {
        "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
        "Content-Type": "application/json"
    }
    
    resp = requests.post(f"{DEEPSEEK_BASE}/v1/chat/completions", 
                         json=payload, headers=headers)
    
    result = resp.json()
    
    # 將 DeepSeek 格式轉回 Claude 格式
    claude_resp = {
        "id": result.get("id", ""),
        "type": "message",
        "role": "assistant",
        "content": [{"type": "text", "text": result['choices'][0]['message']['content']}],
        "model": "deepseek-chat",
        "stop_reason": "end_turn",
        "usage": result.get("usage", {})
    }
    
    return jsonify(claude_resp)

if __name__ == '__main__':
    app.run(port=8081)
```

> ⚠️ **重要**：把檔案中第 6 行的 `sk-你的API金鑰` 換成你真正的 DeepSeek API Key。

### 5.3 啟動轉發伺服器

在另一個終端機視窗執行：

```bash
python3 ~/claude-proxy.py
```

看到 `Running on http://127.0.0.1:8081` 表示啟動成功。**這個視窗要一直開著**，讓伺服器在背景運作。

## 六、開始使用

回到原本的終端機，執行 Claude Code 並指定用 DeepSeek：

```bash
claude --model deepseek-chat --base-url http://127.0.0.1:8081
```

如果一切正常，你會看到：

```
▌ 歡迎使用 Claude Code
▌ 目前使用模型: deepseek-chat
▌ 輸入你的問題或指令...
```

### 實戰測試：請 AI 幫你寫一個擷取網頁標題的指令碼

在 Claude Code 的提示輸入：

> 幫我寫一個 Python 指令碼，接收一個 URL 引數，下載該網頁的 HTML 並提取 `<title>` 標籤的內容。輸出格式為「網頁標題: xxx」。

Claude Code 會呼叫 DeepSeek 來推理，然後直接在終端機中顯示程式碼。你可以請它儲存到檔案，甚至直接執行。

---

## 七、日常使用的便利技巧

### 在專案目錄中直接啟動

如果你在某個專案資料夾工作，可以直接在該資料夾下執行：

```bash
cd ~/my-project
claude --model deepseek-chat --base-url http://127.0.0.1:8081
```

Claude Code 會自動讀取你的專案結構，之後的對話都會基於這個專案上下文。

### 節省 Token 的技巧

- **使用便宜模型做簡單任務**：日常問答、程式碼解釋用 DeepSeek-chat 就很夠
- **一次處理一個問題**：不要在一段話裡塞好幾個不相關的問題，分開問 token 更省
- **設定 max_tokens**：回答太長時，Claude Code 支援傳入 `--max-tokens` 引數限制輸出長度

## 八、常見問題

### Q：為什麼用了 DeepSeek，Claude Code 還是顯示「需要登入」？

你的轉發伺服器可能沒有正確啟動。檢查：

1. 確認 `~/claude-proxy.py` 正在執行（看終端機有無報錯）
2. 確認 API Key 正確
3. 試試用 curl 測試轉發層：

```bash
curl -X POST http://127.0.0.1:8081/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"hi"}]}'
```

### Q：DeepSeek API 會比 Claude 官方差很多嗎？

**完全不差**。DeepSeek-chat 在程式碼生成、邏輯推理上與 Claude Sonnet 相當接近，但價格只有幾十分之一。對於日常開發輔助，它是目前 CP 值最高的選擇。

### Q：轉發伺服器一定要開著嗎？

是的，`claude-proxy.py` 必須持續運作。你可以設定開機自動啟動，或使用 `nohup python3 ~/claude-proxy.py &` 讓它在背景執行。

## 總結

不到 20 行程式指令，你就可以在 Mac 終端機上擁有一個**串接中國 AI 模型**的命令列程式設計助手。整個流程：

`終端機 → Claude Code → 本機轉發層 → DeepSeek API → AI 回應`

這種組合的優勢在於：

- ✅ **不需要美國手機號碼**驗證
- ✅ **按量計費**，10 元人民幣可以用好幾個月
- ✅ **資料不出中國**（全部走 DeepSeek 的國內伺服器）
- ✅ **熟悉 terminal 的工作流**，不用離開命令列

當你能在終端機中直接對 AI 下達「幫我寫一個爬蟲」、「解釋這段程式碼」、「重構這個函式」時，你才會真正感受到 AI 程式設計助手的威力。
