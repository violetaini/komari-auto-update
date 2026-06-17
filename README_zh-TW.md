<div align="center">

<img src="assets/avatar.webp" alt="Komari Auto Update" width="120" />

# **Komari Auto Update**

[English](README.md) · [简体中文](README_zh.md) · [繁體中文](README_zh-TW.md) · [日本語](README_ja.md)

[![Version](https://img.shields.io/endpoint?style=for-the-badge&url=https%3A%2F%2Fraw.githubusercontent.com%2Fvioletaini%2Fkomari-auto-update%2Fmain%2F.github%2Fbadges%2Fversion.json&cacheSeconds=3600)](VERSION)
[![Shell](https://img.shields.io/badge/Shell-Bash%20%2B%20systemd-4eaa25?style=for-the-badge)](komari-auto-update)
[![License](https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge)](LICENSE)
[![Contributors](https://img.shields.io/endpoint?style=for-the-badge&url=https%3A%2F%2Fraw.githubusercontent.com%2Fvioletaini%2Fkomari-auto-update%2Fmain%2F.github%2Fbadges%2Fcontributors.json&cacheSeconds=3600)](https://github.com/violetaini/komari-auto-update/graphs/contributors)
[![Commit activity](https://img.shields.io/endpoint?style=for-the-badge&url=https%3A%2F%2Fraw.githubusercontent.com%2Fvioletaini%2Fkomari-auto-update%2Fmain%2F.github%2Fbadges%2Fcommit-activity.json&cacheSeconds=3600)](https://github.com/violetaini/komari-auto-update/commits/main)
[![Repo size](https://img.shields.io/endpoint?style=for-the-badge&url=https%3A%2F%2Fraw.githubusercontent.com%2Fvioletaini%2Fkomari-auto-update%2Fmain%2F.github%2Fbadges%2Frepo-size.json&cacheSeconds=3600)](https://github.com/violetaini/komari-auto-update)
[![Stars](https://img.shields.io/endpoint?style=for-the-badge&url=https%3A%2F%2Fraw.githubusercontent.com%2Fvioletaini%2Fkomari-auto-update%2Fmain%2F.github%2Fbadges%2Fstars.json&cacheSeconds=3600)](https://github.com/violetaini/komari-auto-update/stargazers)
[![Forks](https://img.shields.io/endpoint?style=for-the-badge&url=https%3A%2F%2Fraw.githubusercontent.com%2Fvioletaini%2Fkomari-auto-update%2Fmain%2F.github%2Fbadges%2Fforks.json&cacheSeconds=3600)](https://github.com/violetaini/komari-auto-update/forks)

</div>

用於二進位安裝方式的 [Komari Monitor](https://github.com/komari-monitor/komari) 自動更新器。偵測邏輯和 Komari 面板的升級提示思路一致：讀取本機 `/api/version`，比對官方 GitHub Releases，略過 draft 和 prerelease，只在發現更新的穩定版時執行升級。

專案範圍刻意收窄：只更新由 systemd 管理的 Komari server 二進位檔。不負責安裝 Komari，不管理 `komari-agent`，也不支援 Docker 或 Compose 部署。

## 功能

- 一條命令安裝，適用於 systemd 管理的 Komari 二進位部署。
- 檢查官方 Komari GitHub Releases，並略過 draft/prerelease。
- 下載前先做語義化版本比較。
- 下載精確版本的 release asset，不依賴滾動的 `latest` 位址。
- 替換前備份目前二進位檔和 `data` 目錄。
- 只保留設定數量的備份版本。
- 新服務啟動失敗或版本驗證失敗時自動回滾。
- 使用 `flock` 防止並行執行。
- 使用 systemd timer，支援自訂執行間隔。
- 提供卸載命令。
- README 徽章資料由本倉庫 GitHub Actions 呼叫 GitHub 官方 API 產生。

## 支援的部署方式

支援：

- Linux
- systemd
- Komari 以本機二進位方式安裝，通常為 `/opt/komari/komari`
- Komari systemd 服務，通常為 `komari.service`

不支援：

- Docker
- Docker Compose
- 原始碼開發目錄部署
- 只更新 agent
- 從零安裝 Komari

安裝器會驗證設定的 systemd 服務確實執行設定的 Komari 二進位檔。驗證失敗會直接停止，避免猜測安裝方式。

## 依賴

- Root 權限
- Bash
- systemd
- `curl`
- `jq`
- `flock`
- `tar`
- `cmp`
- `install`
- `timeout`

Debian/Ubuntu：

```bash
apt update
apt install -y curl jq util-linux tar coreutils
```

## 快速安裝

```bash
curl -fsSL -o install-komari-auto-update.sh https://raw.githubusercontent.com/violetaini/komari-auto-update/main/install.sh && chmod +x install-komari-auto-update.sh && sudo bash install-komari-auto-update.sh
```

預設行為：

- 檢查間隔：`6h`
- 備份保留：`2`
- Komari 二進位：`/opt/komari/komari`
- Komari 服務：`komari.service`
- 本機版本 API：`http://127.0.0.1:25774/api/version`

## 自訂更新頻率

使用 `--interval` 修改自動更新的執行間隔。該值會寫入 systemd `OnUnitActiveSec`。

```bash
sudo bash install-komari-auto-update.sh --interval 12h
```

常見範例：

```bash
sudo bash install-komari-auto-update.sh --interval 6h
sudo bash install-komari-auto-update.sh --interval 12h
sudo bash install-komari-auto-update.sh --interval 1d
```

也可以使用環境變數：

```bash
INTERVAL=12h KEEP_BACKUPS=3 sudo -E bash install-komari-auto-update.sh
```

## 自訂備份保留數量

使用 `--keep-backups` 控制保留多少份二進位備份和資料備份。

```bash
sudo bash install-komari-auto-update.sh --keep-backups 2
```

清理邏輯會在以下目錄分別保留最新的 `N` 份二進位備份和 `N` 份資料封存：

```text
/opt/komari/backups/auto-update
```

## 自訂路徑

如果二進位路徑、服務名稱或本機 API 位址不同：

```bash
sudo bash install-komari-auto-update.sh \
  --bin /opt/komari/komari \
  --service komari.service \
  --api http://127.0.0.1:25774/api/version \
  --interval 6h \
  --keep-backups 2
```

## 使用

手動執行一次更新檢查：

```bash
sudo /usr/local/sbin/komari-auto-update
```

僅演練，不實際替換：

```bash
sudo /usr/local/sbin/komari-auto-update --dry-run
```

查看 timer 狀態：

```bash
systemctl status komari-auto-update.timer --no-pager -l
systemctl list-timers --all | grep komari-auto-update
```

查看日誌：

```bash
journalctl -u komari-auto-update.service -n 80 --no-pager
journalctl -u komari-auto-update.service -f
```

卸載：

```bash
sudo /usr/local/sbin/komari-auto-update-uninstall
```

或：

```bash
sudo bash uninstall.sh
```

## 設定

安裝器會寫入：

```text
/etc/komari-auto-update.conf
```

範例：

```bash
KOMARI_BIN="/opt/komari/komari"
KOMARI_SERVICE="komari.service"
KOMARI_API="http://127.0.0.1:25774/api/version"
KEEP_BACKUPS="2"
```

安裝後如需修改執行頻率，編輯：

```text
/etc/systemd/system/komari-auto-update.timer
```

然後重新載入並重啟 timer：

```bash
sudo systemctl daemon-reload
sudo systemctl restart komari-auto-update.timer
```

例如把：

```ini
OnUnitActiveSec=6h
```

改成：

```ini
OnUnitActiveSec=12h
```

安裝後如需修改備份保留數量，編輯：

```text
/etc/komari-auto-update.conf
```

然後可以先演練一次：

```bash
sudo /usr/local/sbin/komari-auto-update --dry-run
```

## 安全行為

自動更新器按無人值守情境設計：

- Komari 已經是最新穩定版時直接退出。
- Komari 服務未執行時拒絕更新。
- 不支援的 CPU 架構會拒絕執行。
- 找不到匹配的 Linux 二進位 asset 時拒絕執行。
- 替換前備份二進位檔。
- 替換前封存 `data` 目錄。
- 替換後啟動 Komari 並驗證報告版本。
- 啟動失敗或驗證失敗時回滾二進位和資料備份。
- 按設定清理舊備份。

## 安裝內容

安裝器會建立：

```text
/usr/local/sbin/komari-auto-update
/usr/local/sbin/komari-auto-update-uninstall
/etc/komari-auto-update.conf
/etc/systemd/system/komari-auto-update.service
/etc/systemd/system/komari-auto-update.timer
/opt/komari/backups/auto-update/
```

倉庫檔案：

```text
.
├── komari-auto-update
├── install.sh
├── uninstall.sh
├── examples/
│   ├── komari-auto-update.service
│   └── komari-auto-update.timer
├── scripts/
│   └── generate-badges.mjs
└── .github/
    ├── badges/
    └── workflows/update-badges.yml
```

## 徽章資料

`.github/badges` 下的 README badge JSON 由 `.github/workflows/update-badges.yml` 產生。workflow 使用 GitHub Actions 和 GitHub 官方 API 資料，然後把產生的 JSON 提交回倉庫。

徽章由 `img.shields.io/endpoint` 渲染，但統計資料來自本倉庫自己的 GitHub Actions，而不是第三方統計服務。

## 授權

本專案使用 [MIT License](LICENSE) 開源。
