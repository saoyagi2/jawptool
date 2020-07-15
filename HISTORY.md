# jawptoolの歴史

## 2011年5月17日 - 初めてプログラムの構想を思いつく。

## 2011年5月19日 - wpja-lintの開発開始。

## 2011年5月27日 - wpjatoolに名称変更。

## 2011年5月29日 - lint機能一通り完成。

## 2011年6月3日 - jawptoolに名称変更。

## 2011年7月13日 - 0.10公開。

## 2011年7月24日 - 0.11公開。修正内容は以下の通り。
* lint-textのチェック項目強化
* lint-textの出力件数の上限を10000件に設定。
* titlelistの出力形式を修正
* テスト強化
* 多少の高速化
* メモリ使用量の多少の削減
* その他バグ修正

## 2011年7月27日 - 0.12公開。修正内容は以下の通り。
* ソースコード整理
* テスト強化
* その他バグ修正

## 2011年8月9日 - 0.13公開。修正内容は以下の通り。
* LintText強化
  - リンク先が曖昧さ回避またはリダイレクトの場合に警告
  - 存在しないカテゴリ、テンプレートの呼び出しを警告
* Statistic強化
  - 発リンクランキング
  - 節名の使用数ランキング
  - 外部リンクのドメイン統計
* メモリ使用量の多少の削減
* その他バグ修正

## 2011年9月21日 - 0.20公開。修正内容は以下の通り。
* jawp-lint.cgi - 新設
* lint-redirect、lint-index、passed-sakujo、person、noindex、index-list、aimaiの各コマンドを新設
* living-noref - 出力上限1万件の制限を解除
* titlelist - Data::Dumperを使用しないように変更。名前空間ごとに別ファイルに出力するように変更
* statistic - 井戸端統計を追加
* その他バグ修正

## 2011年10月5日 - 0.21公開。修正内容は以下の通り。
* lint-title - チェック機能強化
* lint-redirect - チェック機能強化、レポート形式変更
* lint-index - チェック機能強化
* statistic - 議論の統計項目追加
* person - 都道府県別出身人物検出機能追加
* Aimai - 小中高等学校加筆候補検出機能追加
* jawp-lint.cgi - titlelist読み込み機能追加
* 多少の高速化
* その他バグ修正

## 2011年11月29日 - 0.22公開。修正内容は以下の通り。
* テストをクラスごとに分割しt/に移動
* wiki2html.plの機能強化
* テストの強化とコード整理
* その他バグ修正

## 2012年7月25日 - 0.30公開。修正内容は以下の通り。
* passed-sakujoを機能強化しlongterm-requestに変更
* index-listを機能強化しindex-statisticに変更
* shortpage、lonelypage、category-statisticを追加
* personの出力情報を変更
* jawp-lint.cgiをlint-text.cgiにファイル名変更
* lint-title.cgiを追加
* wiki2html.plの機能強化
* manual.htmlの同梱
* その他バグ修正
