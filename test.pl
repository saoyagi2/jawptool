#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Encode;
use open IO  => ":utf8";
binmode Test::More->builder->output, ":utf8";
binmode Test::More->builder->failure_output, ":utf8";
binmode Test::More->builder->todo_output, ":utf8";

use Test::More 'no_plan';


my $testdir = 'jawptool_test_directory';
my $testxmlfile = "$testdir/test.xml";
my $testreportfile = "$testdir/report.txt";


################################################################################
# メイン
################################################################################

{
	Startup();

	TestJAWP();
	TestJAWPArticle();
	TestJAWPTitleList();
	TestJAWPData();
	TestJAWPUtil();
	TestJAWPReport();
	TestJAWPApp();

	Cleanup();
}


################################################################################
# JAWP
################################################################################

sub TestJAWP {
	diag( '###################### Test JAWP ######################' );

	# useテスト
	use_ok( 'JAWP', 'use JAWP' );
}


################################################################################
# JAWP::Articleクラス
################################################################################

sub TestJAWPArticle {
	diag( '###################### Test JAWP::Article ######################' );

	# メソッド呼び出しテスト
	{
		foreach my $method ( 'new', 'IsRedirect', 'IsAimai', 'IsLiving', 'IsNoref', 'LintTitle', 'LintText' ) {
			ok( JAWP::Article->can($method), "call method $method" );
		}
	}

	# メンバー変数確認
	{
		my $article = new JAWP::Article;

		ok( defined( $article ), 'new' );
		cmp_ok( keys( %$article ), '==', 3, 'member count' );

		foreach my $member ( 'title', 'timestamp', 'text' ) {
			ok( defined( $article->{$member} ), "defined member $member" );
			is( $article->{$member}, '', "member $member value" );
		}
	}

	# IsRedirectテスト
	{
		diag( '# Test IsRedirect' );
		my $article = new JAWP::Article;

		ok( !$article->IsRedirect, 'empty' );

		foreach my $text ( '#redirect[[転送先]]', '#REDIRECT[[転送先]]', '#転送[[転送先]]', '＃redirect[[転送先]]', '＃REDIRECT[[転送先]]', '＃転送[[転送先]]' ) {
			$article->{'text'} = $text;
			ok( $article->IsRedirect, $text );
		}
	}

	# IsAimaiテスト
	{
		diag( '# Test IsAimai' );
		my $article = new JAWP::Article;

		ok( !$article->IsAimai, 'empty' );

		foreach my $text ( '{{aimai}}', '{{人名の曖昧さ回避}}', '{{地名の曖昧さ回避}}' ) {
			$article->{'text'} = $text;
			ok( $article->IsAimai, $text );
		}
	}

	# IsLivingテスト
	{
		diag( '# Test IsLiving' );
		my $article = new JAWP::Article;

		ok( !$article->IsLiving, 'empty' );

		$article->{'text'} = '[[Category:存命人物]]';
		ok( $article->IsLiving, '[[Category:存命人物]]' );
	}

	# IsNorefテスト
	{
		diag( '# Test IsNoref' );
		my $article = new JAWP::Article;

		ok( $article->IsNoref, 'empty' );

		foreach my $text ( '== 参考 ==', '== 文献 ==', '== 資料 ==', '== 書籍 ==', '== 図書 ==', '== 注 ==', '== 註 ==', '== 出典 ==', '== 典拠 ==', '== 出所 ==', '== 原典 ==', '== ソース ==', '== 情報源 ==', '== 引用元 ==', '== 論拠 ==', '== 参照 ==', '<ref>' ) {
			$article->{'text'} = "あああ\n$text\nいいい\n";
			ok( !$article->IsNoref, $text );
		}
	}

	# Namespaceテスト
	{
		diag( '# Test Namespace' );
		my $article = new JAWP::Article;
		my $namespace;

		is( $article->Namespace, '標準', 'empty' );

		foreach my $title ( '利用者:dummy', 'Wikipedia:dummy', 'ファイル:dummy', 'MediaWiki:dummy', 'Template:dummy', 'Help:dummy', 'Category:dummy', 'Portal:dummy', 'プロジェクト:dummy', 'ノート:dummy', '利用者‐会話:dummy', 'Wikipedia‐ノート:dummy', 'ファイル‐ノート:dummy', 'MediaWiki‐ノート:dummy', 'Template‐ノート:dummy', 'Help‐ノート:dummy', 'Category‐ノート:dummy', 'Portal‐ノート:dummy', 'プロジェクト‐ノート:dummy' ) {
			$article->{'title'} = $title;
			$namespace = $title;
			$namespace =~ s/:.*//;
			is( $article->Namespace, $namespace, $title );
		}
	}

	# LintTitleテスト
	{
		diag( '# Test LintTitle' );

		my $article = new JAWP::Article;
		my $result_ref;

		$article->{'title'} = '';
		$result_ref = $article->LintTitle;
		is( ref $result_ref, 'ARRAY', 'result is ARRAY reference' );
		is( @$result_ref + 0, 0, 'result array size 0' );

		# 標準記事空間以外は無視確認
		foreach my $title ( '利用者:①', 'Wikipedia:①', 'ファイル:①', 'MediaWiki:①', 'Template:①', 'Help:①', 'Category:①', 'Portal:①', 'プロジェクト:①', 'ノート:①', '利用者‐会話:①', 'Wikipedia‐ノート:①', 'ファイル‐ノート:①', 'MediaWiki‐ノート:①', 'Template‐ノート:①', 'Help‐ノート:①', 'Category‐ノート:①', 'Portal‐ノート:①', 'プロジェクト‐ノート:①' ) {
			$article->{'title'} = $title;
			$result_ref = $article->LintTitle;
			is( @$result_ref + 0, 0, $title );
		}

		# リダイレクト記事は無視確認
		$article->{'text'} = '#redirect[[転送先]]';
		foreach my $title ( '記事名（曖昧さ回避）', '記事名(曖昧さ回避)', '記事名  (曖昧さ回避)', '株式会社あいうえお', 'あいうえお株式会社', '，', '．', '！', '？', '＆', '＠', 'Ａ', 'Ｚ', 'ａ', 'ｚ', '０', '９', 'ｱ', 'ﾝ', 'ﾞ', 'ﾟ', 'ｧ', 'ｫ', 'ｬ', 'ｮ', '｡', '｢', '｣', '､', 'Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ', 'Ⅶ', 'Ⅷ', 'Ⅸ', 'Ⅹ', '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩', '⑪', '⑫', '⑬', '⑭', '⑮', '⑯', '⑰', '⑱', '⑲', '⑳', '髙' ) {
			$article->{'title'} = $title;
			$result_ref = $article->LintTitle;
			is( @$result_ref + 0, 0, "$title(リダイレクト)" );
		}

		# 曖昧さ回避テスト
		{
			$article->{'text'} = '';
			foreach my $title ( '記事名（曖昧さ回避）' ) {
				$article->{'title'} = $title;
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "$title(非リダイレクト)" );
				is( $result_ref->[0], '曖昧さ回避の記事であればカッコは半角でないといけません', "$title(非リダイレクト)" );
			}
			$article->{'text'} = '';
			foreach my $title ( '記事名(曖昧さ回避)', '記事名  (曖昧さ回避)' ) {
				$article->{'title'} = $title;
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "$title(非リダイレクト)" );
				is( $result_ref->[0], '曖昧さ回避の記事であればカッコの前のスペースはひとつでないといけません', "$title(非リダイレクト)" );
			}
		}

		# 記事名に使用できる文字・文言テスト
		{
			$article->{'text'} = '';
			foreach my $title ( '株式会社あいうえお', 'あいうえお株式会社', '有限会社あいうえお', 'あいうえお有限会社', '合名会社あいうえお', 'あいうえお合名会社', '合資会社あいうえお', 'あいうえお合資会社', '合同会社あいうえお', 'あいうえお合同会社' ) {
				$article->{'title'} = $title;
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "$title(非リダイレクト)" );
				is( $result_ref->[0], '会社の記事であれば法的地位を示す語句を含むことは推奨されません', "$title(非リダイレクト)" );
			}
			$article->{'text'} = '';
			foreach my $title ( '，', '．', '！', '？', '＆', '＠' ) {
				$article->{'title'} = $title;
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "$title(非リダイレクト)" );
				is( $result_ref->[0], '全角記号の使用は推奨されません', "$title(非リダイレクト)" );
			}
			$article->{'text'} = '';
			foreach my $title ( 'Ａ', 'Ｚ', 'ａ', 'ｚ', '０', '９' ) {
				$article->{'title'} = $title;
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "$title(非リダイレクト)" );
				is( $result_ref->[0], '全角英数字の使用は推奨されません', "$title(非リダイレクト)" );
			}
			$article->{'text'} = '';
			foreach my $title ( 'ｱ', 'ﾝ', 'ﾞ', 'ﾟ', 'ｧ', 'ｫ', 'ｬ', 'ｮ', '｡', '｢', '｣', '､' ) {
				$article->{'title'} = $title;
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "$title(非リダイレクト)" );
				is( $result_ref->[0], '半角カタカナの使用は推奨されません', "$title(非リダイレクト)" );
			}
			$article->{'text'} = '';
			foreach my $title ( 'Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ', 'Ⅶ', 'Ⅷ', 'Ⅸ', 'Ⅹ' ) {
				$article->{'title'} = $title;
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "$title(非リダイレクト)" );
				is( $result_ref->[0], 'ローマ数字はアルファベットを組み合わせましょう', "$title(非リダイレクト)" );
			}
			$article->{'text'} = '';
			foreach my $title ( '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩', '⑪', '⑫', '⑬', '⑭', '⑮', '⑯', '⑰', '⑱', '⑲', '⑳' ) {
				$article->{'title'} = $title;
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "$title(非リダイレクト)" );
				is( $result_ref->[0], '丸付き数字の使用は推奨されません', "$title(非リダイレクト)" );
			}
			$article->{'text'} = '';
			foreach my $title ( '髙' ) {
				$article->{'title'} = $title;
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "$title(非リダイレクト)" );
				is( $result_ref->[0], sprintf( "%s(U+%04X) はJIS X 0208外の文字です", $title, ord( $title ) ), "$title(非リダイレクト)" );
			}
		}
	}

	# LintTextテスト
	{
		diag( '# Test LintText' );

		my $article = new JAWP::Article;
		my $result_ref;

		# 標準記事空間以外は無視確認
		foreach my $namespace ( '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート' ) {
			$article->{'title'} = "$namespace:TEST";
			$article->{'text'} = '標準';
			$result_ref = $article->LintText( $article );
			is( ref $result_ref, 'ARRAY', 'result is ARRAY reference' );
			is( @$result_ref + 0, 0, 'result array size 0' );
		}

		# リダイレクト記事は無視確認
		$article->{'title'} = '標準';
		$article->{'text'} = '#redirect[[転送先]]';
		$result_ref = $article->LintText( $article );
		is( ref $result_ref, 'ARRAY', 'result is ARRAY reference' );
		is( @$result_ref + 0, 0, 'result array size 0' );


		# 特定タグ内は無視確認
		{
			foreach my $tag ( 'math', 'code', 'pre', 'nowiki' ) {
				$article->{'title'} = '標準';
				$article->{'text'} = "<$tag>\n= あああ =\n</$tag>\n{{aimai}}";
				$result_ref = $article->LintText;
				is( @$result_ref + 0, 0, "$tag タグ内無視(警告数)" );

				$article->{'title'} = '標準';
				$article->{'text'} = "<$tag>\nあああ\n</$tag>\n= いいい =\n{{aimai}}";
				$result_ref = $article->LintText;
				is( @$result_ref + 0, 1, "$tag タグ内無視(行数の不動)-2(警告数)" );
				is( $result_ref->[0], "レベル1の見出しがあります(4)", "$tag タグ内無視(行数の不動)-2(警告文)" );

				$article->{'title'} = '標準';
				$article->{'text'} = "<$tag>\nあああ\n</$tag>\n= いいい =\n<$tag>\nううう\n</$tag>{{aimai}}";
				$result_ref = $article->LintText;
				is( @$result_ref + 0, 1, "$tag タグ内無視(タグが複数ある場合)-3(警告数)" );
				is( $result_ref->[0], "レベル1の見出しがあります(4)", "$tag タグ内無視(タグが複数ある場合)-3(警告文)" );
			}
		}

		# 見出しテスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n= いいい =\nううう\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "見出しレベル1(警告数)" );
			is( $result_ref->[0], "レベル1の見出しがあります(2)", "見出しレベル1(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n = いいい = \nううう\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "無効な見出しレベル1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n== いいい ==\nううう\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "見出しレベル2(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n == いいい == \nううう\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "無効な見出しレベル2(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n== いいい ==\n=== ううう ===\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "見出しレベル3-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n=== いいい ===\nううう\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "見出しレベル3-2(警告数)" );
			is( $result_ref->[0], "レベル3の見出しの前にレベル2の見出しが必要です(2)", "見出しレベル3-2(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n === いいい === \nううう\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "無効な見出しレベル3(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "見出しレベル4-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n== いいい ==\n==== えええ ====\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "見出しレベル4-2(警告数)" );
			is( $result_ref->[0], "レベル4の見出しの前にレベル3の見出しが必要です(3)", "見出しレベル4-2(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n==== いいい ====\nううう\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "見出しレベル4-3(警告数)" );
			is( $result_ref->[0], "レベル4の見出しの前にレベル3の見出しが必要です(2)", "見出しレベル4-3(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n ==== いいい ==== \nううう\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "無効な見出しレベル4(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n===== おおお =====\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "見出しレベル5-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n== いいい ==\n=== ううう ===\n===== おおお =====\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "見出しレベル5-2(警告数)" );
			is( $result_ref->[0], "レベル5の見出しの前にレベル4の見出しが必要です(4)", "見出しレベル5-2(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n===== いいい =====\nううう\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "見出しレベル5-3(警告数)" );
			is( $result_ref->[0], "レベル5の見出しの前にレベル4の見出しが必要です(2)", "見出しレベル5-3(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n ===== いいい ===== \nううう\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "無効な見出しレベル5(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "あああ\n== いいい =\nううう\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "見出し(警告数)" );
			is( $result_ref->[0], "見出し記法の左右の=の数が一致しません(2)", "見出し(警告文)" );
		}

		# ISBN記法テスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "ISBN 0123456789\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "ISBN-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "ISBN 012345678901X\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "ISBN-2(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "ISBN=012345678901X\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "ISBN-3(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "ISBN0123456789\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "ISBN-4(警告数)" );
			is( $result_ref->[0], "ISBN記法では、ISBNと数字の間に半角スペースが必要です(1)", "ISBN-4(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "ISBN 012345678\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "ISBN-5(警告数)" );
			is( $result_ref->[0], "ISBNは10桁もしくは13桁でないといけません(1)", "ISBN-5(警告文)" );
		}

		# 西暦記述テスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "2011年\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "西暦-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "'11年\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "西暦-2(警告数)" );
			is( $result_ref->[0], "西暦は全桁表示が推奨されます(1)", "西暦-2(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "’11年\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "西暦-3(警告数)" );
			is( $result_ref->[0], "西暦は全桁表示が推奨されます(1)", "西暦-3(警告文)" );
		}

		# 不正コメントタグテスト
		$article->{'title'} = '標準';
		$article->{'text'} = "<!--\n{{aimai}}";
		$result_ref = $article->LintText;
		is( @$result_ref + 0, 1, "不正コメント(警告数)" );
		is( $result_ref->[0], "閉じられていないコメントタグがあります(1)", "不正コメント(警告文)" );

		# ソートキーテスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "{{DEFAULTSORT:あああ}}\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "ソートキー-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "{{デフォルトソート:あああ}}\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "ソートキー-2(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "{{aimai}}\n[[Category:カテゴリ|あああ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "ソートキー-3(警告数)" );

			foreach my $char ( 'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ', 'っ', 'ゃ', 'ゅ', 'ょ', 'ゎ', 'が', 'ぎ', 'ぐ', 'げ', 'ご', 'ざ', 'じ', 'ず', 'ぜ', 'ぞ', 'だ', 'ぢ', 'づ', 'で', 'ど', 'ば', 'び', 'ぶ', 'べ', 'ぼ', 'ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ', 'ー' ) {
				$article->{'title'} = '標準';
				$article->{'text'} = "{{DEFAULTSORT:あああ$char}}\n{{aimai}}";
				$result_ref = $article->LintText;
				is( @$result_ref + 0, 1, "ソートキー-4 $char(警告数)" );
				is( $result_ref->[0], "ソートキーには濁音、半濁音、吃音、長音は使用しないことが推奨されます(1)", "ソートキー-4 $char(警告文)" );

				$article->{'title'} = '標準';
				$article->{'text'} = "{{デフォルトソート:あああ$char}}\n{{aimai}}";
				$result_ref = $article->LintText;
				is( @$result_ref + 0, 1, "ソートキー-5 $char(警告数)" );
				is( $result_ref->[0], "ソートキーには濁音、半濁音、吃音、長音は使用しないことが推奨されます(1)", "ソートキー-5 $char(警告文)" );

				$article->{'title'} = '標準';
				$article->{'text'} = "{{aimai}}\n[[Category:カテゴリ|あああ$char]]\n";
				$result_ref = $article->LintText;
				is( @$result_ref + 0, 1, "ソートキー-6 $char(警告数)" );
				is( $result_ref->[0], "ソートキーには濁音、半濁音、吃音、長音は使用しないことが推奨されます(2)", "ソートキー-6 $char(警告文)" );
			}
		}

		# デフォルトソートテスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "{{DEFAULTSORT:あああ}}\n{{DEFAULTSORT:あああ}}\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "デフォルトソート-1(警告数)" );
			is( $result_ref->[0], "デフォルトソートが複数存在します(2)", "デフォルトソート-1(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "{{DEFAULTSORT:}}\n\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "デフォルトソート-2(警告数)" );
			is( $result_ref->[0], "デフォルトソートではソートキーが必須です(1)", "デフォルトソート-2(警告文)" );
		}

		# カテゴリテスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "{{aimai}}\n[[Category:カテゴリ1]]\n[[Category:カテゴリ2]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "カテゴリ-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "{{aimai}}\n[[Category:カテゴリ]]\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "カテゴリ-2(警告数)" );
			is( $result_ref->[0], "既に使用されているカテゴリです(3)", "カテゴリ-2(警告文)" );
		}

		# 使用できる文字・文言テスト
		{
			$article->{'title'} = '標準';
			foreach my $char ( '，', '．', '！', '？', '＆', '＠' ) {
				$article->{'text'} = "$char\n{{aimai}}\n";
				$result_ref = $article->LintText;
				is( @$result_ref + 0, 1, "$char(警告数)" );
				is( $result_ref->[0], "全角記号の使用は推奨されません(1)", "$char(警告文)" );
			}
			$article->{'title'} = '標準';
			foreach my $char ( 'Ａ', 'Ｚ', 'ａ', 'ｚ', '０', '９' ) {
				$article->{'text'} = "$char\n{{aimai}}\n";
				$result_ref = $article->LintText;
				is( @$result_ref + 0, 1, "$char(警告数)" );
				is( $result_ref->[0], "全角英数字の使用は推奨されません(1)", "$char(警告文)" );
			}
			$article->{'title'} = '標準';
			foreach my $char ( 'ｱ', 'ﾝ', 'ﾞ', 'ﾟ', 'ｧ', 'ｫ', 'ｬ', 'ｮ', '｡', '｢', '｣', '､' ) {
				$article->{'text'} = "$char\n{{aimai}}\n";
				$result_ref = $article->LintText;
				is( @$result_ref + 0, 1, "$char(警告数)" );
				is( $result_ref->[0], "半角カタカナの使用は推奨されません(1)", "$char(警告文)" );
			}
			$article->{'title'} = '標準';
			foreach my $char ( 'Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ', 'Ⅶ', 'Ⅷ', 'Ⅸ', 'Ⅹ' ) {
				$article->{'text'} = "$char\n{{aimai}}\n";
				$result_ref = $article->LintText;
				is( @$result_ref + 0, 1, "$char(警告数)" );
				is( $result_ref->[0], "ローマ数字はアルファベットを組み合わせましょう(1)", "$char(警告文)" );
			}
			$article->{'title'} = '標準';
			foreach my $char ( '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩', '⑪', '⑫', '⑬', '⑭', '⑮', '⑯', '⑰', '⑱', '⑲', '⑳' ) {
				$article->{'text'} = "$char\n{{aimai}}\n";
				$result_ref = $article->LintText;
				is( @$result_ref + 0, 1, "$char(警告数)" );
				is( $result_ref->[0], "丸付き数字の使用は推奨されません(1)", "$char(警告文)" );
			}
		}

		# 言語間リンクテスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "{{aimai}}\n[[en:dummy]]";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "言語間リンク-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "{{aimai}}\n[[en:dummy]]\n[[fr:dummy]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "言語間リンク-2(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "{{aimai}}\n[[en:dummy]]\n[[en:dummy]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "言語間リンク-3(警告数)" );
			is( $result_ref->[0], "言語間リンクが重複しています(3)", "言語間リンク-3(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "{{aimai}}\n[[fr:dummy]]\n[[en:dummy]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "言語間リンク-4(警告数)" );
			is( $result_ref->[0], "言語間リンクはアルファベット順に並べることが推奨されます(3)", "言語間リンク-4(警告文)" );
		}

		# 年月日リンクテスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "[[2011年]][[1月1日]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "年月日リンク-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[2011年1月1日は元旦]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "年月日リンク-2(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[2011年1月1日]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "年月日リンク-3(警告数)" );
			is( $result_ref->[0], "年月日へのリンクは年と月日を分けることが推奨されます(1)", "年月日リンク-3(警告文)" );
		}

		# カッコ対応テスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "[ ]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "カッコ対応-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "{ }\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "カッコ対応-2(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "カッコ対応-3(警告数)" );
			is( $result_ref->[0], "空のリンクまたは閉じられていないカッコがあります(1)", "カッコ対応-3(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "カッコ対応-4(警告数)" );
			is( $result_ref->[0], "空のリンクまたは閉じられていないカッコがあります(1)", "カッコ対応-4(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "{\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "カッコ対応-5(警告数)" );
			is( $result_ref->[0], "空のリンクまたは閉じられていないカッコがあります(1)", "カッコ対応-5(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "}\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "カッコ対応-6(警告数)" );
			is( $result_ref->[0], "空のリンクまたは閉じられていないカッコがあります(1)", "カッコ対応-6(警告文)" );
		}

		# リファレンステスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "<ref>あああ</ref>\n<references/>\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "ref要素-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "<ref>あああ</ref>\n{{reflist}}\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "ref要素-2(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "<ref>あああ</ref>\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "ref要素-3(警告数)" );
			is( $result_ref->[0], "<ref>要素があるのに<references>要素がありません", "ref要素-3(警告文)" );
		}

		# 定義文テスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "定義文無し-1(警告数)" );
			is( $result_ref->[0], "定義文が見当たりません", "定義文無し-1(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "'''あああ'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "定義文無し-2(警告数)" );
			is( $result_ref->[0], "定義文が見当たりません", "定義文無し-2(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "'''標 準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "定義文あり-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "''' 標準 '''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "定義文あり-2(警告数)" );

			$article->{'title'} = '標 準';
			$article->{'text'} = "''' 標 準 '''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "定義文あり-3(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "'''あああ'''\n''' 標準 '''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "定義文あり-4(警告数)" );

			$article->{'title'} = '標準 (曖昧さ回避)';
			$article->{'text'} = "'''標準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "定義文あり-5(警告数)" );

			$article->{'title'} = 'Abc';
			$article->{'text'} = "'''abc'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "定義文あり-6(警告数)" );

			$article->{'title'} = 'Shift JIS';
			$article->{'text'} = "'''Shift_JIS'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "定義文あり-7(警告数)" );
		}

		# カテゴリ、デフォルトソート、出典なしテスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "'''標準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "カテゴリ無し(警告数)" );
			is( $result_ref->[0], "カテゴリが一つもありません", "カテゴリ無し(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "'''標準'''\n== 出典 ==\n[[Category:カテゴリ]]";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "デフォルトソート無し(警告数)" );
			is( $result_ref->[0], "デフォルトソートがありません", "デフォルトソート無し(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "'''標準'''\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "出典無し(警告数)" );
			is( $result_ref->[0], "出典に関する節がありません", "出典無し(警告文)" );
		}

		# ブロック順序テスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "'''標準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n[[en:interlink]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "ブロック順序-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "== 出典 ==\n[[Category:カテゴリ]]\n'''標準'''\n{{DEFAULTSORT:あああ}}\n[[en:interlink]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "ブロック順序-2(警告数)" );
			is( $result_ref->[0], "本文、カテゴリ、言語間リンクの順に記述することが推奨されます(3)", "ブロック順序-2(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "== 出典 ==\n[[Category:カテゴリ]]\n{{DEFAULTSORT:あああ}}\n[[en:interlink]]\n'''標準'''\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "ブロック順序-3(警告数)" );
			is( $result_ref->[0], "本文、カテゴリ、言語間リンクの順に記述することが推奨されます(5)", "ブロック順序-3(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "'''標準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[en:interlink]]\n[[Category:カテゴリ]]\n";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "ブロック順序-4(警告数)" );
			is( $result_ref->[0], "本文、カテゴリ、言語間リンクの順に記述することが推奨されます(5)", "ブロック順序-4(警告文)" );
		}

		# 生没年カテゴリテスト
		{
			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:2001年生]]\n[[Category:存命人物]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "生没年カテゴリ-1(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:生年不明]]\n[[Category:存命人物]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "生没年カテゴリ-2(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:2001年生]]\n[[Category:2011年没]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "生没年カテゴリ-3(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:生年不明]]\n[[Category:2011年没]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "生没年カテゴリ-4(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:2001年生]]\n[[Category:没年不明]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "生没年カテゴリ-5(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:生年不明]]\n[[Category:没年不明]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 0, "生没年カテゴリ-6(警告数)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:2001年生]]\n[[Category:2011年没]]\n[[Category:存命人物]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "生没年カテゴリ-7(警告数)" );
			is( $result_ref->[0], "存命人物ではありません", "生没年カテゴリ-7(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:2001年生]]\n[[Category:没年不明]]\n[[Category:存命人物]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "生没年カテゴリ-8(警告数)" );
			is( $result_ref->[0], "存命人物ではありません", "生没年カテゴリ-8(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:存命人物]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "生没年カテゴリ-9(警告数)" );
			is( $result_ref->[0], "生年のカテゴリがありません", "生没年カテゴリ-9(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:2011年没]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "生没年カテゴリ-10(警告数)" );
			is( $result_ref->[0], "生年のカテゴリがありません", "生没年カテゴリ-10(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:没年不明]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "生没年カテゴリ-11(警告数)" );
			is( $result_ref->[0], "生年のカテゴリがありません", "生没年カテゴリ-11(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:2001年生]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "生没年カテゴリ-12(警告数)" );
			is( $result_ref->[0], "存命人物または没年のカテゴリがありません", "生没年カテゴリ-12(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:生年不明]]\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "生没年カテゴリ-13(警告数)" );
			is( $result_ref->[0], "存命人物または没年のカテゴリがありません", "生没年カテゴリ-13(警告文)" );

			$article->{'title'} = '標準';
			$article->{'text'} = "[[Category:2001年生]]\n[[Category:存命人物]]\n{{死亡年月日と没年齢|2001|1|1|2011|12|31}}\n{{aimai}}";
			$result_ref = $article->LintText;
			is( @$result_ref + 0, 1, "生没年カテゴリ-14(警告数)" );
			is( $result_ref->[0], "存命人物ではありません", "生没年カテゴリ-14(警告文)" );
		}
	}
}


################################################################################
# JAWP::TitleListクラス
################################################################################

sub TestJAWPTitleList {
	diag( '###################### Test JAWP::TitleList ######################' );

	# メソッド呼び出しテスト
	{
		ok( JAWP::TitleList->can('new'), "call method new" );
	}

	# メンバー変数確認
	{
		my $titlelist = new JAWP::TitleList;

		ok( defined( $titlelist ), 'new' );
		cmp_ok( keys( %$titlelist ),  '==', 23, 'member count' );

		foreach my $member ( '標準', '標準_曖昧', '標準_リダイレクト', '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート' ) {
			ok( defined( $titlelist->{$member} ), "defined member $member" );
			is( ref $titlelist->{$member}, 'HASH', "member $member value" );
		}

		foreach my $member ( 'allcount' ) {
			ok( defined( $titlelist->{$member} ), "defined member $member" );
			cmp_ok( $titlelist->{$member}, '==', 0, "member $member value" );
		}
	}
}



################################################################################
# JAWP::DataFileクラス
################################################################################

sub TestJAWPData {
	diag( '###################### Test JAWP::DataFile ######################' );

	# メソッド呼び出しテスト
	{
		foreach my $method ( 'new', 'GetArticle', 'GetTitleList' ) {
			ok( JAWP::DataFile->can($method), "call method $method" );
		}
	}

	# 空new失敗確認テスト
	{
		my $data = new JAWP::DataFile;
		ok( !defined( $data ), 'new(empty)' );
	}

	# メンバー変数確認
	{
		WriteTestXMLFile( '' );
		my $data = new JAWP::DataFile( $testxmlfile );

		ok( defined( $data ), 'new' );
		cmp_ok( keys( %$data ),  '==', 2, 'member count' );

		ok( defined( $data->{'filename'} ), "defined member filename" );
		is( $data->{'filename'}, $testxmlfile, "member filename value" );

		ok( defined( $data->{'fh'} ), "defined member fh" );
		is( ref $data->{'fh'}, 'GLOB', "member fh value" );
	}
}


################################################################################
# JAWP::ReportFileクラス
################################################################################

sub TestJAWPReport {
	diag( '###################### Test JAWP::ReportFile ######################' );

	# メソッド呼び出しテスト
	{
		foreach my $method ( 'new', 'OutputWiki', 'OutputWikiList', 'OutputDirect' ) {
			ok( JAWP::ReportFile->can($method), "call method $method" );
		}
	}


	# 空newテスト
	{
		my $report = new JAWP::ReportFile;

		ok( !defined( $report ), 'new' );
	}


	# ファイル名指定newテスト
	{
		my $report = new JAWP::ReportFile( $testreportfile );

		ok( defined( $report ), 'new' );
		cmp_ok( keys( %$report ),  '==', 2, 'member count' );

		ok( defined( $report->{'filename'} ), "defined member filename" );
		is( $report->{'filename'}, $testreportfile, "member filename value" );

		ok( defined( $report->{'fh'} ), "defined member fh" );
		is( ref $report->{'fh'}, 'GLOB', "member fh value" );
	}


	# 出力テスト(テキスト)
	{
		{
			my $report = new JAWP::ReportFile( $testreportfile );
			my @datalist;

			$report->OutputWiki( 'title', \( "text1\ntext2" ) );
		}
		{
			my $str = <<'STR';
== title ==
text1
text2

STR
			is( ReadReportFile(), $str, 'output(empty)' );
		}
	}

	# 出力テスト(空配列データ)
	{
		{
			my $report = new JAWP::ReportFile( $testreportfile );
			my @datalist;

			$report->OutputWikiList( 'title', \@datalist );
		}
		{
			my $str = <<'STR';
== title ==

STR
			is( ReadReportFile(), $str, 'output(empty)' );
		}
	}

	# 出力テスト(配列データ)
	{
		{
			my $report = new JAWP::ReportFile( $testreportfile );
			my @datalist = ( 'あいうえお', 'かきくけこ', 'さしすせそ' );

			$report->OutputWikiList( 'title', \@datalist );
		}
		{
			my $str = <<'STR';
== title ==
*あいうえお
*かきくけこ
*さしすせそ

STR
			is( ReadReportFile(), $str, 'output(array)' );
		}
	}

	# 出力テスト(配列データ複数回)
	{
		{
			my $report = new JAWP::ReportFile( $testreportfile );
			my @datalist1 = ( 'あいうえお', 'かきくけこ', 'さしすせそ' );
			my @datalist2 = ( 'abcde', '01234' );

			$report->OutputWikiList( 'title1', \@datalist1 );
			$report->OutputWikiList( 'title2', \@datalist2 );
		}
		{
			my $str = <<'STR';
== title1 ==
*あいうえお
*かきくけこ
*さしすせそ

== title2 ==
*abcde
*01234

STR
			is( ReadReportFile(), $str, 'output(array multi)' );
		}
	}

	# 直接出力テスト(空データ)
	{
		{
			my $report = new JAWP::ReportFile( $testreportfile );

			$report->OutputDirect( '' );
		}
		{
			is( ReadReportFile(), '', 'output direct(empty)' );
		}
	}

	# 直接出力テスト(文字列)
	{
		{
			my $report = new JAWP::ReportFile( $testreportfile );

			$report->OutputDirect( '隣の客はよく柿食う客だ' );
		}
		{
			is( ReadReportFile(), '隣の客はよく柿食う客だ', 'output direct(string)' );
		}
	}

	# 直接出力テスト(文字列複数回)
	{
		{
			my $report = new JAWP::ReportFile( $testreportfile );

			$report->OutputDirect( "赤巻紙青巻紙黄巻紙\n" );
			$report->OutputDirect( "坊主が屏風に上手に坊主の絵を書いた\n" );
		}
		{
			my $str = <<'STR';
赤巻紙青巻紙黄巻紙
坊主が屏風に上手に坊主の絵を書いた
STR
			is( ReadReportFile(), $str, 'output(array multi)' );
		}
	}
}


################################################################################
# JAWP::Utilクラス
################################################################################

sub TestJAWPUtil {
	diag( '###################### Test JAWP::Util ######################' );

	# メソッド呼び出しテスト
	{
		foreach my $method ( 'UnescapeHTML', 'DecodeURL', 'SortHash', 'GetLinkwordList', 'GetTemplatewordList', 'GetLinkType' ) {
			ok( JAWP::Util->can($method), "call method $method" );
		}
	}

	# HTMLUnescapeテスト
	{
		diag( '# Test JAWP::Util::HTMLUnescape' );
		is( JAWP::Util::UnescapeHTML( 'abcdef') , 'abcdef', '無変換1' );
		is( JAWP::Util::UnescapeHTML( '&amp') , '&amp', '無変換2' );
		is( JAWP::Util::UnescapeHTML( '&quot;&amp;&lt;&gt;' ), '"&<>', '文字実体参照(マークアップ記号)' );
		is( JAWP::Util::UnescapeHTML( '&nbsp; &iexcl; &cent; &pound; &curren; &yen; &brvbar; &sect; &uml; &copy; &ordf; &laquo; &not; &shy; &reg; &macr; &deg; &plusmn; &sup2; &sup3; &acute; &micro; &para; &middot; &cedil; &sup1; &ordm; &raquo; &frac14; &frac12; &frac34; &iquest; &Agrave; &Aacute; &Acirc; &Atilde; &Auml; &Aring; &AElig; &Ccedil; &Egrave; &Eacute; &Ecirc; &Euml; &Igrave; &Iacute; &Icirc; &Iuml; &ETH; &Ntilde; &Ograve; &Oacute; &Ocirc; &Otilde; &Ouml; &times; &Oslash; &Ugrave; &Uacute; &Ucirc; &Uuml; &Yacute; &THORN; &szlig; &agrave; &aacute; &acirc; &atilde; &auml; &aring; &aelig; &ccedil; &egrave; &eacute; &ecirc; &euml; &igrave; &iacute; &icirc; &iuml; &eth; &ntilde; &ograve; &oacute; &ocirc; &otilde; &ouml; &divide; &oslash; &ugrave; &uacute; &ucirc; &uuml; &yacute; &thorn; &yuml;' ), '  ¡ ￠ ￡ ¤ \ ￤ § ¨ © ª « ￢ ­ ® ¯ ° ± ² ³ ´ µ ¶ · ¸ ¹ º » ¼ ½ ¾ ¿ À Á Â Ã Ä Å Æ Ç È É Ê Ë Ì Í Î Ï Ð Ñ Ò Ó Ô Õ Ö × Ø Ù Ú Û Ü Ý Þ ß à á â ã ä å æ ç è é ê ë ì í î ï ð ñ ò ó ô õ ö ÷ ø ù ú û ü ý þ ÿ', '文字実体参照(ISO-8859-1 ラテン)' );
		is( JAWP::Util::UnescapeHTML( '&OElig; &oelig; &Scaron; &scaron; &Yuml; &circ; &tilde; &fnof;' ), 'Œ œ Š š Ÿ ˆ ˜ ƒ', '文字実体参照(ラテン拡張)' );
		is( JAWP::Util::UnescapeHTML( '&Alpha; &Beta; &Gamma; &Delta; &Epsilon; &Zeta; &Eta; &Theta; &Iota; &Kappa; &Lambda; &Mu; &Nu; &Xi; &Omicron; &Pi; &Rho; &Sigma; &Tau; &Upsilon; &Phi; &Chi; &Psi; &Omega; &alpha; &beta; &gamma; &delta; &epsilon; &zeta; &eta; &theta; &iota; &kappa; &lambda; &mu; &nu; &xi; &omicron; &pi; &rho; &sigmaf; &sigma; &tau; &upsilon; &phi; &chi; &psi; &omega; &thetasym; &upsih; &piv;' ), 'Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο Π Ρ Σ Τ Υ Φ Χ Ψ Ω α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ ς σ τ υ φ χ ψ ω ϑ ϒ ϖ', '文字実体参照(ギリシア文字)' );
		is( JAWP::Util::UnescapeHTML( '&ensp; &emsp; &thinsp; &zwnj; &zwj; &lrm; &rlm; &ndash; &mdash; &lsquo; &rsquo; &sbquo; &ldquo; &rdquo; &bdquo; &dagger; &Dagger; &bull; &hellip; &permil; &prime; &Prime; &lsaquo; &rsaquo; &oline; &frasl; &euro; &image; &ewierp; &real; &trade; &alefsym; &larr; &uarr; &rarr; &darr; &harr; &crarr; &lArr; &uArr; &rArr; &dArr; &hArr;' ), '      ‌ ‍ ‎ ‏ – ― ‘ ’ ‚ “ ” „ † ‡ • … ‰ ′ ″ ‹ › ~ ⁄ € ℑ ℘ ℜ ™ ℵ ← ↑ → ↓ ↔ ↵ ⇐ ⇑ ⇒ ⇓ ⇔', '文字実体参照(一般記号と国際化用の制御文字)' );
		is( JAWP::Util::UnescapeHTML( '&forall; &part; &exist; &empty; &nabla; &isin; &notin; &ni; &prod; &sum; &minus; &lowast; &radic; &prop; &infin; &ang; &and; &or; &cap; &cup; &int; &there4; &sim; &cong; &asymp; &ne; &equiv; &le; &ge; &sub; &sup; &nsub; &sube; &supe; &oplus; &otimes; &perp; &sdot;' ), '∀ ∂ ∃ ∅ ∇ ∈ ∉ ∋ ∏ ∑ － ∗ √ ∝ ∞ ∠ ∧ ∨ ∩ ∪ ∫ ∴ ∼ ≅ ≈ ≠ ≡ ≤ ≥ ⊂ ⊃ ⊄ ⊆ ⊇ ⊕ ⊗ ⊥ ⋅', '文字実体参照(数学記号)' );
		is( JAWP::Util::UnescapeHTML( '&lceil; &rceil; &lfloor; &rfloor; &lang; &rang; &loz; &spades; &clubs; &hearts; &diams;' ), '⌈ ⌉ ⌊ ⌋ 〈 〉 ◊ ♠ ♣ ♥ ♦', '文字実体参照(シンボル)' );
		is( JAWP::Util::UnescapeHTML( '&#34;&#38;&#60;&#62;' ), '"&<>', '数値文字参照' );
		is( JAWP::Util::UnescapeHTML( '&amp;lt;' ), '<', '二重エスケープ' );
	}

	# DecodeURLテスト
	{
		diag( '# Test JAWP::Util::DecodeURL' );
		is( JAWP::Util::DecodeURL( 'abcdef') , 'abcdef', '無変換' );
		is( JAWP::Util::DecodeURL( '%E7%89%B9%E5%88%A5:') , '特別:', '変換(特別)' );
	}

	# SortHashテスト
	{
		diag( '# Test JAWP::Util::HTMLUnescape' );

		my %hash = ( 'a'=>2, 'b'=>1, 'c'=>3 );
		my $sorted = JAWP::Util::SortHash( \%hash );
		is( ref $sorted, 'ARRAY', 'result is ARRAY reference' );
		is( @$sorted + 0, 3, 'sorted array size' );
		is( $sorted->[0], 'c', 'sorted array[0]' );
		is( $sorted->[1], 'a', 'sorted array[1]' );
		is( $sorted->[2], 'b', 'sorted array[2]' );
	}

	# GetLinkwordListテスト
	{
		diag( '# Test JAWP::Util::GetLinkwordList' );

		my @result;

		@result = JAWP::Util::GetLinkwordList( '' );
		is( @result + 0 , 0, '空文字列' );

		@result = JAWP::Util::GetLinkwordList( 'あああ' );
		is( @result + 0 , 0, '通常文字列' );

		@result = JAWP::Util::GetLinkwordList( '[あああ]' );
		is( @result + 0 , 0, '外部リンク' );

		@result = JAWP::Util::GetLinkwordList( '[[あああ' );
		is( @result + 0 , 0, '不完全リンク' );

		@result = JAWP::Util::GetLinkwordList( '[[あああ]]' );
		is( @result + 0 , 1, 'リンク' );
		is( $result[0] , 'あああ', 'リンク(リンクワード)' );

		@result = JAWP::Util::GetLinkwordList( 'あああ[[いいい]]ううう' );
		is( @result + 0 , 1, '文字列中リンク' );
		is( $result[0] , 'いいい', '文字列中リンク(リンクワード)' );

		@result = JAWP::Util::GetLinkwordList( '[[あああ|いいい]]' );
		is( @result + 0 , 1, 'パイプリンク' );
		is( $result[0] , 'あああ', 'パイプリンク(リンクワード)' );

		@result = JAWP::Util::GetLinkwordList( '[[あああ]]いいい[[ううう]]' );
		is( @result + 0 , 2, '複数リンク' );
		is( $result[0] , 'あああ', '複数リンク(リンクワード1)' );
		is( $result[1] , 'ううう', '複数リンク(リンクワード2)' );

		@result = JAWP::Util::GetLinkwordList( "[[あああ]]\nいいい\n[[ううう]]\n" );
		is( @result + 0 , 2, '複数行テキストリンク' );
		is( $result[0] , 'あああ', '複数行テキストリンク(リンクワード1)' );
		is( $result[1] , 'ううう', '複数行テキストリンク(リンクワード2)' );
	}

	# GetTemplatewordListテスト
	{
		diag( '# Test JAWP::Util::GetTemplatewordList' );

		my @result;

		@result = JAWP::Util::GetTemplatewordList( '' );
		is( @result + 0 , 0, '空文字列' );

		@result = JAWP::Util::GetTemplatewordList( 'あああ' );
		is( @result + 0 , 0, '通常文字列' );

		@result = JAWP::Util::GetTemplatewordList( '{あああ}' );
		is( @result + 0 , 0, '不完全呼び出し-1' );

		@result = JAWP::Util::GetTemplatewordList( '{{あああ' );
		is( @result + 0 , 0, '不完全呼び出し-2' );

		@result = JAWP::Util::GetTemplatewordList( '{{あああ}}' );
		is( @result + 0 , 1, '呼び出し-1' );
		is( $result[0] , 'あああ', '呼び出し(テンプレートワード)' );

		@result = JAWP::Util::GetTemplatewordList( 'あああ{{いいい}}ううう' );
		is( @result + 0 , 1, '文字列中呼び出し' );
		is( $result[0] , 'いいい', '文字列中呼び出し(テンプレートワード)' );

		@result = JAWP::Util::GetTemplatewordList( '{{あああ|いいい}}' );
		is( @result + 0 , 1, 'パイプリンク' );
		is( $result[0] , 'あああ', 'パラメータ付き呼び出し(テンプレートワード)' );

		@result = JAWP::Util::GetTemplatewordList( '{{あああ}}いいい{{ううう}}' );
		is( @result + 0 , 2, '複数リンク' );
		is( $result[0] , 'あああ', '複数呼び出し(テンプレートワード1)' );
		is( $result[1] , 'ううう', '複数呼び出し(テンプレートワード2)' );

		@result = JAWP::Util::GetTemplatewordList( "{{あああ}}\nいいい\n{{ううう}}\n" );
		is( @result + 0 , 2, '複数行テキスト呼び出し' );
		is( $result[0] , 'あああ', '複数行テキスト呼び出し(テンプレートワード1)' );
		is( $result[1] , 'ううう', '複数行テキスト呼び出し(テンプレートワード2)' );
	}

	# GetLinkTypeテスト
	{
		diag( '# Test JAWP::Util::GetLinkType' );
		my $titlelist = new JAWP::TitleList;
	}
}


################################################################################
# JAWP::Appクラス
################################################################################

sub TestJAWPApp {
	diag( '###################### Test JAWP::App ######################' );

	# メソッド呼び出しテスト
	{
		foreach my $method ( 'Run', 'Usage', 'LintTitle', 'LintText',
			'Statistic', 'StatisticReportSub1', 'StatisticReportSub2', 'TitleList', 'LivingNoref' ) {
			ok( JAWP::App->can($method), "call method $method" );
		}
	}
}


################################################################################
# テスト用ユーティリティ関数
################################################################################

# スタートアップ
sub Startup {
	if( !( -d $testdir ) ) {
		mkdir( $testdir ) or die "failed to create test directory($!)";
	}
}


# クリーンナップ
sub Cleanup {
	if( -e $testxmlfile ) {
		unlink( $testxmlfile ) or die "failed to remove $testxmlfile($!)";
	}
	if( -e $testreportfile ) {
		unlink( $testreportfile ) or die "failed to remove $testreportfile($!)";
	}
	rmdir( $testdir ) or die "failed to remove test directory($!)";
}


# テストXMLファイル作成
sub WriteTestXMLFile {
	my $text = shift;

	open F, '>', $testxmlfile or die "failed to open $testxmlfile($!)";
	print F $text or die "failed to write $testxmlfile($!)";
	close F or die "failed to close $testxmlfile($!)";
}

# レポートファイル読み込み
sub ReadReportFile {
	my $text;

	open F, '<', $testreportfile or die "failed to open $testreportfile($!)";
	$text = join( '', <F> );
	close F or die "failed to close $testreportfile($!)";

	return $text;
}
