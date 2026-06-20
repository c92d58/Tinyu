---
title: 'Fail2ban + SSH 審計聯動：VPS 公網最佳防護方案'
description: '一套完整的 SSH 暴力破解防護方案，整合 Fail2ban、Systemd 日誌與審計記錄，實現即時封禁、可回溯、不誤傷公鑰使用者的生產級配置。'
date: 2026-06-04
tags: ['Linux', '安全', 'SSH', 'Fail2ban', 'DevOps', '伺服器']
draft: true
---

如果你的 VPS 直接暴露在公網上，大概在開機後 24 小時內，你就會看到 `sshd` 日誌裡充滿了來自世界各地的暴力掃描。這不是「會不會」的問題，而是「何時」的問題。

## 為什麼需要專用方案？

很多人以為「禁用密碼登入 + 使用金鑰」就夠了。但實際上：

| 威脅 | 純金鑰能抵禦？ | Fail2ban 能加強？ |
|------|:--------------:|:-----------------:|
| 字典掃描（密碼嘗試） | ✅ 是（已禁用密碼） | 🟡 減少日誌噪音 |
| 金鑰暴力列舉 | ❌ 否（sshd 照樣記錄） | ✅ 封禁此類連線 |
| 非標準埠命中 | ❌ 否 | ✅ 監控自定義埠 |
| DoS 類連線泛洪 | ❌ 部分 | ✅ 自動封禁 |

即使你只使用金鑰登入，攻擊者仍會嘗試**無效使用者**和**無效金鑰**，這些連線本身就會增加系統負擔和日誌大小。本文提供的方案會將這些行為**即時封禁**並**完整記錄**到審計日誌中。

## 方案設計理念

### 三個核心目標

- **即時封禁** — 識別到惡意行為後自動加入黑名單
- **可回溯審計** — 所有封禁行為記錄到 journald，方便事後調查
- **零誤傷** — 正常使用金鑰登入的使用者不受影響

### 雙層防護架構

```
SSH 連線請求
    │
    ├─▶ sshd 日誌 (journald)
    │       │
    │       ├─▶ [sshd] jail ──▶ 3 次失敗 ──▶ 封禁 24h
    │       │
    │       └─▶ [sshd-audit] jail ──▶ 2 次異常 ──▶ 封禁 48h
    │
    └─▶ 正常金鑰登入 ──▶ 透過（不受影響）
```

## 部署指令碼

以下是一鍵部署指令碼，可直接在 Debian/Ubuntu 系統上執行：

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Fail2ban + SSH 審計聯動部署開始 ==="

# ---------- 1. 安裝 Fail2ban ----------
echo "[+] 安裝 Fail2ban"
apt update -qq
apt install -y fail2ban

systemctl enable fail2ban --now

# ---------- 2. Fail2ban 基礎配置 ----------
echo "[+] 寫入 Fail2ban 本機配置"

cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 24h
findtime = 10m
maxretry = 3
backend  = systemd
usedns   = no
destemail = root
sender = fail2ban@localhost
action = %(action_mwl)s

[sshd]
enabled  = true
port     = 22
filter   = sshd
logpath  = %(systemd_journal)s
maxretry = 3
EOF

# ---------- 3. SSH 審計聯動過濾器 ----------
echo "[+] 配置 SSH 審計增強過濾器"

cat > /etc/fail2ban/filter.d/sshd-audit.conf <<'EOF'
[Definition]
failregex = ^
            ^.*sshd.*Failed publickey for .* from <HOST> port .*$
            ^.*sshd.*Invalid user .* from <HOST> port .*$
            ^.*sshd.*authentication failure; .* rhost=<HOST>.*$
ignoreregex =
EOF

# ---------- 4. 啟用審計過濾 jail ----------
cat >> /etc/fail2ban/jail.local <<'EOF'

[sshd-audit]
enabled  = true
filter   = sshd-audit
port     = 22
logpath  = /var/log/sshd-audit.log
maxretry = 2
bantime  = 48h
EOF

# ---------- 5. journald 封禁行為可審計 ----------
echo "[+] Fail2ban 封禁日誌進入 journald"

mkdir -p /etc/systemd/system/fail2ban.service.d

cat > /etc/systemd/system/fail2ban.service.d/override.conf <<'EOF'
[Service]
ExecStartPost=/usr/bin/logger -t fail2ban "Fail2ban service started"
EOF

systemctl daemon-reload

# ---------- 6. 重新啟動服務 ----------
echo "[+] 重新啟動 Fail2ban"
systemctl restart fail2ban

# ---------- 7. 狀態檢查 ----------
echo
echo "=== 狀態檢查 ==="
fail2ban-client status
echo
fail2ban-client status sshd
fail2ban-client status sshd-audit
```

## 配置說明

### `jail.local` — 主要防護規則

| 引數 | 值 | 說明 |
|------|------|------|
| `bantime` | 24h | 封禁持續時間，一天後自動解封 |
| `findtime` | 10m | 監控時間視窗，10 分鐘內累計計算 |
| `maxretry` | 3 | 觸發封禁的失敗次數 |
| `backend` | systemd | 從 journald 讀取日誌，而非檔案 |
| `port` | 22 | 你的自定義 SSH 埠（按實際修改） |

### `sshd-audit` — 增強審計規則

這個自定義過濾器專門捕捉三類事件：

1. **Failed publickey** — 嘗試用無效金鑰登入 (最常見)
2. **Invalid user** — 嘗試用不存在的使用者名稱登入
3. **Authentication failure** — 一般的認證失敗

由於金鑰使用者幾乎不會觸發這些規則（只要金鑰匹配，sshd 不會記錄為 Failed），所以 `maxretry = 2` 是安全的。

## 常用管理指令

### 狀態查詢

```bash
# 檢視所有監控的 jail
fail2ban-client status

# 檢視 SSH 防護狀態
fail2ban-client status sshd

# 檢視審計防護狀態
fail2ban-client status sshd-audit
```

### 手動操作

```bash
# 解封某個 IP
fail2ban-client set sshd unbanip 1.2.3.4

# 檢視封禁日誌（journald）
journalctl -t fail2ban

# 即時監控審計日誌
tail -f /var/log/sshd-audit.log
```

### 檢視已封禁 IP

```bash
# iptables 封禁列表
iptables -L -n | grep f2b

# fail2ban 客戶端
fail2ban-client status sshd | grep "Banned IP list"
```

## 常見問題

### Q: 會誤封我自己的連線嗎？

不會。如果你使用金鑰登入且金鑰正確，sshd 不會觸發任何失敗記錄。只有當你打錯密碼或使用錯誤金鑰連續 3 次時才會觸發——而這種情況很少發生。

萬一被誤封，可透過另一個 IP 或 VNC 連入伺服器，執行：

```bash
fail2ban-client set sshd unbanip YOUR_IP
```

### Q: 修改 SSH 埠後需要調整什麼？

將 `jail.local` 中的 `port = 22` 改為你的實際埠，然後重新啟動 fail2ban：

```bash
systemctl restart fail2ban
```

### Q: 如何檢視歷史封禁記錄？

```bash
journalctl -t fail2ban --since "7 days ago"
```

這會顯示過去一週內的所有封禁事件。

## 結語

安全不是一次性的配置，而是持續的習慣。Fail2ban + SSH 審計聯動方案的核心價值在於：**讓機器處理常規威脅，讓人類專注於例外事件**。當你的 VPS 每天被掃描數百次時，一個自動化的封禁系統比任何手動監控都可靠。配置好之後，它會安安靜靜地在背景執行——直到有需要的那一天，你會感謝自己提前做了這件事。
