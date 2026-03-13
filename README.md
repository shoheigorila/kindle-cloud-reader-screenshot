# kindle-screenshot

Kindle Cloud Reader（read.amazon.co.jp）の全ページを自動でスクリーンショット保存するツール。

[playwright-cli](https://www.npmjs.com/package/playwright-cli) を使ってブラウザ操作を自動化し、ページ送り→スクリーンショット→終了検出を行う。

## 必要なもの

- [playwright-cli](https://www.npmjs.com/package/playwright-cli)
- macOS（クロップに `sips` を使用）

```bash
npm install -g playwright-cli
playwright-cli open  # ブラウザをインストール
```

## 使い方

### 1. 初回ログイン

```bash
./capture_kindle.sh --login
```

ブラウザが開くので、手動でAmazonにログインする。ログイン後、別ターミナルで以下を実行してブラウザを閉じる：

```bash
playwright-cli -s=kindle close
```

セッションは永続化されるので、次回以降はログイン不要。

### 2. スクリーンショット撮影

```bash
# 縦書き（右→左）の本（デフォルト）
./capture_kindle.sh --url "https://read.amazon.co.jp/?asin=..." --output ./my_book

# 横書き（左→右）の本
./capture_kindle.sh --url "https://read.amazon.co.jp/?asin=..." --output ./my_book --ltr
```

### 3. 並列実行

別々のターミナルタブで、セッション名を分けて実行する：

```bash
# タブ1
./capture_kindle.sh --session s1 --url "https://...?asin=AAA" --output ./book_a

# タブ2
./capture_kindle.sh --session s2 --url "https://...?asin=BBB" --output ./book_b

# タブ3
./capture_kindle.sh --session s3 --url "https://...?asin=CCC" --output ./book_c
```

16GB RAMなら3並列が目安。

## オプション一覧

| オプション | デフォルト | 説明 |
|-----------|-----------|------|
| `--login` | - | ログインモードで起動 |
| `--session NAME` | `kindle` | セッション名。並列実行時に分ける |
| `--url URL` | - | Kindle Cloud ReaderのブックURL |
| `--output DIR` | `./screenshots` | 出力ディレクトリ |
| `--ltr` | - | 横書きの本の場合に指定 |
| `--wait MS` | `1500` | ページ遷移の待機時間(ms) |
| `--no-crop` | - | UIクロップをスキップ |

## 仕組み

1. `playwright-cli` の永続プロファイルでログイン状態を維持
2. `run-code` で全ページループをJS内で一括実行（高速）
3. 各ページのスクリーンショットをBuffer比較し、前ページと同一なら最終ページと判断
4. 撮影完了後、`sips` でUIバー（ヘッダー/フッター/ナビボタン）を一括クロップ
