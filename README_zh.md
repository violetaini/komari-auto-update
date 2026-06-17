<div align="center">

<img src="assets/logo.svg" alt="Komari Auto Update" width="120" />

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

用于二进制安装方式的 [Komari Monitor](https://github.com/komari-monitor/komari) 自动更新器。检测逻辑和 Komari 面板的升级提示思路一致：读取本机 `/api/version`，对比官方 GitHub Releases，跳过 draft 和 prerelease，只在发现更新的稳定版时执行升级。

项目范围刻意收窄：只更新由 systemd 管理的 Komari server 二进制文件。不负责安装 Komari，不管理 `komari-agent`，也不支持 Docker 或 Compose 部署。

## 功能

- 一条命令安装，适用于 systemd 管理的 Komari 二进制部署。
- 检查官方 Komari GitHub Releases，并跳过 draft/prerelease。
- 下载前先做语义化版本比较。
- 下载精确版本的 release asset，不依赖滚动的 `latest` 地址。
- 替换前备份当前二进制文件和 `data` 目录。
- 只保留配置数量的备份版本。
- 新服务启动失败或版本验证失败时自动回滚。
- 使用 `flock` 防止并发执行。
- 使用 systemd timer，支持自定义执行间隔。
- 提供卸载命令。
- README 徽章数据由本仓库 GitHub Actions 调 GitHub 官方 API 生成。

## 支持的部署方式

支持：

- Linux
- systemd
- Komari 以本地二进制方式安装，通常为 `/opt/komari/komari`
- Komari systemd 服务，通常为 `komari.service`

不支持：

- Docker
- Docker Compose
- 源码开发目录部署
- 只更新 agent
- 从零安装 Komari

安装器会验证配置的 systemd 服务确实运行配置的 Komari 二进制文件。验证失败会直接停止，避免猜测安装方式。

## 依赖

- Root 权限
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

## 快速安装

```bash
curl -fsSL -o install-komari-auto-update.sh https://raw.githubusercontent.com/violetaini/komari-auto-update/main/install.sh && chmod +x install-komari-auto-update.sh && sudo bash install-komari-auto-update.sh
```

默认行为：

- 检查间隔：`6h`
- 备份保留：`2`
- Komari 二进制：`/opt/komari/komari`
- Komari 服务：`komari.service`
- 本地版本 API：`http://127.0.0.1:25774/api/version`

## 自定义更新频率

使用 `--interval` 修改自动更新的执行间隔。该值会写入 systemd `OnUnitActiveSec`。

```bash
sudo bash install-komari-auto-update.sh --interval 12h
```

常见示例：

```bash
sudo bash install-komari-auto-update.sh --interval 6h
sudo bash install-komari-auto-update.sh --interval 12h
sudo bash install-komari-auto-update.sh --interval 1d
```

也可以使用环境变量：

```bash
INTERVAL=12h KEEP_BACKUPS=3 sudo -E bash install-komari-auto-update.sh
```

## 自定义备份保留数量

使用 `--keep-backups` 控制保留多少份二进制备份和数据备份。

```bash
sudo bash install-komari-auto-update.sh --keep-backups 2
```

清理逻辑会在以下目录分别保留最新的 `N` 份二进制备份和 `N` 份数据归档：

```text
/opt/komari/backups/auto-update
```

## 自定义路径

如果二进制路径、服务名或本地 API 地址不同：

```bash
sudo bash install-komari-auto-update.sh \
  --bin /opt/komari/komari \
  --service komari.service \
  --api http://127.0.0.1:25774/api/version \
  --interval 6h \
  --keep-backups 2
```

## 使用

手动执行一次更新检查：

```bash
sudo /usr/local/sbin/komari-auto-update
```

仅演练，不实际替换：

```bash
sudo /usr/local/sbin/komari-auto-update --dry-run
```

查看 timer 状态：

```bash
systemctl status komari-auto-update.timer --no-pager -l
systemctl list-timers --all | grep komari-auto-update
```

查看日志：

```bash
journalctl -u komari-auto-update.service -n 80 --no-pager
journalctl -u komari-auto-update.service -f
```

卸载：

```bash
sudo /usr/local/sbin/komari-auto-update-uninstall
```

或：

```bash
sudo bash uninstall.sh
```

## 配置

安装器会写入：

```text
/etc/komari-auto-update.conf
```

示例：

```bash
KOMARI_BIN="/opt/komari/komari"
KOMARI_SERVICE="komari.service"
KOMARI_API="http://127.0.0.1:25774/api/version"
KEEP_BACKUPS="2"
```

安装后如需修改运行频率，编辑：

```text
/etc/systemd/system/komari-auto-update.timer
```

然后重新加载并重启 timer：

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

安装后如需修改备份保留数量，编辑：

```text
/etc/komari-auto-update.conf
```

然后可以先演练一次：

```bash
sudo /usr/local/sbin/komari-auto-update --dry-run
```

## 安全行为

自动更新器按无人值守场景设计：

- Komari 已经是最新稳定版时直接退出。
- Komari 服务未运行时拒绝更新。
- 不支持的 CPU 架构会拒绝执行。
- 找不到匹配的 Linux 二进制 asset 时拒绝执行。
- 替换前备份二进制文件。
- 替换前归档 `data` 目录。
- 替换后启动 Komari 并校验报告版本。
- 启动失败或校验失败时回滚二进制和数据备份。
- 按配置清理旧备份。

## 安装内容

安装器会创建：

```text
/usr/local/sbin/komari-auto-update
/usr/local/sbin/komari-auto-update-uninstall
/etc/komari-auto-update.conf
/etc/systemd/system/komari-auto-update.service
/etc/systemd/system/komari-auto-update.timer
/opt/komari/backups/auto-update/
```

仓库文件：

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

## 徽章数据

`.github/badges` 下的 README badge JSON 由 `.github/workflows/update-badges.yml` 生成。workflow 使用 GitHub Actions 和 GitHub 官方 API 数据，然后把生成的 JSON 提交回仓库。

徽章由 `img.shields.io/endpoint` 渲染，但统计数据来自本仓库自己的 GitHub Actions，而不是第三方统计服务。

## 许可证

本项目使用 [MIT License](LICENSE) 开源。
