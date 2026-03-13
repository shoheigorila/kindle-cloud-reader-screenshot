#!/usr/bin/env bash
# Kindle Cloud Reader 全ページスクリーンショット自動化 (playwright-cli版)
set -euo pipefail

SESSION="kindle"
OUTPUT_DIR="./screenshots"
URL=""
LOGIN=false
WAIT_MS=1500
NEXT_KEY="ArrowLeft"  # rtl(縦書き)がデフォルト
CROP_TOP=60
CROP_BOTTOM=80
CROP_LEFT=90
CROP_RIGHT=90
NO_CROP=false

usage() {
  cat <<'EOF'
Usage:
  capture_kindle.sh --login [--session NAME]
  capture_kindle.sh --url "https://read.amazon.co.jp/..." [OPTIONS]

Options:
  --login            Amazonに手動ログインしてセッションを保存
  --session NAME     セッション名 (default: kindle)。並列実行時に分ける
  --url URL          Kindle Cloud ReaderのブックURL
  --output DIR       スクリーンショット保存先 (default: ./screenshots)
  --ltr              横書き（左→右）の本の場合に指定
  --wait MS          ページ遷移の待機時間ms (default: 1500)
  --no-crop          クロップせずにそのまま保存

Examples:
  # 初回ログイン
  ./capture_kindle.sh --login

  # 1冊キャプチャ
  ./capture_kindle.sh --url "https://read.amazon.co.jp/?asin=..." --output ./book1

  # 並列実行（別々のターミナルタブで）
  ./capture_kindle.sh --session s1 --url "https://..." --output ./book1
  ./capture_kindle.sh --session s2 --url "https://..." --output ./book2
  ./capture_kindle.sh --session s3 --url "https://..." --output ./book3
EOF
  exit 1
}

# --- 引数パース ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --login)    LOGIN=true; shift ;;
    --session)  SESSION="$2"; shift 2 ;;
    --url)      URL="$2"; shift 2 ;;
    --output)   OUTPUT_DIR="$2"; shift 2 ;;
    --ltr)      NEXT_KEY="ArrowRight"; shift ;;
    --wait)     WAIT_MS="$2"; shift 2 ;;
    --no-crop)  NO_CROP=true; shift ;;
    *)          usage ;;
  esac
done

# --- ログインモード ---
if $LOGIN; then
  echo "ブラウザを起動します。Amazonにログインしてください。"
  playwright-cli -s="$SESSION" open "https://read.amazon.co.jp/" --persistent --headed
  echo ""
  echo "ログイン完了後、以下を実行してブラウザを閉じてください:"
  echo "  playwright-cli -s=$SESSION close"
  echo ""
  echo "次回からは --url で本のURLを指定して実行できます。"
  exit 0
fi

# --- キャプチャモード ---
if [[ -z "$URL" ]]; then
  usage
fi

OUTPUT_DIR=$(cd "$(dirname "$OUTPUT_DIR")" 2>/dev/null && pwd)/$(basename "$OUTPUT_DIR") || OUTPUT_DIR=$(pwd)/$OUTPUT_DIR
mkdir -p "$OUTPUT_DIR"

echo "[$SESSION] ブラウザを起動中..."
playwright-cli -s="$SESSION" open --persistent --headed
playwright-cli -s="$SESSION" resize 1920 1080
playwright-cli -s="$SESSION" goto "$URL"

echo "[$SESSION] ページ読み込み待機 (5秒)..."
sleep 5

echo "[$SESSION] スクリーンショット撮影開始 (wait: ${WAIT_MS}ms, key: ${NEXT_KEY})..."

# run-codeで一括実行（プロセス起動オーバーヘッドを排除）
RESULT=$(playwright-cli -s="$SESSION" run-code "async page => {
  const dir = '${OUTPUT_DIR}';
  const key = '${NEXT_KEY}';
  const wait = ${WAIT_MS};
  let pageNum = 1;
  let prevBuf = null;

  while (true) {
    const filepath = dir + '/page_' + String(pageNum).padStart(3, '0') + '.png';
    const buf = await page.screenshot({ path: filepath, type: 'png' });

    if (prevBuf && buf.length === prevBuf.length && buf.every((v, i) => v === prevBuf[i])) {
      return 'DONE:' + (pageNum - 1);
    }

    prevBuf = buf;
    pageNum++;

    await page.keyboard.press(key);
    await page.waitForTimeout(wait);
  }
}")

# 結果からページ数を抽出
TOTAL=$(echo "$RESULT" | grep -o 'DONE:[0-9]*' | cut -d: -f2)
echo "[$SESSION] 最終ページ検出。合計 ${TOTAL} ページ保存しました。"

# 重複した最後のファイルを削除
LAST_FILE=$(printf "%s/page_%03d.png" "$OUTPUT_DIR" "$((TOTAL + 1))")
rm -f "$LAST_FILE"

echo "[$SESSION] ブラウザを閉じています..."
playwright-cli -s="$SESSION" close

# --- 一括クロップ ---
if ! $NO_CROP; then
  echo "[$SESSION] UIをクロップ中..."
  for f in "$OUTPUT_DIR"/page_*.png; do
    w=$(sips -g pixelWidth "$f" | awk '/pixelWidth/{print $2}')
    h=$(sips -g pixelHeight "$f" | awk '/pixelHeight/{print $2}')
    crop_w=$((w - CROP_LEFT - CROP_RIGHT))
    crop_h=$((h - CROP_TOP - CROP_BOTTOM))
    sips -c "$crop_h" "$crop_w" --cropOffset "$CROP_TOP" "$CROP_LEFT" "$f" --out "$f" >/dev/null
  done
  echo "[$SESSION] クロップ完了"
fi

echo "[$SESSION] 完了: $OUTPUT_DIR"
