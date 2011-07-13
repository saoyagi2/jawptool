= jawptool =

'''jawptool'''とは、ウィキペディア日本語版のダンプデータを対象にデータ処理を行うプログラム。

ウィキペディア日本語版を編集していると、「ああ、このミスって機械的にチェックできそうだなぁ」と思うことがよくあったので、実際にチェックするツールを作ってみたというのがスタートです。チェックするには、ウィキペディアのデータを用意しなければなりませんが、そのためにクローラを作ってサイトにアクセスするなんてのは非道です。そして、実際そのような用途のためにデータベースダンプ http://dumps.wikimedia.org/jawiki/ が用意されていますので、そちらを使ってチェックするようにしました。そうして出来上がったのが、wpja-lint.plというプログラムです(非公開)。

チェックは出来たのですが、プログラムを作っているうちに「統計処理をしたら面白いかな」とか色々夢が膨らんできたので、チェック(lint)専用のツールではなく、汎用的なツールとして作り直したのが、このjawptoolです。(wpja→jawpのミスもここで修正しました)。

== 機能 ==
;lint-title
:記事名の文法チェックを行います。

;lint-text
:記事本文の文法チェックを行います。

;statistic
:記事データの統計情報をとります。

;titlelist
:タイトル一覧データをDumper形式で出力します。

;living-noref
:存命人物記事で出典のないものの一覧を出力します。

== 使用法 ==
プログラムのインストールの手順は特にありません。jawptool.plとJAWP.pmを作業用ディレクトリに置いてください。環境によっては、jawptoo.plの先頭行のperlのパスを修正する必要があるかもしれません。

解析するデータは http://dumps.wikimedia.org/jawiki/ よりダウンロードしてきます。基本的にpages-meta-current.xml.bz2か、pages-articles.xml.bz2のどちらかを使用します。jawptoolは標準入力からデータを受け取ることができませんので、bzip2は事前に解凍しておいてください。

usageは次の通りです。
<pre>
jawptool 0.10

Usage: jawptool.pl command xmlfile reportfile

command:
  lint-title
  lint-text
  statistic
  titlelist
  living-noref
</pre>

== 歴史 ==
*2011年5月17日 - 初めてプログラムの構想を思いつく。
*2011年5月19日 - wpja-lintの開発開始。
*2011年5月27日 - wpjatoolに名称変更。
*2011年5月29日 - lint機能一通り完成。
*2011年6月3日 - jawptoolに名称変更。
*2011年7月13日 - 0.10公開。

より詳しい開発の経緯は http://www.saoyagi2.net/wikimedian/ に書かれています(それ以外のことも書いてますが)。

== ライセンス ==
本プログラムはGPLv3でライセンスされます。ライセンスの詳細は同梱のGPL-3.0.txtを参照下さい。日本語参考訳は http://sourceforge.jp/projects/opensource/wiki/licenses%252FGNU_General_Public_License_version_3.0 などにあります。

== 付属ツール ==
;test.pl
:プログラムのテストを行います。全てパスするのが理想ですが、環境によってはパスしないかもしれません。その場合はバグレポートを送っていただけると幸いです。

;wiki2html.pl
:jawptoolの出力は基本的にwikiテキストになっています。これをhtmlに変換するツールです。ただし、現状はごく基本的なwiki記法にしか対応していません。

== TODO ==
*XMLパースが超いい加減なのをちゃんとする。ただし、速度低下は出来ればしないように。
*全体的に高速化。特にXMLパース。
*全体的に省メモリ化。特にstatisticのメモリ消費が激しい。
*lint-textのCGI版を作る。
*Appクラスにある処理を別クラスに移動させ、Appは出来るだけスリムに。
*テストの充実

== 外部リンク ==
* [http://ja.wikipedia.org/wiki/Wikipedia:%E3%83%87%E3%83%BC%E3%82%BF%E3%83%99%E3%83%BC%E3%82%B9%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89 Wikipedia:データベースダウンロード]
* [http://dumps.wikimedia.org/jawiki/ ウィキペディア日本語版データベースダンプ]
* [http://jawptool.sourceforge.jp/ ウィキペディア日本語版データ解析ツール] - プログラム配布元
