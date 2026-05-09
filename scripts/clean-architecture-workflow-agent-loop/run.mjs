#!/usr/bin/env node
/**
 * clean-architecture-violation-fix-workflow を Cursor ローカルエージェントで繰り返し実行する。
 *
 * 事前: export CURSOR_API_KEY=...
 * 初回: このディレクトリで npm install
 *
 * 実行:
 *   node run.mjs
 *   node run.mjs --max-iterations 20
 *   node run.mjs --cwd /path/to/agrr
 *
 * 終了（残課題なし）:
 *   - docs/ca-violations-backlog.md が存在しない、または
 *   - 同ファイル内の「## 修正単位」節に、未処理の項目が検出されない
 *     （`- [ ]` のチェックリスト、または `1. **題名**` 形式の番号付きリスト）
 */

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath, pathToFileURL } from "node:url";
import { Agent, CursorAgentError } from "@cursor/sdk";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const out = {
    cwd: null,
    maxIterations: Number.POSITIVE_INFINITY,
    model: process.env.CA_WORKFLOW_MODEL ?? "composer-2",
    dryRun: false,
  };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--cwd" && argv[i + 1]) {
      out.cwd = path.resolve(argv[++i]);
    } else if (a === "--max-iterations" && argv[i + 1]) {
      out.maxIterations = Math.max(1, Number.parseInt(argv[++i], 10));
      if (Number.isNaN(out.maxIterations)) {
        console.error("--max-iterations は正の整数にしてください");
        process.exit(1);
      }
    } else if (a === "--model" && argv[i + 1]) {
      out.model = argv[++i];
    } else if (a === "--dry-run") {
      out.dryRun = true;
    } else if (a === "-h" || a === "--help") {
      console.log(`Usage: node run.mjs [--cwd DIR] [--max-iterations N] [--model ID] [--dry-run]

環境変数:
  CURSOR_API_KEY   必須（Cursor の API キー）
  CA_WORKFLOW_MODEL  既定モデル（デフォルト: composer-2）
`);
      process.exit(0);
    }
  }
  return out;
}

