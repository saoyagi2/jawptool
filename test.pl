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
			$article->{'text'} = $text;
			ok( !$article->IsNoref, $text );
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

		foreach my $title ( '利用者:①', 'Wikipedia:①', 'ファイル:①', 'MediaWiki:①', 'Template:①', 'Help:①', 'Category:①', 'Portal:①', 'プロジェクト:①', 'ノート:①', '利用者‐会話:①', 'Wikipedia‐ノート:①', 'ファイル‐ノート:①', 'MediaWiki‐ノート:①', 'Template‐ノート:①', 'Help‐ノート:①', 'Category‐ノート:①', 'Portal‐ノート:①', 'プロジェクト‐ノート:①' ) {
			$article->{'title'} = $title;
			$result_ref = $article->LintTitle;
			is( @$result_ref + 0, 0, $title );
		}

		$article->{'text'} = '#redirect[[転送先]]';
		foreach my $title ( '記事名（曖昧さ回避）', '記事名(曖昧さ回避)', '記事名  (曖昧さ回避)', '株式会社あいうえお', 'あいうえお株式会社', '，', '．', '！', '？', '＆', '＠', 'Ａ', 'Ｚ', 'ａ', 'ｚ', '０', '９', 'ｱ', 'ﾝ', 'ﾞ', 'ﾟ', 'ｧ', 'ｫ', 'ｬ', 'ｮ', '｡', '｢', '｣', '､', 'Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ', 'Ⅶ', 'Ⅷ', 'Ⅸ', 'Ⅹ', '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩', '⑪', '⑫', '⑬', '⑭', '⑮', '⑯', '⑰', '⑱', '⑲', '⑳', '髙' ) {
			$article->{'title'} = $title;
			$result_ref = $article->LintTitle;
			is( @$result_ref + 0, 0, "$title(リダイレクト)" );
		}

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
		$article->{'text'} = '';
		foreach my $title ( '株式会社あいうえお', 'あいうえお株式会社' ) {
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
			is( $result_ref->[0], 'ローマ数字はアルファベットを組み合わせましょう。', "$title(非リダイレクト)" );
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

	# LintTextテスト
	{
		diag( '# Test LintText' );

		my $article = new JAWP::Article;
		my $result_ref;

		$article->{'text'} = '';
		$result_ref = $article->LintText( $article );
		is( ref $result_ref, 'ARRAY', 'result is ARRAY reference' );
		is( @$result_ref + 0, 0, 'result array size 0' );
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
		foreach my $method ( 'UnescapeHTML', 'SortHash' ) {
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
}


################################################################################
# JAWP::Appクラス
################################################################################

sub TestJAWPApp {
	diag( '###################### Test JAWP::App ######################' );

	# メソッド呼び出しテスト
	{
		foreach my $method ( 'Run', 'Usage', 'LintTitle', 'LintText',
			'Statistic', 'StatisticReportSub', 'TitleList',
			'TitleListReportSub', 'LivingNoref' ) {
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
