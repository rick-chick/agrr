---
name: restart-angular
description: Restarts the Angular development server (frontend) on port 4200. Use when the user asks to restart Angular, reload the frontend dev server, or when code changes require an Angular server restart.
disable-model-invocation: true
---

# Angular 再起動

ポート 4200 上の Angular 開発サーバーを停止して起動し直す。

## When to Use

- Angular サーバーの再起動依頼（restart, reload, サーバー再起動 等）
- コード変更後に dev server を入れ替えたいとき

## Usage

```bash
.cursor/skills/sync-master-restart/scripts/restart-frontend.sh
```

`package.json` / `package-lock.json` 更新後:

```bash
RUN_NPM_CI=1 .cursor/skills/sync-master-restart/scripts/restart-frontend.sh
```

ポート変更: `PORT=4201 .cursor/skills/sync-master-restart/scripts/restart-frontend.sh`

master 取り込みと合わせる場合は [sync-master-restart](../sync-master-restart/SKILL.md) を使う。
