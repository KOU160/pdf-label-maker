#!/usr/bin/env bash
# コンテナ作成後に一度だけ実行されるセットアップスクリプト
# 1コマンドの失敗で以降がすべてスキップされないよう -e は使わない
set -uo pipefail

echo "==> [0/4] Claude Code の設定ディレクトリの権限を修正しています..."
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$CLAUDE_DIR"
# 名前付きボリュームが root 所有で作成されるケースがあるため、確実に自分の所有に戻す
sudo chown -R "$(id -u)":"$(id -g)" "$CLAUDE_DIR"

echo "==> [1/4] Playwright をインストールしています..."
# Node.js Feature がグローバルインストール先をユーザー権限で書き込めるようにしているため sudo は不要
npm install -g playwright
# Chromium / Firefox / WebKit と必要な依存パッケージ(apt)を一括インストール
# apt へのアクセスが必要な部分は Playwright が内部で自動的に sudo を呼び出す
npx --yes playwright install --with-deps

echo "==> [2/4] context7 MCP サーバーを Claude Code に登録しています..."
# ユーザースコープで登録 -> すべてのプロジェクトで利用可能になる
claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp \
	&& echo "    -> context7 登録成功" \
	|| echo "    !! context7 の登録に失敗しました(ログを確認してください)"

echo "==> [2.5/4] Playwright MCP サーバーを Claude Code に登録しています..."
claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest \
	&& echo "    -> playwright 登録成功" \
	|| echo "    !! playwright MCP の登録に失敗しました(ログを確認してください)"

echo "==> [3/4] Serena MCP サーバーを uv/uvx 経由で Claude Code に登録しています..."
# uvx が GitHub から直接 Serena を取得して起動する(ローカルインストール不要)
claude mcp add --scope user serena -- \
	uvx --from git+https://github.com/oraios/serena \
	serena start-mcp-server --context ide-assistant --project-from-cwd \
	&& echo "    -> serena 登録成功" \
	|| echo "    !! serena の登録に失敗しました(ログを確認してください)"

echo "==> [4/4] 登録結果を確認します"
claude mcp list || echo "    !! claude mcp list の実行に失敗しました"

echo "==> セットアップが完了しました。"