function resolveRepoRoot(explicitCwd) {
  if (explicitCwd) return explicitCwd;
  let dir = process.cwd();
  for (let i = 0; i < 64; i++) {
    if (fs.existsSync(path.join(dir, ".git"))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  throw new Error(
    "リポジトリルートを特定できません。.git があるディレクトリで実行するか --cwd を指定してください。"
  );
}

const BACKLOG_REL = path.join("docs", "ca-violations-backlog.md");

/**
 * 「## 修正単位」から次の「## 」見出し直前までを対象に、未処理項目があるか。
 * SKILL / agent-operational-canonical のチェックリスト形式と、番号付き **題名** の両方を見る。
 */
export function backlogHasPendingItems(markdown) {
  const lines = markdown.split(/\r?\n/);
  let i = 0;
  while (i < lines.length) {
    if (/^##\s+修正単位/.test(lines[i])) {
      i++;
      const body = [];
      while (i < lines.length && !/^##\s/.test(lines[i])) {
        body.push(lines[i]);
        i++;
      }
      const block = body.join("\n");
      if (/-\s*\[\s*\]\s+/.test(block)) return true;
      if (/^\s*\d+\.\s+\*\*/m.test(block)) return true;
      return false;
    }
    i++;
  }
  // 見出しが無い場合はエージェントに正規化させるため「未完了」とみなす
  return true;
}

export function workflowComplete(repoRoot) {
  const backlogPath = path.join(repoRoot, BACKLOG_REL);
  if (!fs.existsSync(backlogPath)) {
    return { complete: true, reason: "docs/ca-violations-backlog.md が存在しない（規約どおりの完了状態）" };
  }
  const text = fs.readFileSync(backlogPath, "utf8");
  if (!backlogHasPendingItems(text)) {
    return {
      complete: true,
      reason:
        "バックログに「## 修正単位」節はあるが、未処理のチェックリスト/番号付き項目が検出されない（残課題なし）",
    };
  }
  return { complete: false, reason: "修正単位に未処理あり" };
}

function buildPrompt(repoRoot) {
  const skillRel = ".cursor/skills/clean-architecture-violation-fix-workflow/SKILL.md";
  const skillPath = path.join(repoRoot, skillRel);
  return `あなたは Cursor エージェントです。作業ディレクトリはリポジトリルート（${repoRoot}）です。

次のワークフローに **厳密に** 従ってください: ${skillRel}（絶対パス: ${skillPath}）
併せて ARCHITECTURE.md、rails-clean-architecture.mdc、no-convenience-tech-debt.mdc、rails-testing-workflow（test-common）、use-skills-on-edit.mdc に従うこと。

**今回のミッション（外側ループ 1 周分）**

1. セクション0: docs/ca-violations-backlog.md を読む。項目があるなら **先頭の修正単位** にスコープを固定する（ユーザーに順番を聞かない）。
   backlog が無い／中身から判断して「修正単位」が空なら、SKILL の「スキャン」を **ARCHITECTURE.md の「What we require」と禁止 1〜30 の通し走査** で実施し、結果を backlog に書くか、違反ゼロなら backlog を削除して外側ループ終了とする（agent-operational-canonical.md の Backlog ファイル運用）。
2. セクション1〜5: 固定した修正単位を実装し、レビュー、アーキテクチャゲート（1 回目・2 回目）、振る舞いチェック（lib/domain・gateway・CompositionRoot 変更時は test-common 経由で Rails テスト）まで行う。
3. セクション6: 意図したスコープだけ git commit する（ユーザーがコミット禁止を明示したときのみ省略）。**通し走査**（`## What we require` と禁止 1〜30）を実行し、その結果で `docs/ca-violations-backlog.md` を再同期する（解消の反映・新規逸脱の追記）。逸脱ゼロなら **backlog ファイルを削除** して外側ループ完了とする。残件があれば先頭の修正単位へ戻りセクション1 へ。詳細は agent-operational-canonical.md の Backlog ファイル運用。

**禁止**: 「続けますか」などユーザー発話待ちで止めること（ワークフロー SKILL セクション6）。規約上の障害で中断する場合は理由を明記する。

終了時点の目標: 残課題がないこと（**通し走査で逸脱ゼロを確認したうえで** backlog を削除した状態、または修正単位が空で同条件を満たしていること）。`;
}

async function main() {
  const opts = parseArgs(process.argv);
  const apiKey = process.env.CURSOR_API_KEY;
  if (!apiKey && !opts.dryRun) {
    console.error("CURSOR_API_KEY が設定されていません。");
    process.exit(1);
  }

  const repoRoot = resolveRepoRoot(opts.cwd);
  let iteration = 0;

  // 開始前に既に完了なら即終了
  const initial = workflowComplete(repoRoot);
  if (initial.complete) {
    console.log(`[ca-workflow-loop] 開始時点で完了: ${initial.reason}`);
    process.exit(0);
  }

  while (iteration < opts.maxIterations) {
    iteration++;
    const status = workflowComplete(repoRoot);
    if (status.complete) {
      console.log(`[ca-workflow-loop] 完了: ${status.reason}`);
      process.exit(0);
    }

    console.log(
      `[ca-workflow-loop] イテレーション ${iteration}${Number.isFinite(opts.maxIterations) ? ` / ${opts.maxIterations}` : ""} を開始します…`
    );

    if (opts.dryRun) {
      console.log("[ca-workflow-loop] --dry-run: エージェントは起動しません。");
      console.log(buildPrompt(repoRoot).slice(0, 500) + "…");
      process.exit(0);
    }

    try {
      const result = await Agent.prompt(buildPrompt(repoRoot), {
        apiKey,
        model: { id: opts.model },
        local: { cwd: repoRoot },
      });

      if (result.status === "error") {
        console.error(`[ca-workflow-loop] エージェント実行が error で終了: run をダッシュボードで確認してください。`);
        process.exit(2);
      }
    } catch (err) {
      if (err instanceof CursorAgentError) {
        console.error(`[ca-workflow-loop] 起動失敗: ${err.message} (retryable=${err.isRetryable})`);
        process.exit(1);
      }
      throw err;
    }

    const after = workflowComplete(repoRoot);
    if (after.complete) {
      console.log(`[ca-workflow-loop] 完了: ${after.reason}`);
      process.exit(0);
    }
  }

  console.error(
    `[ca-workflow-loop] --max-iterations (${opts.maxIterations}) に達しました。残課題ありの可能性があります。`
  );
  process.exit(4);
}

function isExecutedDirectly() {
  const entry = process.argv[1];
  if (!entry) return false;
  try {
    return import.meta.url === pathToFileURL(path.resolve(entry)).href;
  } catch {
    return false;
  }
}

if (isExecutedDirectly()) {
  main();
}
