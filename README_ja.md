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

[Komari Monitor](https://github.com/komari-monitor/komari) のバイナリインストール向け自動更新ツールです。Komari Web パネルの更新通知と同じ考え方で、ローカルの `/api/version` を読み取り、公式 GitHub Releases と比較し、draft と prerelease を除外して、新しい安定版がある場合だけ更新します。

このプロジェクトの対象は意図的に狭くしています。systemd で管理されている Komari server のバイナリだけを更新します。Komari の初期インストール、`komari-agent` の管理、Docker/Compose デプロイには対応しません。

## Features

- systemd ベースの Komari バイナリデプロイ向けワンコマンドインストーラー。
- 公式 Komari GitHub Releases を確認し、draft/prerelease をスキップ。
- ダウンロード前にセマンティックバージョンを比較。
- 移動する `latest` URL ではなく、対象リリースの asset を直接ダウンロード。
- 置き換え前に現在のバイナリと `data` ディレクトリをバックアップ。
- 設定した数のバックアップだけを保持。
- 新しいサービスの起動またはバージョン検証に失敗した場合は自動ロールバック。
- `flock` で同時実行を防止。
- systemd timer による実行間隔の設定。
- アンインストールコマンドを提供。
- README バッジのデータは、このリポジトリの GitHub Actions が GitHub 公式 API から生成。

## Supported Deployment

対応：

- Linux
- systemd
- ローカルバイナリとしてインストールされた Komari。通常は `/opt/komari/komari`
- Komari systemd サービス。通常は `komari.service`

非対応：

- Docker
- Docker Compose
- ソースツリーでの開発用デプロイ
- agent のみの更新
- Komari の新規インストール

インストーラーは、設定された systemd サービスが設定された Komari バイナリを実行していることを検証します。検証に失敗した場合は推測せず停止します。

## Requirements

- Root 権限
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

## Quick Install

```bash
curl -fsSL -o install-komari-auto-update.sh https://raw.githubusercontent.com/violetaini/komari-auto-update/main/install.sh && chmod +x install-komari-auto-update.sh && sudo bash install-komari-auto-update.sh
```

デフォルト：

- チェック間隔：`6h`
- バックアップ保持数：`2`
- Komari バイナリ：`/opt/komari/komari`
- Komari サービス：`komari.service`
- ローカルバージョン API：`http://127.0.0.1:25774/api/version`

## Custom Frequency

`--interval` で自動更新の実行間隔を変更できます。この値は systemd の `OnUnitActiveSec` に渡されます。

```bash
sudo bash install-komari-auto-update.sh --interval 12h
```

よく使う例：

```bash
sudo bash install-komari-auto-update.sh --interval 6h
sudo bash install-komari-auto-update.sh --interval 12h
sudo bash install-komari-auto-update.sh --interval 1d
```

環境変数も使用できます。

```bash
INTERVAL=12h KEEP_BACKUPS=3 sudo -E bash install-komari-auto-update.sh
```

## Backup Retention

`--keep-backups` で保持するバイナリバックアップとデータバックアップの数を指定します。

```bash
sudo bash install-komari-auto-update.sh --keep-backups 2
```

クリーンアップ処理は、以下のディレクトリで最新の `N` 個のバイナリバックアップと最新の `N` 個のデータアーカイブを保持します。

```text
/opt/komari/backups/auto-update
```

## Custom Paths

バイナリ、サービス、ローカル API のパスが異なる場合：

```bash
sudo bash install-komari-auto-update.sh \
  --bin /opt/komari/komari \
  --service komari.service \
  --api http://127.0.0.1:25774/api/version \
  --interval 6h \
  --keep-backups 2
```

## Usage

手動で更新チェックを実行：

```bash
sudo /usr/local/sbin/komari-auto-update
```

ドライラン：

```bash
sudo /usr/local/sbin/komari-auto-update --dry-run
```

timer の状態確認：

```bash
systemctl status komari-auto-update.timer --no-pager -l
systemctl list-timers --all | grep komari-auto-update
```

ログ確認：

```bash
journalctl -u komari-auto-update.service -n 80 --no-pager
journalctl -u komari-auto-update.service -f
```

アンインストール：

```bash
sudo /usr/local/sbin/komari-auto-update-uninstall
```

または：

```bash
sudo bash uninstall.sh
```

## Configuration

インストーラーは次のファイルを書き込みます。

```text
/etc/komari-auto-update.conf
```

例：

```bash
KOMARI_BIN="/opt/komari/komari"
KOMARI_SERVICE="komari.service"
KOMARI_API="http://127.0.0.1:25774/api/version"
KEEP_BACKUPS="2"
```

インストール後に実行頻度を変更する場合は、次を編集します。

```text
/etc/systemd/system/komari-auto-update.timer
```

その後、timer を再読み込みして再起動します。

```bash
sudo systemctl daemon-reload
sudo systemctl restart komari-auto-update.timer
```

例：

```ini
OnUnitActiveSec=6h
```

を次のように変更します。

```ini
OnUnitActiveSec=12h
```

インストール後にバックアップ保持数を変更する場合は、次を編集します。

```text
/etc/komari-auto-update.conf
```

先にドライランで確認できます。

```bash
sudo /usr/local/sbin/komari-auto-update --dry-run
```

## Safety Behavior

自動更新ツールは無人運用を前提にしています。

- Komari がすでに最新安定版なら終了。
- Komari サービスが停止中なら更新を拒否。
- 未対応 CPU アーキテクチャなら拒否。
- 対応する Linux バイナリ asset がないリリースは拒否。
- 置き換え前にバイナリをバックアップ。
- 置き換え前に `data` ディレクトリをアーカイブ。
- 置き換え後に Komari を起動し、報告バージョンを検証。
- 起動または検証に失敗した場合は、バイナリとデータバックアップをロールバック。
- 設定された保持数に従って古いバックアップを削除。

## Installed Components

インストーラーは次を作成します。

```text
/usr/local/sbin/komari-auto-update
/usr/local/sbin/komari-auto-update-uninstall
/etc/komari-auto-update.conf
/etc/systemd/system/komari-auto-update.service
/etc/systemd/system/komari-auto-update.timer
/opt/komari/backups/auto-update/
```

リポジトリ内のファイル：

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

## Badge Data

`.github/badges` 以下の README badge JSON は `.github/workflows/update-badges.yml` により生成されます。この workflow は GitHub Actions と GitHub 公式 API のデータを使用し、生成した JSON をリポジトリへコミットします。

バッジの描画は `img.shields.io/endpoint` を使いますが、統計データは第三者の統計サービスではなく、このリポジトリ自身の GitHub Actions から生成されます。

## License

このプロジェクトは [MIT License](LICENSE) の下で公開されています。
