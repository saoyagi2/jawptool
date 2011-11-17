#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Encode;
use open IO  => ':utf8';
binmode Test::More->builder->output, ':utf8';
binmode Test::More->builder->failure_output, ':utf8';
binmode Test::More->builder->todo_output, ':utf8';

use Test::More 'no_plan';
use File::Temp;

my $fnametemp = 'jawptoolXXXX';


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
	TestJAWPCGIApp();

	Cleanup();
}


################################################################################
# JAWP
################################################################################

sub TestJAWP {
	# useテスト
	use_ok( 'JAWP', 'use JAWP' );
}


################################################################################
# JAWP::Articleクラス
################################################################################

sub TestJAWPArticle {
	# メソッド呼び出しテスト
	{
		foreach my $method ( 'new', 'SetTitle', 'SetTimestamp', 'SetText', 'IsRedirect', 'IsAimai', 'IsLiving', 'IsNoref', 'IsSeibotsuDoujitsu', 'GetPassTime', 'LintTitle', 'LintText', 'LintIndex' ) {
			ok( JAWP::Article->can($method), "JAWP::Article(メソッド呼び出し,$method)" );
		}
	}

	# メンバー変数確認
	{
		my $article = new JAWP::Article;

		ok( defined( $article ), 'new' );
		cmp_ok( keys( %$article ), '==', 3, 'JAWP::Article(メンバ変数個数)' );

		foreach my $member ( 'title', 'timestamp', 'text' ) {
			ok( defined( $article->{$member} ), "JAWP::Article(メンバ変数宣言,$member)" );
			is( $article->{$member}, '', "JAWP::Article(メンバ変数値,$member)" );
		}
	}

	# SetTitleテスト
	{
		my $article = new JAWP::Article;

		$article->SetTitle( '' );
		is( $article->{'title'}, '', 'JAWP::Article::SetTitle(空文字列)' );

		$article->SetTitle( 'a_b' );
		is( $article->{'title'}, 'a b', 'JAWP::Article::SetTitle(アンダーバー変換)' );

		$article->SetTitle( '&amp;' );
		is( $article->{'title'}, '&', 'JAWP::Article::SetTitle(アンエスケープHTML)' );
	}

	# SetTimestampテスト
	{
		my $article = new JAWP::Article;

		$article->SetTimestamp( '2011-01-01T00:00:00Z' );
		is( $article->{'timestamp'}, '2011-01-01T00:00:00Z', 'JAWP::Article::SetTimestamp(2011-01-01T00:00:00Z)' );
	}

	# SetTextテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		is( $article->{'text'}, '', 'JAWP::Article::SetText(空文字列)' );

		$article->SetText( "あああ\nいいい\n" );
		is( $article->{'text'}, "あああ\nいいい\n", 'JAWP::Article::SetText(複数行文字列)' );

		$article->SetText( "<!--あ-->あ<!--あ-->\n<!--\n\n-->\nいいい\n" );
		is( $article->{'text'}, "あ\n\n\n\nいいい\n", 'JAWP::Article::SetText(コメント除去)' );

		$article->SetText( '&amp;' );
		is( $article->{'text'}, '&', 'JAWP::Article::SetText(アンエスケープHTML)' );
	}

	# IsRedirectテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( !$article->IsRedirect, 'JAWP::Article::IsRedirect(空文字列)' );

		foreach my $text ( '#redirect[[転送先]]', '#REDIRECT[[転送先]]', '#転送[[転送先]]', '＃redirect[[転送先]]', '＃REDIRECT[[転送先]]', '＃転送[[転送先]]' ) {
			$article->SetText( $text );
			ok( $article->IsRedirect, "JAWP::Article::IsRedirect($text)" );
		}
	}

	# IsAimaiテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( !$article->IsAimai, 'JAWP::Article::IsAimai(空文字列)' );

		foreach my $text ( '{{aimai}}', '{{Aimai}}', '{{曖昧さ回避}}', '{{人名の曖昧さ回避}}', '{{地名の曖昧さ回避}}' ) {
			$article->SetText( $text );
			ok( $article->IsAimai, "JAWP::Article::IsAimai($text)" );
		}
	}

	# IsLivingテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( !$article->IsLiving, 'JAWP::Article::IsLiving(空文字列)' );

		foreach my $text ( '[[Category:存命人物]]', '{{Blp}}' ) {
			$article->SetText( $text );
			ok( $article->IsLiving, "JAWP::Article::IsLiving($text)" );
		}
	}

	# IsNorefテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( $article->IsNoref, 'JAWP::Article::IsNoref(空文字列)' );

		foreach my $text ( '== 参考 ==', '== 文献 ==', '== 資料 ==', '== 書籍 ==', '== 図書 ==', '== 注 ==', '== 註 ==', '== 出典 ==', '== 典拠 ==', '== 出所 ==', '== 原典 ==', '== ソース ==', '== 情報源 ==', '== 引用元 ==', '== 論拠 ==', '== 参照 ==', '<ref>' ) {
			$article->SetText( "あああ\n$text\nいいい\n" );
			ok( !$article->IsNoref, "JAWP::Article::IsNoref($text)" );
		}
	}

	# GetBirthdayテスト
	{
		my $article = new JAWP::Article;
		my( $y, $m, $d );

		$article->SetText( '' );
		( $y, $m, $d ) = $article->GetBirthday;
		is( $y, 0, 'JAWP::Article::GetBirthday(空文字列,年)' );
		is( $m, 0, 'JAWP::Article::GetBirthday(空文字列,月)' );
		is( $d, 0, 'JAWP::Article::GetBirthday(空文字列,日)' );

		$article->SetText( '{{生年月日と年齢|2001|1|11}}' );
		( $y, $m, $d ) = $article->GetBirthday;
		is( $y, 2001, 'JAWP::Article::GetBirthday(生年月日と年齢テンプレート,2001年)' );
		is( $m, 1, 'JAWP::Article::GetBirthday(生年月日と年齢テンプレート,1月)' );
		is( $d, 11, 'JAWP::Article::GetBirthday(生年月日と年齢テンプレート,11日)' );

		$article->SetText( '{{死亡年月日と没年齢|2001|1|11|2011|12|31}}' );
		( $y, $m, $d ) = $article->GetBirthday;
		is( $y, 2001, 'JAWP::Article::GetBirthday(死亡年月日と没年齢テンプレート,2001年)' );
		is( $m, 1, 'JAWP::Article::GetBirthday(死亡年月日と没年齢テンプレート,1月)' );
		is( $d, 11, 'JAWP::Article::GetBirthday(死亡年月日と没年齢テンプレート,11日)' );

		$article->SetText( '{{没年齢|2001|1|11|2011|12|31}}' );
		( $y, $m, $d ) = $article->GetBirthday;
		is( $y, 2001, 'JAWP::Article::GetBirthday(没年齢テンプレート,2001年)' );
		is( $m, 1, 'JAWP::Article::GetBirthday(没年齢テンプレート,1月)' );
		is( $d, 11, 'JAWP::Article::GetBirthday(没年齢テンプレート,11日)' );

		$article->SetText( '{{生年月日と年齢|２００１|１|１１}}' );
		( $y, $m, $d ) = $article->GetBirthday;
		is( $y, 0, 'JAWP::Article::GetBirthday(生年月日と年齢テンプレート,全角数字,年)' );
		is( $m, 0, 'JAWP::Article::GetBirthday(生年月日と年齢テンプレート,全角数字,月)' );
		is( $d, 0, 'JAWP::Article::GetBirthday(生年月日と年齢テンプレート,全角数字,日)' );

		$article->SetText( '{{死亡年月日と没年齢|２００１|１|１１|２００１|１２|３１}}' );
		( $y, $m, $d ) = $article->GetBirthday;
		is( $y, 0, 'JAWP::Article::GetBirthday(死亡年月日と没年齢テンプレート,全角数字,年)' );
		is( $m, 0, 'JAWP::Article::GetBirthday(死亡年月日と没年齢テンプレート,全角数字,月)' );
		is( $d, 0, 'JAWP::Article::GetBirthday(死亡年月日と没年齢テンプレート,全角数字,日)' );

		$article->SetText( '{{没年齢|２００１|１|１１|２００１|１２|３１}}' );
		( $y, $m, $d ) = $article->GetBirthday;
		is( $y, 0, 'JAWP::Article::GetBirthday(没年齢テンプレート,全角数字,年)' );
		is( $m, 0, 'JAWP::Article::GetBirthday(没年齢テンプレート,全角数字,月)' );
		is( $d, 0, 'JAWP::Article::GetBirthday(没年齢テンプレート,全角数字,日)' );
	}

	# GetDeathdayテスト
	{
		my $article = new JAWP::Article;
		my( $y, $m, $d );

		$article->SetText( '' );
		( $y, $m, $d ) = $article->GetDeathday;
		is( $y, 0, 'JAWP::Article::GetDeathday(空文字列,年)' );
		is( $m, 0, 'JAWP::Article::GetDeathday(空文字列,月)' );
		is( $d, 0, 'JAWP::Article::GetDeathday(空文字列,日)' );

		$article->SetText( '{{死亡年月日と没年齢|2001|1|11|2011|12|31}}' );
		( $y, $m, $d ) = $article->GetDeathday;
		is( $y, 2011, 'JAWP::Article::GetDeathday(死亡年月日と没年齢テンプレート,2001年)' );
		is( $m, 12, 'JAWP::Article::GetDeathday(死亡年月日と没年齢テンプレート,1月)' );
		is( $d, 31, 'JAWP::Article::GetDeathday(死亡年月日と没年齢テンプレート,11日)' );

		$article->SetText( '{{没年齢|2001|1|11|2011|12|31}}' );
		( $y, $m, $d ) = $article->GetDeathday;
		is( $y, 2011, 'JAWP::Article::GetDeathday(没年齢テンプレート,2001年)' );
		is( $m, 12, 'JAWP::Article::GetDeathday(没年齢テンプレート,1月)' );
		is( $d, 31, 'JAWP::Article::GetDeathday(没年齢テンプレート,11日)' );

		$article->SetText( '{{死亡年月日と没年齢|２００１|１|１１|２００１|１２|３１}}' );
		( $y, $m, $d ) = $article->GetDeathday;
		is( $y, 0, 'JAWP::Article::GetDeathday(死亡年月日と没年齢テンプレート,全角数字,年)' );
		is( $m, 0, 'JAWP::Article::GetDeathday(死亡年月日と没年齢テンプレート,全角数字,月)' );
		is( $d, 0, 'JAWP::Article::GetDeathday(死亡年月日と没年齢テンプレート,全角数字,日)' );

		$article->SetText( '{{没年齢|２００１|１|１１|２００１|１２|３１}}' );
		is( $y, 0, 'JAWP::Article::GetDeathday(没年齢テンプレート,全角数字,年)' );
		is( $m, 0, 'JAWP::Article::GetDeathday(没年齢テンプレート,全角数字,月)' );
		is( $d, 0, 'JAWP::Article::GetDeathday(没年齢テンプレート,全角数字,日)' );
	}

	# IsSeibotsuDoujitsuテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( !$article->IsSeibotsuDoujitsu, 'JAWP::Article::IsSeibotsuDoujitsu(空文字列)' );

		$article->SetText( '{{死亡年月日と没年齢|2001|1|1|2011|12|31}}' );
		ok( !$article->IsSeibotsuDoujitsu, 'JAWP::Article::IsSeibotsuDoujitsu(死亡年月日と没年齢テンプレート,2001年1月1日生-2011年12月31日没)' );

		$article->SetText( '{{死亡年月日と没年齢|2001|1|1|2011|1|1}}' );
		ok( $article->IsSeibotsuDoujitsu, 'JAWP::Article::IsSeibotsuDoujitsu(死亡年月日と没年齢テンプレート,2001年1月1日生-2011年1月1日没)' );

		$article->SetText( '{{死亡年月日と没年齢|２００１|１|１１|２０１１|１|１}}' );
		ok( !$article->IsSeibotsuDoujitsu, 'JAWP::Article::IsSeibotsuDoujitsu(死亡年月日と没年齢テンプレート,2001年1月1日生-2011年1月1日没,全角数字)' );

		$article->SetText( '{{没年齢|2001|1|1|2011|12|31}}' );
		ok( !$article->IsSeibotsuDoujitsu, 'JAWP::Article::IsSeibotsuDoujitsu(没年齢テンプレート,2001年1月1日生-2011年12月31日没)' );

		$article->SetText( '{{没年齢|2001|1|1|2011|1|1}}' );
		ok( $article->IsSeibotsuDoujitsu, 'JAWP::Article::IsSeibotsuDoujitsu(没年齢テンプレート,2001年1月1日生-2011年1月1日没)' );

		$article->SetText( '{{没年齢|２００１|１|１１|２０１１|１|１}}' );
		ok( !$article->IsSeibotsuDoujitsu, 'JAWP::Article::IsSeibotsuDoujitsu(没年齢テンプレート,2001年1月1日生-2011年1月1日没,全角数字)' );
	}

	# IsIndexテスト
	{
		my $article = new JAWP::Article;

		$article->SetTitle( '' );
		ok( !$article->IsIndex, 'JAWP::Article::IsIndex(空文字列)' );

		$article->SetTitle( '索引' );
		ok( !$article->IsIndex, 'JAWP::Article::IsIndex(索引)' );

		$article->SetTitle( 'Wikipedia:索引' );
		ok( $article->IsIndex, 'JAWP::Article::IsIndex(Wikipedia:索引)' );

		$article->SetTitle( ' Wikipedia:索引' );
		ok( !$article->IsIndex, 'JAWP::Article::IsIndex( Wikipedia:索引)' );
	}

	# Namespaceテスト
	{
		my $article = new JAWP::Article;

		$article->SetTitle( '' );
		is( $article->Namespace, '標準', 'JAWP::Article::Namespace(空文字列)' );

		foreach my $namespace ( '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート' ) {
			my $title = "$namespace:dummy";
			$article->SetTitle( $title );
			is( $article->Namespace, $namespace, "JAWP::Article::Namespace($title)" );
		}
	}

	# GetPassTimeテスト
	{
		my $article = new JAWP::Article;

		$article->SetTimestamp( '2011-01-01T00:00:00Z' );
		is( $article->GetPassTime( 1293840000 ), '0000-00-00T00:00:00Z', 'JAWP::Article::GetPassTime(2011-01-01T00:00:00Z)' );

		$article->SetTimestamp( '2010-01-01T00:00:01Z' );
		is( $article->GetPassTime( 1293840000 ), '0000-11-29T59:59:59Z', 'JAWP::Article::GetPassTime(2010-01-01T00:00:01Z)' );

		$article->SetTimestamp( '2010-01-01T00:01:00Z' );
		is( $article->GetPassTime( 1293840000 ), '0000-11-29T59:59:00Z', 'JAWP::Article::GetPassTime(2010-01-01T00:01:00Z)' );

		$article->SetTimestamp( '2010-01-01T01:00:00Z' );
		is( $article->GetPassTime( 1293840000 ), '0000-11-29T59:00:00Z', 'JAWP::Article::GetPassTime(2010-01-01T01:00:00Z)' );

		$article->SetTimestamp( '2010-01-02T00:00:00Z' );
		is( $article->GetPassTime( 1293840000 ), '0000-11-29T00:00:00Z', 'JAWP::Article::GetPassTime(2010-01-02T00:00:00Z)' );

		$article->SetTimestamp( '2010-02-01T00:00:00Z' );
		is( $article->GetPassTime( 1293840000 ), '0000-11-00T00:00:00Z', 'JAWP::Article::GetPassTime(2010-02-01T00:00:00Z)' );
	}

	# LintTitleテスト
	{
		my $article = new JAWP::Article;
		my $result_ref;

		# 戻り値の型確認
		$article->SetTitle( '' );
		$result_ref = $article->LintTitle;
		is( ref $result_ref, 'ARRAY', 'JAWP::Article::LintTitle(空文字列:リファレンス種別)' );

		# 標準記事空間以外は無視確認
		foreach my $namespace ( '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート' ) {
			$article->SetTitle( "$namespace:①" );
			$result_ref = $article->LintTitle;
			is( @$result_ref + 0, 0, "JAWP::Article::LintTitle(標準記事空間以外無視,$namespace:警告数)" );
		}

		# リダイレクト記事は無視確認
		{
			$article->SetText( '#redirect[[転送先]]' );
			foreach my $type ( '株式会社', '有限会社', '合名会社', '合資会社', '合同会社' ) {
				my $title;

				$title = "あいうえお" . $type;
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 0, "JAWP::Article::LintTitle(リダイレクト無視,$title:警告数)" );

				$title = $type . "あいうえお";
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 0, "JAWP::Article::LintTitle(リダイレクト無視,$title:警告数)" );
			}
			{
				my $title = '～';
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 0, "JAWP::Article::LintTitle(リダイレクト無視,$title:警告数)" );
			}
			foreach my $title ( @{GetNotJIS_X_0208_KANJI()} ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 0, "JAWP::Article::LintTitle(リダイレクト無視,$title:警告数)" );
			}
		}

		# 曖昧さ回避テスト
		{
			$article->SetText( '' );
			foreach my $title ( '記事名（曖昧さ回避）' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(曖昧さ回避,$title:警告数)" );
				is( $result_ref->[0], '曖昧さ回避の記事であればカッコは半角でないといけません', "JAWP::Article::LintTitle(曖昧さ回避,$title:警告文)" );
			}
			$article->SetText( '' );
			foreach my $title ( '記事名(曖昧さ回避)', '記事名  (曖昧さ回避)' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(曖昧さ回避,$title:警告数)" );
				is( $result_ref->[0], '曖昧さ回避の記事であればカッコの前のスペースはひとつでないといけません', "JAWP::Article::LintTitle(曖昧さ回避,$title:警告文)" );
			}
		}

		# 記事名に使用できる文字・文言テスト
		{
			$article->SetText( '' );
			foreach my $type ( '株式会社', '有限会社', '合名会社', '合資会社', '合同会社' ) {
				my $title;

				$title = $type;
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 0, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );

				$title = "あいうえお" . $type;
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
				is( $result_ref->[0], '会社の記事であれば法的地位を示す語句を含むことは推奨されません', "JAWP::Article::LintTitle(文字・文言,$title:警告文)" );

				$title = $type . "あいうえお";
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
				is( $result_ref->[0], '会社の記事であれば法的地位を示す語句を含むことは推奨されません', "JAWP::Article::LintTitle(文字・文言,$title:警告文)" );
			}
			$article->SetText( '' );
			foreach my $title ( '　', '，', '．', '！', '？', '＆', '＠' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
				is( $result_ref->[0], '全角スペース、全角記号の使用は推奨されません', "JAWP::Article::LintTitle(文字・文言,$title:警告文)" );
			}
			$article->SetText( '' );
			foreach my $title ( 'Ａ', 'Ｚ', 'ａ', 'ｚ', '０', '９' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
				is( $result_ref->[0], '全角英数字の使用は推奨されません', "JAWP::Article::LintTitle(文字・文言,$title:警告文)" );
			}
			$article->SetText( '' );
			foreach my $title ( 'ｱ', 'ﾝ', 'ﾞ', 'ﾟ', 'ｧ', 'ｫ', 'ｬ', 'ｮ', '｡', '｢', '｣', '､' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
				is( $result_ref->[0], '半角カタカナの使用は推奨されません', "JAWP::Article::LintTitle(文字・文言,$title:警告文)" );
			}
			$article->SetText( '' );
			foreach my $title ( 'Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ', 'Ⅶ', 'Ⅷ', 'Ⅸ', 'Ⅹ' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
				is( $result_ref->[0], 'ローマ数字はアルファベットを組み合わせましょう', "JAWP::Article::LintTitle(文字・文言,$title:警告文)" );
			}
			$article->SetText( '' );
			foreach my $title ( '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩', '⑪', '⑫', '⑬', '⑭', '⑮', '⑯', '⑰', '⑱', '⑲', '⑳' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
				is( $result_ref->[0], '丸付き数字の使用は推奨されません', "JAWP::Article::LintTitle(文字・文言,$title:警告文)" );
			}
			$article->SetText( '' );
			foreach my $title ( '「', '」', '『', '』', '〔', '〕', '〈', '〉', '《', '》', '【', '】' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
				is( $result_ref->[0], '括弧の使用は推奨されません', "JAWP::Article::LintTitle(文字・文言,$title:警告文)" );
			}
			{
				my $title = '～';
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
				is( $result_ref->[0], '波記号は〜(U+301C)を使用しましょう', "JAWP::Article::LintTitle(文字・文言,$title:警告文)" );
			}
			{
				my $title;

				$title = 'ああ';
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 0, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );

				$title = 'アア';
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 0, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );

				$title = 'あア';
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
				is( $result_ref->[0], '平仮名と片仮名が混在しています', "JAWP::Article::LintTitle(文字・文言,$title:警告文)" );
			}
			$article->SetText( '' );
			foreach my $title ( @{GetJIS_X_0208_KANJI()} ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 0, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
			}
			$article->SetText( '' );
			foreach my $title ( @{GetNotJIS_X_0208_KANJI()} ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is( @$result_ref + 0, 1, "JAWP::Article::LintTitle(文字・文言,$title:警告数)" );
				is( $result_ref->[0], sprintf( "%s(U+%04X) はJIS X 0208外の文字です", $title, ord( $title ) ), "JAWP::Article::LintTitle(文字・文言,$title:警告文)" );
			}
		}
	}

	# LintTextテスト
	{
		my $article = new JAWP::Article;
		my $titlelist = new JAWP::TitleList;
		my $result_ref;

		$titlelist->{'標準_リダイレクト'}->{'転送語'} = 1;
		$titlelist->{'標準_曖昧'}->{'曖昧さ回避語'} = 1;
		$titlelist->{'Category'}->{'カテゴリ'} = 1;
		$titlelist->{'Category'}->{'カテゴリ1'} = 1;
		$titlelist->{'Category'}->{'カテゴリ2'} = 1;
		$titlelist->{'Category'}->{'存命人物'} = 1;
		$titlelist->{'Category'}->{'1900年生'} = 1;
		$titlelist->{'Category'}->{'1902年没'} = 1;
		$titlelist->{'Category'}->{'2001年生'} = 1;
		$titlelist->{'Category'}->{'2011年没'} = 1;
		$titlelist->{'Category'}->{'生年不明'} = 1;
		$titlelist->{'Category'}->{'没年不明'} = 1;
		$titlelist->{'ファイル'}->{'ファイル'} = 1;
		$titlelist->{'Template'}->{'Reflist'} = 1;
		$titlelist->{'Template'}->{'Aimai'} = 1;
		$titlelist->{'Template'}->{'死亡年月日と没年齢'} = 1;
		$titlelist->{'Template'}->{'テンプレート'} = 1;

		# 戻り値の型確認
		$article->SetTitle( '標準' );
		$article->SetText( '' );
		$result_ref = $article->LintTitle;
		is( ref $result_ref, 'ARRAY', 'JAWP::Article::LintText(空文字列:リファレンス種別)' );

		# 標準記事空間以外は無視確認
		foreach my $namespace ( '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート' ) {
			$article->SetTitle( "$namespace:TEST" );
			$article->SetText( '' );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, "JAWP::Article::LintText(標準記事空間以外無視,$namespace:警告数)" );
		}

		# リダイレクト記事は無視確認
		$article->SetTitle( '標準' );
		$article->SetText( '#redirect[[転送先]]' );
		$result_ref = $article->LintText( $titlelist );
		is( @$result_ref + 0, 0, 'JAWP::Article::LintText(リダイレクト無視:警告数)' );

		# 特定タグ内は無視確認
		{
			foreach my $tag ( 'math', 'code', 'pre', 'nowiki' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "<$tag>\n= あああ =\n</$tag>\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 0, "JAWP::Article::LintText($tag 内無視:警告数)" );

				$article->SetTitle( '標準' );
				$article->SetText( "<$tag>\nあああ\n</$tag>\n= いいい =\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText($tag 内無視,行数の不動:警告数)" );
				is( $result_ref->[0], 'レベル1の見出しがあります(4)', "JAWP::Article::LintText($tag 内無視,行数の不動:警告文)" );

				$article->SetTitle( '標準' );
				$article->SetText( "<$tag>\nあああ\n</$tag>\n= いいい =\n<$tag>\nううう\n</$tag>{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText($tag 内無視,タグ複数:警告数)" );
				is( $result_ref->[0], 'レベル1の見出しがあります(4)', "JAWP::Article::LintText($tag 内無視,タグ複数:警告文)" );
			}
		}

		# 見出しテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n= いいい =\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(見出しレベル1:警告数)' );
			is( $result_ref->[0], 'レベル1の見出しがあります(2)', 'JAWP::Article::LintText(見出しレベル1:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n = いいい = \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(見出しレベル1,無効:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(見出しレベル2:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n == いいい == \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(見出しレベル2,無効:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(見出しレベル3:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n=== いいい ===\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(見出しレベル3,レベル違反(3):警告数)' );
			is( $result_ref->[0], 'レベル3の見出しの前にレベル2の見出しが必要です(2)', 'JAWP::Article::LintText(見出しレベル3,レベル違反(3):警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n === いいい === \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(見出しレベル3,無効:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(見出しレベル4:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n==== えええ ====\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(見出しレベル4,レベル違反(2-4):警告数)' );
			is( $result_ref->[0], 'レベル4の見出しの前にレベル3の見出しが必要です(3)', 'JAWP::Article::LintText(見出しレベル4,レベル違反(2-4):警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n==== いいい ====\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(見出しレベル4,レベル違反(4):警告数)' );
			is( $result_ref->[0], 'レベル4の見出しの前にレベル3の見出しが必要です(2)', 'JAWP::Article::LintText(見出しレベル4,レベル違反(4):警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n ==== いいい ==== \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(見出しレベル4,無効:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n===== おおお =====\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(見出しレベル5:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n===== おおお =====\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(見出しレベル5,レベル違反(2-3-5):警告数)' );
			is( $result_ref->[0], 'レベル5の見出しの前にレベル4の見出しが必要です(4)', 'JAWP::Article::LintText(見出しレベル5,レベル違反(2-3-5):警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n===== いいい =====\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(見出しレベル5,レベル違反(5):警告数)' );
			is( $result_ref->[0], 'レベル5の見出しの前にレベル4の見出しが必要です(2)', 'JAWP::Article::LintText(見出しレベル5,レベル違反(5):警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n ===== いいい ===== \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(見出しレベル5,無効:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n===== おおお =====\n====== かかか ======\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(見出しレベル6:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n====== かかか ======\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(見出しレベル5,レベル違反(2-3-4-6):警告数)' );
			is( $result_ref->[0], 'レベル6の見出しの前にレベル5の見出しが必要です(5)', 'JAWP::Article::LintText(見出しレベル6,レベル違反(2-3-4-6):警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n====== いいい ======\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(見出しレベル5,レベル違反(6):警告数)' );
			is( $result_ref->[0], 'レベル6の見出しの前にレベル5の見出しが必要です(2)', 'JAWP::Article::LintText(見出しレベル6,レベル違反(6):警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n ====== いいい ====== \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(見出しレベル6,無効:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n===== おおお =====\n====== かかか ======\n======= ききき =======\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(見出しレベル7:警告数)' );
			is( $result_ref->[0], '見出しレベルは6までです(7)', 'JAWP::Article::LintText(見出しレベル7:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい =\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(見出しレベル左右不一致:警告数)' );
			is( $result_ref->[0], '見出し記法の左右の=の数が一致しません(2)', 'JAWP::Article::LintText(見出しレベル左右不一致:警告文)' );
		}

		# ISBN記法テスト
		{
			foreach my $code ( '0123456789', '0-12-345678-9', '012345678901X', '012-3-45-678901-X' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "ISBN $code\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 0, "JAWP::Article::LintText(ISBN,' ',$code:警告数)" );

				$article->SetTitle( '標準' );
				$article->SetText( "ISBN=$code\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 0, "JAWP::Article::LintText(ISBN,'=',$code:警告数)" );

				$article->SetTitle( '標準' );
				$article->SetText( "ISBN$code\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(ISBN,半角スペース無し,$code:警告数)" );
				is( $result_ref->[0], 'ISBN記法では、ISBNと数字の間に半角スペースが必要です(1)', "JAWP::Article::LintText(ISBN,半角スペース無し,$code:警告文)" );
			}

			$article->SetTitle( '標準' );
			$article->SetText( "ISBN 012345678\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(ISBN,桁数違反:警告数)' );
			is( $result_ref->[0], 'ISBNは10桁もしくは13桁でないといけません(1)', 'JAWP::Article::LintText(ISBN,桁数違反:警告文)' );
		}

		# 西暦記述テスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "2011年\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(西暦:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "'11年\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(西暦,2桁,半角クォート:警告数)' );
			is( $result_ref->[0], '西暦は全桁表示が推奨されます(1)', 'JAWP::Article::LintText(西暦,2桁,半角クォート:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "’11年\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(西暦,2桁,全角クォート:警告数)' );
			is( $result_ref->[0], '西暦は全桁表示が推奨されます(1)', 'JAWP::Article::LintText(西暦,2桁,全角クォート:警告文)' );
		}

		# 不正コメントタグテスト
		{
			foreach my $tag ( '<!--', '-->' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "$tag\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, 'JAWP::Article::LintText(不正コメント:警告数)' );
				is( $result_ref->[0], '閉じられていないコメントタグがあります(1)', 'JAWP::Article::LintText(不正コメント:警告文)' );
			}
		}

		# ソートキーテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "{{DEFAULTSORT:あああ}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(ソートキー,DEFAULTSORT:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{デフォルトソート:あああ}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(ソートキー,デフォルトソート:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{aimai}}\n[[Category:カテゴリ|あああ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(ソートキー,Category:警告数)' );

			foreach my $char ( 'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ', 'っ', 'ゃ', 'ゅ', 'ょ', 'ゎ', 'が', 'ぎ', 'ぐ', 'げ', 'ご', 'ざ', 'じ', 'ず', 'ぜ', 'ぞ', 'だ', 'ぢ', 'づ', 'で', 'ど', 'ば', 'び', 'ぶ', 'べ', 'ぼ', 'ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ', 'ー' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "{{DEFAULTSORT:あああ$char}}\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(ソートキー,濁音、半濁音、吃音、長音,DEFAULTSORT,$char:警告数)" );
				is( $result_ref->[0], 'ソートキーには濁音、半濁音、吃音、長音は清音化することが推奨されます(1)', "JAWP::Article::LintText(ソートキー,濁音、半濁音、吃音、長音,DEFAULTSORT,$char:警告文)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{デフォルトソート:あああ$char}}\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(ソートキー,濁音、半濁音、吃音、長音,デフォルトソート,$char:警告数)" );
				is( $result_ref->[0], 'ソートキーには濁音、半濁音、吃音、長音は清音化することが推奨されます(1)', "JAWP::Article::LintText(ソートキー,濁音、半濁音、吃音、長音,デフォルトソート,$char:警告文)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[Category:カテゴリ|あああ$char]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(ソートキー,濁音、半濁音、吃音、長音,Category,$char:警告数)" );
				is( $result_ref->[0], 'ソートキーには濁音、半濁音、吃音、長音は清音化することが推奨されます(2)', "JAWP::Article::LintText(ソートキー,濁音、半濁音、吃音、長音,Category,$char:警告文)" );
			}
		}

		# デフォルトソートテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "{{DEFAULTSORT:あああ}}\n{{DEFAULTSORT:あああ}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(デフォルトソート,複数:警告数)' );
			is( $result_ref->[0], 'デフォルトソートが複数存在します(2)', 'JAWP::Article::LintText(デフォルトソート,複数:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{DEFAULTSORT:あああ}}\n{{デフォルトソート:あああ}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(デフォルトソート,複数:警告数)' );
			is( $result_ref->[0], 'デフォルトソートが複数存在します(2)', 'JAWP::Article::LintText(デフォルトソート,複数:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{デフォルトソート:あああ}}\n{{デフォルトソート:あああ}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(デフォルトソート,複数:警告数)' );
			is( $result_ref->[0], 'デフォルトソートが複数存在します(2)', 'JAWP::Article::LintText(デフォルトソート,複数:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{DEFAULTSORT:}}\n\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(デフォルトソート,ソートキー無し:警告数)' );
			is( $result_ref->[0], 'デフォルトソートではソートキーが必須です(1)', 'JAWP::Article::LintText(デフォルトソート,ソートキー無し:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{デフォルトソート:}}\n\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(デフォルトソート,ソートキー無し:警告数)' );
			is( $result_ref->[0], 'デフォルトソートではソートキーが必須です(1)', 'JAWP::Article::LintText(デフォルトソート,ソートキー無し:警告文)' );
		}

		# カテゴリテスト
		{
			foreach my $type ( 'Category', 'category', 'カテゴリ' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:カテゴリ1]]\n[[$type:カテゴリ2]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 0, "JAWP::Article::LintText($type:警告数)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:カテゴリ1]][[$type:カテゴリ2]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 0, "JAWP::Article::LintText($type,同一行:警告数)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:カテゴリ]]\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText($type,重複指定:警告数)" );
				is( $result_ref->[0], '既に使用されているカテゴリです(3)', "JAWP::Article::LintText($type,重複指定:警告文)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:カテゴリ]][[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText($type,重複指定,同一行:警告数)" );
				is( $result_ref->[0], '既に使用されているカテゴリです(2)', "JAWP::Article::LintText($type,重複指定,同一行:警告文)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:カテゴリ3]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText($type,不存在:警告数)" );
				is( $result_ref->[0], '(カテゴリ3)は存在しないカテゴリです(2)', "JAWP::Article::LintText($type,不存在:警告文)" );
			}
		}

		# テンプレートテスト
		{
			foreach my $type ( 'Template', 'template', 'テンプレート' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:テンプレート]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 0, "JAWP::Article::LintText($type,リンク呼び出し:警告数)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:テンプレート1]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText($type,リンク呼び出し,不存在:警告数)" );
				is( $result_ref->[0], '(テンプレート1)は存在しないテンプレートです(2)', "JAWP::Article::LintText($type,リンク呼び出し,不存在:警告文)" );
			}
		}

		# 使用できる文字・文言テスト
		{
			$article->SetTitle( '標準' );
			foreach my $char ( '，', '．', '！', '？', '＆', '＠' ) {
				$article->SetText( "$char\n{{aimai}}\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(全角記号,$char:警告数)" );
				is( $result_ref->[0], '全角記号の使用は推奨されません(1)', "JAWP::Article::LintText(全角記号,$char:警告文)" );
			}
			$article->SetTitle( '標準' );
			foreach my $char ( 'Ａ', 'Ｚ', 'ａ', 'ｚ', '０', '９' ) {
				$article->SetText( "$char\n{{aimai}}\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(全角英数字,$char:警告数)" );
				is( $result_ref->[0], '全角英数字の使用は推奨されません(1)', "JAWP::Article::LintText(全角英数字,$char:警告文)" );
			}
			$article->SetTitle( '標準' );
			foreach my $char ( 'ｱ', 'ﾝ', 'ﾞ', 'ﾟ', 'ｧ', 'ｫ', 'ｬ', 'ｮ', '｡', '｢', '｣', '､' ) {
				$article->SetText( "$char\n{{aimai}}\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(半角カタカナ,$char:警告数)" );
				is( $result_ref->[0], '半角カタカナの使用は推奨されません(1)', "JAWP::Article::LintText(半角カタカナ,$char:警告文)" );
			}
			$article->SetTitle( '標準' );
			foreach my $char ( 'Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ', 'Ⅶ', 'Ⅷ', 'Ⅸ', 'Ⅹ' ) {
				$article->SetText( "$char\n{{aimai}}\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(ローマ数字,$char:警告数)" );
				is( $result_ref->[0], 'ローマ数字はアルファベットを組み合わせましょう(1)', "JAWP::Article::LintText(ローマ数字,$char:警告文)" );
			}
			$article->SetTitle( '標準' );
			foreach my $char ( '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩', '⑪', '⑫', '⑬', '⑭', '⑮', '⑯', '⑰', '⑱', '⑲', '⑳' ) {
				$article->SetText( "$char\n{{aimai}}\n" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(丸付き数字,$char:警告数)" );
				is( $result_ref->[0], '丸付き数字の使用は推奨されません(1)', "JAWP::Article::LintText(丸付き数字,$char:警告文)" );
			}
		}

		# 言語間リンクテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "{{aimai}}\n[[en:dummy]]" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(言語間リンク:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{aimai}}\n[[en:dummy]]\n[[fr:dummy]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(言語間リンク,複数:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{aimai}}\n[[en:dummy]]\n[[en:dummy]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(言語間リンク,重複:警告数)' );
			is( $result_ref->[0], '言語間リンクが重複しています(3)', 'JAWP::Article::LintText(言語間リンク,重複:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{aimai}}\n[[fr:dummy]]\n[[en:dummy]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(言語間リンク,順序:警告数)' );
			is( $result_ref->[0], '言語間リンクはアルファベット順に並べることが推奨されます(3)', 'JAWP::Article::LintText(言語間リンク,順序:警告文)' );
		}

		# 曖昧さ回避リンクテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "[[標準]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(曖昧さ回避リンク,標準:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[曖昧さ回避語]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(曖昧さ回避リンク,曖昧さ回避語:警告数)' );
			is( $result_ref->[0], '(曖昧さ回避語)のリンク先は曖昧さ回避です(1)', 'JAWP::Article::LintText(曖昧さ回避リンク,曖昧さ回避語:警告文)' );
		}

		# リダイレクトリンクテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "[[標準]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(リダイレクトリンク,標準:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[転送語]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(リダイレクトリンク,転送語:警告数)' );
			is( $result_ref->[0], '(転送語)のリンク先はリダイレクトです(1)', 'JAWP::Article::LintText(リダイレクトリンク,転送語:警告文)' );
		}

		# 年月日リンクテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "[[2011年]][[1月1日]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(年月日リンク,[[2011年]][[1月1日]]:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[2011年1月1日は元旦]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(年月日リンク,[[2011年1月1日は元旦]]:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[2011年1月1日]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(年月日リンク,[[2011年1月1日]]:警告数)' );
			is( $result_ref->[0], '年月日へのリンクは年と月日を分けることが推奨されます(1)', 'JAWP::Article::LintText(リダイレクトリンク,[[2011年1月1日]]:警告文)' );
		}

		# 不正URLテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "[http://www.yahoo.co.jp/]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(不正URL,http://www.yahoo.co.jp/:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[http:///www.yahoo.co.jp/]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(不正URL,http:///www.yahoo.co.jp/:警告数)' );
			is( $result_ref->[0], '不正なURLです(1)', 'JAWP::Article::LintText(不正URL,http:///www.yahoo.co.jp/:警告文)' );
		}

		# カッコ対応テスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "[ ]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(カッコ対応,[ ]:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{ }\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(カッコ対応,{ }:警告数)' );

			foreach my $subtext ( '[', ']', '[[', ']]', '{', '}', '{{', '}}', '[}', '{]' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "$subtext\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, 'JAWP::Article::LintText(カッコ対応,[:警告数)' );
				is( $result_ref->[0], '空のリンクまたは閉じられていないカッコがあります(1)', "JAWP::Article::LintText(カッコ対応,$subtext:警告文)" );
			}
		}

		# リファレンステスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "<ref>あああ</ref>\n<references/>\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(リファレンス,<references/>:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "<ref>あああ</ref>\n{{reflist}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(リファレンス,{{reflist}}:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "<ref>あああ</ref>\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(リファレンス,不存在:警告数)' );
			is( $result_ref->[0], '<ref>要素があるのに<references>要素がありません', 'JAWP::Article::LintText(リファレンス,不存在:警告文)' );
		}

		# 定義文テスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, "JAWP::Article::LintText(定義文,'標準'-'':警告数)" );
			is( $result_ref->[0], '定義文が見当たりません', "JAWP::Article::LintText(定義文,'標準'-'':警告文)" );

			$article->SetTitle( '標準' );
			$article->SetText( "'''あああ'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, "JAWP::Article::LintText(定義文,'標準'-'''あああ''':警告数)" );
			is( $result_ref->[0], '定義文が見当たりません', "JAWP::Article::LintText(定義文,'標準'-'''あああ''':警告文)" );

			$article->SetTitle( '標準' );
			$article->SetText( "'''標 準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, "JAWP::Article::LintText(定義文,'標準'-'''標 準''':警告数)" );

			$article->SetTitle( '標準' );
			$article->SetText( "''' 標準 '''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, "JAWP::Article::LintText(定義文,'標準'-''' 標準 ''':警告数)" );

			$article->SetTitle( '標 準' );
			$article->SetText( "''' 標 準 '''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, "JAWP::Article::LintText(定義文,'標 準'-''' 標 準 ''':警告数)" );

			$article->SetTitle( '標準' );
			$article->SetText( "'''あああ'''\n''' 標準 '''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, "JAWP::Article::LintText(定義文,'標準'-'''あああ'''\n''' 標準 ''':警告数)" );

			$article->SetTitle( '標準 (曖昧さ回避)' );
			$article->SetText( "'''標準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, "JAWP::Article::LintText(定義文,'標準 (曖昧さ回避)'-'''標準''':警告数)" );

			$article->SetTitle( 'Abc' );
			$article->SetText( "'''abc'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, "JAWP::Article::LintText(定義文,'Abc'-'''abc''':警告数)" );

			$article->SetTitle( 'Shift JIS' );
			$article->SetText( "'''Shift_JIS'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, "JAWP::Article::LintText(定義文,'Shift JIS'-'''Shift_JIS''':警告数)" );
		}

		# カテゴリ、デフォルトソート、出典なしテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "'''標準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(カテゴリ無し:警告数)' );
			is( $result_ref->[0], 'カテゴリが一つもありません', 'JAWP::Article::LintText(カテゴリ無し:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "'''標準'''\n== 出典 ==\n[[Category:カテゴリ]]" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(デフォルトソート無し:警告数)' );
			is( $result_ref->[0], 'デフォルトソートがありません', 'JAWP::Article::LintText(デフォルトソート無し:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "'''標準'''\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(出典無し:警告数)' );
			is( $result_ref->[0], '出典に関する節がありません', 'JAWP::Article::LintText(出典無し:警告文)' );
		}

		# ブロック順序テスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "'''標準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(ブロック順序,本文-カテゴリ:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "'''標準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[Category:カテゴリ]]\n[[en:interlink]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(ブロック順序,本文-カテゴリ-言語間リンク:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "'''標準'''\n== 出典 ==\n[[en:interlink]]\n[[Category:カテゴリ]]\n{{DEFAULTSORT:あああ}}\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(ブロック順序,本文-言語間リンク-カテゴリ:警告数)' );
			is( $result_ref->[0], '本文、カテゴリ、言語間リンクの順に記述することが推奨されます(4)', 'JAWP::Article::LintText(ブロック順序,本文-言語間リンク-カテゴリ:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[Category:カテゴリ]]\n'''標準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[en:interlink]]\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(ブロック順序,カテゴリ-本文-言語間リンク:警告数)' );
			is( $result_ref->[0], '本文、カテゴリ、言語間リンクの順に記述することが推奨されます(2)', 'JAWP::Article::LintText(ブロック順序,カテゴリ-本文-言語間リンク:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[Category:カテゴリ]]\n{{DEFAULTSORT:あああ}}\n[[en:interlink]]\n'''標準'''\n== 出典 ==\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(ブロック順序,カテゴリ-言語間リンク-本文:警告数)' );
			is( $result_ref->[0], '本文、カテゴリ、言語間リンクの順に記述することが推奨されます(4)', 'JAWP::Article::LintText(ブロック順序,カテゴリ-言語間リンク-本文:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[en:interlink]]\n[[Category:カテゴリ]]\n{{DEFAULTSORT:あああ}}\n'''標準'''\n== 出典 ==\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(ブロック順序,言語間リンク-カテゴリ-本文:警告数)' );
			is( $result_ref->[0], '本文、カテゴリ、言語間リンクの順に記述することが推奨されます(2)', 'JAWP::Article::LintText(ブロック順序,言語間リンク-カテゴリ-本文:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[en:interlink]]\n'''標準'''\n== 出典 ==\n[[Category:カテゴリ]]\n{{DEFAULTSORT:あああ}}\n" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(ブロック順序,言語間リンク-本文-カテゴリ:警告数)' );
			is( $result_ref->[0], '本文、カテゴリ、言語間リンクの順に記述することが推奨されます(2)', 'JAWP::Article::LintText(ブロック順序,言語間リンク-本文-カテゴリ:警告文)' );
		}

		# 生没年カテゴリテスト
		{
			foreach my $subtext ( "[[Category:2001年生]]\n[[Category:存命人物]]\n{{生年月日と年齢|2001|1|1}}", "[[Category:生年不明]]\n[[Category:存命人物]]", "[[Category:2001年生]]\n[[Category:2011年没]]\n{{死亡年月日と没年齢|2001|1|1|2011|12|31}}", "[[Category:2001年生]]\n[[Category:2011年没]]\n{{没年齢|2001|1|1|2011|12|31}}", "[[Category:生年不明]]\n[[Category:2011年没]]", "[[Category:2001年生]]\n[[Category:没年不明]]", "[[Category:生年不明]]\n[[Category:没年不明]]" ) {
				$article->SetTitle( '標準' );
				$article->SetText( "$subtext\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 0, "JAWP::Article::LintText(生没年カテゴリ,$subtext:警告数)" );
			}

			foreach my $subtext ( "[[Category:2001年生]]\n[[Category:2011年没]]\n[[Category:存命人物]]\n{{死亡年月日と没年齢|2001|1|1|2011|12|31}}", "[[Category:2001年生]]\n[[Category:没年不明]]\n[[Category:存命人物]]", "[[Category:生年不明]]\n[[Category:2011年没]]\n[[Category:存命人物]]", "[[Category:生年不明]]\n[[Category:没年不明]]\n[[Category:存命人物]]", "[[Category:2001年生]]\n[[Category:存命人物]]\n{{死亡年月日と没年齢|2001|1|1|2011|12|31}}" ) {
				$article->SetTitle( '標準' );
				$article->SetText( "$subtext\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(生没年カテゴリ,存命人物ではありません,$subtext:警告数)" );
				is( $result_ref->[0], '存命人物ではありません', "JAWP::Article::LintText(生没年カテゴリ,存命人物ではありません,$subtext:警告文)" );
			}

			foreach my $subtext ( "[[Category:存命人物]]", "[[Category:2011年没]]", "[[Category:没年不明]]" ) {
				$article->SetTitle( '標準' );
				$article->SetText( "$subtext\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(生没年カテゴリ,生年のカテゴリがありません,$subtext:警告数)" );
				is( $result_ref->[0], '生年のカテゴリがありません', "JAWP::Article::LintText(生没年カテゴリ,生年のカテゴリがありません,$subtext:警告文)" );
			}

			foreach my $subtext ( "[[Category:2001年生]]", "[[Category:生年不明]]" ) {
				$article->SetTitle( '標準' );
				$article->SetText( "$subtext\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(生没年カテゴリ,存命人物または没年のカテゴリがありません,$subtext:警告数)" );
				is( $result_ref->[0], '存命人物または没年のカテゴリがありません', "JAWP::Article::LintText(生没年カテゴリ,存命人物または没年のカテゴリがありません,$subtext:警告文)" );
			}

			foreach my $subtext ( "[[Category:2001年生]]\n[[Category:2011年没]]\n{{死亡年月日と没年齢|2002|1|1|2011|12|31}}", "[[Category:2001年生]]\n[[Category:2011年没]]\n{{没年齢|2002|1|1|2011|12|31}}", "[[Category:2001年生]]\n[[Category:存命人物]]\n{{生年月日と年齢|2002|1|1}}" ) {
				$article->SetTitle( '標準' );
				$article->SetText( "$subtext\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(生没年カテゴリ,テンプレートと生年のカテゴリ不一致,$subtext:警告数)" );
				is( $result_ref->[0], '(生年月日と年齢or死亡年月日と没年齢or没年齢)テンプレートと生年のカテゴリが一致しません', "JAWP::Article::LintText(生没年カテゴリ,テンプレートと生年のカテゴリ不一致,$subtext:警告文)" );
			}

			foreach my $subtext ("[[Category:2001年生]]\n[[Category:2011年没]]\n{{死亡年月日と没年齢|2001|1|1|2012|12|31}}", "[[Category:2001年生]]\n[[Category:2011年没]]\n{{没年齢|2001|1|1|2012|12|31}}" ) {
				$article->SetTitle( '標準' );
				$article->SetText( "$subtext\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is( @$result_ref + 0, 1, "JAWP::Article::LintText(生没年カテゴリ,テンプレートと没年のカテゴリ不一致,$subtext:警告数)" );
				is( $result_ref->[0], '(死亡年月日と没年齢or没年齢)テンプレートと没年のカテゴリが一致しません', "JAWP::Article::LintText(生没年カテゴリ,テンプレートと没年のカテゴリ不一致,$subtext:警告文)" );
			}

			$article->SetTitle( '標準' );
			$article->SetText( "[[Category:2001年生]]\n[[Category:存命人物]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(生没年カテゴリ,2001年生-存命人物,テンプレート未使用:警告数)' );
			is( $result_ref->[0], '(生年月日と年齢)のテンプレートを使うと便利です', 'JAWP::Article::LintText(生没年カテゴリ,2001年生-存命人物,テンプレート未使用:警告文)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[Category:1900年生]]\n[[Category:1902年没]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 0, 'JAWP::Article::LintText(生没年カテゴリ,1900年生-1902年没,テンプレート範囲外:警告数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[Category:2001年生]]\n[[Category:2011年没]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is( @$result_ref + 0, 1, 'JAWP::Article::LintText(生没年カテゴリ,2001年生-2011年没,テンプレート未使用:警告数)' );
			is( $result_ref->[0], '(死亡年月日と没年齢)のテンプレートを使うと便利です', 'JAWP::Article::LintText(生没年カテゴリ,2001年生-2011年没,テンプレート未使用:警告文)' );
		}
	}

	# LintRedirectテスト
	{
		my $article = new JAWP::Article;
		my $result_ref;

		$article->SetTitle( '' );
		$article->SetText( '' );
		$result_ref = $article->LintRedirect;
		is( ref $result_ref, 'ARRAY', 'JAWP::Article::LintRedirect(空文字列:リファレンス種別)' );
		is( @$result_ref + 0, 0, 'JAWP::Article::LintRedirect(空文字列:警告数)' );

		# リダイレクト以外は無視確認
		$article->SetTitle( 'aaa (aaa)' );
		$article->SetText( '' );
		$result_ref = $article->LintRedirect;
		is( @$result_ref + 0, 0, 'JAWP::Article::LintRedirect(非リダイレクト:警告数)' );

		# カッコ付き記事
		$article->SetTitle( 'aaa (aaa)' );
		$article->SetText( '#REDIRECT[[aaa]]' );
		$result_ref = $article->LintRedirect;
		is( @$result_ref + 0, 1, 'JAWP::Article::LintRedirect(カッコ付き記事:警告数)' );
		is( $result_ref->[0], 'カッコ付きのリダイレクトは有用ではない可能性があります', 'JAWP::Article::LintRedirect(カッコ付き記事:警告文)' );

		# ノート
		$article->SetTitle( 'ノート:aaa' );
		$article->SetText( '#REDIRECT[[aaa]]' );
		$result_ref = $article->LintRedirect;
		is( @$result_ref + 0, 1, 'JAWP::Article::LintRedirect(ノート:警告数)' );
		is( $result_ref->[0], 'ノートのリダイレクトは有用ではない可能性があります', 'JAWP::Article::LintRedirect(ノート:警告文)' );
	}
}


################################################################################
# JAWP::TitleListクラス
################################################################################

sub TestJAWPTitleList {
	# メソッド呼び出しテスト
	{
		ok( JAWP::TitleList->can('new'), 'JAWP::TitleList(メソッド呼び出し,new)' );
	}

	# メンバー変数確認
	{
		my $titlelist = new JAWP::TitleList;

		ok( defined( $titlelist ), 'new' );
		cmp_ok( keys( %$titlelist ),  '==', 23, 'JAWP::TitleList(メンバ変数個数)' );

		foreach my $member ( '標準', '標準_曖昧', '標準_リダイレクト', '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート' ) {
			ok( defined( $titlelist->{$member} ), "JAWP::TitleList(メンバ変数宣言,$member)" );
			is( ref $titlelist->{$member}, 'HASH', "JAWP::TitleList(メンバ変数リファレンス種別,$member)" );
		}

		foreach my $member ( 'allcount' ) {
			ok( defined( $titlelist->{$member} ), "JAWP::TitleList(メンバ変数宣言,$member)" );
			cmp_ok( $titlelist->{$member}, '==', 0, "JAWP::TitleList(メンバ変数値,$member)" );
		}
	}
}


################################################################################
# JAWP::DataFileクラス
################################################################################

sub TestJAWPData {
	# メソッド呼び出しテスト
	{
		foreach my $method ( 'new', 'GetArticle', 'GetTitleList' ) {
			ok( JAWP::DataFile->can($method), "JAWP::DataFile(メソッド呼び出し,$method)" );
		}
	}

	# 空new失敗確認テスト
	{
		my $data = new JAWP::DataFile;
		ok( !defined( $data ), 'JAWP::DataFile(空new)' );
	}

	# メンバー変数確認
	{
		my $fname = WriteTestXMLFile( '' );
		my $data = new JAWP::DataFile( $fname );

		ok( defined( $data ), 'JAWP::DataFile(ファイル名指定)' );
		cmp_ok( keys( %$data ),  '==', 2, 'JAWP::DataFile(メンバ変数個数)' );

		ok( defined( $data->{'filename'} ), 'JAWP::DataFile(メンバ変数宣言,filename)' );
		is( $data->{'filename'}, $fname, 'JAWP::DataFile(メンバ変数値,filename)' );

		ok( defined( $data->{'fh'} ), 'JAWP::DataFile(メンバ変数宣言,fh)' );
		is( ref $data->{'fh'}, 'GLOB', 'JAWP::DataFile(メンバ変数リファレンス種別,fh)' );

		unlink( $fname ) or die $!;
	}

	# GetArticleテスト
	{
		# 空XMLファイル
		{
			my $fname = WriteTestXMLFile( '' );
			my $data = new JAWP::DataFile( $fname );
			my $article = $data->GetArticle;

			ok( !defined( $article ), 'JAWP::DataFile::GetArticle(空XMLファイル)' );

			unlink( $fname ) or die $!;
		}

		# xml要素のみXMLファイル
		{
			my $fname = WriteTestXMLFile( '<xml></xml>' );
			my $data = new JAWP::DataFile( $fname );
			my $article = $data->GetArticle;

			ok( !defined( $article ), 'JAWP::DataFile::GetArticle(xml要素のみXMLファイル)' );

			unlink( $fname ) or die $!;
		}

		# 破損XMLファイル,title無し
		{
			my $str = <<'STR';
<xml>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve">本文</text>
</xml>
STR
			my $fname = WriteTestXMLFile( $str );
			my $data = new JAWP::DataFile( $fname );
			my $article = $data->GetArticle;

			ok( !defined( $article ), 'JAWP::DataFile::GetArticle(破損XMLファイル,title無し)' );

			unlink( $fname ) or die $!;
		}

		# 破損XMLファイル,timestamp無し
		{
			my $str = <<'STR';
<xml>
	<title>記事名</title>
	<text xml:space="preserve">本文</text>
</xml>
STR
			my $fname = WriteTestXMLFile( $str );
			my $data = new JAWP::DataFile( $fname );
			my $article = $data->GetArticle;

			ok( !defined( $article ), 'JAWP::DataFile::GetArticle(破損XMLファイル,timestamp無し)' );

			unlink( $fname ) or die $!;
		}

		# 破損XMLファイル,text無し
		{
			my $str = <<'STR';
<xml>
	<title>記事名</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
</xml>
STR
			my $fname = WriteTestXMLFile( $str );
			my $data = new JAWP::DataFile( $fname );
			my $article = $data->GetArticle;

			ok( !defined( $article ), 'JAWP::DataFile::GetArticle(破損XMLファイル,text無し)' );

			unlink( $fname ) or die $!;
		}

		# 要素重複XMLファイル
		{
			my $str = <<'STR';
<xml>
	<title>偽記事名</title>
	<title>真記事名</title>
	<timestamp>9999-12-31T23:59:59Z</timestamp>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve">本文</text>
</xml>
STR
			my $fname = WriteTestXMLFile( $str );
			my $data = new JAWP::DataFile( $fname );
			my $article = $data->GetArticle;

			ok( defined( $article ), 'JAWP::DataFile::GetArticle(要素重複XMLファイル,記事取得)' );
			is( $article->{'title'}, '真記事名', 'JAWP::DataFile::GetArticle(要素重複XMLファイル,title)' );
			is( $article->{'timestamp'}, '2011-01-01T00:00:00Z', 'JAWP::DataFile::GetArticle(要素重複XMLファイル,timestamp)' );
			is( $article->{'text'}, '本文', 'JAWP::DataFile::GetArticle(要素重複XMLファイル,text)' );

			unlink( $fname ) or die $!;
		}

		# 要素逆順XMLファイル
		{
			my $str = <<'STR';
<xml>
	<text xml:space="preserve">本文</text>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<title>記事名</title>
</xml>
STR
			my $fname = WriteTestXMLFile( $str );
			my $data = new JAWP::DataFile( $fname );
			my $article = $data->GetArticle;

			ok( defined( $article ), 'JAWP::DataFile::GetArticle(要素逆順XMLファイル,記事取得)' );
			is( $article->{'title'}, '記事名', 'JAWP::DataFile::GetArticle(要素逆順XMLファイル,title)' );
			is( $article->{'timestamp'}, '2011-01-01T00:00:00Z', 'JAWP::DataFile::GetArticle(要素逆順XMLファイル,timestamp)' );
			is( $article->{'text'}, '本文', 'JAWP::DataFile::GetArticle(要素逆順XMLファイル,text)' );

			unlink( $fname ) or die $!;
		}

		# 2周読み込み
		{
			my $str = <<'STR';
<xml>
	<title>記事名</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve">本文</text>
</xml>
STR
			my $fname = WriteTestXMLFile( $str );
			my $data = new JAWP::DataFile( $fname );
			my $article = $data->GetArticle;

			ok( defined( $article ), 'JAWP::DataFile::GetArticle(2周読み込み,1周目1記事目取得)' );
			is( $article->{'title'}, '記事名', 'JAWP::DataFile::GetArticle(2周読み込み,1周目1記事目,title)' );
			is( $article->{'timestamp'}, '2011-01-01T00:00:00Z', 'JAWP::DataFile::GetArticle(2周読み込み,1周目1記事目,timestamp)' );
			is( $article->{'text'}, '本文', 'JAWP::DataFile::GetArticle(2周読み込み,1周目1記事目,text)' );

			$article = $data->GetArticle;
			ok( !defined( $article ), 'JAWP::DataFile::GetArticle(2周読み込み,1周目2記事目取得)' );

			$article = $data->GetArticle;

			ok( defined( $article ), 'JAWP::DataFile::GetArticle(2周読み込み,2周目1記事目取得)' );
			is( $article->{'title'}, '記事名', 'JAWP::DataFile::GetArticle(2周読み込み,2周目1記事目,title)' );
			is( $article->{'timestamp'}, '2011-01-01T00:00:00Z', 'JAWP::DataFile::GetArticle(2周読み込み,2周目1記事目,timestamp)' );
			is( $article->{'text'}, '本文', 'JAWP::DataFile::GetArticle(2周読み込み,2周目1記事目,text)' );

			$article = $data->GetArticle;
			ok( !defined( $article ), 'JAWP::DataFile::GetArticle(2周読み込み,2周目2記事目取得)' );

			unlink( $fname ) or die $!;
		}

		# 本文複数行
		{
			my $str = <<'STR';
<xml>
	<title>記事名</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve">
本文1
本文2
本文3
</text>
</xml>
STR
			my $fname = WriteTestXMLFile( $str );
			my $data = new JAWP::DataFile( $fname );
			my $article = $data->GetArticle;

			ok( defined( $article ), 'JAWP::DataFile::GetArticle(本文複数行,記事取得)' );
			is( $article->{'title'}, '記事名', 'JAWP::DataFile::GetArticle(本文複数行,title)' );
			is( $article->{'timestamp'}, '2011-01-01T00:00:00Z', 'JAWP::DataFile::GetArticle(本文複数行,timestamp)' );
			is( $article->{'text'}, "\n本文1\n本文2\n本文3\n", 'JAWP::DataFile::GetArticle(本文複数行,text)' );

			unlink( $fname ) or die $!;
		}

		# コメント除去
		{
			my $str = <<'STR';
<xml>
	<title>記事名</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve">
本文1
<!--
本文2
-->
<!-- 偽本文3 -->真本文3<!-- 偽本文3 -->
</text>
</xml>
STR
			my $fname = WriteTestXMLFile( $str );
			my $data = new JAWP::DataFile( $fname );
			my $article = $data->GetArticle;

			ok( defined( $article ), 'JAWP::DataFile::GetArticle(コメント除去,記事取得)' );
			is( $article->{'title'}, '記事名', 'JAWP::DataFile::GetArticle(コメント除去,title)' );
			is( $article->{'timestamp'}, '2011-01-01T00:00:00Z', 'JAWP::DataFile::GetArticle(コメント除去,timestamp)' );
			is( $article->{'text'}, "\n本文1\n\n\n\n真本文3\n", 'JAWP::DataFile::GetArticle(コメント除去,text)' );

			unlink( $fname ) or die $!;
		}

		# 2記事読み込み
		{
			my $str = <<'STR';
<xml>
	<title>記事名1</title>
	<timestamp>2011-01-01T00:00:01Z</timestamp>
	<text xml:space="preserve">本文1</text>
	<title>記事名2</title>
	<timestamp>2011-01-01T00:00:02Z</timestamp>
	<text xml:space="preserve">本文2</text>
</xml>
STR
			my $fname = WriteTestXMLFile( $str );
			my $data = new JAWP::DataFile( $fname );
			my $article = $data->GetArticle;

			ok( defined( $article ), 'JAWP::DataFile::GetArticle(2記事読み込み,1記事目取得)' );
			is( $article->{'title'}, '記事名1', 'JAWP::DataFile::GetArticle(2記事読み込み,1記事目,title)' );
			is( $article->{'timestamp'}, '2011-01-01T00:00:01Z', 'JAWP::DataFile::GetArticle(2記事読み込み,1記事目,timestamp)' );
			is( $article->{'text'}, '本文1', 'JAWP::DataFile::GetArticle(2記事読み込み,1記事目,text)' );

			$article = $data->GetArticle;

			ok( defined( $article ), 'JAWP::DataFile::GetArticle(2記事読み込み,2記事目取得)' );
			is( $article->{'title'}, '記事名2', 'JAWP::DataFile::GetArticle(2記事読み込み,2記事目,title)' );
			is( $article->{'timestamp'}, '2011-01-01T00:00:02Z', 'JAWP::DataFile::GetArticle(2記事読み込み,2記事目,timestamp)' );
			is( $article->{'text'}, '本文2', 'JAWP::DataFile::GetArticle(2記事読み込み,2記事目,text)' );

			$article = $data->GetArticle;
			ok( !defined( $article ), 'JAWP::DataFile::GetArticle(2記事読み込み,3記事目取得)' );

			unlink( $fname ) or die $!;
		}
	}

	# GetTitleListテスト
	{
		# 空XMLファイル
		{
			my $fname = WriteTestXMLFile( '' );
			my $data = new JAWP::DataFile( $fname );
			my $titlelist = $data->GetTitleList;

			ok( defined( $titlelist ), 'JAWP::DataFile::GetTitleList(空XMLファイル' );
			foreach my $namespace ( '標準', '標準_曖昧', '標準_リダイレクト', '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート' ) {
				ok( defined( $titlelist->{$namespace} ), "JAWP::DataFile::GetTitleList(空XMLファイル,$namespace)" );
			}

			unlink( $fname ) or die $!;
		}

		# xml要素のみXMLファイル
		{
			my $fname = WriteTestXMLFile( '<xml></xml>' );
			my $data = new JAWP::DataFile( $fname );
			my $titlelist = $data->GetTitleList;

			ok( defined( $titlelist ), 'xml要素のみXMLファイル' );
			foreach my $namespace ( '標準', '標準_曖昧', '標準_リダイレクト', '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート' ) {
				ok( defined( $titlelist->{$namespace} ), "JAWP::DataFile::GetTitleList(xml要素のみXMLファイル,$namespace)" );
			}

			unlink( $fname ) or die $!;
		}

		# 標準XMLファイル
		{
			my $str = <<'STR';
<xml>
	<title>標準A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>標準 曖昧A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve">{{aimai}}</text>

	<title>A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve">#redirect[[あああ]]</text>

	<title>利用者:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>Wikipedia:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>ファイル:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>MediaWiki:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>Template:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>Help:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>Category:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>Portal:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>プロジェクト:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>ノート:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>利用者‐会話:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>Wikipedia‐ノート:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>ファイル‐ノート:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>MediaWiki‐ノート:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>Template‐ノート:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>Help‐ノート:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>Category‐ノート:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>Portal‐ノート:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>

	<title>プロジェクト‐ノート:A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve"></text>
</xml>
STR
			my $fname = WriteTestXMLFile( $str );
			my $data = new JAWP::DataFile( $fname );
			my $titlelist = $data->GetTitleList;

			ok( defined( $titlelist ), 'JAWP::DataFile::GetTitleList(標準XMLファイル)' );
			ok( defined( $titlelist->{'標準'} ), 'JAWP::DataFile::GetTitleList(標準XMLファイル,標準)' );
			is( keys %{$titlelist->{'標準'}}, 2, 'JAWP::DataFile::GetTitleList(標準XMLファイル,標準,記事数)' );
			ok( defined( $titlelist->{'標準'}->{'標準A'} ), 'JAWP::DataFile::GetTitleList(標準XMLファイル,標準,標準A)' );
			ok( defined( $titlelist->{'標準'}->{'標準 曖昧A'} ), 'JAWP::DataFile::GetTitleList(標準XMLファイル,標準_曖昧,標準 曖昧A)' );
			foreach my $namespace ( '標準_リダイレクト', '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート' ) {
				ok( defined( $titlelist->{$namespace} ), "JAWP::DataFile::GetTitleList(標準XMLファイル,$namespace)" );
				is( keys %{$titlelist->{$namespace}}, 1, "JAWP::DataFile::GetTitleList(標準XMLファイル,$namespace,記事数)" );
				ok( defined( $titlelist->{$namespace}->{'A'} ), "JAWP::DataFile::GetTitleList(標準XMLファイル,$namespace,A)" );
			}

			unlink( $fname ) or die $!;
		}
	}
}


################################################################################
# JAWP::ReportFileクラス
################################################################################

sub TestJAWPReport {
	# メソッド呼び出しテスト
	{
		foreach my $method ( 'new', 'OutputWiki', 'OutputWikiList', 'OutputDirect' ) {
			ok( JAWP::ReportFile->can($method), "JAWP::ReportFile(メソッド呼び出し,$method)" );
		}
	}

	# 空new失敗確認テスト
	{
		my $report = new JAWP::ReportFile;

		ok( !defined( $report ), 'JAWP::ReportFile(空new)' );
	}

	# メンバー変数確認
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );

			ok( defined( $report ), 'JAWP::ReportFile(ファイル名指定)' );
			cmp_ok( keys( %$report ),  '==', 2, 'JAWP::ReportFile(メンバ変数個数)' );

			ok( defined( $report->{'filename'} ), 'JAWP::ReportFile(メンバ変数宣言,filename)' );
			is( $report->{'filename'}, $fname, 'JAWP::ReportFile(メンバ変数値,filename)' );

			ok( defined( $report->{'fh'} ), 'JAWP::ReportFile(メンバ変数宣言,fh)' );
			is( ref $report->{'fh'}, 'GLOB', 'JAWP::ReportFile(メンバ変数リファレンス種別,fh)' );
		}
		unlink( $fname ) or die $!;
	}

	# OutputWikiテスト(空テキスト)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );
			my @datalist;

			$report->OutputWiki( 'title', \( '' ) );
		}
		{
			my $str = <<'STR';
== title ==


STR
			is( ReadReportFile( $fname ), $str, 'JAWP::ReportFile::OutputWiki(空テキスト)' );
		}
		unlink( $fname ) or die $!;
	}

	# OutputWikiテスト(テキスト)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );
			my @datalist;

			$report->OutputWiki( 'title', \( "text1\ntext2" ) );
		}
		{
			my $str = <<'STR';
== title ==
text1
text2

STR
			is( ReadReportFile( $fname ), $str, 'JAWP::ReportFile::OutputWiki(テキスト)' );
		}
		unlink( $fname ) or die $!;
	}

	# OutputWikiテスト(テキスト複数回)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );
			my @datalist;

			$report->OutputWiki( 'title1', \( "text1\ntext2" ) );
			$report->OutputWiki( 'title2', \( "text3\ntext4" ) );
		}
		{
			my $str = <<'STR';
== title1 ==
text1
text2

== title2 ==
text3
text4

STR
			is( ReadReportFile( $fname ), $str, 'JAWP::ReportFile::OutputWiki(テキスト複数回)' );
		}
		unlink( $fname ) or die $!;
	}

	# OutputWikiListテスト(空配列データ)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );
			my @datalist;

			$report->OutputWikiList( 'title', \@datalist );
		}
		{
			my $str = <<'STR';
== title ==

STR
			is( ReadReportFile( $fname ), $str, 'JAWP::ReportFile::OutputWikiList(空配列データ)' );
		}
		unlink( $fname ) or die $!;
	}

	# OutputWikiListテスト(配列データ)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );
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
			is( ReadReportFile( $fname ), $str, 'JAWP::ReportFile::OutputWikiList(配列データ)' );
		}
		unlink( $fname ) or die $!;
	}

	# OutputWikiListテスト(配列データ複数回)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );
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
			is( ReadReportFile( $fname ), $str, 'JAWP::ReportFile::OutputWikiList(配列データ複数回)' );
		}
		unlink( $fname ) or die $!;
	}

	# OutputDirectテスト(空データ)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );

			$report->OutputDirect( '' );
		}
		{
			is( ReadReportFile( $fname ), '', 'JAWP::ReportFile::OutputDirect(空データ)' );
		}
		unlink( $fname ) or die $!;
	}

	# OutputDirectテスト(文字列)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );

			$report->OutputDirect( '隣の客はよく柿食う客だ' );
		}
		{
			is( ReadReportFile( $fname ), '隣の客はよく柿食う客だ', 'JAWP::ReportFile::OutputDirect(文字列)' );
		}
		unlink( $fname ) or die $!;
	}

	# OutputDirectテスト(文字列複数回)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );

			$report->OutputDirect( "赤巻紙青巻紙黄巻紙\n" );
			$report->OutputDirect( "坊主が屏風に上手に坊主の絵を書いた\n" );
		}
		{
			my $str = <<'STR';
赤巻紙青巻紙黄巻紙
坊主が屏風に上手に坊主の絵を書いた
STR
			is( ReadReportFile( $fname ), $str, 'JAWP::ReportFile::OutputDirect(文字列複数回)' );
		}
		unlink( $fname ) or die $!;
	}
}


################################################################################
# JAWP::Utilクラス
################################################################################

sub TestJAWPUtil {
	# メソッド呼び出しテスト
	{
		foreach my $method ( 'UnescapeHTML', 'DecodeURL', 'SortHash',
			'GetLinkwordList', 'GetTemplatewordList', 'GetExternallinkList',
			'GetHost', 'GetLinkType', 'GetHeadnameList', 'GetTalkTimestampList' ) {
			ok( JAWP::Util->can($method), "JAWP::Util(メソッド呼び出し,$method)" );
		}
	}

	# UnescapeHTMLテスト
	{
		is( JAWP::Util::UnescapeHTML( 'abcdef') , 'abcdef', 'JAWP::Util::UnescapeHTML(無変換,abcdef)' );
		is( JAWP::Util::UnescapeHTML( '&amp') , '&amp', 'JAWP::Util::UnescapeHTML(無変換,&amp)' );
		is( JAWP::Util::UnescapeHTML( '&quot;&amp;&lt;&gt;' ), '"&<>', 'JAWP::Util::UnescapeHTML(文字実体参照,マークアップ記号)' );
		is( JAWP::Util::UnescapeHTML( '&nbsp; &iexcl; &cent; &pound; &curren; &yen; &brvbar; &sect; &uml; &copy; &ordf; &laquo; &not; &shy; &reg; &macr; &deg; &plusmn; &sup2; &sup3; &acute; &micro; &para; &middot; &cedil; &sup1; &ordm; &raquo; &frac14; &frac12; &frac34; &iquest; &Agrave; &Aacute; &Acirc; &Atilde; &Auml; &Aring; &AElig; &Ccedil; &Egrave; &Eacute; &Ecirc; &Euml; &Igrave; &Iacute; &Icirc; &Iuml; &ETH; &Ntilde; &Ograve; &Oacute; &Ocirc; &Otilde; &Ouml; &times; &Oslash; &Ugrave; &Uacute; &Ucirc; &Uuml; &Yacute; &THORN; &szlig; &agrave; &aacute; &acirc; &atilde; &auml; &aring; &aelig; &ccedil; &egrave; &eacute; &ecirc; &euml; &igrave; &iacute; &icirc; &iuml; &eth; &ntilde; &ograve; &oacute; &ocirc; &otilde; &ouml; &divide; &oslash; &ugrave; &uacute; &ucirc; &uuml; &yacute; &thorn; &yuml;' ), '  ¡ ￠ ￡ ¤ \ ￤ § ¨ © ª « ￢ ­ ® ¯ ° ± ² ³ ´ µ ¶ · ¸ ¹ º » ¼ ½ ¾ ¿ À Á Â Ã Ä Å Æ Ç È É Ê Ë Ì Í Î Ï Ð Ñ Ò Ó Ô Õ Ö × Ø Ù Ú Û Ü Ý Þ ß à á â ã ä å æ ç è é ê ë ì í î ï ð ñ ò ó ô õ ö ÷ ø ù ú û ü ý þ ÿ', 'JAWP::Util::UnescapeHTML(文字実体参照,ISO-8859-1 ラテン)' );
		is( JAWP::Util::UnescapeHTML( '&OElig; &oelig; &Scaron; &scaron; &Yuml; &circ; &tilde; &fnof;' ), 'Œ œ Š š Ÿ ˆ ˜ ƒ', 'JAWP::Util::UnescapeHTML,文字実体参照(ラテン拡張)' );
		is( JAWP::Util::UnescapeHTML( '&Alpha; &Beta; &Gamma; &Delta; &Epsilon; &Zeta; &Eta; &Theta; &Iota; &Kappa; &Lambda; &Mu; &Nu; &Xi; &Omicron; &Pi; &Rho; &Sigma; &Tau; &Upsilon; &Phi; &Chi; &Psi; &Omega; &alpha; &beta; &gamma; &delta; &epsilon; &zeta; &eta; &theta; &iota; &kappa; &lambda; &mu; &nu; &xi; &omicron; &pi; &rho; &sigmaf; &sigma; &tau; &upsilon; &phi; &chi; &psi; &omega; &thetasym; &upsih; &piv;' ), 'Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο Π Ρ Σ Τ Υ Φ Χ Ψ Ω α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ ς σ τ υ φ χ ψ ω ϑ ϒ ϖ', 'JAWP::Util::UnescapeHTML(文字実体参照,ギリシア文字)' );
		is( JAWP::Util::UnescapeHTML( '&ensp; &emsp; &thinsp; &zwnj; &zwj; &lrm; &rlm; &ndash; &mdash; &lsquo; &rsquo; &sbquo; &ldquo; &rdquo; &bdquo; &dagger; &Dagger; &bull; &hellip; &permil; &prime; &Prime; &lsaquo; &rsaquo; &oline; &frasl; &euro; &image; &ewierp; &real; &trade; &alefsym; &larr; &uarr; &rarr; &darr; &harr; &crarr; &lArr; &uArr; &rArr; &dArr; &hArr;' ), '      ‌ ‍ ‎ ‏ – ― ‘ ’ ‚ “ ” „ † ‡ • … ‰ ′ ″ ‹ › ~ ⁄ € ℑ ℘ ℜ ™ ℵ ← ↑ → ↓ ↔ ↵ ⇐ ⇑ ⇒ ⇓ ⇔', 'JAWP::Util::UnescapeHTML(文字実体参照,一般記号と国際化用の制御文字)' );
		is( JAWP::Util::UnescapeHTML( '&forall; &part; &exist; &empty; &nabla; &isin; &notin; &ni; &prod; &sum; &minus; &lowast; &radic; &prop; &infin; &ang; &and; &or; &cap; &cup; &int; &there4; &sim; &cong; &asymp; &ne; &equiv; &le; &ge; &sub; &sup; &nsub; &sube; &supe; &oplus; &otimes; &perp; &sdot;' ), '∀ ∂ ∃ ∅ ∇ ∈ ∉ ∋ ∏ ∑ － ∗ √ ∝ ∞ ∠ ∧ ∨ ∩ ∪ ∫ ∴ ∼ ≅ ≈ ≠ ≡ ≤ ≥ ⊂ ⊃ ⊄ ⊆ ⊇ ⊕ ⊗ ⊥ ⋅', 'JAWP::Util::UnescapeHTML(文字実体参照,数学記号)' );
		is( JAWP::Util::UnescapeHTML( '&lceil; &rceil; &lfloor; &rfloor; &lang; &rang; &loz; &spades; &clubs; &hearts; &diams;' ), '⌈ ⌉ ⌊ ⌋ 〈 〉 ◊ ♠ ♣ ♥ ♦', 'JAWP::Util::UnescapeHTML(文字実体参照,シンボル)' );
		is( JAWP::Util::UnescapeHTML( '&#34;&#38;&#60;&#62;' ), '"&<>', 'JAWP::Util::UnescapeHTML(数値文字参照)' );
		is( JAWP::Util::UnescapeHTML( '&amp;lt;' ), '<', 'JAWP::Util::UnescapeHTML(二重エスケープ)' );
	}

	# DecodeURLテスト
	{
		is( JAWP::Util::DecodeURL( 'abcdef') , 'abcdef', 'JAWP::Util::DecodeURL(abcdef)' );
		is( JAWP::Util::DecodeURL( '%E7%89%B9%E5%88%A5:') , '特別:', 'JAWP::Util::DecodeURL(%E7%89%B9%E5%88%A5:)' );
	}

	# SortHashテスト
	{
		my %hash = ( 'a'=>2, 'b'=>1, 'c'=>3 );
		my $sorted = JAWP::Util::SortHash( \%hash );
		is( ref $sorted, 'ARRAY', 'JAWP::Util::SortHash(リファレンス種別)' );
		is( @$sorted + 0, 3, 'JAWP::Util::SortHash(配列要素数)' );
		is( $sorted->[0], 'c', 'JAWP::Util::SortHash(配列要素1)' );
		is( $sorted->[1], 'a', 'JAWP::Util::SortHash(配列要素2)' );
		is( $sorted->[2], 'b', 'JAWP::Util::SortHash(配列要素3)' );
	}

	# SortHashByStrテスト
	{
		my %hash = ( 'a'=>'い', 'b'=>'あ', 'c'=>'う' );
		my $sorted = JAWP::Util::SortHashByStr( \%hash );
		is( ref $sorted, 'ARRAY', 'JAWP::Util::SortHashByStr(リファレンス種別)' );
		is( @$sorted + 0, 3, 'JAWP::Util::SortHashByStr(配列要素数)' );
		is( $sorted->[0], 'b', 'JAWP::Util::SortHashByStr(配列要素1)' );
		is( $sorted->[1], 'a', 'JAWP::Util::SortHashByStr(配列要素2)' );
		is( $sorted->[2], 'c', 'JAWP::Util::SortHashByStr(配列要素3)' );
	}

	# GetLinkwordListテスト
	{
		my @result;

		foreach my $str ( '', 'あああ', '[あああ]', '[[あああ', '[[]]', '[[#abc]]' ) {
			@result = JAWP::Util::GetLinkwordList( $str );
			is( @result + 0 , 0, "JAWP::Util::GetLinkwordList($str,リンクワード数)" );
		}

		@result = JAWP::Util::GetLinkwordList( '[[あああ]]' );
		is( @result + 0 , 1, 'JAWP::Util::GetLinkwordList([[あああ]],リンクワード数)' );
		is( $result[0] , 'あああ', 'JAWP::Util::GetLinkwordList([[あああ]],リンクワード)' );

		@result = JAWP::Util::GetLinkwordList( 'あああ[[いいい]]ううう' );
		is( @result + 0 , 1, 'JAWP::Util::GetLinkwordList(あああ[[いいい]]ううう,リンクワード数)' );
		is( $result[0] , 'いいい', 'JAWP::Util::GetLinkwordList(あああ[[いいい]]ううう,リンクワード)' );

		@result = JAWP::Util::GetLinkwordList( '[[あああ|いいい]]' );
		is( @result + 0 , 1, 'JAWP::Util::GetLinkwordList([[あああ|いいい]],リンクワード数)' );
		is( $result[0] , 'あああ', 'JAWP::Util::GetLinkwordList([[あああ|いいい]],リンクワード)' );

		@result = JAWP::Util::GetLinkwordList( '[[あああ]]いいい[[ううう]]' );
		is( @result + 0 , 2, 'JAWP::Util::GetLinkwordList([[あああ]]いいい[[ううう]],リンクワード数)' );
		is( $result[0] , 'あああ', 'JAWP::Util::GetLinkwordList([[あああ]]いいい[[ううう]],リンクワード1' );
		is( $result[1] , 'ううう', 'JAWP::Util::GetLinkwordList([[あああ]]いいい[[ううう]],リンクワード2' );

		@result = JAWP::Util::GetLinkwordList( "[[あああ]]\nいいい\n[[ううう]]\n" );
		is( @result + 0 , 2, 'JAWP::Util::GetLinkwordList([[あああ]]\nいいい\n[[ううう]]\n,リンクワード数)' );
		is( $result[0] , 'あああ', 'JAWP::Util::GetLinkwordList([[あああ]]\nいいい\n[[ううう]]\n,リンクワード1)' );
		is( $result[1] , 'ううう', 'JAWP::Util::GetLinkwordList([[あああ]]\nいいい\n[[ううう]]\n,リンクワード2)' );
	}

	# GetTemplatewordListテスト
	{
		my @result;

		foreach my $str ( '', 'あああ', '{あああ}', '{{あああ', '{{デフォルトソート:あああ}}', '{{DEFAULTSORT:あああ}}', '{{}}' ) {
			@result = JAWP::Util::GetTemplatewordList( $str );
			is( @result + 0 , 0, "JAWP::Util::GetTemplatewordList($str:テンプレートワード数)" );
		}

		@result = JAWP::Util::GetTemplatewordList( '{{あああ}}' );
		is( @result + 0 , 1, 'JAWP::Util::GetTemplatewordList({{あああ}}:テンプレートワード数)' );
		is( $result[0] , 'あああ', 'JAWP::Util::GetTemplatewordList({{あああ}}:テンプレートワード)' );

		@result = JAWP::Util::GetTemplatewordList( 'あああ{{いいい}}ううう' );
		is( @result + 0 , 1, 'JAWP::Util::GetTemplatewordList(あああ{{いいい}}ううう:テンプレートワード数)' );
		is( $result[0] , 'いいい', 'JAWP::Util::GetTemplatewordList(あああ{{いいい}}ううう:テンプレートワード)' );

		@result = JAWP::Util::GetTemplatewordList( '{{あああ|いいい}}' );
		is( @result + 0 , 1, 'JAWP::Util::GetTemplatewordList({{あああ|いいい}}:テンプレートワード数)' );
		is( $result[0] , 'あああ', 'JAWP::Util::GetTemplatewordList({{あああ|いいい}}:テンプレートワード)' );

		@result = JAWP::Util::GetTemplatewordList( '{{あああ}}いいい{{ううう}}' );
		is( @result + 0 , 2, 'JAWP::Util::GetTemplatewordList({{あああ}}いいい{{ううう}}:テンプレートワード数)' );
		is( $result[0] , 'あああ', 'JAWP::Util::GetTemplatewordList({{あああ}}いいい{{ううう}}:テンプレートワード1)' );
		is( $result[1] , 'ううう', 'JAWP::Util::GetTemplatewordList({{あああ}}いいい{{ううう}}:テンプレートワード2)' );

		@result = JAWP::Util::GetTemplatewordList( "{{あああ}}\nいいい\n{{ううう}}\n" );
		is( @result + 0 , 2, 'JAWP::Util::GetTemplatewordList({{あああ}}\nいいい\n{{ううう}}\n:テンプレートワード数)' );
		is( $result[0] , 'あああ', 'JAWP::Util::GetTemplatewordList({{あああ}}\nいいい\n{{ううう}}\n:テンプレートワード1)' );
		is( $result[1] , 'ううう', 'JAWP::Util::GetTemplatewordList({{あああ}}\nいいい\n{{ううう}}\n:テンプレートワード2)' );
	}

	# GetExternallinkListテスト
	{
		my @result;

		@result = JAWP::Util::GetExternallinkList( '' );
		is( @result + 0 , 0, 'JAWP::Util::GetExternallinkList(空文字列,URL数)' );

		@result = JAWP::Util::GetExternallinkList( 'あああ' );
		is( @result + 0 , 0, 'JAWP::Util::GetExternallinkList(あああ,URL数)' );

		@result = JAWP::Util::GetExternallinkList( 'あああ http://www.yahoo.co.jp いいい' );
		is( @result + 0 , 1, 'JAWP::Util::GetExternallinkList(あああ http://www.yahoo.co.jp いいい,URL数)' );
		is( $result[0], 'http://www.yahoo.co.jp', 'JAWP::Util::GetExternallinkList(あああ http://www.yahoo.co.jp いいい,URL)' );

		@result = JAWP::Util::GetExternallinkList( 'あああ http://www.yahoo.co.jp/aaa/bbb http://www.google.co.jp/ccc/ddd いいい' );
		is( @result + 0 , 2, 'JAWP::Util::GetExternallinkList(あああ http://www.yahoo.co.jp/aaa/bbb http://www.google.co.jp/ccc/ddd いいい,URL数)' );
		is( $result[0], 'http://www.yahoo.co.jp/aaa/bbb', 'JAWP::Util::GetExternallinkList(あああ http://www.yahoo.co.jp/aaa/bbb http://www.google.co.jp/ccc/ddd いいい,URL1)' );
		is( $result[1], 'http://www.google.co.jp/ccc/ddd', 'JAWP::Util::GetExternallinkList(あああ http://www.yahoo.co.jp/aaa/bbb http://www.google.co.jp/ccc/ddd いいい,URL2)' );
	}

	# GetHostテスト
	{
		my $host;

		foreach my $url ( 'http://www.yahoo.co.jp', 'http://www.yahoo.co.jp/', 'http://www.yahoo.co.jp/aaa/bbb', 'https://www.yahoo.co.jp', 'https://www.yahoo.co.jp/', 'https://www.yahoo.co.jp/aaa/bbb' ) {
			$host = JAWP::Util::GetHost( $url );
			is( $host, 'www.yahoo.co.jp', "JAWP::Util::GetHost($url)" );
		}
	}

	# GetLinkTypeテスト
	{
		my( $linktype, $word );
		my $titlelist = new JAWP::TitleList;

		$titlelist->{'標準'} = { '標準記事'=>1, '曖昧記事'=>1 };
		$titlelist->{'標準_曖昧'} = { '曖昧記事'=>1 };
		$titlelist->{'標準_リダイレクト'} = { 'リダイレクト記事'=>1 };
		$titlelist->{'ファイル'} = { 'ファイル名'=>1 };
		$titlelist->{'Template'} = { 'テンプレート名'=>1 };
		$titlelist->{'Category'} = { 'カテゴリ名'=>1 };

		( $linktype, $word ) = JAWP::Util::GetLinkType( '', $titlelist );
		is( $linktype , 'redlink', 'JAWP::Util::GetLinkType(空文字列:linktype)' );
		is( $word, '', 'JAWP::Util::GetLinkType(空文字列:word)' );

		( $linktype, $word ) = JAWP::Util::GetLinkType( '標準記事', $titlelist );
		is( $linktype , '標準', 'JAWP::Util::GetLinkType(標準記事:linktype)' );
		is( $word, '標準記事', 'JAWP::Util::GetLinkType(標準記事:word)' );

		( $linktype, $word ) = JAWP::Util::GetLinkType( '曖昧記事', $titlelist );
		is( $linktype , 'aimai', 'JAWP::Util::GetLinkType(曖昧記事:linktype)' );
		is( $word, '曖昧記事', 'JAWP::Util::GetLinkType(曖昧記事:word)' );

		( $linktype, $word ) = JAWP::Util::GetLinkType( 'リダイレクト記事', $titlelist );
		is( $linktype , 'redirect', 'JAWP::Util::GetLinkType(リダイレクト記事:linktype)' );
		is( $word, 'リダイレクト記事', 'JAWP::Util::GetLinkType(リダイレクト記事:word)' );

		foreach my $type ( 'Category', 'カテゴリ' ) {
			( $linktype, $word ) = JAWP::Util::GetLinkType( "$type:カテゴリ名", $titlelist );
			is( $linktype , 'category', "JAWP::Util::GetLinkType(カテゴリ名,$type:linktype)" );
			is( $word, 'カテゴリ名', "JAWP::Util::GetLinkType(カテゴリ名,$type:word)" );
		}

		foreach my $type ( 'ファイル', '画像', 'メディア', 'file', 'image', 'media' ) {
			( $linktype, $word ) = JAWP::Util::GetLinkType( "$type:ファイル名", $titlelist );
			is( $linktype , 'file', "JAWP::Util::GetLinkType(ファイル名,$type:linktype)" );
			is( $word, 'ファイル名', "JAWP::Util::GetLinkType(ファイル名,$type:word)" );
		}

		foreach my $type ( 'Template', 'テンプレート' ) {
			( $linktype, $word ) = JAWP::Util::GetLinkType( "$type:テンプレート名", $titlelist );
			is( $linktype , 'template', "JAWP::Util::GetLinkType(テンプレート名,$type:linktype)" );
			is( $word, 'テンプレート名', "JAWP::Util::GetLinkType(テンプレート名,$type:word)" );
		}

		( $linktype, $word ) = JAWP::Util::GetLinkType( '赤リンク記事', $titlelist );
		is( $linktype , 'redlink', 'JAWP::Util::GetLinkType(赤リンク記事:linktype)' );
		is( $word, '赤リンク記事', 'JAWP::Util::GetLinkType(赤リンク記事:word)' );

		foreach my $type (
			'Help', 'ヘルプ', 'MediaWiki', 'Portal', 'Wikipedia', 'プロジェクト', 'Project',
			'Special', '特別', '利用者', 'User', 'ノート', 'トーク', 'talk', '利用者‐会話', '利用者・トーク', 'User talk', 'Wikipedia‐ノート', 'Wikipedia・トーク', 'Wikipedia talk', 'ファイル‐ノート', 'ファイル・トーク', '画像‐ノート', 'File talk', 'Image Talk', 'MediaWiki‐ノート', 'MediaWiki・トーク', 'MediaWiki talk', 'Template‐ノート', 'Template talk', 'Help‐ノート', 'Help talk', 'Category‐ノート', 'Category talk', 'カテゴリ・トーク', 'Portal‐ノート', 'Portal・トーク', 'Portal talk', 'プロジェクト‐ノート', 'Project talk',
			'aa', 'aar', 'ab', 'abk', 'ace', 'ach', 'ada', 'ady', 'ae', 'af', 'afa', 'afh', 'afr', 'ain', 'ak', 'aka', 'akk', 'alb', 'ale', 'alg', 'als', 'alt', 'am', 'amh', 'an', 'ang', 'apa', 'ar', 'ara', 'arc', 'arg', 'arm', 'arn', 'arp', 'art', 'arw', 'arz', 'as', 'asm', 'ast', 'ath', 'aus', 'av', 'ava', 'ave', 'awa', 'ay', 'aym', 'az', 'aze', 'ba', 'bad', 'bai', 'bak', 'bal', 'bam', 'ban', 'baq', 'bar', 'bas', 'bat', 'bat-smg', 'bcl', 'be', 'be-x-old', 'bej', 'bel', 'bem', 'ben', 'ber', 'bg', 'bh', 'bho', 'bi', 'bih', 'bik', 'bin', 'bis', 'bjn', 'bla', 'bm', 'bn', 'bnt', 'bo', 'bod', 'bos', 'bpy', 'br', 'bra', 'bre', 'bs', 'bua', 'bug', 'bul', 'bur', 'bxr', 'byn', 'ca', 'cad', 'cai', 'car', 'cat', 'cau', 'cbk-zam', 'cdo', 'ce', 'ceb', 'cel', 'ces', 'ch', 'cha', 'chb', 'che', 'chg', 'chi', 'chm', 'chn', 'cho', 'chr', 'chu', 'chv', 'chy', 'ckb', 'co', 'cop', 'cor', 'cos', 'cpe', 'cpf', 'cpp', 'cr', 'cre', 'crh', 'crp', 'cs', 'csb', 'cu', 'cus', 'cv', 'cy', 'cym', 'cze', 'da', 'dak', 'dan', 'dar', 'day', 'de', 'del', 'deu', 'dgr', 'din', 'diq', 'div', 'doi', 'dra', 'dsb', 'dua', 'dum', 'dut', 'dv', 'dyu', 'dz', 'dzo', 'ee', 'efi', 'egy', 'eka', 'el', 'ell', 'elx', 'eml', 'en', 'eng', 'enm', 'eo', 'epo', 'es', 'esk', 'est', 'et', 'eu', 'eus', 'ewe', 'ewo', 'ext', 'fa', 'fan', 'fao', 'fas', 'fat', 'ff', 'fi', 'fij', 'fin', 'fiu', 'fiu-vro', 'fj', 'fo', 'fon', 'fr', 'fra', 'fre', 'frm', 'fro', 'frp', 'frr', 'frs', 'fry', 'ful', 'fur', 'fy', 'ga', 'gaa', 'gag', 'gan', 'gay', 'gd', 'gem', 'geo', 'ger', 'gez', 'gil', 'gl', 'gla', 'gle', 'glg', 'glk', 'glv', 'gmh', 'gn', 'goh', 'gon', 'gor', 'got', 'grb', 'grc', 'gre', 'grn', 'gu', 'guj', 'gv', 'ha', 'hai', 'hak', 'hat', 'hau', 'haw', 'he', 'heb', 'her', 'hi', 'hif', 'hil', 'him', 'hin', 'hit', 'hmn', 'hmo', 'ho', 'hr', 'hrv', 'hsb', 'ht', 'hu', 'hun', 'hup', 'hy', 'hye', 'hz', 'ia', 'iba', 'ibo', 'ice', 'id', 'ido', 'ie', 'ig', 'ii', 'iii', 'ijo', 'ik', 'iku', 'ile', 'ilo', 'ina', 'inc', 'ind', 'ine', 'inh', 'io', 'ipk', 'ira', 'iro', 'is', 'isl', 'it', 'ita', 'iu', 'ja', 'jav', 'jbo', 'jpn', 'jpr', 'jrb', 'jv', 'ka', 'kaa', 'kab', 'kac', 'kal', 'kam', 'kan', 'kar', 'kas', 'kat', 'kau', 'kaw', 'kaz', 'kbd', 'kg', 'kha', 'khi', 'khm', 'kho', 'ki', 'kik', 'kin', 'kir', 'kj', 'kk', 'kl', 'km', 'kmb', 'kn', 'ko', 'koi', 'kok', 'kom', 'kon', 'kor', 'kos', 'kpe', 'kr', 'krc', 'kro', 'kru', 'ks', 'ksh', 'ku', 'kua', 'kum', 'kur', 'kut', 'kv', 'kw', 'ky', 'la', 'lad', 'lah', 'lam', 'lao', 'lat', 'lav', 'lb', 'lbe', 'lez', 'lg', 'li', 'lij', 'lim', 'lin', 'lit', 'lmo', 'ln', 'lo', 'lol', 'loz', 'lt', 'ltg', 'ltz', 'lu', 'lub', 'lug', 'lui', 'lun', 'luo', 'lv', 'mac', 'mad', 'mag', 'mah', 'mai', 'mak', 'mal', 'man', 'mao', 'map', 'map-bms', 'mar', 'mas', 'may', 'mdf', 'men', 'mg', 'mga', 'mh', 'mhr', 'mi', 'mic', 'min', 'mis', 'mk', 'mkd', 'mkh', 'ml', 'mlg', 'mlt', 'mn', 'mnc', 'mni', 'mno', 'mo', 'moh', 'mol', 'mon', 'mos', 'mr', 'mri', 'mrj', 'ms', 'msa', 'mt', 'mul', 'mun', 'mus', 'mwl', 'mwr', 'my', 'mya', 'myn', 'myv', 'mzn', 'na', 'nah', 'nai', 'nap', 'nau', 'nav', 'nb', 'nbl', 'nd', 'nde', 'ndo', 'nds', 'nds-nl', 'ne', 'nep', 'new', 'ng', 'nic', 'niu', 'nl', 'nld', 'nn', 'nno', 'no', 'nob', 'nog', 'non', 'nor', 'nov', 'nr', 'nrm', 'nso', 'nub', 'nv', 'nwc', 'ny', 'nya', 'nym', 'nyn', 'nyo', 'nzi', 'oc', 'oci', 'oj', 'oji', 'ojp', 'om', 'or', 'ori', 'orm', 'os', 'osa', 'oss', 'ota', 'oto', 'pa', 'paa', 'pag', 'pal', 'pam', 'pan', 'pap', 'pau', 'pcd', 'pdc', 'peo', 'per', 'pfl', 'phn', 'pi', 'pih', 'pl', 'pli', 'pms', 'pnb', 'pnt', 'pol', 'pon', 'por', 'pra', 'pro', 'ps', 'pt', 'pus', 'qu', 'que', 'raj', 'rap', 'rar', 'rm', 'rmy', 'rn', 'ro', 'roa', 'roa-rup', 'roa-tara', 'roh', 'rom', 'ron', 'ru', 'rue', 'rum', 'run', 'rus', 'rw', 'sa', 'sad', 'sag', 'sah', 'sai', 'sal', 'sam', 'san', 'sc', 'scc', 'scn', 'sco', 'scr', 'sd', 'se', 'sel', 'sem', 'sg', 'sga', 'sgn', 'sh', 'shn', 'si', 'sid', 'simple', 'sin', 'sio', 'sit', 'sk', 'sl', 'sla', 'slk', 'slo', 'slv', 'sm', 'sma', 'sme', 'smi', 'smj', 'smn', 'smo', 'sms', 'sn', 'sna', 'snd', 'so', 'sog', 'som', 'son', 'sot', 'spa', 'sq', 'sqi', 'sr', 'srd', 'srn', 'srp', 'srr', 'ss', 'ssa', 'ssw', 'st', 'stq', 'su', 'suk', 'sun', 'sus', 'sux', 'sv', 'sw', 'swa', 'swe', 'syr', 'szl', 'ta', 'tah', 'tai', 'tam', 'tat', 'te', 'tel', 'tem', 'ter', 'tet', 'tg', 'tgk', 'tgl', 'th', 'tha', 'ti', 'tib', 'tig', 'tir', 'tiv', 'tju', 'tk', 'tkl', 'tl', 'tlh', 'tli', 'tmh', 'tn', 'to', 'tog', 'ton', 'tpi', 'tr', 'tru', 'ts', 'tsi', 'tsn', 'tso', 'tt', 'tuk', 'tum', 'tup', 'tur', 'tut', 'tw', 'twi', 'ty', 'tyv', 'udm', 'ug', 'uga', 'uig', 'uk', 'ukr', 'umb', 'und', 'ur', 'urd', 'uz', 'uzb', 'vai', 've', 'vec', 'ven', 'vi', 'vie', 'vls', 'vo', 'vol', 'vot', 'wa', 'wak', 'wal', 'war', 'was', 'wel', 'wen', 'wln', 'wo', 'wol', 'wuu', 'xal', 'xh', 'xho', 'yao', 'yap', 'yi', 'yid', 'yo', 'yor', 'za', 'zap', 'zea', 'zen', 'zh', 'zh-classical', 'zh-cn', 'zh-min-nan', 'nan', 'zh-tw', 'zh-yue', 'zha', 'zho', 'zu', 'zul', 'zun',
			'wikipedia', 'w', 'wiktionary', 'wikt', 'wikinews', 'n', 'wikibooks', 'b', 'wikiquote', 'q', 'wikisource', 's', 'wikispecies', 'species', 'v', 'wikimedia', 'foundation', 'wmf', 'commons', 'meta', 'm', 'incubator', 'mw', 'bugzilla', 'mediazilla', 'translatewiki', 'betawiki', 'tools',
			'Rev', 'Sulutil', 'Testwiki', 'CentralWikia', 'Choralwiki', 'google', 'irc', 'Mail', 'Mailarchive', 'MarvelDatabase', 'MeatBall', 'MemoryAlpha', 'MozillaWiki', 'Uncyclopedia', 'Wikia', 'Wikitravel', 'IMDbTitle' ) {
			( $linktype, $word ) = JAWP::Util::GetLinkType( "$type:記事名", $titlelist );
			is( $linktype , 'none', "JAWP::Util::GetLinkType(記事名,$type:linktype)" );
			is( $word, "$type:記事名", "JAWP::Util::GetLinkType(記事名,$type:word)" );
		}

		( $linktype, $word ) = JAWP::Util::GetLinkType( 'http://記事名', $titlelist );
		is( $linktype , 'none', "JAWP::Util::GetLinkType('http://記事名':linktype)" );
		is( $word, 'http://記事名', "JAWP::Util::GetLinkType('http://記事名':word)" );

		( $linktype, $word ) = JAWP::Util::GetLinkType( '/', $titlelist );
		is( $linktype , 'none', "JAWP::Util::GetLinkType('/':linktype)" );
		is( $word, '/', "JAWP::Util::GetLinkType('/':word)" );

		( $linktype, $word ) = JAWP::Util::GetLinkType( '../', $titlelist );
		is( $linktype , 'none', "JAWP::Util::GetLinkType('../':linktype)" );
		is( $word, '../', "JAWP::Util::GetLinkType('../':word)" );

		( $linktype, $word ) = JAWP::Util::GetLinkType( '#name', $titlelist );
		is( $linktype , 'none', "JAWP::Util::GetLinkType('#name':linktype)" );
		is( $word, '#name', "JAWP::Util::GetLinkType('#name':word)" );

		( $linktype, $word ) = JAWP::Util::GetLinkType( ':es:test', $titlelist );
		is( $linktype , 'none', "JAWP::Util::GetLinkType(':es:test':linktype)" );
		is( $word, ':es:test', "JAWP::Util::GetLinkType(':es:test':word)" );
	}

	# GetHeadnameListテスト
	{
		my @result;

		@result = JAWP::Util::GetHeadnameList( '' );
		is( @result + 0 , 0, 'JAWP::Util::GetHeadnameList(空文字列:見出し数)' );

		@result = JAWP::Util::GetHeadnameList( 'あああ' );
		is( @result + 0 , 0, 'JAWP::Util::GetHeadnameList(あああ:見出し数)' );

		@result = JAWP::Util::GetHeadnameList( '= =' );
		is( @result + 0 , 0, 'JAWP::Util::GetHeadnameList(= =:見出し数)' );

		@result = JAWP::Util::GetHeadnameList( "あああ\n==見出し==\nいいい" );
		is( @result + 0 , 1, 'JAWP::Util::GetHeadnameList(あああ\n==見出し==\nいいい:見出し数)' );
		is( $result[0], '見出し', 'JAWP::Util::GetHeadnameList(あああ\n==見出し==\nいいい:見出し)' );

		@result = JAWP::Util::GetHeadnameList( "あああ\n==見出し==\n== 見出し2 ==\nいいい" );
		is( @result + 0 , 2, 'JAWP::Util::GetHeadnameList(あああ\n==見出し==\n== 見出し2 ==\nいいい:見出し数)' );
		is( $result[0], '見出し', 'JAWP::Util::GetHeadnameList(あああ\n==見出し==\n== 見出し2 ==\nいいい:見出し1)' );
		is( $result[1], '見出し2', 'JAWP::Util::GetHeadnameList(あああ\n==見出し==\n== 見出し2 ==\nいいい:見出し2)' );

		@result = JAWP::Util::GetHeadnameList( "あああ\n==見 出 し==\nいいい" );
		is( @result + 0 , 1, 'JAWP::Util::GetHeadnameList(あああ\n==見 出 し==\nいいい:見出し数)' );
		is( $result[0], '見 出 し', 'JAWP::Util::GetHeadnameList(あああ\n==見 出 し==\nいいい:見出し)' );
	}

	# GetTalkTimestampListテスト
	{
		my @result;

		@result = JAWP::Util::GetTalkTimestampList( '' );
		is( @result + 0 , 0, 'JAWP::Util::GetTalkTimestampList(空文字列:発言日時数)' );

		@result = JAWP::Util::GetTalkTimestampList( 'あああ' );
		is( @result + 0 , 0, 'JAWP::Util::GetTalkTimestampList(あああ:発言日時数)' );

		@result = JAWP::Util::GetTalkTimestampList( '2011年8月2日 (火) 14:14 (UTC)' );
		is( @result + 0 , 1, 'JAWP::Util::GetTalkTimestampList(2011年8月2日 (火) 14:14 (UTC):発言日時数)' );
		is( $result[0], '2011-08-02T14:14:00Z', 'JAWP::Util::GetTalkTimestampList(2011年8月2日 (火) 14:14 (UTC):発言日時)' );

		@result = JAWP::Util::GetTalkTimestampList( '２０１１年８月２日 (火) １４:１４ (UTC)' );
		is( @result + 0 , 0, 'JAWP::Util::GetTalkTimestampList(２０１１年８月２日 (火) １４:１４ (UTC):発言日時数,全角数字)' );

		@result = JAWP::Util::GetTalkTimestampList( '2011年8月2日 (火) 14:14 (UTC)あああ2011年8月7日 (日) 14:55 (UTC)' );
		is( @result + 0 , 2, 'JAWP::Util::GetTalkTimestampList(2011年8月2日 (火) 14:14 (UTC)あああ2011年8月7日 (日) 14:55 (UTC):発言日時数)' );
		is( $result[0], '2011-08-02T14:14:00Z', 'JAWP::Util::GetTalkTimestampList(2011年8月2日 (火) 14:14 (UTC)あああ2011年8月7日 (日) 14:55 (UTC):発言日時1)' );
		is( $result[1], '2011-08-07T14:55:00Z', 'JAWP::Util::GetTalkTimestampList(2011年8月2日 (火) 14:14 (UTC)あああ2011年8月7日 (日) 14:55 (UTC):発言日時2)' );
	}
}


################################################################################
# JAWP::Appクラス
################################################################################

sub TestJAWPApp {
	# メソッド呼び出しテスト
	{
		foreach my $method ( 'Run', 'Usage', 'LintTitle', 'LintText', 'LintIndex',
			'LintRedirect', 'Statistic', 'StatisticReportSub1', 'StatisticReportSub2',
			'TitleList', 'LivingNoref', 'PassedSakujo', 'Person',
			'NoIndex', 'IndexList', 'Aimai' ) {
			ok( JAWP::App->can($method), "JAWP::App(メソッド呼び出し,$method)" );
		}
	}
}


################################################################################
# JAWP::CGIAppクラス
################################################################################

sub TestJAWPCGIApp {
	# メソッド呼び出しテスト
	{
		foreach my $method ( 'Run' ) {
			ok( JAWP::CGIApp->can($method), "JAWP::CGIApp(メソッド呼び出し,$method)" );
		}
	}
}


################################################################################
# テスト用ユーティリティ関数
################################################################################

# スタートアップ
sub Startup {
}


# クリーンナップ
sub Cleanup {
}


# テストXMLファイル作成
sub WriteTestXMLFile {
	my $text = shift;
	my $fname = GetTempFilename();

	open F, '>', $fname or die $!;
	print F $text or die $!;
	close F or die $!;

	return( $fname );
}


# レポートファイル読み込み
sub ReadReportFile {
	my $fname = shift;
	my $text;

	open F, '<', $fname or die $!;
	$text = join( '', <F> );
	close F or die $!;

	return( $text );
}


# テスト用ファイル名取得
sub GetTempFilename {
	my( $fh, $fname ) = mkstemp( $fnametemp );

	close $fh or die $!;

	return( $fname );
}


# JIS X 0208漢字取得
sub GetJIS_X_0208_KANJI {
	my @JIS_X_0208_KANJI = ( '一', '丁', '七', '万', '丈', '三', '上', '下', '不', '与', '丐', '丑', '且', '丕', '世', '丗', 
		'丘', '丙', '丞', '両', '並', '个', '中', '丱', '串', '丶', '丸', '丹', '主', '丼', '丿', '乂', 
		'乃', '久', '之', '乍', '乎', '乏', '乕', '乖', '乗', '乘', '乙', '九', '乞', '也', '乢', '乱', 
		'乳', '乾', '亀', '亂', '亅', '了', '予', '争', '亊', '事', '二', '于', '云', '互', '五', '井', 
		'亘', '亙', '些', '亜', '亞', '亟', '亠', '亡', '亢', '交', '亥', '亦', '亨', '享', '京', '亭', 
		'亮', '亰', '亳', '亶', '人', '什', '仁', '仂', '仄', '仆', '仇', '今', '介', '仍', '从', '仏', 
		'仔', '仕', '他', '仗', '付', '仙', '仝', '仞', '仟', '代', '令', '以', '仭', '仮', '仰', '仲', 
		'件', '价', '任', '企', '伉', '伊', '伍', '伎', '伏', '伐', '休', '会', '伜', '伝', '伯', '估', 
		'伴', '伶', '伸', '伺', '似', '伽', '佃', '但', '佇', '位', '低', '住', '佐', '佑', '体', '何', 
		'佗', '余', '佚', '佛', '作', '佝', '佞', '佩', '佯', '佰', '佳', '併', '佶', '佻', '佼', '使', 
		'侃', '來', '侈', '例', '侍', '侏', '侑', '侖', '侘', '供', '依', '侠', '価', '侫', '侭', '侮', 
		'侯', '侵', '侶', '便', '係', '促', '俄', '俊', '俎', '俐', '俑', '俔', '俗', '俘', '俚', '俛', 
		'保', '俟', '信', '俣', '俤', '俥', '修', '俯', '俳', '俵', '俶', '俸', '俺', '俾', '倅', '倆', 
		'倉', '個', '倍', '倏', '們', '倒', '倔', '倖', '候', '倚', '借', '倡', '倣', '値', '倥', '倦', 
		'倨', '倩', '倪', '倫', '倬', '倭', '倶', '倹', '偃', '假', '偈', '偉', '偏', '偐', '偕', '偖', 
		'做', '停', '健', '偬', '偲', '側', '偵', '偶', '偸', '偽', '傀', '傅', '傍', '傑', '傘', '備', 
		'傚', '催', '傭', '傲', '傳', '傴', '債', '傷', '傾', '僂', '僅', '僉', '僊', '働', '像', '僑', 
		'僕', '僖', '僚', '僞', '僣', '僥', '僧', '僭', '僮', '僵', '價', '僻', '儀', '儁', '儂', '億', 
		'儉', '儒', '儔', '儕', '儖', '儘', '儚', '償', '儡', '優', '儲', '儷', '儺', '儻', '儼', '儿', 
		'兀', '允', '元', '兄', '充', '兆', '兇', '先', '光', '克', '兌', '免', '兎', '児', '兒', '兔', 
		'党', '兜', '兢', '入', '全', '兩', '兪', '八', '公', '六', '兮', '共', '兵', '其', '具', '典', 
		'兼', '冀', '冂', '内', '円', '冉', '冊', '册', '再', '冏', '冐', '冑', '冒', '冓', '冕', '冖', 
		'冗', '写', '冠', '冢', '冤', '冥', '冦', '冨', '冩', '冪', '冫', '冬', '冰', '冱', '冲', '决', 
		'冴', '况', '冶', '冷', '冽', '凄', '凅', '准', '凉', '凋', '凌', '凍', '凖', '凛', '凜', '凝', 
		'几', '凡', '処', '凧', '凩', '凪', '凭', '凰', '凱', '凵', '凶', '凸', '凹', '出', '函', '凾', 
		'刀', '刃', '刄', '分', '切', '刈', '刊', '刋', '刎', '刑', '刔', '列', '初', '判', '別', '刧', 
		'利', '刪', '刮', '到', '刳', '制', '刷', '券', '刹', '刺', '刻', '剃', '剄', '則', '削', '剋', 
		'剌', '前', '剏', '剔', '剖', '剛', '剞', '剣', '剤', '剥', '剩', '剪', '副', '剰', '剱', '割', 
		'剳', '剴', '創', '剽', '剿', '劃', '劇', '劈', '劉', '劍', '劑', '劒', '劔', '力', '功', '加', 
		'劣', '助', '努', '劫', '劬', '劭', '励', '労', '劵', '効', '劼', '劾', '勁', '勃', '勅', '勇', 
		'勉', '勍', '勒', '動', '勗', '勘', '務', '勝', '勞', '募', '勠', '勢', '勣', '勤', '勦', '勧', 
		'勲', '勳', '勵', '勸', '勹', '勺', '勾', '勿', '匁', '匂', '包', '匆', '匈', '匍', '匏', '匐', 
		'匕', '化', '北', '匙', '匚', '匝', '匠', '匡', '匣', '匪', '匯', '匱', '匳', '匸', '匹', '区', 
		'医', '匿', '區', '十', '千', '卅', '卆', '升', '午', '卉', '半', '卍', '卑', '卒', '卓', '協', 
		'南', '単', '博', '卜', '卞', '占', '卦', '卩', '卮', '卯', '印', '危', '即', '却', '卵', '卷', 
		'卸', '卻', '卿', '厂', '厄', '厖', '厘', '厚', '原', '厠', '厥', '厦', '厨', '厩', '厭', '厮', 
		'厰', '厳', '厶', '去', '参', '參', '又', '叉', '及', '友', '双', '反', '収', '叔', '取', '受', 
		'叙', '叛', '叟', '叡', '叢', '口', '古', '句', '叨', '叩', '只', '叫', '召', '叭', '叮', '可', 
		'台', '叱', '史', '右', '叶', '号', '司', '叺', '吁', '吃', '各', '合', '吉', '吊', '吋', '同', 
		'名', '后', '吏', '吐', '向', '君', '吝', '吟', '吠', '否', '吩', '含', '听', '吭', '吮', '吶', 
		'吸', '吹', '吻', '吼', '吽', '吾', '呀', '呂', '呆', '呈', '呉', '告', '呎', '呑', '呟', '周', 
		'呪', '呰', '呱', '味', '呵', '呶', '呷', '呻', '呼', '命', '咀', '咄', '咆', '咋', '和', '咎', 
		'咏', '咐', '咒', '咢', '咤', '咥', '咨', '咫', '咬', '咯', '咲', '咳', '咸', '咼', '咽', '咾', 
		'哀', '品', '哂', '哄', '哇', '哈', '哉', '哘', '員', '哢', '哥', '哦', '哨', '哩', '哭', '哮', 
		'哲', '哺', '哽', '唄', '唆', '唇', '唏', '唐', '唔', '唖', '售', '唯', '唱', '唳', '唸', '唹', 
		'唾', '啀', '啄', '啅', '商', '啌', '問', '啓', '啖', '啗', '啜', '啝', '啣', '啻', '啼', '啾', 
		'喀', '喃', '善', '喇', '喉', '喊', '喋', '喘', '喙', '喚', '喜', '喝', '喞', '喟', '喧', '喨', 
		'喩', '喪', '喫', '喬', '單', '喰', '営', '嗄', '嗅', '嗇', '嗔', '嗚', '嗜', '嗟', '嗣', '嗤', 
		'嗷', '嗹', '嗽', '嗾', '嘆', '嘉', '嘔', '嘖', '嘗', '嘘', '嘛', '嘩', '嘯', '嘱', '嘲', '嘴', 
		'嘶', '嘸', '噂', '噌', '噎', '噐', '噛', '噤', '器', '噪', '噫', '噬', '噴', '噸', '噺', '嚀', 
		'嚆', '嚇', '嚊', '嚏', '嚔', '嚠', '嚢', '嚥', '嚮', '嚴', '嚶', '嚼', '囀', '囁', '囂', '囃', 
		'囈', '囎', '囑', '囓', '囗', '囘', '囚', '四', '回', '因', '団', '囮', '困', '囲', '図', '囹', 
		'固', '国', '囿', '圀', '圃', '圄', '圈', '圉', '國', '圍', '圏', '園', '圓', '圖', '團', '圜', 
		'土', '圦', '圧', '在', '圭', '地', '圷', '圸', '圻', '址', '坂', '均', '坊', '坎', '坏', '坐', 
		'坑', '坡', '坤', '坦', '坩', '坪', '坿', '垂', '垈', '垉', '型', '垓', '垠', '垢', '垣', '垤', 
		'垪', '垰', '垳', '埀', '埃', '埆', '埋', '城', '埒', '埓', '埔', '埖', '埜', '域', '埠', '埣', 
		'埴', '執', '培', '基', '埼', '堀', '堂', '堅', '堆', '堊', '堋', '堕', '堙', '堝', '堡', '堤', 
		'堪', '堯', '堰', '報', '場', '堵', '堺', '堽', '塀', '塁', '塊', '塋', '塑', '塒', '塔', '塗', 
		'塘', '塙', '塚', '塞', '塢', '塩', '填', '塰', '塲', '塵', '塹', '塾', '境', '墅', '墓', '増', 
		'墜', '墟', '墨', '墫', '墮', '墳', '墸', '墹', '墺', '墻', '墾', '壁', '壅', '壇', '壊', '壌', 
		'壑', '壓', '壕', '壗', '壘', '壙', '壜', '壞', '壟', '壤', '壥', '士', '壬', '壮', '壯', '声', 
		'壱', '売', '壷', '壹', '壺', '壻', '壼', '壽', '夂', '変', '夊', '夏', '夐', '夕', '外', '夘', 
		'夙', '多', '夛', '夜', '夢', '夥', '大', '天', '太', '夫', '夬', '夭', '央', '失', '夲', '夷', 
		'夸', '夾', '奄', '奇', '奈', '奉', '奎', '奏', '奐', '契', '奔', '奕', '套', '奘', '奚', '奠', 
		'奢', '奥', '奧', '奨', '奩', '奪', '奬', '奮', '女', '奴', '奸', '好', '妁', '如', '妃', '妄', 
		'妊', '妍', '妓', '妖', '妙', '妛', '妝', '妣', '妥', '妨', '妬', '妲', '妹', '妻', '妾', '姆', 
		'姉', '始', '姐', '姑', '姓', '委', '姙', '姚', '姜', '姥', '姦', '姨', '姪', '姫', '姶', '姻', 
		'姿', '威', '娃', '娉', '娑', '娘', '娚', '娜', '娟', '娠', '娥', '娩', '娯', '娵', '娶', '娼', 
		'婀', '婁', '婆', '婉', '婚', '婢', '婦', '婪', '婬', '婿', '媒', '媚', '媛', '媼', '媽', '媾', 
		'嫁', '嫂', '嫉', '嫋', '嫌', '嫐', '嫖', '嫗', '嫡', '嫣', '嫦', '嫩', '嫺', '嫻', '嬉', '嬋', 
		'嬌', '嬖', '嬢', '嬪', '嬬', '嬰', '嬲', '嬶', '嬾', '孀', '孃', '孅', '子', '孑', '孔', '孕', 
		'字', '存', '孚', '孛', '孜', '孝', '孟', '季', '孤', '孥', '学', '孩', '孫', '孰', '孱', '孳', 
		'孵', '學', '孺', '宀', '它', '宅', '宇', '守', '安', '宋', '完', '宍', '宏', '宕', '宗', '官', 
		'宙', '定', '宛', '宜', '宝', '実', '客', '宣', '室', '宥', '宦', '宮', '宰', '害', '宴', '宵', 
		'家', '宸', '容', '宿', '寂', '寃', '寄', '寅', '密', '寇', '寉', '富', '寐', '寒', '寓', '寔', 
		'寛', '寝', '寞', '察', '寡', '寢', '寤', '寥', '實', '寧', '寨', '審', '寫', '寮', '寰', '寳', 
		'寵', '寶', '寸', '寺', '対', '寿', '封', '専', '射', '尅', '将', '將', '專', '尉', '尊', '尋', 
		'對', '導', '小', '少', '尓', '尖', '尚', '尠', '尢', '尤', '尨', '尭', '就', '尸', '尹', '尺', 
		'尻', '尼', '尽', '尾', '尿', '局', '屁', '居', '屆', '屈', '届', '屋', '屍', '屎', '屏', '屐', 
		'屑', '屓', '展', '属', '屠', '屡', '層', '履', '屬', '屮', '屯', '山', '屶', '屹', '岌', '岐', 
		'岑', '岔', '岡', '岨', '岩', '岫', '岬', '岱', '岳', '岶', '岷', '岸', '岻', '岼', '岾', '峅', 
		'峇', '峙', '峠', '峡', '峨', '峩', '峪', '峭', '峯', '峰', '島', '峺', '峻', '峽', '崇', '崋', 
		'崎', '崑', '崔', '崕', '崖', '崗', '崘', '崙', '崚', '崛', '崟', '崢', '崩', '嵋', '嵌', '嵎', 
		'嵐', '嵒', '嵜', '嵩', '嵬', '嵯', '嵳', '嵶', '嶂', '嶄', '嶇', '嶋', '嶌', '嶐', '嶝', '嶢', 
		'嶬', '嶮', '嶷', '嶺', '嶼', '嶽', '巉', '巌', '巍', '巒', '巓', '巖', '巛', '川', '州', '巡', 
		'巣', '工', '左', '巧', '巨', '巫', '差', '己', '已', '巳', '巴', '巵', '巷', '巻', '巽', '巾', 
		'市', '布', '帆', '帋', '希', '帑', '帖', '帙', '帚', '帛', '帝', '帥', '師', '席', '帯', '帰', 
		'帳', '帶', '帷', '常', '帽', '幀', '幃', '幄', '幅', '幇', '幌', '幎', '幔', '幕', '幗', '幟', 
		'幡', '幢', '幣', '幤', '干', '平', '年', '幵', '并', '幸', '幹', '幺', '幻', '幼', '幽', '幾', 
		'广', '庁', '広', '庄', '庇', '床', '序', '底', '庖', '店', '庚', '府', '庠', '度', '座', '庫', 
		'庭', '庵', '庶', '康', '庸', '廁', '廂', '廃', '廈', '廉', '廊', '廏', '廐', '廓', '廖', '廚', 
		'廛', '廝', '廟', '廠', '廡', '廢', '廣', '廨', '廩', '廬', '廰', '廱', '廳', '廴', '延', '廷', 
		'廸', '建', '廻', '廼', '廾', '廿', '弁', '弃', '弄', '弉', '弊', '弋', '弌', '弍', '式', '弐', 
		'弑', '弓', '弔', '引', '弖', '弗', '弘', '弛', '弟', '弥', '弦', '弧', '弩', '弭', '弯', '弱', 
		'張', '強', '弸', '弼', '弾', '彁', '彈', '彊', '彌', '彎', '彑', '当', '彖', '彗', '彙', '彜', 
		'彝', '彡', '形', '彦', '彩', '彪', '彫', '彬', '彭', '彰', '影', '彳', '彷', '役', '彼', '彿', 
		'往', '征', '徂', '徃', '径', '待', '徇', '很', '徊', '律', '後', '徐', '徑', '徒', '従', '得', 
		'徘', '徙', '從', '徠', '御', '徨', '復', '循', '徭', '微', '徳', '徴', '徹', '徼', '徽', '心', 
		'必', '忌', '忍', '忖', '志', '忘', '忙', '応', '忝', '忠', '忤', '快', '忰', '忱', '念', '忸', 
		'忻', '忽', '忿', '怎', '怏', '怐', '怒', '怕', '怖', '怙', '怛', '怜', '思', '怠', '怡', '急', 
		'怦', '性', '怨', '怩', '怪', '怫', '怯', '怱', '怺', '恁', '恂', '恃', '恆', '恊', '恋', '恍', 
		'恐', '恒', '恕', '恙', '恚', '恟', '恠', '恢', '恣', '恤', '恥', '恨', '恩', '恪', '恫', '恬', 
		'恭', '息', '恰', '恵', '恷', '悁', '悃', '悄', '悉', '悋', '悌', '悍', '悒', '悔', '悖', '悗', 
		'悚', '悛', '悟', '悠', '患', '悦', '悧', '悩', '悪', '悲', '悳', '悴', '悵', '悶', '悸', '悼', 
		'悽', '情', '惆', '惇', '惑', '惓', '惘', '惚', '惜', '惟', '惠', '惡', '惣', '惧', '惨', '惰', 
		'惱', '想', '惴', '惶', '惷', '惹', '惺', '惻', '愀', '愁', '愃', '愆', '愈', '愉', '愍', '愎', 
		'意', '愕', '愚', '愛', '感', '愡', '愧', '愨', '愬', '愴', '愼', '愽', '愾', '愿', '慂', '慄', 
		'慇', '慈', '慊', '態', '慌', '慍', '慎', '慓', '慕', '慘', '慙', '慚', '慝', '慟', '慢', '慣', 
		'慥', '慧', '慨', '慫', '慮', '慯', '慰', '慱', '慳', '慴', '慵', '慶', '慷', '慾', '憂', '憇', 
		'憊', '憎', '憐', '憑', '憔', '憖', '憙', '憚', '憤', '憧', '憩', '憫', '憬', '憮', '憲', '憶', 
		'憺', '憾', '懃', '懆', '懇', '懈', '應', '懊', '懋', '懌', '懍', '懐', '懣', '懦', '懲', '懴', 
		'懶', '懷', '懸', '懺', '懼', '懽', '懾', '懿', '戀', '戈', '戉', '戊', '戌', '戍', '戎', '成', 
		'我', '戒', '戔', '或', '戚', '戛', '戝', '戞', '戟', '戡', '戦', '截', '戮', '戯', '戰', '戲', 
		'戳', '戴', '戸', '戻', '房', '所', '扁', '扇', '扈', '扉', '手', '才', '扎', '打', '払', '托', 
		'扛', '扞', '扠', '扣', '扨', '扮', '扱', '扶', '批', '扼', '找', '承', '技', '抂', '抃', '抄', 
		'抉', '把', '抑', '抒', '抓', '抔', '投', '抖', '抗', '折', '抛', '抜', '択', '披', '抬', '抱', 
		'抵', '抹', '抻', '押', '抽', '拂', '担', '拆', '拇', '拈', '拉', '拊', '拌', '拍', '拏', '拐', 
		'拑', '拒', '拓', '拔', '拗', '拘', '拙', '招', '拜', '拝', '拠', '拡', '括', '拭', '拮', '拯', 
		'拱', '拳', '拵', '拶', '拷', '拾', '拿', '持', '挂', '指', '挈', '按', '挌', '挑', '挙', '挟', 
		'挧', '挨', '挫', '振', '挺', '挽', '挾', '挿', '捉', '捌', '捍', '捏', '捐', '捕', '捗', '捜', 
		'捧', '捨', '捩', '捫', '据', '捲', '捶', '捷', '捺', '捻', '掀', '掃', '授', '掉', '掌', '掎', 
		'掏', '排', '掖', '掘', '掛', '掟', '掠', '採', '探', '掣', '接', '控', '推', '掩', '措', '掫', 
		'掬', '掲', '掴', '掵', '掻', '掾', '揀', '揃', '揄', '揆', '揉', '描', '提', '插', '揖', '揚', 
		'換', '握', '揣', '揩', '揮', '援', '揶', '揺', '搆', '損', '搏', '搓', '搖', '搗', '搜', '搦', 
		'搨', '搬', '搭', '搴', '搶', '携', '搾', '摂', '摎', '摘', '摧', '摩', '摯', '摶', '摸', '摺', 
		'撃', '撈', '撒', '撓', '撕', '撚', '撞', '撤', '撥', '撩', '撫', '播', '撮', '撰', '撲', '撹', 
		'撻', '撼', '擁', '擂', '擅', '擇', '操', '擒', '擔', '擘', '據', '擠', '擡', '擢', '擣', '擦', 
		'擧', '擬', '擯', '擱', '擲', '擴', '擶', '擺', '擽', '擾', '攀', '攅', '攘', '攜', '攝', '攣', 
		'攤', '攪', '攫', '攬', '支', '攴', '攵', '收', '攷', '攸', '改', '攻', '放', '政', '故', '效', 
		'敍', '敏', '救', '敕', '敖', '敗', '敘', '教', '敝', '敞', '敢', '散', '敦', '敬', '数', '敲', 
		'整', '敵', '敷', '數', '斂', '斃', '文', '斈', '斉', '斌', '斎', '斐', '斑', '斗', '料', '斛', 
		'斜', '斟', '斡', '斤', '斥', '斧', '斫', '斬', '断', '斯', '新', '斷', '方', '於', '施', '旁', 
		'旃', '旄', '旅', '旆', '旋', '旌', '族', '旒', '旗', '旙', '旛', '无', '旡', '既', '日', '旦', 
		'旧', '旨', '早', '旬', '旭', '旱', '旺', '旻', '昂', '昃', '昆', '昇', '昊', '昌', '明', '昏', 
		'易', '昔', '昜', '星', '映', '春', '昧', '昨', '昭', '是', '昴', '昵', '昶', '昼', '昿', '晁', 
		'時', '晃', '晄', '晉', '晋', '晏', '晒', '晝', '晞', '晟', '晢', '晤', '晦', '晧', '晨', '晩', 
		'普', '景', '晰', '晴', '晶', '智', '暁', '暃', '暄', '暇', '暈', '暉', '暎', '暑', '暖', '暗', 
		'暘', '暝', '暢', '暦', '暫', '暮', '暴', '暸', '暹', '暼', '暾', '曁', '曄', '曇', '曉', '曖', 
		'曙', '曚', '曜', '曝', '曠', '曦', '曩', '曰', '曲', '曳', '更', '曵', '曷', '書', '曹', '曼', 
		'曽', '曾', '替', '最', '會', '月', '有', '朋', '服', '朏', '朔', '朕', '朖', '朗', '望', '朝', 
		'朞', '期', '朦', '朧', '木', '未', '末', '本', '札', '朮', '朱', '朴', '朶', '朷', '朸', '机', 
		'朽', '朿', '杁', '杆', '杉', '李', '杏', '材', '村', '杓', '杖', '杙', '杜', '杞', '束', '杠', 
		'条', '杢', '杣', '杤', '来', '杪', '杭', '杯', '杰', '東', '杲', '杳', '杵', '杷', '杼', '松', 
		'板', '枅', '枇', '枉', '枋', '枌', '析', '枕', '林', '枚', '果', '枝', '枠', '枡', '枢', '枦', 
		'枩', '枯', '枳', '枴', '架', '枷', '枸', '枹', '柁', '柄', '柆', '柊', '柎', '柏', '某', '柑', 
		'染', '柔', '柘', '柚', '柝', '柞', '柢', '柤', '柧', '柩', '柬', '柮', '柯', '柱', '柳', '柴', 
		'柵', '査', '柾', '柿', '栂', '栃', '栄', '栓', '栖', '栗', '栞', '校', '栢', '栩', '株', '栫', 
		'栲', '栴', '核', '根', '格', '栽', '桀', '桁', '桂', '桃', '框', '案', '桍', '桎', '桐', '桑', 
		'桓', '桔', '桙', '桜', '桝', '桟', '档', '桧', '桴', '桶', '桷', '桾', '桿', '梁', '梃', '梅', 
		'梍', '梏', '梓', '梔', '梗', '梛', '條', '梟', '梠', '梢', '梦', '梧', '梨', '梭', '梯', '械', 
		'梱', '梳', '梵', '梶', '梹', '梺', '梼', '棄', '棆', '棉', '棊', '棋', '棍', '棒', '棔', '棕', 
		'棗', '棘', '棚', '棟', '棠', '棡', '棣', '棧', '森', '棯', '棲', '棹', '棺', '椀', '椁', '椄', 
		'椅', '椈', '椋', '椌', '植', '椎', '椏', '椒', '椙', '椚', '椛', '検', '椡', '椢', '椣', '椥', 
		'椦', '椨', '椪', '椰', '椴', '椶', '椹', '椽', '椿', '楊', '楓', '楔', '楕', '楙', '楚', '楜', 
		'楝', '楞', '楠', '楡', '楢', '楪', '楫', '業', '楮', '楯', '楳', '楴', '極', '楷', '楸', '楹', 
		'楼', '楽', '楾', '榁', '概', '榊', '榎', '榑', '榔', '榕', '榛', '榜', '榠', '榧', '榮', '榱', 
		'榲', '榴', '榻', '榾', '榿', '槁', '槃', '槇', '槊', '構', '槌', '槍', '槎', '槐', '槓', '様', 
		'槙', '槝', '槞', '槧', '槨', '槫', '槭', '槲', '槹', '槻', '槽', '槿', '樂', '樅', '樊', '樋', 
		'樌', '樒', '樓', '樔', '樗', '標', '樛', '樞', '樟', '模', '樢', '樣', '権', '横', '樫', '樮', 
		'樵', '樶', '樸', '樹', '樺', '樽', '橄', '橇', '橈', '橋', '橘', '橙', '機', '橡', '橢', '橦', 
		'橲', '橸', '橿', '檀', '檄', '檍', '檎', '檐', '檗', '檜', '檠', '檢', '檣', '檪', '檬', '檮', 
		'檳', '檸', '檻', '櫁', '櫂', '櫃', '櫑', '櫓', '櫚', '櫛', '櫞', '櫟', '櫨', '櫪', '櫺', '櫻', 
		'欄', '欅', '權', '欒', '欖', '欝', '欟', '欠', '次', '欣', '欧', '欲', '欷', '欸', '欹', '欺', 
		'欽', '款', '歃', '歇', '歉', '歌', '歎', '歐', '歓', '歔', '歙', '歛', '歟', '歡', '止', '正', 
		'此', '武', '歩', '歪', '歯', '歳', '歴', '歸', '歹', '死', '歿', '殀', '殃', '殄', '殆', '殉', 
		'殊', '残', '殍', '殕', '殖', '殘', '殞', '殤', '殪', '殫', '殯', '殱', '殲', '殳', '殴', '段', 
		'殷', '殺', '殻', '殼', '殿', '毀', '毅', '毆', '毋', '母', '毎', '毒', '毓', '比', '毘', '毛', 
		'毟', '毫', '毬', '毯', '毳', '氈', '氏', '民', '氓', '气', '気', '氛', '氣', '氤', '水', '氷', 
		'永', '氾', '汀', '汁', '求', '汎', '汐', '汕', '汗', '汚', '汝', '汞', '江', '池', '汢', '汨', 
		'汪', '汰', '汲', '汳', '決', '汽', '汾', '沁', '沂', '沃', '沈', '沌', '沍', '沐', '沒', '沓', 
		'沖', '沙', '沚', '沛', '没', '沢', '沫', '沮', '沱', '河', '沸', '油', '沺', '治', '沼', '沽', 
		'沾', '沿', '況', '泄', '泅', '泉', '泊', '泌', '泓', '法', '泗', '泙', '泛', '泝', '泡', '波', 
		'泣', '泥', '注', '泪', '泯', '泰', '泱', '泳', '洋', '洌', '洒', '洗', '洙', '洛', '洞', '洟', 
		'津', '洩', '洪', '洫', '洲', '洳', '洵', '洶', '洸', '活', '洽', '派', '流', '浄', '浅', '浙', 
		'浚', '浜', '浣', '浤', '浦', '浩', '浪', '浬', '浮', '浴', '海', '浸', '浹', '涅', '消', '涌', 
		'涎', '涓', '涕', '涙', '涛', '涜', '涯', '液', '涵', '涸', '涼', '淀', '淅', '淆', '淇', '淋', 
		'淌', '淑', '淒', '淕', '淘', '淙', '淞', '淡', '淤', '淦', '淨', '淪', '淫', '淬', '淮', '深', 
		'淳', '淵', '混', '淹', '淺', '添', '清', '渇', '済', '渉', '渊', '渋', '渓', '渕', '渙', '渚', 
		'減', '渝', '渟', '渠', '渡', '渣', '渤', '渥', '渦', '温', '渫', '測', '渭', '渮', '港', '游', 
		'渺', '渾', '湃', '湊', '湍', '湎', '湖', '湘', '湛', '湟', '湧', '湫', '湮', '湯', '湲', '湶', 
		'湾', '湿', '満', '溂', '溌', '溏', '源', '準', '溘', '溜', '溝', '溟', '溢', '溥', '溪', '溯', 
		'溲', '溶', '溷', '溺', '溽', '滂', '滄', '滅', '滉', '滋', '滌', '滑', '滓', '滔', '滕', '滝', 
		'滞', '滬', '滯', '滲', '滴', '滷', '滸', '滾', '滿', '漁', '漂', '漆', '漉', '漏', '漑', '漓', 
		'演', '漕', '漠', '漢', '漣', '漫', '漬', '漱', '漲', '漸', '漾', '漿', '潁', '潅', '潔', '潘', 
		'潛', '潜', '潟', '潤', '潦', '潭', '潮', '潯', '潰', '潴', '潸', '潺', '潼', '澀', '澁', '澂', 
		'澄', '澆', '澎', '澑', '澗', '澡', '澣', '澤', '澪', '澱', '澳', '澹', '激', '濁', '濂', '濃', 
		'濆', '濔', '濕', '濘', '濛', '濟', '濠', '濡', '濤', '濫', '濬', '濮', '濯', '濱', '濳', '濶', 
		'濺', '濾', '瀁', '瀉', '瀋', '瀏', '瀑', '瀕', '瀘', '瀚', '瀛', '瀝', '瀞', '瀟', '瀦', '瀧', 
		'瀬', '瀰', '瀲', '瀾', '灌', '灑', '灘', '灣', '火', '灯', '灰', '灸', '灼', '災', '炉', '炊', 
		'炎', '炒', '炙', '炬', '炭', '炮', '炯', '炳', '炸', '点', '為', '烈', '烋', '烏', '烙', '烝', 
		'烟', '烱', '烹', '烽', '焉', '焔', '焙', '焚', '焜', '無', '焦', '然', '焼', '煉', '煌', '煎', 
		'煕', '煖', '煙', '煢', '煤', '煥', '煦', '照', '煩', '煬', '煮', '煽', '熄', '熈', '熊', '熏', 
		'熔', '熕', '熙', '熟', '熨', '熬', '熱', '熹', '熾', '燃', '燈', '燉', '燎', '燐', '燒', '燔', 
		'燕', '燗', '營', '燠', '燥', '燦', '燧', '燬', '燭', '燮', '燵', '燹', '燻', '燼', '燿', '爆', 
		'爍', '爐', '爛', '爨', '爪', '爬', '爭', '爰', '爲', '爵', '父', '爺', '爻', '爼', '爽', '爾', 
		'爿', '牀', '牆', '片', '版', '牋', '牌', '牒', '牘', '牙', '牛', '牝', '牟', '牡', '牢', '牧', 
		'物', '牲', '牴', '特', '牽', '牾', '犀', '犁', '犂', '犇', '犒', '犖', '犠', '犢', '犧', '犬', 
		'犯', '犲', '状', '犹', '狂', '狃', '狄', '狆', '狎', '狐', '狒', '狗', '狙', '狛', '狠', '狡', 
		'狢', '狩', '独', '狭', '狷', '狸', '狹', '狼', '狽', '猊', '猖', '猗', '猛', '猜', '猝', '猟', 
		'猥', '猩', '猪', '猫', '献', '猯', '猴', '猶', '猷', '猾', '猿', '獄', '獅', '獎', '獏', '獗', 
		'獣', '獨', '獪', '獰', '獲', '獵', '獸', '獺', '獻', '玄', '率', '玉', '王', '玖', '玩', '玲', 
		'玳', '玻', '珀', '珂', '珈', '珊', '珍', '珎', '珞', '珠', '珥', '珪', '班', '珮', '珱', '珸', 
		'現', '球', '琅', '理', '琉', '琢', '琥', '琲', '琳', '琴', '琵', '琶', '琺', '琿', '瑁', '瑕', 
		'瑙', '瑚', '瑛', '瑜', '瑞', '瑟', '瑠', '瑣', '瑤', '瑩', '瑪', '瑯', '瑰', '瑳', '瑶', '瑾', 
		'璃', '璋', '璞', '璢', '璧', '環', '璽', '瓊', '瓏', '瓔', '瓜', '瓠', '瓢', '瓣', '瓦', '瓧', 
		'瓩', '瓮', '瓰', '瓱', '瓲', '瓶', '瓷', '瓸', '甃', '甄', '甅', '甌', '甍', '甎', '甑', '甓', 
		'甕', '甘', '甚', '甜', '甞', '生', '産', '甥', '甦', '用', '甫', '甬', '田', '由', '甲', '申', 
		'男', '甸', '町', '画', '甼', '畄', '畆', '畉', '畊', '畋', '界', '畍', '畏', '畑', '畔', '留', 
		'畚', '畛', '畜', '畝', '畠', '畢', '畤', '略', '畦', '畧', '畩', '番', '畫', '畭', '異', '畳', 
		'畴', '當', '畷', '畸', '畿', '疂', '疆', '疇', '疉', '疊', '疋', '疎', '疏', '疑', '疔', '疚', 
		'疝', '疣', '疥', '疫', '疱', '疲', '疳', '疵', '疸', '疹', '疼', '疽', '疾', '痂', '痃', '病', 
		'症', '痊', '痍', '痒', '痔', '痕', '痘', '痙', '痛', '痞', '痢', '痣', '痩', '痰', '痲', '痳', 
		'痴', '痺', '痼', '痾', '痿', '瘁', '瘉', '瘋', '瘍', '瘟', '瘠', '瘡', '瘢', '瘤', '瘧', '瘰', 
		'瘴', '瘻', '療', '癆', '癇', '癈', '癌', '癒', '癖', '癘', '癜', '癡', '癢', '癧', '癨', '癩', 
		'癪', '癬', '癰', '癲', '癶', '癸', '発', '登', '發', '白', '百', '皀', '皃', '的', '皆', '皇', 
		'皈', '皋', '皎', '皐', '皓', '皖', '皙', '皚', '皮', '皰', '皴', '皷', '皸', '皹', '皺', '皿', 
		'盂', '盃', '盆', '盈', '益', '盍', '盒', '盖', '盗', '盛', '盜', '盞', '盟', '盡', '監', '盤', 
		'盥', '盧', '盪', '目', '盲', '直', '相', '盻', '盾', '省', '眄', '眇', '眈', '眉', '看', '県', 
		'眛', '眞', '真', '眠', '眤', '眥', '眦', '眩', '眷', '眸', '眺', '眼', '着', '睇', '睚', '睛', 
		'睡', '督', '睥', '睦', '睨', '睫', '睹', '睾', '睿', '瞋', '瞎', '瞑', '瞞', '瞠', '瞥', '瞬', 
		'瞭', '瞰', '瞳', '瞶', '瞹', '瞻', '瞼', '瞽', '瞿', '矇', '矍', '矗', '矚', '矛', '矜', '矢', 
		'矣', '知', '矧', '矩', '短', '矮', '矯', '石', '矼', '砂', '砌', '砒', '研', '砕', '砠', '砥', 
		'砦', '砧', '砲', '破', '砺', '砿', '硅', '硝', '硫', '硬', '硯', '硲', '硴', '硼', '碁', '碆', 
		'碇', '碌', '碍', '碎', '碑', '碓', '碕', '碗', '碚', '碣', '碧', '碩', '碪', '碯', '碵', '確', 
		'碼', '碾', '磁', '磅', '磆', '磊', '磋', '磐', '磑', '磔', '磚', '磧', '磨', '磬', '磯', '磴', 
		'磽', '礁', '礇', '礎', '礑', '礒', '礙', '礦', '礪', '礫', '礬', '示', '礼', '社', '祀', '祁', 
		'祇', '祈', '祉', '祐', '祓', '祕', '祖', '祗', '祚', '祝', '神', '祟', '祠', '祢', '祥', '票', 
		'祭', '祷', '祺', '祿', '禀', '禁', '禄', '禅', '禊', '禍', '禎', '福', '禝', '禦', '禧', '禪', 
		'禮', '禰', '禳', '禹', '禺', '禽', '禾', '禿', '秀', '私', '秉', '秋', '科', '秒', '秕', '秘', 
		'租', '秡', '秣', '秤', '秦', '秧', '秩', '秬', '称', '移', '稀', '稈', '程', '稍', '税', '稔', 
		'稗', '稘', '稙', '稚', '稜', '稟', '稠', '種', '稱', '稲', '稷', '稻', '稼', '稽', '稾', '稿', 
		'穀', '穂', '穃', '穆', '穉', '積', '穎', '穏', '穐', '穗', '穡', '穢', '穣', '穩', '穫', '穰', 
		'穴', '究', '穹', '空', '穽', '穿', '突', '窃', '窄', '窈', '窒', '窓', '窕', '窖', '窗', '窘', 
		'窟', '窩', '窪', '窮', '窯', '窰', '窶', '窺', '窿', '竃', '竄', '竅', '竇', '竈', '竊', '立', 
		'竍', '竏', '竒', '竓', '竕', '站', '竚', '竜', '竝', '竟', '章', '竡', '竢', '竣', '童', '竦', 
		'竪', '竭', '端', '竰', '競', '竸', '竹', '竺', '竿', '笂', '笄', '笆', '笈', '笊', '笋', '笏', 
		'笑', '笘', '笙', '笛', '笞', '笠', '笥', '符', '笨', '第', '笳', '笵', '笶', '笹', '筅', '筆', 
		'筈', '等', '筋', '筌', '筍', '筏', '筐', '筑', '筒', '答', '策', '筝', '筥', '筧', '筬', '筮', 
		'筰', '筱', '筴', '筵', '筺', '箆', '箇', '箋', '箍', '箏', '箒', '箔', '箕', '算', '箘', '箙', 
		'箚', '箜', '箝', '箟', '管', '箪', '箭', '箱', '箴', '箸', '節', '篁', '範', '篆', '篇', '築', 
		'篋', '篌', '篏', '篝', '篠', '篤', '篥', '篦', '篩', '篭', '篳', '篶', '篷', '簀', '簇', '簍', 
		'簑', '簒', '簓', '簔', '簗', '簟', '簡', '簣', '簧', '簪', '簫', '簷', '簸', '簽', '簾', '簿', 
		'籀', '籃', '籌', '籍', '籏', '籐', '籔', '籖', '籘', '籟', '籠', '籤', '籥', '籬', '米', '籵', 
		'籾', '粁', '粂', '粃', '粉', '粋', '粍', '粐', '粒', '粕', '粗', '粘', '粛', '粟', '粡', '粢', 
		'粤', '粥', '粧', '粨', '粫', '粭', '粮', '粱', '粲', '粳', '粹', '粽', '精', '糀', '糂', '糅', 
		'糊', '糎', '糒', '糖', '糘', '糜', '糞', '糟', '糠', '糢', '糧', '糯', '糲', '糴', '糶', '糸', 
		'糺', '系', '糾', '紀', '紂', '約', '紅', '紆', '紊', '紋', '納', '紐', '純', '紕', '紗', '紘', 
		'紙', '級', '紛', '紜', '素', '紡', '索', '紫', '紬', '紮', '累', '細', '紲', '紳', '紵', '紹', 
		'紺', '紿', '終', '絃', '組', '絅', '絆', '絋', '経', '絎', '絏', '結', '絖', '絛', '絞', '絡', 
		'絢', '絣', '給', '絨', '絮', '統', '絲', '絳', '絵', '絶', '絹', '絽', '綉', '綏', '經', '継', 
		'続', '綛', '綜', '綟', '綢', '綣', '綫', '綬', '維', '綮', '綯', '綰', '綱', '網', '綴', '綵', 
		'綸', '綺', '綻', '綽', '綾', '綿', '緇', '緊', '緋', '総', '緑', '緒', '緕', '緘', '線', '緜', 
		'緝', '緞', '締', '緡', '緤', '編', '緩', '緬', '緯', '緲', '練', '緻', '縁', '縄', '縅', '縉', 
		'縊', '縋', '縒', '縛', '縞', '縟', '縡', '縢', '縣', '縦', '縫', '縮', '縱', '縲', '縵', '縷', 
		'縹', '縺', '縻', '總', '績', '繁', '繃', '繆', '繊', '繋', '繍', '織', '繕', '繖', '繙', '繚', 
		'繝', '繞', '繦', '繧', '繩', '繪', '繭', '繰', '繹', '繻', '繼', '繽', '繿', '纂', '纃', '纈', 
		'纉', '續', '纎', '纏', '纐', '纒', '纓', '纔', '纖', '纛', '纜', '缶', '缸', '缺', '罅', '罌', 
		'罍', '罎', '罐', '网', '罔', '罕', '罘', '罟', '罠', '罧', '罨', '罩', '罪', '罫', '置', '罰', 
		'署', '罵', '罷', '罸', '罹', '羂', '羃', '羅', '羆', '羇', '羈', '羊', '羌', '美', '羔', '羚', 
		'羝', '羞', '羣', '群', '羨', '義', '羮', '羯', '羲', '羶', '羸', '羹', '羽', '翁', '翅', '翆', 
		'翊', '翌', '習', '翔', '翕', '翠', '翡', '翦', '翩', '翫', '翰', '翳', '翹', '翻', '翼', '耀', 
		'老', '考', '耄', '者', '耆', '耋', '而', '耐', '耒', '耕', '耗', '耘', '耙', '耜', '耡', '耨', 
		'耳', '耶', '耻', '耽', '耿', '聆', '聊', '聒', '聖', '聘', '聚', '聞', '聟', '聡', '聢', '聨', 
		'聯', '聰', '聲', '聳', '聴', '聶', '職', '聹', '聽', '聾', '聿', '肄', '肅', '肆', '肇', '肉', 
		'肋', '肌', '肓', '肖', '肘', '肚', '肛', '肝', '股', '肢', '肥', '肩', '肪', '肬', '肭', '肯', 
		'肱', '育', '肴', '肺', '胃', '胄', '胆', '背', '胎', '胖', '胙', '胚', '胛', '胝', '胞', '胡', 
		'胤', '胥', '胯', '胱', '胴', '胸', '胼', '能', '脂', '脅', '脆', '脇', '脈', '脉', '脊', '脚', 
		'脛', '脣', '脩', '脯', '脱', '脳', '脹', '脾', '腆', '腋', '腎', '腐', '腑', '腓', '腔', '腕', 
		'腟', '腥', '腦', '腫', '腮', '腰', '腱', '腴', '腸', '腹', '腺', '腿', '膀', '膂', '膃', '膈', 
		'膊', '膏', '膓', '膕', '膚', '膜', '膝', '膠', '膣', '膤', '膨', '膩', '膰', '膳', '膵', '膸', 
		'膺', '膽', '膾', '膿', '臀', '臂', '臆', '臈', '臉', '臍', '臑', '臓', '臘', '臙', '臚', '臟', 
		'臠', '臣', '臥', '臧', '臨', '自', '臭', '至', '致', '臺', '臻', '臼', '臾', '舁', '舂', '舅', 
		'與', '興', '舉', '舊', '舌', '舍', '舎', '舐', '舒', '舖', '舗', '舘', '舛', '舜', '舞', '舟', 
		'舩', '航', '舫', '般', '舮', '舳', '舵', '舶', '舷', '舸', '船', '艀', '艇', '艘', '艙', '艚', 
		'艝', '艟', '艢', '艤', '艦', '艨', '艪', '艫', '艮', '良', '艱', '色', '艶', '艷', '艸', '艾', 
		'芋', '芍', '芒', '芙', '芝', '芟', '芥', '芦', '芫', '芬', '芭', '芯', '花', '芳', '芸', '芹', 
		'芻', '芽', '苅', '苑', '苒', '苓', '苔', '苗', '苙', '苛', '苜', '苞', '苟', '苡', '苣', '若', 
		'苦', '苧', '苫', '英', '苳', '苴', '苹', '苺', '苻', '茂', '范', '茄', '茅', '茆', '茉', '茎', 
		'茖', '茗', '茘', '茜', '茣', '茨', '茫', '茯', '茱', '茲', '茴', '茵', '茶', '茸', '茹', '荀', 
		'荅', '草', '荊', '荏', '荐', '荒', '荘', '荳', '荵', '荷', '荻', '荼', '莅', '莇', '莉', '莊', 
		'莎', '莓', '莖', '莚', '莞', '莟', '莠', '莢', '莨', '莪', '莫', '莱', '莵', '莽', '菁', '菅', 
		'菊', '菌', '菎', '菓', '菖', '菘', '菜', '菟', '菠', '菩', '菫', '華', '菰', '菱', '菲', '菴', 
		'菷', '菻', '菽', '萃', '萄', '萇', '萋', '萌', '萍', '萎', '萓', '萠', '萢', '萩', '萪', '萬', 
		'萱', '萵', '萸', '萼', '落', '葆', '葉', '葎', '著', '葛', '葡', '葢', '董', '葦', '葩', '葫', 
		'葬', '葭', '葮', '葯', '葱', '葵', '葷', '葹', '葺', '蒂', '蒄', '蒋', '蒐', '蒔', '蒙', '蒜', 
		'蒟', '蒡', '蒭', '蒲', '蒸', '蒹', '蒻', '蒼', '蒿', '蓁', '蓄', '蓆', '蓉', '蓊', '蓋', '蓍', 
		'蓐', '蓑', '蓖', '蓙', '蓚', '蓬', '蓮', '蓴', '蓼', '蓿', '蔀', '蔆', '蔑', '蔓', '蔔', '蔕', 
		'蔗', '蔘', '蔚', '蔟', '蔡', '蔦', '蔬', '蔭', '蔵', '蔽', '蕀', '蕁', '蕃', '蕈', '蕉', '蕊', 
		'蕋', '蕎', '蕕', '蕗', '蕘', '蕚', '蕣', '蕨', '蕩', '蕪', '蕭', '蕷', '蕾', '薀', '薄', '薇', 
		'薈', '薊', '薐', '薑', '薔', '薗', '薙', '薛', '薜', '薤', '薦', '薨', '薩', '薪', '薫', '薬', 
		'薮', '薯', '薹', '薺', '藁', '藉', '藍', '藏', '藐', '藕', '藜', '藝', '藤', '藥', '藩', '藪', 
		'藷', '藹', '藺', '藻', '藾', '蘂', '蘆', '蘇', '蘊', '蘋', '蘓', '蘖', '蘗', '蘚', '蘢', '蘭', 
		'蘯', '蘰', '蘿', '虍', '虎', '虐', '虔', '處', '虚', '虜', '虞', '號', '虧', '虫', '虱', '虹', 
		'虻', '蚊', '蚋', '蚌', '蚓', '蚕', '蚣', '蚤', '蚩', '蚪', '蚫', '蚯', '蚰', '蚶', '蛄', '蛆', 
		'蛇', '蛉', '蛋', '蛍', '蛎', '蛔', '蛙', '蛛', '蛞', '蛟', '蛤', '蛩', '蛬', '蛭', '蛮', '蛯', 
		'蛸', '蛹', '蛻', '蛾', '蜀', '蜂', '蜃', '蜆', '蜈', '蜉', '蜊', '蜍', '蜑', '蜒', '蜘', '蜚', 
		'蜜', '蜥', '蜩', '蜴', '蜷', '蜻', '蜿', '蝉', '蝋', '蝌', '蝎', '蝓', '蝕', '蝗', '蝙', '蝟', 
		'蝠', '蝣', '蝦', '蝨', '蝪', '蝮', '蝴', '蝶', '蝸', '蝿', '螂', '融', '螟', '螢', '螫', '螯', 
		'螳', '螺', '螻', '螽', '蟀', '蟄', '蟆', '蟇', '蟋', '蟐', '蟒', '蟠', '蟯', '蟲', '蟶', '蟷', 
		'蟹', '蟻', '蟾', '蠅', '蠍', '蠎', '蠏', '蠑', '蠕', '蠖', '蠡', '蠢', '蠣', '蠧', '蠱', '蠶', 
		'蠹', '蠻', '血', '衂', '衄', '衆', '行', '衍', '衒', '術', '街', '衙', '衛', '衝', '衞', '衡', 
		'衢', '衣', '表', '衫', '衰', '衲', '衵', '衷', '衽', '衾', '衿', '袁', '袂', '袈', '袋', '袍', 
		'袒', '袖', '袗', '袙', '袞', '袢', '袤', '被', '袮', '袰', '袱', '袴', '袵', '袷', '袿', '裁', 
		'裂', '裃', '裄', '装', '裏', '裔', '裕', '裘', '裙', '補', '裝', '裟', '裡', '裨', '裲', '裳', 
		'裴', '裸', '裹', '裼', '製', '裾', '褂', '褄', '複', '褊', '褌', '褐', '褒', '褓', '褝', '褞', 
		'褥', '褪', '褫', '褶', '褸', '褻', '襁', '襃', '襄', '襌', '襍', '襖', '襞', '襟', '襠', '襤', 
		'襦', '襪', '襭', '襯', '襲', '襴', '襷', '襾', '西', '要', '覃', '覆', '覇', '覈', '覊', '見', 
		'規', '覓', '視', '覗', '覘', '覚', '覡', '覦', '覧', '覩', '親', '覬', '覯', '覲', '観', '覺', 
		'覽', '覿', '觀', '角', '觚', '觜', '觝', '解', '触', '觧', '觴', '觸', '言', '訂', '訃', '計', 
		'訊', '訌', '討', '訐', '訓', '訖', '託', '記', '訛', '訝', '訟', '訣', '訥', '訪', '設', '許', 
		'訳', '訴', '訶', '診', '註', '証', '詁', '詆', '詈', '詐', '詑', '詒', '詔', '評', '詛', '詞', 
		'詠', '詢', '詣', '試', '詩', '詫', '詬', '詭', '詮', '詰', '話', '該', '詳', '詼', '誂', '誄', 
		'誅', '誇', '誉', '誌', '認', '誑', '誓', '誕', '誘', '誚', '語', '誠', '誡', '誣', '誤', '誥', 
		'誦', '誨', '説', '読', '誰', '課', '誹', '誼', '調', '諂', '諄', '談', '請', '諌', '諍', '諏', 
		'諒', '論', '諚', '諛', '諜', '諞', '諠', '諡', '諢', '諤', '諦', '諧', '諫', '諭', '諮', '諱', 
		'諳', '諷', '諸', '諺', '諾', '謀', '謁', '謂', '謄', '謇', '謌', '謎', '謐', '謔', '謖', '謗', 
		'謙', '謚', '講', '謝', '謠', '謡', '謦', '謨', '謫', '謬', '謳', '謹', '謾', '譁', '證', '譌', 
		'譎', '譏', '譖', '識', '譚', '譛', '譜', '譟', '警', '譫', '譬', '譯', '議', '譱', '譲', '譴', 
		'護', '譽', '讀', '讃', '變', '讌', '讎', '讐', '讒', '讓', '讖', '讙', '讚', '谷', '谺', '谿', 
		'豁', '豆', '豈', '豊', '豌', '豎', '豐', '豕', '豚', '象', '豢', '豪', '豫', '豬', '豸', '豹', 
		'豺', '豼', '貂', '貅', '貉', '貊', '貌', '貍', '貎', '貔', '貘', '貝', '貞', '負', '財', '貢', 
		'貧', '貨', '販', '貪', '貫', '責', '貭', '貮', '貯', '貰', '貲', '貳', '貴', '貶', '買', '貸', 
		'費', '貼', '貽', '貿', '賀', '賁', '賂', '賃', '賄', '資', '賈', '賊', '賍', '賎', '賑', '賓', 
		'賚', '賛', '賜', '賞', '賠', '賢', '賣', '賤', '賦', '質', '賭', '賺', '賻', '購', '賽', '贄', 
		'贅', '贇', '贈', '贊', '贋', '贍', '贏', '贐', '贓', '贔', '贖', '赤', '赦', '赧', '赫', '赭', 
		'走', '赱', '赳', '赴', '起', '趁', '超', '越', '趙', '趣', '趨', '足', '趺', '趾', '跂', '跋', 
		'跌', '跏', '跖', '跚', '跛', '距', '跟', '跡', '跣', '跨', '跪', '跫', '路', '跳', '践', '跼', 
		'跿', '踈', '踉', '踊', '踏', '踐', '踝', '踞', '踟', '踪', '踰', '踴', '踵', '蹂', '蹄', '蹇', 
		'蹈', '蹉', '蹊', '蹌', '蹐', '蹕', '蹙', '蹟', '蹠', '蹣', '蹤', '蹲', '蹴', '蹶', '蹼', '躁', 
		'躄', '躅', '躇', '躊', '躋', '躍', '躑', '躓', '躔', '躙', '躡', '躪', '身', '躬', '躯', '躰', 
		'躱', '躾', '軅', '軆', '軈', '車', '軋', '軌', '軍', '軒', '軛', '軟', '転', '軣', '軫', '軸', 
		'軻', '軼', '軽', '軾', '較', '輅', '載', '輊', '輌', '輒', '輓', '輔', '輕', '輙', '輛', '輜', 
		'輝', '輟', '輦', '輩', '輪', '輯', '輳', '輸', '輹', '輻', '輾', '輿', '轂', '轄', '轅', '轆', 
		'轉', '轌', '轍', '轎', '轗', '轜', '轟', '轡', '轢', '轣', '轤', '辛', '辜', '辞', '辟', '辣', 
		'辧', '辨', '辭', '辮', '辯', '辰', '辱', '農', '辷', '辺', '辻', '込', '辿', '迂', '迄', '迅', 
		'迎', '近', '返', '迚', '迢', '迥', '迦', '迩', '迪', '迫', '迭', '迯', '述', '迴', '迷', '迸', 
		'迹', '迺', '追', '退', '送', '逃', '逅', '逆', '逋', '逍', '逎', '透', '逐', '逑', '逓', '途', 
		'逕', '逖', '逗', '這', '通', '逝', '逞', '速', '造', '逡', '逢', '連', '逧', '逮', '週', '進', 
		'逵', '逶', '逸', '逹', '逼', '逾', '遁', '遂', '遅', '遇', '遉', '遊', '運', '遍', '過', '遏', 
		'遐', '遑', '遒', '道', '達', '違', '遖', '遘', '遙', '遜', '遞', '遠', '遡', '遣', '遥', '遨', 
		'適', '遭', '遮', '遯', '遲', '遵', '遶', '遷', '選', '遺', '遼', '遽', '避', '邀', '邁', '邂', 
		'邃', '還', '邇', '邉', '邊', '邏', '邑', '那', '邦', '邨', '邪', '邯', '邱', '邵', '邸', '郁', 
		'郊', '郎', '郛', '郡', '郢', '郤', '部', '郭', '郵', '郷', '都', '鄂', '鄒', '鄙', '鄭', '鄰', 
		'鄲', '酉', '酊', '酋', '酌', '配', '酎', '酒', '酔', '酖', '酘', '酢', '酣', '酥', '酩', '酪', 
		'酬', '酲', '酳', '酵', '酷', '酸', '醂', '醇', '醉', '醋', '醍', '醐', '醒', '醗', '醜', '醢', 
		'醤', '醪', '醫', '醯', '醴', '醵', '醸', '醺', '釀', '釁', '釆', '采', '釈', '釉', '釋', '里', 
		'重', '野', '量', '釐', '金', '釖', '釘', '釛', '釜', '針', '釟', '釡', '釣', '釦', '釧', '釵', 
		'釶', '釼', '釿', '鈍', '鈎', '鈑', '鈔', '鈕', '鈞', '鈩', '鈬', '鈴', '鈷', '鈿', '鉄', '鉅', 
		'鉈', '鉉', '鉋', '鉐', '鉗', '鉚', '鉛', '鉞', '鉢', '鉤', '鉦', '鉱', '鉾', '銀', '銃', '銅', 
		'銑', '銓', '銕', '銖', '銘', '銚', '銛', '銜', '銭', '銷', '銹', '鋏', '鋒', '鋤', '鋩', '鋪', 
		'鋭', '鋲', '鋳', '鋸', '鋺', '鋼', '錆', '錏', '錐', '錘', '錙', '錚', '錠', '錢', '錣', '錦', 
		'錨', '錫', '錬', '錮', '錯', '録', '錵', '錺', '錻', '鍄', '鍋', '鍍', '鍔', '鍖', '鍛', '鍜', 
		'鍠', '鍬', '鍮', '鍵', '鍼', '鍾', '鎌', '鎔', '鎖', '鎗', '鎚', '鎧', '鎬', '鎭', '鎮', '鎰', 
		'鎹', '鏃', '鏈', '鏐', '鏑', '鏖', '鏗', '鏘', '鏝', '鏡', '鏤', '鏥', '鏨', '鐃', '鐇', '鐐', 
		'鐓', '鐔', '鐘', '鐙', '鐚', '鐡', '鐫', '鐵', '鐶', '鐸', '鐺', '鑁', '鑄', '鑑', '鑒', '鑓', 
		'鑚', '鑛', '鑞', '鑠', '鑢', '鑪', '鑰', '鑵', '鑷', '鑼', '鑽', '鑾', '鑿', '钁', '長', '門', 
		'閂', '閃', '閇', '閉', '閊', '開', '閏', '閑', '間', '閔', '閖', '閘', '閙', '閠', '関', '閣', 
		'閤', '閥', '閧', '閨', '閭', '閲', '閹', '閻', '閼', '閾', '闃', '闇', '闊', '闌', '闍', '闔', 
		'闕', '闖', '闘', '關', '闡', '闢', '闥', '阜', '阡', '阨', '阪', '阮', '阯', '防', '阻', '阿', 
		'陀', '陂', '附', '陋', '陌', '降', '陏', '限', '陛', '陜', '陝', '陞', '陟', '院', '陣', '除', 
		'陥', '陦', '陪', '陬', '陰', '陲', '陳', '陵', '陶', '陷', '陸', '険', '陽', '隅', '隆', '隈', 
		'隊', '隋', '隍', '階', '随', '隔', '隕', '隗', '隘', '隙', '際', '障', '隠', '隣', '隧', '隨', 
		'險', '隰', '隱', '隲', '隴', '隶', '隷', '隸', '隹', '隻', '隼', '雀', '雁', '雄', '雅', '集', 
		'雇', '雉', '雋', '雌', '雍', '雎', '雑', '雕', '雖', '雙', '雛', '雜', '離', '難', '雨', '雪', 
		'雫', '雰', '雲', '零', '雷', '雹', '電', '需', '霄', '霆', '震', '霈', '霊', '霍', '霎', '霏', 
		'霑', '霓', '霖', '霙', '霜', '霞', '霤', '霧', '霪', '霰', '露', '霸', '霹', '霽', '霾', '靂', 
		'靄', '靆', '靈', '靉', '青', '靖', '静', '靜', '非', '靠', '靡', '面', '靤', '靦', '靨', '革', 
		'靫', '靭', '靱', '靴', '靹', '靺', '靼', '鞁', '鞄', '鞅', '鞆', '鞋', '鞍', '鞏', '鞐', '鞘', 
		'鞜', '鞠', '鞣', '鞦', '鞨', '鞫', '鞭', '鞳', '鞴', '韃', '韆', '韈', '韋', '韓', '韜', '韭', 
		'韮', '韲', '音', '韵', '韶', '韻', '響', '頁', '頂', '頃', '項', '順', '須', '頌', '頏', '預', 
		'頑', '頒', '頓', '頗', '領', '頚', '頡', '頤', '頬', '頭', '頴', '頷', '頸', '頻', '頼', '頽', 
		'顆', '顋', '題', '額', '顎', '顏', '顔', '顕', '願', '顛', '類', '顧', '顫', '顯', '顰', '顱', 
		'顳', '顴', '風', '颪', '颯', '颱', '颶', '飃', '飄', '飆', '飛', '飜', '食', '飢', '飩', '飫', 
		'飭', '飮', '飯', '飲', '飴', '飼', '飽', '飾', '餃', '餅', '餉', '養', '餌', '餐', '餒', '餓', 
		'餔', '餘', '餝', '餞', '餠', '餡', '餤', '館', '餬', '餮', '餽', '餾', '饂', '饅', '饉', '饋', 
		'饌', '饐', '饑', '饒', '饕', '饗', '首', '馗', '馘', '香', '馥', '馨', '馬', '馭', '馮', '馳', 
		'馴', '馼', '駁', '駄', '駅', '駆', '駈', '駐', '駑', '駒', '駕', '駘', '駛', '駝', '駟', '駢', 
		'駭', '駮', '駱', '駲', '駸', '駻', '駿', '騁', '騅', '騎', '騏', '騒', '験', '騙', '騨', '騫', 
		'騰', '騷', '騾', '驀', '驂', '驃', '驅', '驍', '驕', '驗', '驚', '驛', '驟', '驢', '驤', '驥', 
		'驩', '驪', '驫', '骨', '骭', '骰', '骸', '骼', '髀', '髄', '髏', '髑', '髓', '體', '高', '髞', 
		'髟', '髢', '髣', '髦', '髪', '髫', '髭', '髮', '髯', '髱', '髴', '髷', '髻', '鬆', '鬘', '鬚', 
		'鬟', '鬢', '鬣', '鬥', '鬧', '鬨', '鬩', '鬪', '鬮', '鬯', '鬱', '鬲', '鬻', '鬼', '魁', '魂', 
		'魃', '魄', '魅', '魍', '魎', '魏', '魑', '魔', '魘', '魚', '魯', '魴', '鮃', '鮎', '鮑', '鮒', 
		'鮓', '鮖', '鮗', '鮟', '鮠', '鮨', '鮪', '鮫', '鮭', '鮮', '鮴', '鮹', '鯀', '鯆', '鯉', '鯊', 
		'鯏', '鯑', '鯒', '鯔', '鯖', '鯛', '鯡', '鯢', '鯣', '鯤', '鯨', '鯰', '鯱', '鯲', '鯵', '鰄', 
		'鰆', '鰈', '鰉', '鰊', '鰌', '鰍', '鰐', '鰒', '鰓', '鰔', '鰕', '鰛', '鰡', '鰤', '鰥', '鰭', 
		'鰮', '鰯', '鰰', '鰲', '鰹', '鰺', '鰻', '鰾', '鱆', '鱇', '鱈', '鱒', '鱗', '鱚', '鱠', '鱧', 
		'鱶', '鱸', '鳥', '鳧', '鳩', '鳫', '鳬', '鳰', '鳳', '鳴', '鳶', '鴃', '鴆', '鴇', '鴈', '鴉', 
		'鴎', '鴒', '鴕', '鴛', '鴟', '鴣', '鴦', '鴨', '鴪', '鴫', '鴬', '鴻', '鴾', '鴿', '鵁', '鵄', 
		'鵆', '鵈', '鵐', '鵑', '鵙', '鵜', '鵝', '鵞', '鵠', '鵡', '鵤', '鵬', '鵯', '鵲', '鵺', '鶇', 
		'鶉', '鶏', '鶚', '鶤', '鶩', '鶫', '鶯', '鶲', '鶴', '鶸', '鶺', '鶻', '鷁', '鷂', '鷄', '鷆', 
		'鷏', '鷓', '鷙', '鷦', '鷭', '鷯', '鷲', '鷸', '鷹', '鷺', '鷽', '鸚', '鸛', '鸞', '鹵', '鹸', 
		'鹹', '鹽', '鹿', '麁', '麈', '麋', '麌', '麑', '麒', '麓', '麕', '麗', '麝', '麟', '麥', '麦', 
		'麩', '麪', '麭', '麸', '麹', '麺', '麻', '麼', '麾', '麿', '黄', '黌', '黍', '黎', '黏', '黐', 
		'黒', '黔', '默', '黙', '黛', '黜', '黝', '點', '黠', '黥', '黨', '黯', '黴', '黶', '黷', '黹', 
		'黻', '黼', '黽', '鼇', '鼈', '鼎', '鼓', '鼕', '鼠', '鼡', '鼬', '鼻', '鼾', '齊', '齋', '齎', 
		'齏', '齒', '齔', '齟', '齠', '齡', '齢', '齣', '齦', '齧', '齪', '齬', '齲', '齶', '齷', '龍', 
		'龕', '龜', '龝', '龠' );

	return( \@JIS_X_0208_KANJI );
}


sub GetNotJIS_X_0208_KANJI {
	my @NotJIS_X_0208_KANJI = (
		'丂', '丄', '丅', '丆', '丌', '丏', '丒', '专', '业', '丛', '东', '丝', '丟', '丠', '丢', '丣', 
		'两', '严', '丧', '丨', '丩', '丫', '丬', '丮', '丯', '丰', '丳', '临', '丵', '丷', '为', '丽', 
		'举', '乀', '乁', '乄', '乆', '乇', '么', '义', '乊', '乌', '乐', '乑', '乒', '乓', '乔', '乚', 
		'乛', '乜', '习', '乡', '乣', '乤', '乥', '书', '乧', '乨', '乩', '乪', '乫', '乬', '乭', '乮', 
		'乯', '买', '乲', '乴', '乵', '乶', '乷', '乸', '乹', '乺', '乻', '乼', '乽', '乿', '亁', '亃', 
		'亄', '亇', '亍', '亏', '亐', '亓', '亖', '亗', '亚', '亝', '亣', '产', '亩', '亪', '亯', '亱', 
		'亲', '亴', '亵', '亷', '亸', '亹', '亻', '亼', '亽', '亾', '亿', '仃', '仅', '仈', '仉', '仌', 
		'仐', '仑', '仒', '仓', '仚', '仛', '仜', '仠', '仡', '仢', '仦', '仧', '仨', '仩', '仪', '仫', 
		'们', '仯', '仱', '仳', '仴', '仵', '仸', '仹', '仺', '仼', '份', '仾', '仿', '伀', '伂', '伃', 
		'伄', '伅', '伆', '伇', '伈', '伋', '伌', '伒', '伓', '伔', '伕', '伖', '众', '优', '伙', '伛', 
		'伞', '伟', '传', '伡', '伢', '伣', '伤', '伥', '伦', '伧', '伨', '伩', '伪', '伫', '伬', '伭', 
		'伮', '伱', '伲', '伳', '伵', '伷', '伹', '伻', '伾', '伿', '佀', '佁', '佂', '佄', '佅', '佈', 
		'佉', '佊', '佋', '佌', '佒', '佔', '佖', '佘', '佟', '你', '佡', '佢', '佣', '佤', '佥', '佦', 
		'佧', '佨', '佪', '佫', '佬', '佭', '佮', '佱', '佲', '佴', '佷', '佸', '佹', '佺', '佽', '佾', 
		'侀', '侁', '侂', '侄', '侅', '侇', '侉', '侊', '侌', '侎', '侐', '侒', '侓', '侔', '侕', '侗', 
		'侙', '侚', '侜', '侞', '侟', '侢', '侣', '侤', '侥', '侦', '侧', '侨', '侩', '侪', '侬', '侰', 
		'侱', '侲', '侳', '侴', '侷', '侸', '侹', '侺', '侻', '侼', '侽', '侾', '俀', '俁', '俅', '俆', 
		'俇', '俈', '俉', '俋', '俌', '俍', '俏', '俒', '俓', '俕', '俖', '俙', '俜', '俞', '俠', '俢', 
		'俦', '俧', '俨', '俩', '俪', '俫', '俬', '俭', '俰', '俱', '俲', '俴', '俷', '俹', '俻', '俼', 
		'俽', '俿', '倀', '倁', '倂', '倃', '倄', '倇', '倈', '倊', '倌', '倎', '倐', '倓', '倕', '倗', 
		'倘', '倛', '倜', '倝', '倞', '倠', '倢', '倧', '倮', '倯', '倰', '倱', '倲', '倳', '倴', '倵', 
		'倷', '倸', '债', '倻', '值', '倽', '倾', '倿', '偀', '偁', '偂', '偄', '偅', '偆', '偊', '偋', 
		'偌', '偍', '偎', '偑', '偒', '偓', '偔', '偗', '偘', '偙', '偛', '偝', '偞', '偟', '偠', '偡', 
		'偢', '偣', '偤', '偦', '偧', '偨', '偩', '偪', '偫', '偭', '偮', '偯', '偰', '偱', '偳', '偷', 
		'偹', '偺', '偻', '偼', '偾', '偿', '傁', '傂', '傃', '傄', '傆', '傇', '傈', '傉', '傊', '傋', 
		'傌', '傎', '傏', '傐', '傒', '傓', '傔', '傕', '傖', '傗', '傛', '傜', '傝', '傞', '傟', '傠', 
		'傡', '傢', '傣', '傤', '傥', '傦', '傧', '储', '傩', '傪', '傫', '傮', '傯', '傰', '傱', '傶', 
		'傸', '傹', '傺', '傻', '傼', '傽', '傿', '僀', '僁', '僃', '僄', '僆', '僇', '僈', '僋', '僌', 
		'僎', '僐', '僒', '僓', '僔', '僗', '僘', '僙', '僛', '僜', '僝', '僟', '僠', '僡', '僢', '僤', 
		'僦', '僨', '僩', '僪', '僫', '僬', '僯', '僰', '僱', '僲', '僳', '僴', '僶', '僷', '僸', '僺', 
		'僼', '僽', '僾', '僿', '儃', '儅', '儆', '儇', '儈', '儊', '儋', '儌', '儍', '儎', '儏', '儐', 
		'儑', '儓', '儗', '儙', '儛', '儜', '儝', '儞', '儠', '儢', '儣', '儤', '儥', '儦', '儧', '儨', 
		'儩', '儫', '儬', '儭', '儮', '儯', '儰', '儱', '儳', '儴', '儵', '儶', '儸', '儹', '儽', '儾', 
		'兂', '兊', '兏', '兑', '兓', '兕', '兖', '兗', '兘', '兙', '兛', '兝', '兞', '兟', '兠', '兡', 
		'兣', '兤', '兦', '內', '兯', '兰', '兲', '关', '兴', '兹', '兺', '养', '兽', '兾', '兿', '冁', 
		'冃', '冄', '冇', '冈', '冋', '冎', '冔', '冘', '冚', '军', '农', '冝', '冞', '冟', '冡', '冣', 
		'冧', '冭', '冮', '冯', '冸', '冹', '冺', '冻', '冼', '冾', '冿', '净', '凁', '凂', '凃', '凇', 
		'凈', '凊', '凎', '减', '凐', '凑', '凒', '凓', '凔', '凕', '凗', '凘', '凙', '凚', '凞', '凟', 
		'凢', '凣', '凤', '凥', '凨', '凫', '凬', '凮', '凯', '凲', '凳', '凴', '凷', '击', '凼', '凿', 
		'刁', '刂', '刅', '刉', '刌', '刍', '刏', '刐', '划', '刓', '刕', '刖', '刘', '则', '刚', '创', 
		'刜', '刞', '刟', '删', '刡', '刢', '刣', '刦', '刨', '别', '刬', '刭', '刯', '刱', '刲', '刴', 
		'刵', '刼', '刽', '刾', '刿', '剀', '剁', '剂', '剅', '剆', '剈', '剉', '剎', '剐', '剑', '剒', 
		'剓', '剕', '剗', '剘', '剙', '剚', '剜', '剝', '剟', '剠', '剡', '剢', '剦', '剧', '剨', '剫', 
		'剬', '剭', '剮', '剶', '剷', '剸', '剹', '剺', '剻', '剼', '剾', '劀', '劁', '劂', '劄', '劅', 
		'劆', '劊', '劋', '劌', '劎', '劏', '劐', '劓', '劕', '劖', '劗', '劘', '劙', '劚', '劜', '劝', 
		'办', '务', '劢', '劤', '劥', '劦', '劧', '动', '劮', '劯', '劰', '劲', '劳', '劶', '劷', '劸', 
		'劺', '劻', '劽', '势', '勀', '勂', '勄', '勆', '勈', '勊', '勋', '勌', '勎', '勏', '勐', '勑', 
		'勓', '勔', '勖', '勚', '勛', '勜', '勡', '勥', '勨', '勩', '勪', '勫', '勬', '勭', '勮', '勯', 
		'勰', '勱', '勴', '勶', '勷', '勻', '勼', '勽', '匀', '匃', '匄', '匇', '匉', '匊', '匋', '匌', 
		'匎', '匑', '匒', '匓', '匔', '匘', '匛', '匜', '匞', '匟', '匢', '匤', '匥', '匦', '匧', '匨', 
		'匩', '匫', '匬', '匭', '匮', '匰', '匲', '匴', '匵', '匶', '匷', '匼', '匽', '匾', '卂', '卄', 
		'卋', '卌', '华', '协', '卐', '单', '卖', '卙', '卛', '卝', '卟', '卡', '卢', '卣', '卤', '卥', 
		'卧', '卨', '卪', '卫', '卬', '卭', '卲', '卶', '卹', '卺', '卼', '卽', '卾', '厀', '厁', '厃', 
		'厅', '历', '厇', '厈', '厉', '厊', '压', '厌', '厍', '厎', '厏', '厐', '厑', '厒', '厓', '厔', 
		'厕', '厗', '厙', '厛', '厜', '厝', '厞', '厡', '厢', '厣', '厤', '厧', '厪', '厫', '厬', '厯', 
		'厱', '厲', '厴', '厵', '厷', '厸', '厹', '厺', '厼', '厽', '厾', '县', '叀', '叁', '叄', '叅', 
		'叆', '叇', '叏', '叐', '发', '叒', '叓', '叕', '变', '叚', '叜', '叝', '叞', '叠', '另', '叧', 
		'叴', '叵', '叹', '叻', '叼', '叽', '叾', '叿', '吀', '吂', '吅', '吆', '吇', '吒', '吓', '吔', 
		'吕', '吖', '吗', '吘', '吙', '吚', '吜', '吞', '吡', '吢', '吣', '吤', '吥', '吧', '吨', '吪', 
		'启', '吰', '吱', '吲', '吳', '吴', '吵', '吷', '吺', '吿', '呁', '呃', '呄', '呅', '呇', '呋', 
		'呌', '呍', '呏', '呐', '呒', '呓', '呔', '呕', '呖', '呗', '员', '呙', '呚', '呛', '呜', '呝', 
		'呞', '呠', '呡', '呢', '呣', '呤', '呥', '呦', '呧', '呩', '呫', '呬', '呭', '呮', '呯', '呲', 
		'呴', '呸', '呹', '呺', '呾', '呿', '咁', '咂', '咃', '咅', '咇', '咈', '咉', '咊', '咍', '咑', 
		'咓', '咔', '咕', '咖', '咗', '咘', '咙', '咚', '咛', '咜', '咝', '咞', '咟', '咠', '咡', '咣', 
		'咦', '咧', '咩', '咪', '咭', '咮', '咰', '咱', '咴', '咵', '咶', '咷', '咹', '咺', '咻', '咿', 
		'哃', '哅', '哆', '哊', '哋', '哌', '响', '哎', '哏', '哐', '哑', '哒', '哓', '哔', '哕', '哖', 
		'哗', '哙', '哚', '哛', '哜', '哝', '哞', '哟', '哠', '哣', '哤', '哧', '哪', '哫', '哬', '哯', 
		'哰', '哱', '哳', '哴', '哵', '哶', '哷', '哸', '哹', '哻', '哼', '哾', '哿', '唀', '唁', '唂', 
		'唃', '唅', '唈', '唉', '唊', '唋', '唌', '唍', '唎', '唑', '唒', '唓', '唕', '唗', '唘', '唙', 
		'唚', '唛', '唜', '唝', '唞', '唟', '唠', '唡', '唢', '唣', '唤', '唥', '唦', '唧', '唨', '唩', 
		'唪', '唫', '唬', '唭', '唰', '唲', '唴', '唵', '唶', '唷', '唺', '唻', '唼', '唽', '唿', '啁', 
		'啂', '啃', '啇', '啈', '啉', '啊', '啋', '啍', '啎', '啐', '啑', '啒', '啔', '啕', '啘', '啙', 
		'啚', '啛', '啞', '啟', '啠', '啡', '啢', '啤', '啥', '啦', '啧', '啨', '啩', '啪', '啫', '啬', 
		'啭', '啮', '啯', '啰', '啱', '啲', '啳', '啴', '啵', '啶', '啷', '啸', '啹', '啺', '啽', '啿', 
		'喁', '喂', '喅', '喆', '喈', '喌', '喍', '喎', '喏', '喐', '喑', '喒', '喓', '喔', '喕', '喖', 
		'喗', '喛', '喠', '喡', '喢', '喣', '喤', '喥', '喦', '喭', '喯', '喱', '喲', '喳', '喴', '喵', 
		'喷', '喸', '喹', '喺', '喻', '喼', '喽', '喾', '喿', '嗀', '嗁', '嗂', '嗃', '嗆', '嗈', '嗉', 
		'嗊', '嗋', '嗌', '嗍', '嗎', '嗏', '嗐', '嗑', '嗒', '嗓', '嗕', '嗖', '嗗', '嗘', '嗙', '嗛', 
		'嗝', '嗞', '嗠', '嗡', '嗢', '嗥', '嗦', '嗧', '嗨', '嗩', '嗪', '嗫', '嗬', '嗭', '嗮', '嗯', 
		'嗰', '嗱', '嗲', '嗳', '嗴', '嗵', '嗶', '嗸', '嗺', '嗻', '嗼', '嗿', '嘀', '嘁', '嘂', '嘃', 
		'嘄', '嘅', '嘇', '嘈', '嘊', '嘋', '嘌', '嘍', '嘎', '嘏', '嘐', '嘑', '嘒', '嘓', '嘕', '嘙', 
		'嘚', '嘜', '嘝', '嘞', '嘟', '嘠', '嘡', '嘢', '嘣', '嘤', '嘥', '嘦', '嘧', '嘨', '嘪', '嘫', 
		'嘬', '嘭', '嘮', '嘰', '嘳', '嘵', '嘷', '嘹', '嘺', '嘻', '嘼', '嘽', '嘾', '嘿', '噀', '噁', 
		'噃', '噄', '噅', '噆', '噇', '噈', '噉', '噊', '噋', '噍', '噏', '噑', '噒', '噓', '噔', '噕', 
		'噖', '噗', '噘', '噙', '噚', '噜', '噝', '噞', '噟', '噠', '噡', '噢', '噣', '噥', '噦', '噧', 
		'噩', '噭', '噮', '噯', '噰', '噱', '噲', '噳', '噵', '噶', '噷', '噹', '噻', '噼', '噽', '噾', 
		'噿', '嚁', '嚂', '嚃', '嚄', '嚅', '嚈', '嚉', '嚋', '嚌', '嚍', '嚎', '嚐', '嚑', '嚒', '嚓', 
		'嚕', '嚖', '嚗', '嚘', '嚙', '嚚', '嚛', '嚜', '嚝', '嚞', '嚟', '嚡', '嚣', '嚤', '嚦', '嚧', 
		'嚨', '嚩', '嚪', '嚫', '嚬', '嚭', '嚯', '嚰', '嚱', '嚲', '嚳', '嚵', '嚷', '嚸', '嚹', '嚺', 
		'嚻', '嚽', '嚾', '嚿', '囄', '囅', '囆', '囇', '囉', '囊', '囋', '囌', '囍', '囏', '囐', '囒', 
		'囔', '囕', '囖', '囙', '囜', '囝', '囟', '囡', '团', '囤', '囥', '囦', '囧', '囨', '囩', '囪', 
		'囫', '囬', '园', '囯', '囱', '围', '囵', '囶', '囷', '囸', '囻', '囼', '图', '圁', '圂', '圅', 
		'圆', '圇', '圊', '圌', '圎', '圐', '圑', '圔', '圕', '圗', '圙', '圚', '圛', '圝', '圞', '圠', 
		'圡', '圢', '圣', '圤', '圥', '圩', '圪', '圫', '圬', '圮', '圯', '圱', '圲', '圳', '圴', '圵', 
		'圶', '圹', '场', '圼', '圽', '圾', '圿', '坁', '坃', '坄', '坅', '坆', '坈', '坉', '坋', '坌', 
		'坍', '坒', '坓', '坔', '坕', '坖', '块', '坘', '坙', '坚', '坛', '坜', '坝', '坞', '坟', '坠', 
		'坢', '坣', '坥', '坧', '坨', '坫', '坬', '坭', '坮', '坯', '坰', '坱', '坲', '坳', '坴', '坵', 
		'坶', '坷', '坸', '坹', '坺', '坻', '坼', '坽', '坾', '垀', '垁', '垃', '垄', '垅', '垆', '垇', 
		'垊', '垌', '垍', '垎', '垏', '垐', '垑', '垒', '垔', '垕', '垖', '垗', '垘', '垙', '垚', '垛', 
		'垜', '垝', '垞', '垟', '垡', '垥', '垦', '垧', '垨', '垩', '垫', '垬', '垭', '垮', '垯', '垱', 
		'垲', '垴', '垵', '垶', '垷', '垸', '垹', '垺', '垻', '垼', '垽', '垾', '垿', '埁', '埂', '埄', 
		'埅', '埇', '埈', '埉', '埊', '埌', '埍', '埏', '埐', '埑', '埕', '埗', '埘', '埙', '埚', '埛', 
		'埝', '埞', '埡', '埢', '埤', '埥', '埦', '埧', '埨', '埩', '埪', '埫', '埬', '埭', '埮', '埯', 
		'埰', '埱', '埲', '埳', '埵', '埶', '埸', '埻', '埽', '埾', '埿', '堁', '堃', '堄', '堇', '堈', 
		'堉', '堌', '堍', '堎', '堏', '堐', '堑', '堒', '堓', '堔', '堖', '堗', '堘', '堚', '堛', '堜', 
		'堞', '堟', '堠', '堢', '堣', '堥', '堦', '堧', '堨', '堩', '堫', '堬', '堭', '堮', '堲', '堳', 
		'堶', '堷', '堸', '堹', '堻', '堼', '堾', '堿', '塂', '塃', '塄', '塅', '塆', '塇', '塈', '塉', 
		'塌', '塍', '塎', '塏', '塐', '塓', '塕', '塖', '塛', '塜', '塝', '塟', '塠', '塡', '塣', '塤', 
		'塥', '塦', '塧', '塨', '塪', '塬', '塭', '塮', '塯', '塱', '塳', '塴', '塶', '塷', '塸', '塺', 
		'塻', '塼', '塽', '塿', '墀', '墁', '墂', '墄', '墆', '墇', '墈', '墉', '墊', '墋', '墌', '墍', 
		'墎', '墏', '墐', '墑', '墒', '墔', '墕', '墖', '墘', '墙', '墚', '墛', '墝', '增', '墠', '墡', 
		'墢', '墣', '墤', '墥', '墦', '墧', '墩', '墪', '墬', '墭', '墯', '墰', '墱', '墲', '墴', '墵', 
		'墶', '墷', '墼', '墽', '墿', '壀', '壂', '壃', '壄', '壆', '壈', '壉', '壋', '壍', '壎', '壏', 
		'壐', '壒', '壔', '壖', '壚', '壛', '壝', '壠', '壡', '壢', '壣', '壦', '壧', '壨', '壩', '壪', 
		'壭', '壳', '壴', '壵', '壶', '壸', '壾', '壿', '夀', '夁', '夃', '处', '夅', '夆', '备', '夈', 
		'夋', '夌', '复', '夎', '夑', '夒', '夓', '夔', '夗', '夝', '夞', '够', '夠', '夡', '夣', '夤', 
		'夦', '夨', '夯', '夰', '夳', '头', '夵', '夶', '夹', '夺', '夻', '夼', '夽', '夿', '奀', '奁', 
		'奂', '奃', '奅', '奆', '奊', '奋', '奌', '奍', '奒', '奓', '奖', '奙', '奛', '奜', '奝', '奞', 
		'奟', '奡', '奣', '奤', '奦', '奫', '奭', '奯', '奰', '奱', '奲', '奵', '奶', '奷', '她', '奺', 
		'奻', '奼', '奾', '奿', '妀', '妅', '妆', '妇', '妈', '妉', '妋', '妌', '妎', '妏', '妐', '妑', 
		'妒', '妔', '妕', '妗', '妘', '妚', '妜', '妞', '妟', '妠', '妡', '妢', '妤', '妦', '妧', '妩', 
		'妪', '妫', '妭', '妮', '妯', '妰', '妱', '妳', '妴', '妵', '妶', '妷', '妸', '妺', '妼', '妽', 
		'妿', '姀', '姁', '姂', '姃', '姄', '姅', '姇', '姈', '姊', '姌', '姍', '姎', '姏', '姒', '姕', 
		'姖', '姗', '姘', '姛', '姝', '姞', '姟', '姠', '姡', '姢', '姣', '姤', '姧', '姩', '姬', '姭', 
		'姮', '姯', '姰', '姱', '姲', '姳', '姴', '姵', '姷', '姸', '姹', '姺', '姼', '姽', '姾', '娀', 
		'娂', '娄', '娅', '娆', '娇', '娈', '娊', '娋', '娌', '娍', '娎', '娏', '娐', '娒', '娓', '娔', 
		'娕', '娖', '娗', '娙', '娛', '娝', '娞', '娡', '娢', '娣', '娤', '娦', '娧', '娨', '娪', '娫', 
		'娬', '娭', '娮', '娰', '娱', '娲', '娳', '娴', '娷', '娸', '娹', '娺', '娻', '娽', '娾', '娿', 
		'婂', '婃', '婄', '婅', '婇', '婈', '婊', '婋', '婌', '婍', '婎', '婏', '婐', '婑', '婒', '婓', 
		'婔', '婕', '婖', '婗', '婘', '婙', '婛', '婜', '婝', '婞', '婟', '婠', '婡', '婣', '婤', '婥', 
		'婧', '婨', '婩', '婫', '婭', '婮', '婯', '婰', '婱', '婲', '婳', '婴', '婵', '婶', '婷', '婸', 
		'婹', '婺', '婻', '婼', '婽', '婾', '媀', '媁', '媂', '媃', '媄', '媅', '媆', '媇', '媈', '媉', 
		'媊', '媋', '媌', '媍', '媎', '媏', '媐', '媑', '媓', '媔', '媕', '媖', '媗', '媘', '媙', '媜', 
		'媝', '媞', '媟', '媠', '媡', '媢', '媣', '媤', '媥', '媦', '媧', '媨', '媩', '媪', '媫', '媬', 
		'媭', '媮', '媯', '媰', '媱', '媲', '媳', '媴', '媵', '媶', '媷', '媸', '媹', '媺', '媻', '媿', 
		'嫀', '嫃', '嫄', '嫅', '嫆', '嫇', '嫈', '嫊', '嫍', '嫎', '嫏', '嫑', '嫒', '嫓', '嫔', '嫕', 
		'嫘', '嫙', '嫚', '嫛', '嫜', '嫝', '嫞', '嫟', '嫠', '嫢', '嫤', '嫥', '嫧', '嫨', '嫪', '嫫', 
		'嫬', '嫭', '嫮', '嫯', '嫰', '嫱', '嫲', '嫳', '嫴', '嫵', '嫶', '嫷', '嫸', '嫹', '嫼', '嫽', 
		'嫾', '嫿', '嬀', '嬁', '嬂', '嬃', '嬄', '嬅', '嬆', '嬇', '嬈', '嬊', '嬍', '嬎', '嬏', '嬐', 
		'嬑', '嬒', '嬓', '嬔', '嬕', '嬗', '嬘', '嬙', '嬚', '嬛', '嬜', '嬝', '嬞', '嬟', '嬠', '嬡', 
		'嬣', '嬤', '嬥', '嬦', '嬧', '嬨', '嬩', '嬫', '嬭', '嬮', '嬯', '嬱', '嬳', '嬴', '嬵', '嬷', 
		'嬸', '嬹', '嬺', '嬻', '嬼', '嬽', '嬿', '孁', '孂', '孄', '孆', '孇', '孈', '孉', '孊', '孋', 
		'孌', '孍', '孎', '孏', '孒', '孓', '孖', '孙', '孞', '孠', '孡', '孢', '孧', '孨', '孪', '孬', 
		'孭', '孮', '孯', '孲', '孴', '孶', '孷', '孹', '孻', '孼', '孽', '孾', '孿', '宁', '宂', '宄', 
		'宆', '宊', '宎', '宐', '宑', '宒', '宓', '宔', '宖', '实', '宠', '审', '宧', '宨', '宩', '宪', 
		'宫', '宬', '宭', '宯', '宱', '宲', '宷', '宺', '宻', '宼', '宽', '宾', '寀', '寁', '寈', '寊', 
		'寋', '寍', '寎', '寏', '寑', '寕', '寖', '寗', '寘', '寙', '寚', '寜', '寠', '寣', '寪', '寬', 
		'寭', '寯', '寱', '寲', '寴', '寷', '对', '寻', '导', '寽', '尀', '尃', '尌', '尐', '尒', '尔', 
		'尕', '尗', '尘', '尙', '尛', '尜', '尝', '尞', '尟', '尡', '尣', '尥', '尦', '尧', '尩', '尪', 
		'尫', '尬', '尮', '尯', '尰', '尲', '尳', '尴', '尵', '尶', '尷', '层', '屃', '屄', '屇', '屉', 
		'屌', '屒', '屔', '屖', '屗', '屘', '屙', '屚', '屛', '屜', '屝', '屟', '屢', '屣', '屦', '屧', 
		'屨', '屩', '屪', '屫', '屭', '屰', '屲', '屳', '屴', '屵', '屷', '屸', '屺', '屻', '屼', '屽', 
		'屾', '屿', '岀', '岁', '岂', '岃', '岄', '岅', '岆', '岇', '岈', '岉', '岊', '岋', '岍', '岎', 
		'岏', '岒', '岓', '岕', '岖', '岗', '岘', '岙', '岚', '岛', '岜', '岝', '岞', '岟', '岠', '岢', 
		'岣', '岤', '岥', '岦', '岧', '岪', '岭', '岮', '岯', '岰', '岲', '岴', '岵', '岹', '岺', '岽', 
		'岿', '峀', '峁', '峂', '峃', '峄', '峆', '峈', '峉', '峊', '峋', '峌', '峍', '峎', '峏', '峐', 
		'峑', '峒', '峓', '峔', '峕', '峖', '峗', '峘', '峚', '峛', '峜', '峝', '峞', '峟', '峢', '峣', 
		'峤', '峥', '峦', '峧', '峫', '峬', '峮', '峱', '峲', '峳', '峴', '峵', '峷', '峸', '峹', '峼', 
		'峾', '峿', '崀', '崁', '崂', '崃', '崄', '崅', '崆', '崈', '崉', '崊', '崌', '崍', '崏', '崐', 
		'崒', '崓', '崜', '崝', '崞', '崠', '崡', '崣', '崤', '崥', '崦', '崧', '崨', '崪', '崫', '崬', 
		'崭', '崮', '崯', '崰', '崱', '崲', '崳', '崴', '崵', '崶', '崷', '崸', '崹', '崺', '崻', '崼', 
		'崽', '崾', '崿', '嵀', '嵁', '嵂', '嵃', '嵄', '嵅', '嵆', '嵇', '嵈', '嵉', '嵊', '嵍', '嵏', 
		'嵑', '嵓', '嵔', '嵕', '嵖', '嵗', '嵘', '嵙', '嵚', '嵛', '嵝', '嵞', '嵟', '嵠', '嵡', '嵢', 
		'嵣', '嵤', '嵥', '嵦', '嵧', '嵨', '嵪', '嵫', '嵭', '嵮', '嵰', '嵱', '嵲', '嵴', '嵵', '嵷', 
		'嵸', '嵹', '嵺', '嵻', '嵼', '嵽', '嵾', '嵿', '嶀', '嶁', '嶃', '嶅', '嶆', '嶈', '嶉', '嶊', 
		'嶍', '嶎', '嶏', '嶑', '嶒', '嶓', '嶔', '嶕', '嶖', '嶗', '嶘', '嶙', '嶚', '嶛', '嶜', '嶞', 
		'嶟', '嶠', '嶡', '嶣', '嶤', '嶥', '嶦', '嶧', '嶨', '嶩', '嶪', '嶫', '嶭', '嶯', '嶰', '嶱', 
		'嶲', '嶳', '嶴', '嶵', '嶶', '嶸', '嶹', '嶻', '嶾', '嶿', '巀', '巁', '巂', '巃', '巄', '巅', 
		'巆', '巇', '巈', '巊', '巋', '巎', '巏', '巐', '巑', '巔', '巕', '巗', '巘', '巙', '巚', '巜', 
		'巟', '巠', '巢', '巤', '巩', '巪', '巬', '巭', '巯', '巰', '巶', '巸', '巹', '巺', '巼', '巿', 
		'帀', '币', '帄', '帅', '帇', '师', '帉', '帊', '帍', '帎', '帏', '帐', '帒', '帓', '帔', '帕', 
		'帗', '帘', '帜', '帞', '帟', '帠', '帡', '帢', '帣', '帤', '带', '帧', '帨', '帩', '帪', '帬', 
		'帮', '帱', '帲', '帴', '帵', '帹', '帺', '帻', '帼', '帾', '帿', '幁', '幂', '幆', '幈', '幉', 
		'幊', '幋', '幍', '幏', '幐', '幑', '幒', '幓', '幖', '幘', '幙', '幚', '幛', '幜', '幝', '幞', 
		'幠', '幥', '幦', '幧', '幨', '幩', '幪', '幫', '幬', '幭', '幮', '幯', '幰', '幱', '幷', '庀', 
		'庂', '庅', '庆', '庈', '庉', '庋', '庌', '庍', '庎', '庐', '庑', '庒', '库', '应', '庘', '庙', 
		'庛', '庝', '庞', '废', '庡', '庢', '庣', '庤', '庥', '庨', '庩', '庪', '庬', '庮', '庯', '庰', 
		'庱', '庲', '庳', '庴', '庹', '庺', '庻', '庼', '庽', '庾', '庿', '廀', '廄', '廅', '廆', '廇', 
		'廋', '廌', '廍', '廎', '廑', '廒', '廔', '廕', '廗', '廘', '廙', '廜', '廞', '廤', '廥', '廦', 
		'廧', '廪', '廫', '廭', '廮', '廯', '廲', '廵', '廹', '廽', '开', '异', '弅', '弆', '弇', '弈', 
		'弎', '弒', '弙', '弚', '弜', '弝', '弞', '张', '弡', '弢', '弣', '弤', '弨', '弪', '弫', '弬', 
		'弮', '弰', '弲', '弳', '弴', '弶', '弹', '强', '弻', '弽', '弿', '彀', '彂', '彃', '彄', '彅', 
		'彆', '彇', '彉', '彋', '彍', '彏', '彐', '归', '彔', '录', '彘', '彚', '彛', '彞', '彟', '彠', 
		'彣', '彤', '彥', '彧', '彨', '彮', '彯', '彲', '彴', '彵', '彶', '彸', '彺', '彻', '彽', '彾', 
		'徆', '徉', '徍', '徎', '徏', '徔', '徕', '徖', '徚', '徛', '徜', '徝', '徟', '徢', '徣', '徤', 
		'徥', '徦', '徧', '徫', '徬', '徯', '徰', '徱', '徲', '徵', '徶', '德', '徸', '徺', '徻', '徾', 
		'徿', '忀', '忁', '忂', '忄', '忆', '忇', '忈', '忉', '忊', '忋', '忎', '忏', '忐', '忑', '忒', 
		'忓', '忔', '忕', '忚', '忛', '忞', '忟', '忡', '忢', '忣', '忥', '忦', '忧', '忨', '忩', '忪', 
		'忬', '忭', '忮', '忯', '忲', '忳', '忴', '忶', '忷', '忹', '忺', '忼', '忾', '怀', '态', '怂', 
		'怃', '怄', '怅', '怆', '怇', '怈', '怉', '怊', '怋', '怌', '怍', '怑', '怓', '怔', '怗', '怘', 
		'怚', '怞', '怟', '怢', '怣', '怤', '怬', '怭', '怮', '怰', '怲', '怳', '怴', '怵', '怶', '怷', 
		'怸', '怹', '总', '怼', '怽', '怾', '怿', '恀', '恄', '恅', '恇', '恈', '恉', '恌', '恎', '恏', 
		'恑', '恓', '恔', '恖', '恗', '恘', '恛', '恜', '恝', '恞', '恡', '恦', '恧', '恮', '恱', '恲', 
		'恳', '恴', '恶', '恸', '恹', '恺', '恻', '恼', '恽', '恾', '恿', '悀', '悂', '悅', '悆', '悇', 
		'悈', '悊', '悎', '悏', '悐', '悑', '悓', '悕', '悘', '悙', '悜', '悝', '悞', '悡', '悢', '悤', 
		'悥', '您', '悫', '悬', '悭', '悮', '悯', '悰', '悱', '悷', '悹', '悺', '悻', '悾', '悿', '惀', 
		'惁', '惂', '惃', '惄', '惈', '惉', '惊', '惋', '惌', '惍', '惎', '惏', '惐', '惒', '惔', '惕', 
		'惖', '惗', '惙', '惛', '惝', '惞', '惢', '惤', '惥', '惦', '惩', '惪', '惫', '惬', '惭', '惮', 
		'惯', '惲', '惵', '惸', '惼', '惽', '惾', '惿', '愂', '愄', '愅', '愇', '愊', '愋', '愌', '愐', 
		'愑', '愒', '愓', '愔', '愖', '愗', '愘', '愙', '愜', '愝', '愞', '愠', '愢', '愣', '愤', '愥', 
		'愦', '愩', '愪', '愫', '愭', '愮', '愯', '愰', '愱', '愲', '愳', '愵', '愶', '愷', '愸', '愹', 
		'愺', '愻', '慀', '慁', '慃', '慅', '慆', '慉', '慏', '慐', '慑', '慒', '慔', '慖', '慗', '慛', 
		'慜', '慞', '慠', '慡', '慤', '慦', '慩', '慪', '慬', '慭', '慲', '慸', '慹', '慺', '慻', '慼', 
		'慽', '慿', '憀', '憁', '憃', '憄', '憅', '憆', '憈', '憉', '憋', '憌', '憍', '憏', '憒', '憓', 
		'憕', '憗', '憘', '憛', '憜', '憝', '憞', '憟', '憠', '憡', '憢', '憣', '憥', '憦', '憨', '憪', 
		'憭', '憯', '憰', '憱', '憳', '憴', '憵', '憷', '憸', '憹', '憻', '憼', '憽', '憿', '懀', '懁', 
		'懂', '懄', '懅', '懎', '懏', '懑', '懒', '懓', '懔', '懕', '懖', '懗', '懘', '懙', '懚', '懛', 
		'懜', '懝', '懞', '懟', '懠', '懡', '懢', '懤', '懥', '懧', '懨', '懩', '懪', '懫', '懬', '懭', 
		'懮', '懯', '懰', '懱', '懳', '懵', '懹', '懻', '戁', '戂', '戃', '戄', '戅', '戆', '戇', '戋', 
		'戏', '戓', '戕', '戗', '战', '戙', '戜', '戠', '戢', '戣', '戤', '戥', '戧', '戨', '戩', '戫', 
		'戬', '戭', '戱', '戵', '戶', '户', '戹', '戺', '戼', '戽', '戾', '扂', '扃', '扄', '扅', '扆', 
		'扊', '扌', '扏', '扐', '扑', '扒', '扔', '扖', '扗', '扙', '扚', '扜', '扝', '扟', '扡', '扢', 
		'扤', '扥', '扦', '执', '扩', '扪', '扫', '扬', '扭', '扯', '扰', '扲', '扳', '扴', '扵', '扷', 
		'扸', '扺', '扻', '扽', '抁', '抅', '抆', '抇', '抈', '抋', '抌', '抍', '抎', '抏', '抐', '抙', 
		'抚', '抝', '抟', '抠', '抡', '抢', '抣', '护', '报', '抦', '抧', '抨', '抩', '抪', '抭', '抮', 
		'抯', '抰', '抲', '抳', '抴', '抶', '抷', '抸', '抺', '抾', '抿', '拀', '拁', '拃', '拄', '拋', 
		'拎', '拕', '拖', '拚', '拞', '拟', '拢', '拣', '拤', '拥', '拦', '拧', '拨', '择', '拪', '拫', 
		'拰', '拲', '拴', '拸', '拹', '拺', '拻', '拼', '拽', '挀', '挃', '挄', '挅', '挆', '挊', '挋', 
		'挍', '挎', '挏', '挐', '挒', '挓', '挔', '挕', '挖', '挗', '挘', '挚', '挛', '挜', '挝', '挞', 
		'挠', '挡', '挢', '挣', '挤', '挥', '挦', '挩', '挪', '挬', '挭', '挮', '挰', '挱', '挲', '挳', 
		'挴', '挵', '挶', '挷', '挸', '挹', '挻', '挼', '捀', '捁', '捂', '捃', '捄', '捅', '捆', '捇', 
		'捈', '捊', '捋', '捎', '捑', '捒', '捓', '捔', '捖', '捘', '捙', '捚', '捛', '捝', '捞', '损', 
		'捠', '捡', '换', '捣', '捤', '捥', '捦', '捪', '捬', '捭', '捯', '捰', '捱', '捳', '捴', '捵', 
		'捸', '捹', '捼', '捽', '捾', '捿', '掁', '掂', '掄', '掅', '掆', '掇', '掊', '掋', '掍', '掐', 
		'掑', '掓', '掔', '掕', '掗', '掙', '掚', '掜', '掝', '掞', '掤', '掦', '掭', '掮', '掯', '掰', 
		'掱', '掳', '掶', '掷', '掸', '掹', '掺', '掼', '掽', '掿', '揁', '揂', '揅', '揇', '揈', '揊', 
		'揋', '揌', '揍', '揎', '揑', '揓', '揔', '揕', '揗', '揘', '揙', '揜', '揝', '揞', '揟', '揠', 
		'揢', '揤', '揥', '揦', '揧', '揨', '揪', '揫', '揬', '揭', '揯', '揰', '揱', '揲', '揳', '揵', 
		'揷', '揸', '揹', '揻', '揼', '揽', '揾', '揿', '搀', '搁', '搂', '搃', '搄', '搅', '搇', '搈', 
		'搉', '搊', '搋', '搌', '搎', '搐', '搑', '搒', '搔', '搕', '搘', '搙', '搚', '搛', '搝', '搞', 
		'搟', '搠', '搡', '搢', '搣', '搤', '搥', '搧', '搩', '搪', '搫', '搮', '搯', '搰', '搱', '搲', 
		'搳', '搵', '搷', '搸', '搹', '搻', '搼', '搽', '搿', '摀', '摁', '摃', '摄', '摅', '摆', '摇', 
		'摈', '摉', '摊', '摋', '摌', '摍', '摏', '摐', '摑', '摒', '摓', '摔', '摕', '摖', '摗', '摙', 
		'摚', '摛', '摜', '摝', '摞', '摟', '摠', '摡', '摢', '摣', '摤', '摥', '摦', '摨', '摪', '摫', 
		'摬', '摭', '摮', '摰', '摱', '摲', '摳', '摴', '摵', '摷', '摹', '摻', '摼', '摽', '摾', '摿', 
		'撀', '撁', '撂', '撄', '撅', '撆', '撇', '撉', '撊', '撋', '撌', '撍', '撎', '撏', '撐', '撑', 
		'撔', '撖', '撗', '撘', '撙', '撛', '撜', '撝', '撟', '撠', '撡', '撢', '撣', '撦', '撧', '撨', 
		'撪', '撬', '撯', '撱', '撳', '撴', '撵', '撶', '撷', '撸', '撺', '撽', '撾', '撿', '擀', '擃', 
		'擄', '擆', '擈', '擉', '擊', '擋', '擌', '擎', '擏', '擐', '擑', '擓', '擕', '擖', '擗', '擙', 
		'擛', '擜', '擝', '擞', '擟', '擤', '擥', '擨', '擩', '擪', '擫', '擭', '擮', '擰', '擳', '擵', 
		'擷', '擸', '擹', '擻', '擼', '擿', '攁', '攂', '攃', '攄', '攆', '攇', '攈', '攉', '攊', '攋', 
		'攌', '攍', '攎', '攏', '攐', '攑', '攒', '攓', '攔', '攕', '攖', '攗', '攙', '攚', '攛', '攞', 
		'攟', '攠', '攡', '攢', '攥', '攦', '攧', '攨', '攩', '攭', '攮', '攰', '攱', '攲', '攳', '攺', 
		'攼', '攽', '敀', '敁', '敂', '敃', '敄', '敆', '敇', '敉', '敊', '敋', '敌', '敎', '敐', '敒', 
		'敓', '敔', '敚', '敛', '敜', '敟', '敠', '敡', '敤', '敥', '敧', '敨', '敩', '敪', '敫', '敭', 
		'敮', '敯', '敱', '敳', '敶', '敹', '敺', '敻', '敼', '敽', '敾', '敿', '斀', '斁', '斄', '斅', 
		'斆', '斊', '斋', '斍', '斏', '斒', '斓', '斔', '斕', '斖', '斘', '斚', '斝', '斞', '斠', '斢', 
		'斣', '斦', '斨', '斩', '斪', '斮', '斱', '斲', '斳', '斴', '斵', '斶', '斸', '斺', '斻', '斾', 
		'斿', '旀', '旂', '旇', '旈', '旉', '旊', '旍', '旎', '旐', '旑', '旓', '旔', '旕', '旖', '旘', 
		'旚', '旜', '旝', '旞', '旟', '旣', '旤', '旪', '旫', '旮', '旯', '旰', '旲', '旳', '旴', '旵', 
		'时', '旷', '旸', '旹', '旼', '旽', '旾', '旿', '昀', '昁', '昄', '昅', '昈', '昉', '昋', '昍', 
		'昐', '昑', '昒', '昕', '昖', '昗', '昘', '昙', '昚', '昛', '昝', '昞', '昡', '昢', '昣', '昤', 
		'昦', '昩', '昪', '昫', '昬', '昮', '昰', '昱', '昲', '昳', '昷', '昸', '昹', '昺', '昻', '昽', 
		'显', '晀', '晅', '晆', '晇', '晈', '晊', '晌', '晍', '晎', '晐', '晑', '晓', '晔', '晕', '晖', 
		'晗', '晘', '晙', '晚', '晛', '晜', '晠', '晡', '晣', '晥', '晪', '晫', '晬', '晭', '晱', '晲', 
		'晳', '晵', '晷', '晸', '晹', '晻', '晼', '晽', '晾', '晿', '暀', '暂', '暅', '暆', '暊', '暋', 
		'暌', '暍', '暏', '暐', '暒', '暓', '暔', '暕', '暙', '暚', '暛', '暜', '暞', '暟', '暠', '暡', 
		'暣', '暤', '暥', '暧', '暨', '暩', '暪', '暬', '暭', '暯', '暰', '暱', '暲', '暳', '暵', '暶', 
		'暷', '暺', '暻', '暽', '暿', '曀', '曂', '曃', '曅', '曆', '曈', '曊', '曋', '曌', '曍', '曎', 
		'曏', '曐', '曑', '曒', '曓', '曔', '曕', '曗', '曘', '曛', '曞', '曟', '曡', '曢', '曣', '曤', 
		'曥', '曧', '曨', '曪', '曫', '曬', '曭', '曮', '曯', '曱', '曶', '曺', '曻', '朁', '朂', '朄', 
		'朅', '朆', '朇', '朊', '朌', '朎', '朐', '朑', '朒', '朓', '朘', '朙', '朚', '朜', '朠', '朡', 
		'朢', '朣', '朤', '朥', '朩', '术', '朰', '朲', '朳', '朵', '朹', '朻', '朼', '朾', '杀', '杂', 
		'权', '杄', '杅', '杇', '杈', '杊', '杋', '杌', '杍', '杒', '杔', '杕', '杗', '杘', '杚', '杛', 
		'杝', '杦', '杧', '杨', '杩', '杫', '杬', '杮', '杴', '杶', '杸', '杹', '杺', '杻', '杽', '枀', 
		'极', '枂', '枃', '构', '枆', '枈', '枊', '枍', '枎', '枏', '枑', '枒', '枓', '枔', '枖', '枘', 
		'枙', '枛', '枞', '枟', '枣', '枤', '枥', '枧', '枨', '枪', '枫', '枬', '枭', '枮', '枰', '枱', 
		'枲', '枵', '枺', '枻', '枼', '枽', '枾', '枿', '柀', '柂', '柃', '柅', '柇', '柈', '柉', '柋', 
		'柌', '柍', '柒', '柕', '柖', '柗', '柙', '柛', '柜', '柟', '柠', '柡', '柣', '查', '柦', '柨', 
		'柪', '柫', '柭', '柰', '柲', '柶', '柷', '柸', '柹', '柺', '柼', '柽', '栀', '栁', '栅', '栆', 
		'标', '栈', '栉', '栊', '栋', '栌', '栍', '栎', '栏', '栐', '树', '栒', '栔', '栕', '栘', '栙', 
		'栚', '栛', '栜', '栝', '栟', '栠', '栣', '栤', '栥', '栦', '栧', '栨', '栬', '栭', '栮', '栯', 
		'栰', '栱', '栳', '栵', '栶', '样', '栺', '栻', '栾', '栿', '桄', '桅', '桇', '桉', '桊', '桋', 
		'桌', '桏', '桒', '桕', '桖', '桗', '桘', '桚', '桛', '桞', '桠', '桡', '桢', '桤', '桥', '桦', 
		'桨', '桩', '桪', '桫', '桬', '桭', '桮', '桯', '桰', '桱', '桲', '桳', '桵', '桸', '桹', '桺', 
		'桻', '桼', '桽', '梀', '梂', '梄', '梆', '梇', '梈', '梉', '梊', '梋', '梌', '梎', '梐', '梑', 
		'梒', '梕', '梖', '梘', '梙', '梚', '梜', '梞', '梡', '梣', '梤', '梥', '梩', '梪', '梫', '梬', 
		'梮', '梲', '梴', '梷', '梸', '梻', '梽', '梾', '梿', '检', '棁', '棂', '棃', '棅', '棇', '棈', 
		'棌', '棎', '棏', '棐', '棑', '棓', '棖', '棙', '棛', '棜', '棝', '棞', '棢', '棤', '棥', '棦', 
		'棨', '棩', '棪', '棫', '棬', '棭', '棰', '棱', '棳', '棴', '棵', '棶', '棷', '棸', '棻', '棼', 
		'棽', '棾', '棿', '椂', '椃', '椆', '椇', '椉', '椊', '椐', '椑', '椓', '椔', '椕', '椖', '椗', 
		'椘', '椝', '椞', '椟', '椠', '椤', '椧', '椩', '椫', '椬', '椭', '椮', '椯', '椱', '椲', '椳', 
		'椵', '椷', '椸', '椺', '椻', '椼', '椾', '楀', '楁', '楂', '楃', '楄', '楅', '楆', '楇', '楈', 
		'楉', '楋', '楌', '楍', '楎', '楏', '楐', '楑', '楒', '楖', '楗', '楘', '楛', '楟', '楣', '楤', 
		'楥', '楦', '楧', '楨', '楩', '楬', '楰', '楱', '楲', '楶', '楺', '楻', '楿', '榀', '榃', '榄', 
		'榅', '榆', '榇', '榈', '榉', '榋', '榌', '榍', '榏', '榐', '榒', '榓', '榖', '榗', '榘', '榙', 
		'榚', '榝', '榞', '榟', '榡', '榢', '榣', '榤', '榥', '榦', '榨', '榩', '榪', '榫', '榬', '榭', 
		'榯', '榰', '榳', '榵', '榶', '榷', '榸', '榹', '榺', '榼', '榽', '槀', '槂', '槄', '槅', '槆', 
		'槈', '槉', '槏', '槑', '槒', '槔', '槕', '槖', '槗', '槚', '槛', '槜', '槟', '槠', '槡', '槢', 
		'槣', '槤', '槥', '槦', '槩', '槪', '槬', '槮', '槯', '槰', '槱', '槳', '槴', '槵', '槶', '槷', 
		'槸', '槺', '槼', '槾', '樀', '樁', '樃', '樄', '樆', '樇', '樈', '樉', '樍', '樎', '樏', '樐', 
		'樑', '樕', '樖', '樘', '樚', '樜', '樝', '樠', '樤', '樥', '樦', '樧', '樨', '樬', '樭', '樯', 
		'樰', '樱', '樲', '樳', '樴', '樷', '樻', '樼', '樾', '樿', '橀', '橁', '橂', '橃', '橅', '橆', 
		'橉', '橊', '橌', '橍', '橎', '橏', '橐', '橑', '橒', '橓', '橔', '橕', '橖', '橗', '橚', '橛', 
		'橜', '橝', '橞', '橠', '橣', '橤', '橥', '橧', '橨', '橩', '橪', '橫', '橬', '橭', '橮', '橯', 
		'橰', '橱', '橳', '橴', '橵', '橶', '橷', '橹', '橺', '橻', '橼', '橽', '橾', '檁', '檂', '檃', 
		'檅', '檆', '檇', '檈', '檉', '檊', '檋', '檌', '檏', '檑', '檒', '檓', '檔', '檕', '檖', '檘', 
		'檙', '檚', '檛', '檝', '檞', '檟', '檡', '檤', '檥', '檦', '檧', '檨', '檩', '檫', '檭', '檯', 
		'檰', '檱', '檲', '檴', '檵', '檶', '檷', '檹', '檺', '檼', '檽', '檾', '檿', '櫀', '櫄', '櫅', 
		'櫆', '櫇', '櫈', '櫉', '櫊', '櫋', '櫌', '櫍', '櫎', '櫏', '櫐', '櫒', '櫔', '櫕', '櫖', '櫗', 
		'櫘', '櫙', '櫜', '櫝', '櫠', '櫡', '櫢', '櫣', '櫤', '櫥', '櫦', '櫧', '櫩', '櫫', '櫬', '櫭', 
		'櫮', '櫯', '櫰', '櫱', '櫲', '櫳', '櫴', '櫵', '櫶', '櫷', '櫸', '櫹', '櫼', '櫽', '櫾', '櫿', 
		'欀', '欁', '欂', '欃', '欆', '欇', '欈', '欉', '欋', '欌', '欍', '欎', '欏', '欐', '欑', '欓', 
		'欔', '欕', '欗', '欘', '欙', '欚', '欛', '欜', '欞', '欢', '欤', '欥', '欦', '欨', '欩', '欪', 
		'欫', '欬', '欭', '欮', '欯', '欰', '欱', '欳', '欴', '欵', '欶', '欻', '欼', '欿', '歀', '歁', 
		'歂', '歄', '歅', '歆', '歈', '歊', '歋', '歍', '歏', '歑', '歒', '歕', '歖', '歗', '歘', '歚', 
		'歜', '歝', '歞', '歠', '步', '歧', '歨', '歫', '歬', '歭', '歮', '歰', '歱', '歲', '歵', '歶', 
		'歷', '歺', '歼', '歽', '歾', '殁', '殂', '殅', '殇', '殈', '殌', '殎', '殏', '殐', '殑', '殒', 
		'殓', '殔', '殗', '殙', '殚', '殛', '殜', '殝', '殟', '殠', '殡', '殢', '殣', '殥', '殦', '殧', 
		'殨', '殩', '殬', '殭', '殮', '殰', '殶', '殸', '殹', '殽', '殾', '毁', '毂', '毃', '毄', '毇', 
		'毈', '毉', '毊', '毌', '每', '毐', '毑', '毕', '毖', '毗', '毙', '毚', '毜', '毝', '毞', '毠', 
		'毡', '毢', '毣', '毤', '毥', '毦', '毧', '毨', '毩', '毪', '毭', '毮', '毰', '毱', '毲', '毴', 
		'毵', '毶', '毷', '毸', '毹', '毺', '毻', '毼', '毽', '毾', '毿', '氀', '氁', '氂', '氃', '氄', 
		'氅', '氆', '氇', '氉', '氊', '氋', '氌', '氍', '氎', '氐', '氒', '氕', '氖', '氘', '氙', '氚', 
		'氜', '氝', '氞', '氟', '氠', '氡', '氢', '氥', '氦', '氧', '氨', '氩', '氪', '氫', '氬', '氭', 
		'氮', '氯', '氰', '氱', '氲', '氳', '氵', '氶', '氹', '氺', '氻', '氼', '氽', '氿', '汃', '汄', 
		'汅', '汆', '汇', '汈', '汉', '汊', '汋', '汌', '汍', '汏', '汑', '汒', '汓', '汔', '汖', '汘', 
		'汙', '汛', '汜', '污', '汣', '汤', '汥', '汦', '汧', '汩', '汫', '汬', '汭', '汮', '汯', '汱', 
		'汴', '汵', '汶', '汷', '汸', '汹', '汻', '汼', '汿', '沀', '沄', '沅', '沆', '沇', '沉', '沊', 
		'沋', '沎', '沏', '沑', '沔', '沕', '沗', '沘', '沜', '沝', '沞', '沟', '沠', '沣', '沤', '沥', 
		'沦', '沧', '沨', '沩', '沪', '沬', '沭', '沯', '沰', '沲', '沴', '沵', '沶', '沷', '泀', '泂', 
		'泃', '泆', '泇', '泈', '泋', '泍', '泎', '泏', '泐', '泑', '泒', '泔', '泖', '泘', '泚', '泜', 
		'泞', '泟', '泠', '泤', '泦', '泧', '泩', '泫', '泬', '泭', '泮', '泲', '泴', '泵', '泶', '泷', 
		'泸', '泹', '泺', '泻', '泼', '泽', '泾', '泿', '洀', '洁', '洂', '洃', '洄', '洅', '洆', '洇', 
		'洈', '洉', '洊', '洍', '洎', '洏', '洐', '洑', '洓', '洔', '洕', '洖', '洘', '洚', '洜', '洝', 
		'洠', '洡', '洢', '洣', '洤', '洦', '洧', '洨', '洬', '洭', '洮', '洯', '洰', '洱', '洴', '洷', 
		'洹', '洺', '洼', '洿', '浀', '浂', '浃', '浆', '浇', '浈', '浉', '浊', '测', '浌', '浍', '济', 
		'浏', '浐', '浑', '浒', '浓', '浔', '浕', '浖', '浗', '浘', '浛', '浝', '浞', '浟', '浠', '浡', 
		'浢', '浥', '浧', '浨', '浫', '浭', '浯', '浰', '浱', '浲', '浳', '浵', '浶', '浺', '浻', '浼', 
		'浽', '浾', '浿', '涀', '涁', '涂', '涃', '涄', '涆', '涇', '涉', '涊', '涋', '涍', '涏', '涐', 
		'涑', '涒', '涔', '涖', '涗', '涘', '涚', '涝', '涞', '涟', '涠', '涡', '涢', '涣', '涤', '涥', 
		'润', '涧', '涨', '涩', '涪', '涫', '涬', '涭', '涮', '涰', '涱', '涳', '涴', '涶', '涷', '涹', 
		'涺', '涻', '涽', '涾', '涿', '淁', '淂', '淃', '淄', '淈', '淉', '淊', '淍', '淎', '淏', '淐', 
		'淓', '淔', '淖', '淗', '淚', '淛', '淜', '淝', '淟', '淠', '淢', '淣', '淥', '淧', '淩', '淭', 
		'淯', '淰', '淲', '淴', '淶', '淸', '淼', '淽', '淾', '淿', '渀', '渁', '渂', '渃', '渄', '渆', 
		'渌', '渍', '渎', '渏', '渐', '渑', '渒', '渔', '渖', '渗', '渘', '渜', '渞', '渢', '渧', '渨', 
		'渪', '渰', '渱', '渲', '渳', '渴', '渵', '渶', '渷', '渹', '渻', '渼', '渽', '渿', '湀', '湁', 
		'湂', '湄', '湅', '湆', '湇', '湈', '湉', '湋', '湌', '湏', '湐', '湑', '湒', '湓', '湔', '湕', 
		'湗', '湙', '湚', '湜', '湝', '湞', '湠', '湡', '湢', '湣', '湤', '湥', '湦', '湨', '湩', '湪', 
		'湬', '湭', '湰', '湱', '湳', '湴', '湵', '湷', '湸', '湹', '湺', '湻', '湼', '湽', '溁', '溃', 
		'溄', '溅', '溆', '溇', '溈', '溉', '溊', '溋', '溍', '溎', '溑', '溒', '溓', '溔', '溕', '溗', 
		'溙', '溚', '溛', '溞', '溠', '溡', '溣', '溤', '溦', '溧', '溨', '溩', '溫', '溬', '溭', '溮', 
		'溰', '溱', '溳', '溴', '溵', '溸', '溹', '溻', '溼', '溾', '溿', '滀', '滁', '滃', '滆', '滇', 
		'滈', '滊', '滍', '滎', '滏', '滐', '滒', '滖', '滗', '滘', '滙', '滚', '滛', '滜', '滟', '滠', 
		'满', '滢', '滣', '滤', '滥', '滦', '滧', '滨', '滩', '滪', '滫', '滭', '滮', '滰', '滱', '滳', 
		'滵', '滶', '滹', '滺', '滻', '滼', '滽', '漀', '漃', '漄', '漅', '漇', '漈', '漊', '漋', '漌', 
		'漍', '漎', '漐', '漒', '漖', '漗', '漘', '漙', '漚', '漛', '漜', '漝', '漞', '漟', '漡', '漤', 
		'漥', '漦', '漧', '漨', '漩', '漪', '漭', '漮', '漯', '漰', '漳', '漴', '漵', '漶', '漷', '漹', 
		'漺', '漻', '漼', '漽', '潀', '潂', '潃', '潄', '潆', '潇', '潈', '潉', '潊', '潋', '潌', '潍', 
		'潎', '潏', '潐', '潑', '潒', '潓', '潕', '潖', '潗', '潙', '潚', '潝', '潞', '潠', '潡', '潢', 
		'潣', '潥', '潧', '潨', '潩', '潪', '潫', '潬', '潱', '潲', '潳', '潵', '潶', '潷', '潹', '潻', 
		'潽', '潾', '潿', '澃', '澅', '澇', '澈', '澉', '澊', '澋', '澌', '澍', '澏', '澐', '澒', '澓', 
		'澔', '澕', '澖', '澘', '澙', '澚', '澛', '澜', '澝', '澞', '澟', '澠', '澢', '澥', '澦', '澧', 
		'澨', '澩', '澫', '澬', '澭', '澮', '澯', '澰', '澲', '澴', '澵', '澶', '澷', '澸', '澺', '澻', 
		'澼', '澽', '澾', '澿', '濄', '濅', '濇', '濈', '濉', '濊', '濋', '濌', '濍', '濎', '濏', '濐', 
		'濑', '濒', '濓', '濖', '濗', '濙', '濚', '濜', '濝', '濞', '濢', '濣', '濥', '濦', '濧', '濨', 
		'濩', '濪', '濭', '濰', '濲', '濴', '濵', '濷', '濸', '濹', '濻', '濼', '濽', '濿', '瀀', '瀂', 
		'瀃', '瀄', '瀅', '瀆', '瀇', '瀈', '瀊', '瀌', '瀍', '瀎', '瀐', '瀒', '瀓', '瀔', '瀖', '瀗', 
		'瀙', '瀜', '瀠', '瀡', '瀢', '瀣', '瀤', '瀥', '瀨', '瀩', '瀪', '瀫', '瀭', '瀮', '瀯', '瀱', 
		'瀳', '瀴', '瀵', '瀶', '瀷', '瀸', '瀹', '瀺', '瀻', '瀼', '瀽', '瀿', '灀', '灁', '灂', '灃', 
		'灄', '灅', '灆', '灇', '灈', '灉', '灊', '灋', '灍', '灎', '灏', '灐', '灒', '灓', '灔', '灕', 
		'灖', '灗', '灙', '灚', '灛', '灜', '灝', '灞', '灟', '灠', '灡', '灢', '灤', '灥', '灦', '灧', 
		'灨', '灩', '灪', '灬', '灭', '灮', '灱', '灲', '灳', '灴', '灵', '灶', '灷', '灹', '灺', '灻', 
		'灾', '灿', '炀', '炁', '炂', '炃', '炄', '炅', '炆', '炇', '炈', '炋', '炌', '炍', '炏', '炐', 
		'炑', '炓', '炔', '炕', '炖', '炗', '炘', '炚', '炛', '炜', '炝', '炞', '炟', '炠', '炡', '炢', 
		'炣', '炤', '炥', '炦', '炧', '炨', '炩', '炪', '炫', '炰', '炱', '炲', '炴', '炵', '炶', '炷', 
		'炻', '炼', '炽', '炾', '炿', '烀', '烁', '烂', '烃', '烄', '烅', '烆', '烇', '烉', '烊', '烌', 
		'烍', '烎', '烐', '烑', '烒', '烓', '烔', '烕', '烖', '烗', '烘', '烚', '烛', '烜', '烞', '烠', 
		'烡', '烢', '烣', '烤', '烥', '烦', '烧', '烨', '烩', '烪', '烫', '烬', '热', '烮', '烯', '烰', 
		'烲', '烳', '烴', '烵', '烶', '烷', '烸', '烺', '烻', '烼', '烾', '烿', '焀', '焁', '焂', '焃', 
		'焄', '焅', '焆', '焇', '焈', '焊', '焋', '焌', '焍', '焎', '焏', '焐', '焑', '焒', '焓', '焕', 
		'焖', '焗', '焘', '焛', '焝', '焞', '焟', '焠', '焢', '焣', '焤', '焥', '焧', '焨', '焩', '焪', 
		'焫', '焬', '焭', '焮', '焯', '焰', '焱', '焲', '焳', '焴', '焵', '焷', '焸', '焹', '焺', '焻', 
		'焽', '焾', '焿', '煀', '煁', '煂', '煃', '煄', '煅', '煆', '煇', '煈', '煊', '煋', '煍', '煏', 
		'煐', '煑', '煒', '煓', '煔', '煗', '煘', '煚', '煛', '煜', '煝', '煞', '煟', '煠', '煡', '煣', 
		'煨', '煪', '煫', '煭', '煯', '煰', '煱', '煲', '煳', '煴', '煵', '煶', '煷', '煸', '煹', '煺', 
		'煻', '煼', '煾', '煿', '熀', '熁', '熂', '熃', '熅', '熆', '熇', '熉', '熋', '熌', '熍', '熎', 
		'熐', '熑', '熒', '熓', '熖', '熗', '熘', '熚', '熛', '熜', '熝', '熞', '熠', '熡', '熢', '熣', 
		'熤', '熥', '熦', '熧', '熩', '熪', '熫', '熭', '熮', '熯', '熰', '熲', '熳', '熴', '熵', '熶', 
		'熷', '熸', '熺', '熻', '熼', '熽', '熿', '燀', '燁', '燂', '燄', '燅', '燆', '燇', '燊', '燋', 
		'燌', '燍', '燏', '燑', '燓', '燖', '燘', '燙', '燚', '燛', '燜', '燝', '燞', '燡', '燢', '燣', 
		'燤', '燨', '燩', '燪', '燫', '燯', '燰', '燱', '燲', '燳', '燴', '燶', '燷', '燸', '燺', '燽', 
		'燾', '爀', '爁', '爂', '爃', '爄', '爅', '爇', '爈', '爉', '爊', '爋', '爌', '爎', '爏', '爑', 
		'爒', '爓', '爔', '爕', '爖', '爗', '爘', '爙', '爚', '爜', '爝', '爞', '爟', '爠', '爡', '爢', 
		'爣', '爤', '爥', '爦', '爧', '爩', '爫', '爮', '爯', '爱', '爳', '爴', '爷', '爸', '爹', '牁', 
		'牂', '牃', '牄', '牅', '牉', '牊', '牍', '牎', '牏', '牐', '牑', '牓', '牔', '牕', '牖', '牗', 
		'牚', '牜', '牞', '牠', '牣', '牤', '牥', '牦', '牨', '牪', '牫', '牬', '牭', '牮', '牯', '牰', 
		'牱', '牳', '牵', '牶', '牷', '牸', '牺', '牻', '牼', '牿', '犃', '犄', '犅', '犆', '犈', '犉', 
		'犊', '犋', '犌', '犍', '犎', '犏', '犐', '犑', '犓', '犔', '犕', '犗', '犘', '犙', '犚', '犛', 
		'犜', '犝', '犞', '犟', '犡', '犣', '犤', '犥', '犦', '犨', '犩', '犪', '犫', '犭', '犮', '犰', 
		'犱', '犳', '犴', '犵', '犷', '犸', '犺', '犻', '犼', '犽', '犾', '犿', '狀', '狁', '狅', '狇', 
		'狈', '狉', '狊', '狋', '狌', '狍', '狏', '狑', '狓', '狔', '狕', '狖', '狘', '狚', '狜', '狝', 
		'狞', '狟', '狣', '狤', '狥', '狦', '狧', '狨', '狪', '狫', '狮', '狯', '狰', '狱', '狲', '狳', 
		'狴', '狵', '狶', '狺', '狻', '狾', '狿', '猀', '猁', '猂', '猃', '猄', '猅', '猆', '猇', '猈', 
		'猉', '猋', '猌', '猍', '猎', '猏', '猐', '猑', '猒', '猓', '猔', '猕', '猘', '猙', '猚', '猞', 
		'猠', '猡', '猢', '猣', '猤', '猦', '猧', '猨', '猬', '猭', '猰', '猱', '猲', '猳', '猵', '猸', 
		'猹', '猺', '猻', '猼', '猽', '獀', '獁', '獂', '獃', '獆', '獇', '獈', '獉', '獊', '獋', '獌', 
		'獍', '獐', '獑', '獒', '獓', '獔', '獕', '獖', '獘', '獙', '獚', '獛', '獜', '獝', '獞', '獟', 
		'獠', '獡', '獢', '獤', '獥', '獦', '獧', '獩', '獫', '獬', '獭', '獮', '獯', '獱', '獳', '獴', 
		'獶', '獷', '獹', '獼', '獽', '獾', '獿', '玀', '玁', '玂', '玃', '玅', '玆', '玈', '玊', '玌', 
		'玍', '玎', '玏', '玐', '玑', '玒', '玓', '玔', '玕', '玗', '玘', '玙', '玚', '玛', '玜', '玝', 
		'玞', '玟', '玠', '玡', '玢', '玣', '玤', '玥', '玦', '玧', '玨', '玪', '玫', '玬', '玭', '玮', 
		'环', '现', '玱', '玴', '玵', '玶', '玷', '玸', '玹', '玺', '玼', '玽', '玾', '玿', '珁', '珃', 
		'珄', '珅', '珆', '珇', '珉', '珋', '珌', '珏', '珐', '珑', '珒', '珓', '珔', '珕', '珖', '珗', 
		'珘', '珙', '珚', '珛', '珜', '珝', '珟', '珡', '珢', '珣', '珤', '珦', '珧', '珨', '珩', '珫', 
		'珬', '珯', '珰', '珲', '珳', '珴', '珵', '珶', '珷', '珹', '珺', '珻', '珼', '珽', '珿', '琀', 
		'琁', '琂', '琄', '琇', '琈', '琊', '琋', '琌', '琍', '琎', '琏', '琐', '琑', '琒', '琓', '琔', 
		'琕', '琖', '琗', '琘', '琙', '琚', '琛', '琜', '琝', '琞', '琟', '琠', '琡', '琣', '琤', '琦', 
		'琧', '琨', '琩', '琪', '琫', '琬', '琭', '琮', '琯', '琰', '琱', '琷', '琸', '琹', '琻', '琼', 
		'琽', '琾', '瑀', '瑂', '瑃', '瑄', '瑅', '瑆', '瑇', '瑈', '瑉', '瑊', '瑋', '瑌', '瑍', '瑎', 
		'瑏', '瑐', '瑑', '瑒', '瑓', '瑔', '瑖', '瑗', '瑘', '瑝', '瑡', '瑢', '瑥', '瑦', '瑧', '瑨', 
		'瑫', '瑬', '瑭', '瑮', '瑱', '瑲', '瑴', '瑵', '瑷', '瑸', '瑹', '瑺', '瑻', '瑼', '瑽', '瑿', 
		'璀', '璁', '璂', '璄', '璅', '璆', '璇', '璈', '璉', '璊', '璌', '璍', '璎', '璏', '璐', '璑', 
		'璒', '璓', '璔', '璕', '璖', '璗', '璘', '璙', '璚', '璛', '璜', '璝', '璟', '璠', '璡', '璣', 
		'璤', '璥', '璦', '璨', '璩', '璪', '璫', '璬', '璭', '璮', '璯', '璱', '璲', '璳', '璴', '璵', 
		'璶', '璷', '璸', '璹', '璺', '璻', '璼', '璾', '璿', '瓀', '瓁', '瓂', '瓃', '瓄', '瓅', '瓆', 
		'瓇', '瓈', '瓉', '瓋', '瓌', '瓍', '瓎', '瓐', '瓑', '瓒', '瓓', '瓕', '瓖', '瓗', '瓘', '瓙', 
		'瓚', '瓛', '瓝', '瓞', '瓟', '瓡', '瓤', '瓥', '瓨', '瓪', '瓫', '瓬', '瓭', '瓯', '瓳', '瓴', 
		'瓵', '瓹', '瓺', '瓻', '瓼', '瓽', '瓾', '瓿', '甀', '甁', '甂', '甆', '甇', '甈', '甉', '甊', 
		'甋', '甏', '甐', '甒', '甔', '甖', '甗', '甙', '甛', '甝', '甠', '甡', '產', '甤', '甧', '甩', 
		'甪', '甭', '甮', '甯', '甴', '电', '甶', '甹', '甽', '甾', '甿', '畀', '畁', '畂', '畃', '畅', 
		'畇', '畈', '畎', '畐', '畒', '畓', '畕', '畖', '畗', '畘', '畞', '畟', '畡', '畣', '畨', '畬', 
		'畮', '畯', '畱', '畲', '畵', '畹', '畺', '畻', '畼', '畽', '畾', '疀', '疁', '疃', '疄', '疅', 
		'疈', '疌', '疍', '疐', '疒', '疓', '疕', '疖', '疗', '疘', '疙', '疛', '疜', '疞', '疟', '疠', 
		'疡', '疢', '疤', '疦', '疧', '疨', '疩', '疪', '疬', '疭', '疮', '疯', '疰', '疴', '疶', '疷', 
		'疺', '疻', '疿', '痀', '痁', '痄', '痆', '痈', '痉', '痋', '痌', '痎', '痏', '痐', '痑', '痓', 
		'痖', '痗', '痚', '痜', '痝', '痟', '痠', '痡', '痤', '痥', '痦', '痧', '痨', '痪', '痫', '痬', 
		'痭', '痮', '痯', '痱', '痵', '痶', '痷', '痸', '痹', '痻', '痽', '瘀', '瘂', '瘃', '瘄', '瘅', 
		'瘆', '瘇', '瘈', '瘊', '瘌', '瘎', '瘏', '瘐', '瘑', '瘒', '瘓', '瘔', '瘕', '瘖', '瘗', '瘘', 
		'瘙', '瘚', '瘛', '瘜', '瘝', '瘞', '瘣', '瘥', '瘦', '瘨', '瘩', '瘪', '瘫', '瘬', '瘭', '瘮', 
		'瘯', '瘱', '瘲', '瘳', '瘵', '瘶', '瘷', '瘸', '瘹', '瘺', '瘼', '瘽', '瘾', '瘿', '癀', '癁', 
		'癃', '癄', '癅', '癉', '癊', '癋', '癍', '癎', '癏', '癐', '癑', '癓', '癔', '癕', '癗', '癙', 
		'癚', '癛', '癝', '癞', '癟', '癠', '癣', '癤', '癥', '癦', '癫', '癭', '癮', '癯', '癱', '癳', 
		'癴', '癵', '癷', '癹', '癿', '皁', '皂', '皅', '皉', '皊', '皌', '皍', '皏', '皑', '皒', '皔', 
		'皕', '皗', '皘', '皛', '皜', '皝', '皞', '皟', '皠', '皡', '皢', '皣', '皤', '皥', '皦', '皧', 
		'皨', '皩', '皪', '皫', '皬', '皭', '皯', '皱', '皲', '皳', '皵', '皶', '皻', '皼', '皽', '皾', 
		'盀', '盁', '盄', '盅', '盇', '盉', '盋', '盌', '盎', '盏', '盐', '监', '盓', '盔', '盕', '盘', 
		'盙', '盚', '盝', '盠', '盢', '盦', '盨', '盩', '盫', '盬', '盭', '盯', '盰', '盱', '盳', '盵', 
		'盶', '盷', '盹', '盺', '盼', '盽', '盿', '眀', '眂', '眃', '眅', '眆', '眊', '眍', '眎', '眏', 
		'眐', '眑', '眒', '眓', '眔', '眕', '眖', '眗', '眘', '眙', '眚', '眜', '眝', '眡', '眢', '眣', 
		'眧', '眨', '眪', '眫', '眬', '眭', '眮', '眯', '眰', '眱', '眲', '眳', '眴', '眵', '眶', '眹', 
		'眻', '眽', '眾', '眿', '睁', '睂', '睃', '睄', '睅', '睆', '睈', '睉', '睊', '睋', '睌', '睍', 
		'睎', '睏', '睐', '睑', '睒', '睓', '睔', '睕', '睖', '睗', '睘', '睙', '睜', '睝', '睞', '睟', 
		'睠', '睢', '睤', '睧', '睩', '睪', '睬', '睭', '睮', '睯', '睰', '睱', '睲', '睳', '睴', '睵', 
		'睶', '睷', '睸', '睺', '睻', '睼', '睽', '瞀', '瞁', '瞂', '瞃', '瞄', '瞅', '瞆', '瞇', '瞈', 
		'瞉', '瞊', '瞌', '瞍', '瞏', '瞐', '瞒', '瞓', '瞔', '瞕', '瞖', '瞗', '瞘', '瞙', '瞚', '瞛', 
		'瞜', '瞝', '瞟', '瞡', '瞢', '瞣', '瞤', '瞦', '瞧', '瞨', '瞩', '瞪', '瞫', '瞮', '瞯', '瞱', 
		'瞲', '瞴', '瞵', '瞷', '瞸', '瞺', '瞾', '矀', '矁', '矂', '矃', '矄', '矅', '矆', '矈', '矉', 
		'矊', '矋', '矌', '矎', '矏', '矐', '矑', '矒', '矓', '矔', '矕', '矖', '矘', '矙', '矝', '矞', 
		'矟', '矠', '矡', '矤', '矦', '矨', '矪', '矫', '矬', '矰', '矱', '矲', '矴', '矵', '矶', '矷', 
		'矸', '矹', '矺', '矻', '矽', '矾', '矿', '砀', '码', '砃', '砄', '砅', '砆', '砇', '砈', '砉', 
		'砊', '砋', '砍', '砎', '砏', '砐', '砑', '砓', '砖', '砗', '砘', '砙', '砚', '砛', '砜', '砝', 
		'砞', '砟', '砡', '砢', '砣', '砤', '砨', '砩', '砪', '砫', '砬', '砭', '砮', '砯', '砰', '砱', 
		'砳', '砵', '砶', '砷', '砸', '砹', '砻', '砼', '砽', '砾', '础', '硁', '硂', '硃', '硄', '硆', 
		'硇', '硈', '硉', '硊', '硋', '硌', '硍', '硎', '硏', '硐', '硑', '硒', '硓', '硔', '硕', '硖', 
		'硗', '硘', '硙', '硚', '硛', '硜', '硞', '硟', '硠', '硡', '硢', '硣', '硤', '硥', '硦', '硧', 
		'硨', '硩', '硪', '硭', '确', '硰', '硱', '硳', '硵', '硶', '硷', '硸', '硹', '硺', '硻', '硽', 
		'硾', '硿', '碀', '碂', '碃', '碄', '碅', '碈', '碉', '碊', '碋', '碏', '碐', '碒', '碔', '碖', 
		'碘', '碙', '碛', '碜', '碝', '碞', '碟', '碠', '碡', '碢', '碤', '碥', '碦', '碨', '碫', '碬', 
		'碭', '碮', '碰', '碱', '碲', '碳', '碴', '碶', '碷', '碸', '碹', '碻', '碽', '碿', '磀', '磂', 
		'磃', '磄', '磇', '磈', '磉', '磌', '磍', '磎', '磏', '磒', '磓', '磕', '磖', '磗', '磘', '磙', 
		'磛', '磜', '磝', '磞', '磟', '磠', '磡', '磢', '磣', '磤', '磥', '磦', '磩', '磪', '磫', '磭', 
		'磮', '磰', '磱', '磲', '磳', '磵', '磶', '磷', '磸', '磹', '磺', '磻', '磼', '磾', '磿', '礀', 
		'礂', '礃', '礄', '礅', '礆', '礈', '礉', '礊', '礋', '礌', '礍', '礏', '礐', '礓', '礔', '礕', 
		'礖', '礗', '礘', '礚', '礛', '礜', '礝', '礞', '礟', '礠', '礡', '礢', '礣', '礤', '礥', '礧', 
		'礨', '礩', '礭', '礮', '礯', '礰', '礱', '礲', '礳', '礴', '礵', '礶', '礷', '礸', '礹', '礻', 
		'礽', '礿', '祂', '祃', '祄', '祅', '祆', '祊', '祋', '祌', '祍', '祎', '祏', '祑', '祒', '祔', 
		'祘', '祙', '祛', '祜', '祡', '祣', '祤', '祦', '祧', '祩', '祪', '祫', '祬', '祮', '祯', '祰', 
		'祱', '祲', '祳', '祴', '祵', '祶', '祸', '祹', '祻', '祼', '祽', '祾', '禂', '禃', '禆', '禇', 
		'禈', '禉', '禋', '禌', '禐', '禑', '禒', '禓', '禔', '禕', '禖', '禗', '禘', '禙', '禚', '禛', 
		'禜', '禞', '禟', '禠', '禡', '禢', '禣', '禤', '禥', '禨', '禩', '禫', '禬', '禭', '禯', '禱', 
		'禲', '禴', '禵', '禶', '禷', '禸', '离', '禼', '秂', '秃', '秄', '秅', '秆', '秇', '秈', '秊', 
		'秌', '种', '秎', '秏', '秐', '秓', '秔', '秖', '秗', '秙', '秚', '秛', '秜', '秝', '秞', '秠', 
		'秢', '秥', '秨', '秪', '秫', '秭', '秮', '积', '秱', '秲', '秳', '秴', '秵', '秶', '秷', '秸', 
		'秹', '秺', '秼', '秽', '秾', '秿', '稁', '稂', '稃', '稄', '稅', '稆', '稇', '稉', '稊', '稌', 
		'稏', '稐', '稑', '稒', '稓', '稕', '稖', '稛', '稝', '稞', '稡', '稢', '稣', '稤', '稥', '稦', 
		'稧', '稨', '稩', '稪', '稫', '稬', '稭', '稯', '稰', '稳', '稴', '稵', '稶', '稸', '稹', '稺', 
		'穁', '穄', '穅', '穇', '穈', '穊', '穋', '穌', '穑', '穒', '穓', '穔', '穕', '穖', '穘', '穙', 
		'穚', '穛', '穜', '穝', '穞', '穟', '穠', '穤', '穥', '穦', '穧', '穨', '穪', '穬', '穭', '穮', 
		'穯', '穱', '穲', '穳', '穵', '穷', '穸', '穻', '穼', '穾', '窀', '窂', '窅', '窆', '窇', '窉', 
		'窊', '窋', '窌', '窍', '窎', '窏', '窐', '窑', '窔', '窙', '窚', '窛', '窜', '窝', '窞', '窠', 
		'窡', '窢', '窣', '窤', '窥', '窦', '窧', '窨', '窫', '窬', '窭', '窱', '窲', '窳', '窴', '窵', 
		'窷', '窸', '窹', '窻', '窼', '窽', '窾', '竀', '竁', '竂', '竆', '竉', '竌', '竎', '竐', '竑', 
		'竔', '竖', '竗', '竘', '竛', '竞', '竤', '竧', '竨', '竩', '竫', '竬', '竮', '竱', '竲', '竳', 
		'竴', '竵', '竷', '竻', '竼', '竽', '竾', '笀', '笁', '笃', '笅', '笇', '笉', '笌', '笍', '笎', 
		'笐', '笒', '笓', '笔', '笕', '笖', '笗', '笚', '笜', '笝', '笟', '笡', '笢', '笣', '笤', '笧', 
		'笩', '笪', '笫', '笭', '笮', '笯', '笰', '笱', '笲', '笴', '笷', '笸', '笺', '笻', '笼', '笽', 
		'笾', '笿', '筀', '筁', '筂', '筃', '筄', '筇', '筊', '筎', '筓', '筕', '筗', '筘', '筙', '筚', 
		'筛', '筜', '筞', '筟', '筠', '筡', '筢', '筣', '筤', '筦', '筨', '筩', '筪', '筫', '筭', '筯', 
		'筲', '筳', '筶', '筷', '筸', '筹', '筻', '筼', '筽', '签', '筿', '简', '箁', '箂', '箃', '箄', 
		'箅', '箈', '箉', '箊', '箌', '箎', '箐', '箑', '箓', '箖', '箛', '箞', '箠', '箢', '箣', '箤', 
		'箥', '箦', '箧', '箨', '箩', '箫', '箬', '箮', '箯', '箰', '箲', '箳', '箵', '箶', '箷', '箹', 
		'箺', '箻', '箼', '箽', '箾', '箿', '篂', '篃', '篅', '篈', '篊', '篍', '篎', '篐', '篑', '篒', 
		'篓', '篔', '篕', '篖', '篗', '篘', '篙', '篚', '篛', '篜', '篞', '篟', '篡', '篢', '篣', '篧', 
		'篨', '篪', '篫', '篬', '篮', '篯', '篰', '篱', '篲', '篴', '篵', '篸', '篹', '篺', '篻', '篼', 
		'篽', '篾', '篿', '簁', '簂', '簃', '簄', '簅', '簆', '簈', '簉', '簊', '簋', '簌', '簎', '簏', 
		'簐', '簕', '簖', '簘', '簙', '簚', '簛', '簜', '簝', '簞', '簠', '簢', '簤', '簥', '簦', '簨', 
		'簩', '簬', '簭', '簮', '簯', '簰', '簱', '簲', '簳', '簴', '簵', '簶', '簹', '簺', '簻', '簼', 
		'籁', '籂', '籄', '籅', '籆', '籇', '籈', '籉', '籊', '籋', '籎', '籑', '籒', '籓', '籕', '籗', 
		'籙', '籚', '籛', '籜', '籝', '籞', '籡', '籢', '籣', '籦', '籧', '籨', '籩', '籪', '籫', '籭', 
		'籮', '籯', '籰', '籱', '籲', '籴', '籶', '籷', '籸', '籹', '籺', '类', '籼', '籽', '籿', '粀', 
		'粄', '粅', '粆', '粇', '粈', '粊', '粌', '粎', '粏', '粑', '粓', '粔', '粖', '粙', '粚', '粜', 
		'粝', '粞', '粠', '粣', '粦', '粩', '粪', '粬', '粯', '粰', '粴', '粵', '粶', '粷', '粸', '粺', 
		'粻', '粼', '粿', '糁', '糃', '糄', '糆', '糇', '糈', '糉', '糋', '糌', '糍', '糏', '糐', '糑', 
		'糓', '糔', '糕', '糗', '糙', '糚', '糛', '糝', '糡', '糣', '糤', '糥', '糦', '糨', '糩', '糪', 
		'糫', '糬', '糭', '糮', '糰', '糱', '糳', '糵', '糷', '糹', '糼', '糽', '糿', '紁', '紃', '紇', 
		'紈', '紉', '紌', '紎', '紏', '紑', '紒', '紓', '紖', '紝', '紞', '紟', '紣', '紤', '紥', '紦', 
		'紧', '紨', '紩', '紪', '紭', '紱', '紴', '紶', '紷', '紸', '紻', '紼', '紽', '紾', '絀', '絁', 
		'絇', '絈', '絉', '絊', '絍', '絑', '絒', '絓', '絔', '絕', '絗', '絘', '絙', '絚', '絜', '絝', 
		'絟', '絠', '絤', '絥', '絧', '絩', '絪', '絫', '絬', '絭', '絯', '絰', '絴', '絷', '絸', '絺', 
		'絻', '絼', '絾', '絿', '綀', '綁', '綂', '綃', '綄', '綅', '綆', '綇', '綈', '綊', '綋', '綌', 
		'綍', '綎', '綐', '綑', '綒', '綔', '綕', '綖', '綗', '綘', '綝', '綞', '綠', '綡', '綤', '綥', 
		'綦', '綧', '綨', '綩', '綪', '綳', '綶', '綷', '綹', '綼', '緀', '緁', '緂', '緃', '緄', '緅', 
		'緆', '緈', '緉', '緌', '緍', '緎', '緐', '緓', '緔', '緖', '緗', '緙', '緛', '緟', '緢', '緣', 
		'緥', '緦', '緧', '緪', '緫', '緭', '緮', '緰', '緱', '緳', '緵', '緶', '緷', '緸', '緹', '緺', 
		'緼', '緽', '緾', '緿', '縀', '縂', '縃', '縆', '縇', '縈', '縌', '縍', '縎', '縏', '縐', '縑', 
		'縓', '縔', '縕', '縖', '縗', '縘', '縙', '縚', '縜', '縝', '縠', '縤', '縥', '縧', '縨', '縩', 
		'縪', '縬', '縭', '縯', '縰', '縳', '縴', '縶', '縸', '縼', '縿', '繀', '繂', '繄', '繅', '繇', 
		'繈', '繉', '繌', '繎', '繏', '繐', '繑', '繒', '繓', '繗', '繘', '繛', '繜', '繟', '繠', '繡', 
		'繢', '繣', '繤', '繥', '繨', '繫', '繬', '繮', '繯', '繱', '繲', '繳', '繴', '繵', '繶', '繷', 
		'繸', '繺', '繾', '纀', '纁', '纄', '纅', '纆', '纇', '纊', '纋', '纍', '纑', '纕', '纗', '纘', 
		'纙', '纚', '纝', '纞', '纟', '纠', '纡', '红', '纣', '纤', '纥', '约', '级', '纨', '纩', '纪', 
		'纫', '纬', '纭', '纮', '纯', '纰', '纱', '纲', '纳', '纴', '纵', '纶', '纷', '纸', '纹', '纺', 
		'纻', '纼', '纽', '纾', '线', '绀', '绁', '绂', '练', '组', '绅', '细', '织', '终', '绉', '绊', 
		'绋', '绌', '绍', '绎', '经', '绐', '绑', '绒', '结', '绔', '绕', '绖', '绗', '绘', '给', '绚', 
		'绛', '络', '绝', '绞', '统', '绠', '绡', '绢', '绣', '绤', '绥', '绦', '继', '绨', '绩', '绪', 
		'绫', '绬', '续', '绮', '绯', '绰', '绱', '绲', '绳', '维', '绵', '绶', '绷', '绸', '绹', '绺', 
		'绻', '综', '绽', '绾', '绿', '缀', '缁', '缂', '缃', '缄', '缅', '缆', '缇', '缈', '缉', '缊', 
		'缋', '缌', '缍', '缎', '缏', '缐', '缑', '缒', '缓', '缔', '缕', '编', '缗', '缘', '缙', '缚', 
		'缛', '缜', '缝', '缞', '缟', '缠', '缡', '缢', '缣', '缤', '缥', '缦', '缧', '缨', '缩', '缪', 
		'缫', '缬', '缭', '缮', '缯', '缰', '缱', '缲', '缳', '缴', '缵', '缷', '缹', '缻', '缼', '缽', 
		'缾', '缿', '罀', '罁', '罂', '罃', '罄', '罆', '罇', '罈', '罉', '罊', '罋', '罏', '罒', '罓', 
		'罖', '罗', '罙', '罚', '罛', '罜', '罝', '罞', '罡', '罢', '罣', '罤', '罥', '罦', '罬', '罭', 
		'罯', '罱', '罳', '罴', '罶', '罺', '罻', '罼', '罽', '罾', '罿', '羀', '羁', '羄', '羉', '羋', 
		'羍', '羏', '羐', '羑', '羒', '羓', '羕', '羖', '羗', '羘', '羙', '羛', '羜', '羟', '羠', '羡', 
		'羢', '羥', '羦', '羧', '羪', '羫', '羬', '羭', '羰', '羱', '羳', '羴', '羵', '羷', '羺', '羻', 
		'羼', '羾', '羿', '翀', '翂', '翃', '翄', '翇', '翈', '翉', '翋', '翍', '翎', '翏', '翐', '翑', 
		'翓', '翖', '翗', '翘', '翙', '翚', '翛', '翜', '翝', '翞', '翟', '翢', '翣', '翤', '翥', '翧', 
		'翨', '翪', '翬', '翭', '翮', '翯', '翱', '翲', '翴', '翵', '翶', '翷', '翸', '翺', '翽', '翾', 
		'翿', '耂', '耇', '耈', '耉', '耊', '耍', '耎', '耏', '耑', '耓', '耔', '耖', '耚', '耛', '耝', 
		'耞', '耟', '耠', '耢', '耣', '耤', '耥', '耦', '耧', '耩', '耪', '耫', '耬', '耭', '耮', '耯', 
		'耰', '耱', '耲', '耴', '耵', '耷', '耸', '耹', '耺', '耼', '耾', '聀', '聁', '聂', '聃', '聄', 
		'聅', '聇', '聈', '聉', '聋', '职', '聍', '聎', '聏', '聐', '聑', '聓', '联', '聕', '聗', '聙', 
		'聛', '聜', '聝', '聠', '聣', '聤', '聥', '聦', '聧', '聩', '聪', '聫', '聬', '聭', '聮', '聱', 
		'聵', '聸', '聺', '聻', '聼', '肀', '肁', '肂', '肃', '肈', '肊', '肍', '肎', '肏', '肐', '肑', 
		'肒', '肔', '肕', '肗', '肙', '肜', '肞', '肟', '肠', '肣', '肤', '肦', '肧', '肨', '肫', '肮', 
		'肰', '肳', '肵', '肶', '肷', '肸', '肹', '肻', '肼', '肽', '肾', '肿', '胀', '胁', '胂', '胅', 
		'胇', '胈', '胉', '胊', '胋', '胍', '胏', '胐', '胑', '胒', '胓', '胔', '胕', '胗', '胘', '胜', 
		'胟', '胠', '胢', '胣', '胦', '胧', '胨', '胩', '胪', '胫', '胬', '胭', '胮', '胰', '胲', '胳', 
		'胵', '胶', '胷', '胹', '胺', '胻', '胾', '胿', '脀', '脁', '脃', '脄', '脋', '脌', '脍', '脎', 
		'脏', '脐', '脑', '脒', '脓', '脔', '脕', '脖', '脗', '脘', '脙', '脜', '脝', '脞', '脟', '脠', 
		'脡', '脢', '脤', '脥', '脦', '脧', '脨', '脪', '脫', '脬', '脭', '脮', '脰', '脲', '脴', '脵', 
		'脶', '脷', '脸', '脺', '脻', '脼', '脽', '脿', '腀', '腁', '腂', '腃', '腄', '腅', '腇', '腈', 
		'腉', '腊', '腌', '腍', '腏', '腒', '腖', '腗', '腘', '腙', '腚', '腛', '腜', '腝', '腞', '腠', 
		'腡', '腢', '腣', '腤', '腧', '腨', '腩', '腪', '腬', '腭', '腯', '腲', '腳', '腵', '腶', '腷', 
		'腻', '腼', '腽', '腾', '膁', '膄', '膅', '膆', '膇', '膉', '膋', '膌', '膍', '膎', '膐', '膑', 
		'膒', '膔', '膖', '膗', '膘', '膙', '膛', '膞', '膟', '膡', '膢', '膥', '膦', '膧', '膪', '膫', 
		'膬', '膭', '膮', '膯', '膱', '膲', '膴', '膶', '膷', '膹', '膻', '膼', '臁', '臃', '臄', '臅', 
		'臇', '臊', '臋', '臌', '臎', '臏', '臐', '臒', '臔', '臕', '臖', '臗', '臛', '臜', '臝', '臞', 
		'臡', '臢', '臤', '臦', '臩', '臫', '臬', '臮', '臯', '臰', '臱', '臲', '臵', '臶', '臷', '臸', 
		'臹', '臽', '臿', '舀', '舃', '舄', '舆', '舋', '舏', '舑', '舓', '舔', '舕', '舙', '舚', '舝', 
		'舠', '舡', '舢', '舣', '舤', '舥', '舦', '舧', '舨', '舭', '舯', '舰', '舱', '舲', '舴', '舺', 
		'舻', '舼', '舽', '舾', '舿', '艁', '艂', '艃', '艄', '艅', '艆', '艈', '艉', '艊', '艋', '艌', 
		'艍', '艎', '艏', '艐', '艑', '艒', '艓', '艔', '艕', '艖', '艗', '艛', '艜', '艞', '艠', '艡', 
		'艣', '艥', '艧', '艩', '艬', '艭', '艰', '艳', '艴', '艵', '艹', '艺', '艻', '艼', '艽', '艿', 
		'芀', '芁', '节', '芃', '芄', '芅', '芆', '芇', '芈', '芉', '芊', '芌', '芎', '芏', '芐', '芑', 
		'芓', '芔', '芕', '芖', '芗', '芘', '芚', '芛', '芜', '芞', '芠', '芡', '芢', '芣', '芤', '芧', 
		'芨', '芩', '芪', '芮', '芰', '芲', '芴', '芵', '芶', '芷', '芺', '芼', '芾', '芿', '苀', '苁', 
		'苂', '苃', '苄', '苆', '苇', '苈', '苉', '苊', '苋', '苌', '苍', '苎', '苏', '苐', '苕', '苖', 
		'苘', '苚', '苝', '苠', '苢', '苤', '苨', '苩', '苪', '苬', '苭', '苮', '苯', '苰', '苲', '苵', 
		'苶', '苷', '苸', '苼', '苽', '苾', '苿', '茀', '茁', '茇', '茈', '茊', '茋', '茌', '茍', '茏', 
		'茐', '茑', '茒', '茓', '茔', '茕', '茙', '茚', '茛', '茝', '茞', '茟', '茠', '茡', '茢', '茤', 
		'茥', '茦', '茧', '茩', '茪', '茬', '茭', '茮', '茰', '茳', '茷', '茺', '茻', '茼', '茽', '茾', 
		'茿', '荁', '荂', '荃', '荄', '荆', '荇', '荈', '荋', '荌', '荍', '荎', '荑', '荓', '荔', '荕', 
		'荖', '荗', '荙', '荚', '荛', '荜', '荝', '荞', '荟', '荠', '荡', '荢', '荣', '荤', '荥', '荦', 
		'荧', '荨', '荩', '荪', '荫', '荬', '荭', '荮', '药', '荰', '荱', '荲', '荴', '荶', '荸', '荹', 
		'荺', '荽', '荾', '荿', '莀', '莁', '莂', '莃', '莄', '莆', '莈', '莋', '莌', '莍', '莏', '莐', 
		'莑', '莒', '莔', '莕', '莗', '莘', '莙', '莛', '莜', '莝', '莡', '莣', '莤', '莥', '莦', '莧', 
		'莩', '莬', '莭', '莮', '莯', '莰', '莲', '莳', '莴', '莶', '获', '莸', '莹', '莺', '莻', '莼', 
		'莾', '莿', '菀', '菂', '菃', '菄', '菆', '菇', '菈', '菉', '菋', '菍', '菏', '菐', '菑', '菒', 
		'菔', '菕', '菗', '菙', '菚', '菛', '菝', '菞', '菡', '菢', '菣', '菤', '菥', '菦', '菧', '菨', 
		'菪', '菬', '菭', '菮', '菳', '菵', '菶', '菸', '菹', '菺', '菼', '菾', '菿', '萀', '萁', '萂', 
		'萅', '萆', '萈', '萉', '萊', '萏', '萐', '萑', '萒', '萔', '萕', '萖', '萗', '萘', '萙', '萚', 
		'萛', '萜', '萝', '萞', '萟', '萡', '萣', '萤', '营', '萦', '萧', '萨', '萫', '萭', '萮', '萯', 
		'萰', '萲', '萳', '萴', '萶', '萷', '萹', '萺', '萻', '萾', '萿', '葀', '葁', '葂', '葃', '葄', 
		'葅', '葇', '葈', '葊', '葋', '葌', '葍', '葏', '葐', '葑', '葒', '葓', '葔', '葕', '葖', '葘', 
		'葙', '葚', '葜', '葝', '葞', '葟', '葠', '葤', '葥', '葧', '葨', '葪', '葰', '葲', '葳', '葴', 
		'葶', '葸', '葻', '葼', '葽', '葾', '葿', '蒀', '蒁', '蒃', '蒅', '蒆', '蒇', '蒈', '蒉', '蒊', 
		'蒌', '蒍', '蒎', '蒏', '蒑', '蒒', '蒓', '蒕', '蒖', '蒗', '蒘', '蒚', '蒛', '蒝', '蒞', '蒠', 
		'蒢', '蒣', '蒤', '蒥', '蒦', '蒧', '蒨', '蒩', '蒪', '蒫', '蒬', '蒮', '蒯', '蒰', '蒱', '蒳', 
		'蒴', '蒵', '蒶', '蒷', '蒺', '蒽', '蒾', '蓀', '蓂', '蓃', '蓅', '蓇', '蓈', '蓌', '蓎', '蓏', 
		'蓒', '蓓', '蓔', '蓕', '蓗', '蓘', '蓛', '蓜', '蓝', '蓞', '蓟', '蓠', '蓡', '蓢', '蓣', '蓤', 
		'蓥', '蓦', '蓧', '蓨', '蓩', '蓪', '蓫', '蓭', '蓯', '蓰', '蓱', '蓲', '蓳', '蓵', '蓶', '蓷', 
		'蓸', '蓹', '蓺', '蓻', '蓽', '蓾', '蔁', '蔂', '蔃', '蔄', '蔅', '蔇', '蔈', '蔉', '蔊', '蔋', 
		'蔌', '蔍', '蔎', '蔏', '蔐', '蔒', '蔖', '蔙', '蔛', '蔜', '蔝', '蔞', '蔠', '蔢', '蔣', '蔤', 
		'蔥', '蔧', '蔨', '蔩', '蔪', '蔫', '蔮', '蔯', '蔰', '蔱', '蔲', '蔳', '蔴', '蔶', '蔷', '蔸', 
		'蔹', '蔺', '蔻', '蔼', '蔾', '蔿', '蕂', '蕄', '蕅', '蕆', '蕇', '蕌', '蕍', '蕏', '蕐', '蕑', 
		'蕒', '蕓', '蕔', '蕖', '蕙', '蕛', '蕜', '蕝', '蕞', '蕟', '蕠', '蕡', '蕢', '蕤', '蕥', '蕦', 
		'蕧', '蕫', '蕬', '蕮', '蕯', '蕰', '蕱', '蕲', '蕳', '蕴', '蕵', '蕶', '蕸', '蕹', '蕺', '蕻', 
		'蕼', '蕽', '蕿', '薁', '薂', '薃', '薅', '薆', '薉', '薋', '薌', '薍', '薎', '薏', '薒', '薓', 
		'薕', '薖', '薘', '薚', '薝', '薞', '薟', '薠', '薡', '薢', '薣', '薥', '薧', '薭', '薰', '薱', 
		'薲', '薳', '薴', '薵', '薶', '薷', '薸', '薻', '薼', '薽', '薾', '薿', '藀', '藂', '藃', '藄', 
		'藅', '藆', '藇', '藈', '藊', '藋', '藌', '藎', '藑', '藒', '藓', '藔', '藖', '藗', '藘', '藙', 
		'藚', '藛', '藞', '藟', '藠', '藡', '藢', '藣', '藦', '藧', '藨', '藫', '藬', '藭', '藮', '藯', 
		'藰', '藱', '藲', '藳', '藴', '藵', '藶', '藸', '藼', '藽', '藿', '蘀', '蘁', '蘃', '蘄', '蘅', 
		'蘈', '蘉', '蘌', '蘍', '蘎', '蘏', '蘐', '蘑', '蘒', '蘔', '蘕', '蘘', '蘙', '蘛', '蘜', '蘝', 
		'蘞', '蘟', '蘠', '蘡', '蘣', '蘤', '蘥', '蘦', '蘧', '蘨', '蘩', '蘪', '蘫', '蘬', '蘮', '蘱', 
		'蘲', '蘳', '蘴', '蘵', '蘶', '蘷', '蘸', '蘹', '蘺', '蘻', '蘼', '蘽', '蘾', '虀', '虁', '虂', 
		'虃', '虄', '虅', '虆', '虇', '虈', '虉', '虊', '虋', '虌', '虏', '虑', '虒', '虓', '虖', '虗', 
		'虘', '虙', '虛', '虝', '虠', '虡', '虢', '虣', '虤', '虥', '虦', '虨', '虩', '虪', '虬', '虭', 
		'虮', '虯', '虰', '虲', '虳', '虴', '虵', '虶', '虷', '虸', '虺', '虼', '虽', '虾', '虿', '蚀', 
		'蚁', '蚂', '蚃', '蚄', '蚅', '蚆', '蚇', '蚈', '蚉', '蚍', '蚎', '蚏', '蚐', '蚑', '蚒', '蚔', 
		'蚖', '蚗', '蚘', '蚙', '蚚', '蚛', '蚜', '蚝', '蚞', '蚟', '蚠', '蚡', '蚢', '蚥', '蚦', '蚧', 
		'蚨', '蚬', '蚭', '蚮', '蚱', '蚲', '蚳', '蚴', '蚵', '蚷', '蚸', '蚹', '蚺', '蚻', '蚼', '蚽', 
		'蚾', '蚿', '蛀', '蛁', '蛂', '蛃', '蛅', '蛈', '蛊', '蛌', '蛏', '蛐', '蛑', '蛒', '蛓', '蛕', 
		'蛖', '蛗', '蛘', '蛚', '蛜', '蛝', '蛠', '蛡', '蛢', '蛣', '蛥', '蛦', '蛧', '蛨', '蛪', '蛫', 
		'蛰', '蛱', '蛲', '蛳', '蛴', '蛵', '蛶', '蛷', '蛺', '蛼', '蛽', '蛿', '蜁', '蜄', '蜅', '蜇', 
		'蜋', '蜌', '蜎', '蜏', '蜐', '蜓', '蜔', '蜕', '蜖', '蜗', '蜙', '蜛', '蜝', '蜞', '蜟', '蜠', 
		'蜡', '蜢', '蜣', '蜤', '蜦', '蜧', '蜨', '蜪', '蜫', '蜬', '蜭', '蜮', '蜯', '蜰', '蜱', '蜲', 
		'蜳', '蜵', '蜶', '蜸', '蜹', '蜺', '蜼', '蜽', '蜾', '蝀', '蝁', '蝂', '蝃', '蝄', '蝅', '蝆', 
		'蝇', '蝈', '蝊', '蝍', '蝏', '蝐', '蝑', '蝒', '蝔', '蝖', '蝘', '蝚', '蝛', '蝜', '蝝', '蝞', 
		'蝡', '蝢', '蝤', '蝥', '蝧', '蝩', '蝫', '蝬', '蝭', '蝯', '蝰', '蝱', '蝲', '蝳', '蝵', '蝷', 
		'蝹', '蝺', '蝻', '蝼', '蝽', '蝾', '螀', '螁', '螃', '螄', '螅', '螆', '螇', '螈', '螉', '螊', 
		'螋', '螌', '螎', '螏', '螐', '螑', '螒', '螓', '螔', '螕', '螖', '螗', '螘', '螙', '螚', '螛', 
		'螜', '螝', '螞', '螠', '螡', '螣', '螤', '螥', '螦', '螧', '螨', '螩', '螪', '螬', '螭', '螮', 
		'螰', '螱', '螲', '螴', '螵', '螶', '螷', '螸', '螹', '螼', '螾', '螿', '蟁', '蟂', '蟃', '蟅', 
		'蟈', '蟉', '蟊', '蟌', '蟍', '蟎', '蟏', '蟑', '蟓', '蟔', '蟕', '蟖', '蟗', '蟘', '蟙', '蟚', 
		'蟛', '蟜', '蟝', '蟞', '蟟', '蟡', '蟢', '蟣', '蟤', '蟥', '蟦', '蟧', '蟨', '蟩', '蟪', '蟫', 
		'蟬', '蟭', '蟮', '蟰', '蟱', '蟳', '蟴', '蟵', '蟸', '蟺', '蟼', '蟽', '蟿', '蠀', '蠁', '蠂', 
		'蠃', '蠄', '蠆', '蠇', '蠈', '蠉', '蠊', '蠋', '蠌', '蠐', '蠒', '蠓', '蠔', '蠗', '蠘', '蠙', 
		'蠚', '蠛', '蠜', '蠝', '蠞', '蠟', '蠠', '蠤', '蠥', '蠦', '蠨', '蠩', '蠪', '蠫', '蠬', '蠭', 
		'蠮', '蠯', '蠰', '蠲', '蠳', '蠴', '蠵', '蠷', '蠸', '蠺', '蠼', '蠽', '蠾', '蠿', '衁', '衃', 
		'衅', '衇', '衈', '衉', '衊', '衋', '衎', '衏', '衐', '衑', '衔', '衕', '衖', '衘', '衚', '衜', 
		'衟', '衠', '衤', '补', '衦', '衧', '衩', '衪', '衬', '衭', '衮', '衯', '衱', '衳', '衴', '衶', 
		'衸', '衹', '衺', '衻', '衼', '袀', '袃', '袄', '袅', '袆', '袇', '袉', '袊', '袌', '袎', '袏', 
		'袐', '袑', '袓', '袔', '袕', '袘', '袚', '袛', '袜', '袝', '袟', '袠', '袡', '袣', '袥', '袦', 
		'袧', '袨', '袩', '袪', '袬', '袭', '袯', '袲', '袳', '袶', '袸', '袹', '袺', '袻', '袼', '袽', 
		'袾', '裀', '裆', '裇', '裈', '裉', '裊', '裋', '裌', '裍', '裎', '裐', '裑', '裒', '裓', '裖', 
		'裗', '裚', '裛', '裞', '裠', '裢', '裣', '裤', '裥', '裦', '裧', '裩', '裪', '裫', '裬', '裭', 
		'裮', '裯', '裰', '裱', '裵', '裶', '裷', '裺', '裻', '裿', '褀', '褁', '褃', '褅', '褆', '褈', 
		'褉', '褋', '褍', '褎', '褏', '褑', '褔', '褕', '褖', '褗', '褘', '褙', '褚', '褛', '褜', '褟', 
		'褠', '褡', '褢', '褣', '褤', '褦', '褧', '褨', '褩', '褬', '褭', '褮', '褯', '褰', '褱', '褲', 
		'褳', '褴', '褵', '褷', '褹', '褺', '褼', '褽', '褾', '褿', '襀', '襂', '襅', '襆', '襇', '襈', 
		'襉', '襊', '襋', '襎', '襏', '襐', '襑', '襒', '襓', '襔', '襕', '襗', '襘', '襙', '襚', '襛', 
		'襜', '襝', '襡', '襢', '襣', '襥', '襧', '襨', '襩', '襫', '襬', '襮', '襰', '襱', '襳', '襵', 
		'襶', '襸', '襹', '襺', '襻', '襼', '襽', '覀', '覂', '覄', '覅', '覉', '覌', '覍', '覎', '覐', 
		'覑', '覒', '覔', '覕', '覙', '覛', '覜', '覝', '覞', '覟', '覠', '覢', '覣', '覤', '覥', '覨', 
		'覫', '覭', '覮', '覰', '覱', '覴', '覵', '覶', '覷', '覸', '覹', '覻', '覼', '覾', '见', '观', 
		'觃', '规', '觅', '视', '觇', '览', '觉', '觊', '觋', '觌', '觍', '觎', '觏', '觐', '觑', '觓', 
		'觔', '觕', '觖', '觗', '觘', '觙', '觛', '觞', '觟', '觠', '觡', '觢', '觤', '觥', '觨', '觩', 
		'觪', '觫', '觬', '觭', '觮', '觯', '觰', '觱', '觲', '觳', '觵', '觶', '觷', '觹', '觺', '觻', 
		'觼', '觽', '觾', '觿', '訁', '訄', '訅', '訆', '訇', '訉', '訋', '訍', '訏', '訑', '訒', '訔', 
		'訕', '訙', '訚', '訜', '訞', '訠', '訡', '訢', '訤', '訦', '訧', '訨', '訩', '訫', '訬', '訮', 
		'訯', '訰', '訲', '訵', '訷', '訸', '訹', '訽', '訾', '訿', '詀', '詂', '詃', '詄', '詅', '詇', 
		'詉', '詊', '詋', '詌', '詍', '詎', '詏', '詓', '詖', '詗', '詘', '詙', '詚', '詜', '詝', '詟', 
		'詡', '詤', '詥', '詧', '詨', '詪', '詯', '詴', '詵', '詶', '詷', '詸', '詹', '詺', '詻', '詽', 
		'詾', '詿', '誀', '誁', '誃', '誆', '誈', '誊', '誋', '誎', '誏', '誐', '誒', '誔', '誖', '誗', 
		'誙', '誛', '誜', '誝', '誟', '誢', '誧', '誩', '說', '誫', '誮', '誯', '誱', '誳', '誴', '誵', 
		'誶', '誷', '誸', '誺', '誻', '誽', '誾', '諀', '諁', '諃', '諅', '諆', '諈', '諉', '諊', '諎', 
		'諐', '諑', '諓', '諔', '諕', '諗', '諘', '諙', '諝', '諟', '諣', '諥', '諨', '諩', '諪', '諬', 
		'諯', '諰', '諲', '諴', '諵', '諶', '諹', '諻', '諼', '諽', '諿', '謃', '謅', '謆', '謈', '謉', 
		'謊', '謋', '謍', '謏', '謑', '謒', '謓', '謕', '謘', '謜', '謞', '謟', '謢', '謣', '謤', '謥', 
		'謧', '謩', '謪', '謭', '謮', '謯', '謰', '謱', '謲', '謴', '謵', '謶', '謷', '謸', '謺', '謻', 
		'謼', '謽', '謿', '譀', '譂', '譃', '譄', '譅', '譆', '譇', '譈', '譊', '譋', '譍', '譐', '譑', 
		'譒', '譓', '譔', '譕', '譗', '譙', '譝', '譞', '譠', '譡', '譢', '譣', '譤', '譥', '譧', '譨', 
		'譩', '譪', '譭', '譮', '譳', '譵', '譶', '譸', '譹', '譺', '譻', '譼', '譾', '譿', '讁', '讂', 
		'讄', '讅', '讆', '讇', '讈', '讉', '讋', '讍', '讏', '讑', '讔', '讕', '讗', '讘', '讛', '讜', 
		'讝', '讞', '讟', '讠', '计', '订', '讣', '认', '讥', '讦', '讧', '讨', '让', '讪', '讫', '讬', 
		'训', '议', '讯', '记', '讱', '讲', '讳', '讴', '讵', '讶', '讷', '许', '讹', '论', '讻', '讼', 
		'讽', '设', '访', '诀', '证', '诂', '诃', '评', '诅', '识', '诇', '诈', '诉', '诊', '诋', '诌', 
		'词', '诎', '诏', '诐', '译', '诒', '诓', '诔', '试', '诖', '诗', '诘', '诙', '诚', '诛', '诜', 
		'话', '诞', '诟', '诠', '诡', '询', '诣', '诤', '该', '详', '诧', '诨', '诩', '诪', '诫', '诬', 
		'语', '诮', '误', '诰', '诱', '诲', '诳', '说', '诵', '诶', '请', '诸', '诹', '诺', '读', '诼', 
		'诽', '课', '诿', '谀', '谁', '谂', '调', '谄', '谅', '谆', '谇', '谈', '谉', '谊', '谋', '谌', 
		'谍', '谎', '谏', '谐', '谑', '谒', '谓', '谔', '谕', '谖', '谗', '谘', '谙', '谚', '谛', '谜', 
		'谝', '谞', '谟', '谠', '谡', '谢', '谣', '谤', '谥', '谦', '谧', '谨', '谩', '谪', '谫', '谬', 
		'谭', '谮', '谯', '谰', '谱', '谲', '谳', '谴', '谵', '谶', '谸', '谹', '谻', '谼', '谽', '谾', 
		'豀', '豂', '豃', '豄', '豅', '豇', '豉', '豋', '豍', '豏', '豑', '豒', '豓', '豔', '豖', '豗', 
		'豘', '豙', '豛', '豜', '豝', '豞', '豟', '豠', '豣', '豤', '豥', '豦', '豧', '豨', '豩', '豭', 
		'豮', '豯', '豰', '豱', '豲', '豳', '豴', '豵', '豶', '豷', '豻', '豽', '豾', '豿', '貀', '貁', 
		'貃', '貄', '貆', '貇', '貈', '貋', '貏', '貐', '貑', '貒', '貓', '貕', '貖', '貗', '貙', '貚', 
		'貛', '貜', '貟', '貣', '貤', '貥', '貦', '貱', '貵', '貹', '貺', '貾', '賅', '賆', '賉', '賋', 
		'賌', '賏', '賐', '賒', '賔', '賕', '賖', '賗', '賘', '賙', '賝', '賟', '賡', '賥', '賧', '賨', 
		'賩', '賫', '賬', '賮', '賯', '賰', '賱', '賲', '賳', '賴', '賵', '賶', '賷', '賸', '賹', '賾', 
		'賿', '贀', '贁', '贂', '贃', '贆', '贉', '贌', '贎', '贑', '贒', '贕', '贗', '贘', '贙', '贚', 
		'贛', '贜', '贝', '贞', '负', '贠', '贡', '财', '责', '贤', '败', '账', '货', '质', '贩', '贪', 
		'贫', '贬', '购', '贮', '贯', '贰', '贱', '贲', '贳', '贴', '贵', '贶', '贷', '贸', '费', '贺', 
		'贻', '贼', '贽', '贾', '贿', '赀', '赁', '赂', '赃', '资', '赅', '赆', '赇', '赈', '赉', '赊', 
		'赋', '赌', '赍', '赎', '赏', '赐', '赑', '赒', '赓', '赔', '赕', '赖', '赗', '赘', '赙', '赚', 
		'赛', '赜', '赝', '赞', '赟', '赠', '赡', '赢', '赣', '赥', '赨', '赩', '赪', '赬', '赮', '赯', 
		'赲', '赵', '赶', '赸', '赹', '赺', '赻', '赼', '赽', '赾', '赿', '趀', '趂', '趃', '趄', '趆', 
		'趇', '趈', '趉', '趋', '趌', '趍', '趎', '趏', '趐', '趑', '趒', '趓', '趔', '趕', '趖', '趗', 
		'趘', '趚', '趛', '趜', '趝', '趞', '趟', '趠', '趡', '趢', '趤', '趥', '趦', '趧', '趩', '趪', 
		'趫', '趬', '趭', '趮', '趯', '趰', '趱', '趲', '趴', '趵', '趶', '趷', '趸', '趹', '趻', '趼', 
		'趽', '趿', '跀', '跁', '跃', '跄', '跅', '跆', '跇', '跈', '跉', '跊', '跍', '跎', '跐', '跑', 
		'跒', '跓', '跔', '跕', '跗', '跘', '跙', '跜', '跞', '跠', '跢', '跤', '跥', '跦', '跧', '跩', 
		'跬', '跭', '跮', '跰', '跱', '跲', '跴', '跶', '跷', '跸', '跹', '跺', '跻', '跽', '跾', '踀', 
		'踁', '踂', '踃', '踄', '踅', '踆', '踇', '踋', '踌', '踍', '踎', '踑', '踒', '踓', '踔', '踕', 
		'踖', '踗', '踘', '踙', '踚', '踛', '踜', '踠', '踡', '踢', '踣', '踤', '踥', '踦', '踧', '踨', 
		'踩', '踫', '踬', '踭', '踮', '踯', '踱', '踲', '踳', '踶', '踷', '踸', '踹', '踺', '踻', '踼', 
		'踽', '踾', '踿', '蹀', '蹁', '蹃', '蹅', '蹆', '蹋', '蹍', '蹎', '蹏', '蹑', '蹒', '蹓', '蹔', 
		'蹖', '蹗', '蹘', '蹚', '蹛', '蹜', '蹝', '蹞', '蹡', '蹢', '蹥', '蹦', '蹧', '蹨', '蹩', '蹪', 
		'蹫', '蹬', '蹭', '蹮', '蹯', '蹰', '蹱', '蹳', '蹵', '蹷', '蹸', '蹹', '蹺', '蹻', '蹽', '蹾', 
		'蹿', '躀', '躂', '躃', '躆', '躈', '躉', '躌', '躎', '躏', '躐', '躒', '躕', '躖', '躗', '躘', 
		'躚', '躛', '躜', '躝', '躞', '躟', '躠', '躢', '躣', '躤', '躥', '躦', '躧', '躨', '躩', '躭', 
		'躮', '躲', '躳', '躴', '躵', '躶', '躷', '躸', '躹', '躺', '躻', '躼', '躽', '躿', '軀', '軁', 
		'軂', '軃', '軄', '軇', '軉', '軎', '軏', '軐', '軑', '軓', '軔', '軕', '軖', '軗', '軘', '軙', 
		'軚', '軜', '軝', '軞', '軠', '軡', '軤', '軥', '軦', '軧', '軨', '軩', '軪', '軬', '軭', '軮', 
		'軯', '軰', '軱', '軲', '軳', '軴', '軵', '軶', '軷', '軹', '軺', '軿', '輀', '輁', '輂', '輄', 
		'輆', '輇', '輈', '輋', '輍', '輎', '輏', '輐', '輑', '輖', '輗', '輘', '輚', '輞', '輠', '輡', 
		'輢', '輣', '輤', '輥', '輧', '輨', '輫', '輬', '輭', '輮', '輰', '輱', '輲', '輴', '輵', '輶', 
		'輷', '輺', '輼', '輽', '轀', '轁', '轃', '轇', '轈', '轊', '轋', '轏', '轐', '轑', '轒', '轓', 
		'轔', '轕', '轖', '轘', '轙', '轚', '轛', '轝', '轞', '轠', '轥', '车', '轧', '轨', '轩', '轪', 
		'轫', '转', '轭', '轮', '软', '轰', '轱', '轲', '轳', '轴', '轵', '轶', '轷', '轸', '轹', '轺', 
		'轻', '轼', '载', '轾', '轿', '辀', '辁', '辂', '较', '辄', '辅', '辆', '辇', '辈', '辉', '辊', 
		'辋', '辌', '辍', '辎', '辏', '辐', '辑', '辒', '输', '辔', '辕', '辖', '辗', '辘', '辙', '辚', 
		'辝', '辠', '辡', '辢', '辤', '辥', '辦', '辩', '辪', '辫', '辬', '辳', '辴', '辵', '辶', '辸', 
		'边', '辽', '达', '迀', '迁', '迃', '迆', '过', '迈', '迉', '迊', '迋', '迌', '迍', '迏', '运', 
		'迒', '迓', '迕', '迖', '迗', '还', '这', '进', '远', '违', '连', '迟', '迠', '迡', '迣', '迤', 
		'迧', '迨', '迬', '迮', '迱', '迲', '迳', '迵', '迶', '迻', '迼', '迾', '迿', '适', '逄', '逇', 
		'逈', '选', '逊', '逌', '递', '逘', '逛', '逜', '逤', '逥', '逦', '逨', '逩', '逪', '逫', '逬', 
		'逭', '逯', '逰', '逳', '逴', '逷', '逺', '逻', '逽', '逿', '遀', '遃', '遄', '遆', '遈', '遌', 
		'遗', '遚', '遛', '遝', '遟', '遢', '遤', '遦', '遧', '遪', '遫', '遬', '遰', '遱', '遳', '遴', 
		'遹', '遻', '遾', '邅', '邆', '邈', '邋', '邌', '邍', '邎', '邐', '邒', '邓', '邔', '邕', '邖', 
		'邗', '邘', '邙', '邚', '邛', '邜', '邝', '邞', '邟', '邠', '邡', '邢', '邤', '邥', '邧', '邩', 
		'邫', '邬', '邭', '邮', '邰', '邲', '邳', '邴', '邶', '邷', '邹', '邺', '邻', '邼', '邽', '邾', 
		'邿', '郀', '郂', '郃', '郄', '郅', '郆', '郇', '郈', '郉', '郋', '郌', '郍', '郏', '郐', '郑', 
		'郒', '郓', '郔', '郕', '郖', '郗', '郘', '郙', '郚', '郜', '郝', '郞', '郟', '郠', '郣', '郥', 
		'郦', '郧', '郩', '郪', '郫', '郬', '郮', '郯', '郰', '郱', '郲', '郳', '郴', '郶', '郸', '郹', 
		'郺', '郻', '郼', '郾', '郿', '鄀', '鄁', '鄃', '鄄', '鄅', '鄆', '鄇', '鄈', '鄉', '鄊', '鄋', 
		'鄌', '鄍', '鄎', '鄏', '鄐', '鄑', '鄓', '鄔', '鄕', '鄖', '鄗', '鄘', '鄚', '鄛', '鄜', '鄝', 
		'鄞', '鄟', '鄠', '鄡', '鄢', '鄣', '鄤', '鄥', '鄦', '鄧', '鄨', '鄩', '鄪', '鄫', '鄬', '鄮', 
		'鄯', '鄱', '鄳', '鄴', '鄵', '鄶', '鄷', '鄸', '鄹', '鄺', '鄻', '鄼', '鄽', '鄾', '鄿', '酀', 
		'酁', '酂', '酃', '酄', '酅', '酆', '酇', '酈', '酏', '酐', '酑', '酓', '酕', '酗', '酙', '酚', 
		'酛', '酜', '酝', '酞', '酟', '酠', '酡', '酤', '酦', '酧', '酨', '酫', '酭', '酮', '酯', '酰', 
		'酱', '酴', '酶', '酹', '酺', '酻', '酼', '酽', '酾', '酿', '醀', '醁', '醃', '醄', '醅', '醆', 
		'醈', '醊', '醌', '醎', '醏', '醑', '醓', '醔', '醕', '醖', '醘', '醙', '醚', '醛', '醝', '醞', 
		'醟', '醠', '醡', '醣', '醥', '醦', '醧', '醨', '醩', '醬', '醭', '醮', '醰', '醱', '醲', '醳', 
		'醶', '醷', '醹', '醻', '醼', '醽', '醾', '醿', '釂', '釃', '釄', '釅', '释', '釒', '釓', '釔', 
		'釕', '釗', '釙', '釚', '釞', '釠', '釢', '釤', '釥', '釨', '釩', '釪', '釫', '釬', '釭', '釮', 
		'釯', '釰', '釱', '釲', '釳', '釴', '釷', '釸', '釹', '釺', '釻', '釽', '釾', '鈀', '鈁', '鈂', 
		'鈃', '鈄', '鈅', '鈆', '鈇', '鈈', '鈉', '鈊', '鈋', '鈌', '鈏', '鈐', '鈒', '鈓', '鈖', '鈗', 
		'鈘', '鈙', '鈚', '鈛', '鈜', '鈝', '鈟', '鈠', '鈡', '鈢', '鈣', '鈤', '鈥', '鈦', '鈧', '鈨', 
		'鈪', '鈫', '鈭', '鈮', '鈯', '鈰', '鈱', '鈲', '鈳', '鈵', '鈶', '鈸', '鈹', '鈺', '鈻', '鈼', 
		'鈽', '鈾', '鉀', '鉁', '鉂', '鉃', '鉆', '鉇', '鉊', '鉌', '鉍', '鉎', '鉏', '鉑', '鉒', '鉓', 
		'鉔', '鉕', '鉖', '鉘', '鉙', '鉜', '鉝', '鉟', '鉠', '鉡', '鉣', '鉥', '鉧', '鉨', '鉩', '鉪', 
		'鉫', '鉬', '鉭', '鉮', '鉯', '鉰', '鉲', '鉳', '鉴', '鉵', '鉶', '鉷', '鉸', '鉹', '鉺', '鉻', 
		'鉼', '鉽', '鉿', '銁', '銂', '銄', '銆', '銇', '銈', '銉', '銊', '銋', '銌', '銍', '銎', '銏', 
		'銐', '銒', '銔', '銗', '銙', '銝', '銞', '銟', '銠', '銡', '銢', '銣', '銤', '銥', '銦', '銧', 
		'銨', '銩', '銪', '銫', '銬', '銮', '銯', '銰', '銱', '銲', '銳', '銴', '銵', '銶', '銸', '銺', 
		'銻', '銼', '銽', '銾', '銿', '鋀', '鋁', '鋂', '鋃', '鋄', '鋅', '鋆', '鋇', '鋈', '鋉', '鋊', 
		'鋋', '鋌', '鋍', '鋎', '鋐', '鋑', '鋓', '鋔', '鋕', '鋖', '鋗', '鋘', '鋙', '鋚', '鋛', '鋜', 
		'鋝', '鋞', '鋟', '鋠', '鋡', '鋢', '鋣', '鋥', '鋦', '鋧', '鋨', '鋫', '鋬', '鋮', '鋯', '鋰', 
		'鋱', '鋴', '鋵', '鋶', '鋷', '鋹', '鋻', '鋽', '鋾', '鋿', '錀', '錁', '錂', '錃', '錄', '錅', 
		'錇', '錈', '錉', '錊', '錋', '錌', '錍', '錎', '錑', '錒', '錓', '錔', '錕', '錖', '錗', '錛', 
		'錜', '錝', '錞', '錟', '錡', '錤', '錥', '錧', '錩', '錪', '錭', '錰', '錱', '錳', '錴', '錶', 
		'錷', '錸', '錹', '錼', '錽', '錾', '錿', '鍀', '鍁', '鍂', '鍃', '鍅', '鍆', '鍇', '鍈', '鍉', 
		'鍊', '鍌', '鍎', '鍏', '鍐', '鍑', '鍒', '鍓', '鍕', '鍗', '鍘', '鍙', '鍚', '鍝', '鍞', '鍟', 
		'鍡', '鍢', '鍣', '鍤', '鍥', '鍦', '鍧', '鍨', '鍩', '鍪', '鍫', '鍭', '鍯', '鍰', '鍱', '鍲', 
		'鍳', '鍴', '鍶', '鍷', '鍸', '鍹', '鍺', '鍻', '鍽', '鍿', '鎀', '鎁', '鎂', '鎃', '鎄', '鎅', 
		'鎆', '鎇', '鎈', '鎉', '鎊', '鎋', '鎍', '鎎', '鎏', '鎐', '鎑', '鎒', '鎓', '鎕', '鎘', '鎙', 
		'鎛', '鎜', '鎝', '鎞', '鎟', '鎠', '鎡', '鎢', '鎣', '鎤', '鎥', '鎦', '鎨', '鎩', '鎪', '鎫', 
		'鎯', '鎱', '鎲', '鎳', '鎴', '鎵', '鎶', '鎷', '鎸', '鎺', '鎻', '鎼', '鎽', '鎾', '鎿', '鏀', 
		'鏁', '鏂', '鏄', '鏅', '鏆', '鏇', '鏉', '鏊', '鏋', '鏌', '鏍', '鏎', '鏏', '鏒', '鏓', '鏔', 
		'鏕', '鏙', '鏚', '鏛', '鏜', '鏞', '鏟', '鏠', '鏢', '鏣', '鏦', '鏧', '鏩', '鏪', '鏫', '鏬', 
		'鏭', '鏮', '鏯', '鏰', '鏱', '鏲', '鏳', '鏴', '鏵', '鏶', '鏷', '鏸', '鏹', '鏺', '鏻', '鏼', 
		'鏽', '鏾', '鏿', '鐀', '鐁', '鐂', '鐄', '鐅', '鐆', '鐈', '鐉', '鐊', '鐋', '鐌', '鐍', '鐎', 
		'鐏', '鐑', '鐒', '鐕', '鐖', '鐗', '鐛', '鐜', '鐝', '鐞', '鐟', '鐠', '鐢', '鐣', '鐤', '鐥', 
		'鐦', '鐧', '鐨', '鐩', '鐪', '鐬', '鐭', '鐮', '鐯', '鐰', '鐱', '鐲', '鐳', '鐴', '鐷', '鐹', 
		'鐻', '鐼', '鐽', '鐾', '鐿', '鑀', '鑂', '鑃', '鑅', '鑆', '鑇', '鑈', '鑉', '鑊', '鑋', '鑌', 
		'鑍', '鑎', '鑏', '鑐', '鑔', '鑕', '鑖', '鑗', '鑘', '鑙', '鑜', '鑝', '鑟', '鑡', '鑣', '鑤', 
		'鑥', '鑦', '鑧', '鑨', '鑩', '鑫', '鑬', '鑭', '鑮', '鑯', '鑱', '鑲', '鑳', '鑴', '鑶', '鑸', 
		'鑹', '鑺', '鑻', '钀', '钂', '钃', '钄', '钅', '钆', '钇', '针', '钉', '钊', '钋', '钌', '钍', 
		'钎', '钏', '钐', '钑', '钒', '钓', '钔', '钕', '钖', '钗', '钘', '钙', '钚', '钛', '钜', '钝', 
		'钞', '钟', '钠', '钡', '钢', '钣', '钤', '钥', '钦', '钧', '钨', '钩', '钪', '钫', '钬', '钭', 
		'钮', '钯', '钰', '钱', '钲', '钳', '钴', '钵', '钶', '钷', '钸', '钹', '钺', '钻', '钼', '钽', 
		'钾', '钿', '铀', '铁', '铂', '铃', '铄', '铅', '铆', '铇', '铈', '铉', '铊', '铋', '铌', '铍', 
		'铎', '铏', '铐', '铑', '铒', '铓', '铔', '铕', '铖', '铗', '铘', '铙', '铚', '铛', '铜', '铝', 
		'铞', '铟', '铠', '铡', '铢', '铣', '铤', '铥', '铦', '铧', '铨', '铩', '铪', '铫', '铬', '铭', 
		'铮', '铯', '铰', '铱', '铲', '铳', '铴', '铵', '银', '铷', '铸', '铹', '铺', '铻', '铼', '铽', 
		'链', '铿', '销', '锁', '锂', '锃', '锄', '锅', '锆', '锇', '锈', '锉', '锊', '锋', '锌', '锍', 
		'锎', '锏', '锐', '锑', '锒', '锓', '锔', '锕', '锖', '锗', '锘', '错', '锚', '锛', '锜', '锝', 
		'锞', '锟', '锠', '锡', '锢', '锣', '锤', '锥', '锦', '锧', '锨', '锩', '锪', '锫', '锬', '锭', 
		'键', '锯', '锰', '锱', '锲', '锳', '锴', '锵', '锶', '锷', '锸', '锹', '锺', '锻', '锼', '锽', 
		'锾', '锿', '镀', '镁', '镂', '镃', '镄', '镅', '镆', '镇', '镈', '镉', '镊', '镋', '镌', '镍', 
		'镎', '镏', '镐', '镑', '镒', '镓', '镔', '镕', '镖', '镗', '镘', '镙', '镚', '镛', '镜', '镝', 
		'镞', '镟', '镠', '镡', '镢', '镣', '镤', '镥', '镦', '镧', '镨', '镩', '镪', '镫', '镬', '镭', 
		'镮', '镯', '镰', '镱', '镲', '镳', '镴', '镵', '镶', '镸', '镹', '镺', '镻', '镼', '镽', '镾', 
		'长', '閁', '閄', '閅', '閆', '閈', '閌', '閍', '閎', '閐', '閒', '閕', '閗', '閚', '閛', '閜', 
		'閝', '閞', '閟', '閡', '閦', '閩', '閪', '閫', '閬', '閮', '閯', '閰', '閱', '閳', '閴', '閵', 
		'閶', '閷', '閸', '閺', '閽', '閿', '闀', '闁', '闂', '闄', '闅', '闆', '闈', '闉', '闋', '闎', 
		'闏', '闐', '闑', '闒', '闓', '闗', '闙', '闚', '闛', '闝', '闞', '闟', '闠', '闣', '闤', '闦', 
		'闧', '门', '闩', '闪', '闫', '闬', '闭', '问', '闯', '闰', '闱', '闲', '闳', '间', '闵', '闶', 
		'闷', '闸', '闹', '闺', '闻', '闼', '闽', '闾', '闿', '阀', '阁', '阂', '阃', '阄', '阅', '阆', 
		'阇', '阈', '阉', '阊', '阋', '阌', '阍', '阎', '阏', '阐', '阑', '阒', '阓', '阔', '阕', '阖', 
		'阗', '阘', '阙', '阚', '阛', '阝', '阞', '队', '阠', '阢', '阣', '阤', '阥', '阦', '阧', '阩', 
		'阫', '阬', '阭', '阰', '阱', '阳', '阴', '阵', '阶', '阷', '阸', '阹', '阺', '阼', '阽', '阾', 
		'陁', '陃', '际', '陆', '陇', '陈', '陉', '陊', '陎', '陑', '陒', '陓', '陔', '陕', '陖', '陗', 
		'陘', '陙', '陚', '陠', '陡', '陧', '陨', '险', '陫', '陭', '陮', '陯', '陱', '陴', '陹', '陻', 
		'陼', '陾', '陿', '隀', '隁', '隂', '隃', '隄', '隇', '隉', '隌', '隐', '隑', '隒', '隓', '隖', 
		'隚', '隝', '隞', '隟', '隡', '隢', '隤', '隥', '隦', '隩', '隫', '隬', '隭', '隮', '隯', '隳', 
		'隵', '隺', '隽', '难', '隿', '雂', '雃', '雈', '雊', '雏', '雐', '雒', '雓', '雔', '雗', '雘', 
		'雚', '雝', '雞', '雟', '雠', '雡', '雤', '雥', '雦', '雧', '雩', '雬', '雭', '雮', '雯', '雱', 
		'雳', '雴', '雵', '雸', '雺', '雼', '雽', '雾', '雿', '霁', '霂', '霃', '霅', '霉', '霋', '霌', 
		'霐', '霒', '霔', '霕', '霗', '霘', '霚', '霛', '霝', '霟', '霠', '霡', '霢', '霣', '霥', '霦', 
		'霨', '霩', '霫', '霬', '霭', '霮', '霯', '霱', '霳', '霴', '霵', '霶', '霷', '霺', '霻', '霼', 
		'霿', '靀', '靁', '靃', '靅', '靇', '靊', '靋', '靌', '靍', '靎', '靏', '靐', '靑', '靓', '靔', 
		'靕', '靗', '靘', '靚', '靛', '靝', '靟', '靣', '靥', '靧', '靪', '靬', '靮', '靯', '靰', '靲', 
		'靳', '靵', '靶', '靷', '靸', '靻', '靽', '靾', '靿', '鞀', '鞂', '鞃', '鞇', '鞈', '鞉', '鞊', 
		'鞌', '鞎', '鞑', '鞒', '鞓', '鞔', '鞕', '鞖', '鞗', '鞙', '鞚', '鞛', '鞝', '鞞', '鞟', '鞡', 
		'鞢', '鞤', '鞥', '鞧', '鞩', '鞪', '鞬', '鞮', '鞯', '鞰', '鞱', '鞲', '鞵', '鞶', '鞷', '鞸', 
		'鞹', '鞺', '鞻', '鞼', '鞽', '鞾', '鞿', '韀', '韁', '韂', '韄', '韅', '韇', '韉', '韊', '韌', 
		'韍', '韎', '韏', '韐', '韑', '韒', '韔', '韕', '韖', '韗', '韘', '韙', '韚', '韛', '韝', '韞', 
		'韟', '韠', '韡', '韢', '韣', '韤', '韥', '韦', '韧', '韨', '韩', '韪', '韫', '韬', '韯', '韰', 
		'韱', '韴', '韷', '韸', '韹', '韺', '韼', '韽', '韾', '頀', '頄', '頇', '頉', '頊', '頋', '頍', 
		'頎', '頔', '頕', '頖', '頙', '頛', '頜', '頝', '頞', '頟', '頠', '頢', '頣', '頥', '頦', '頧', 
		'頨', '頩', '頪', '頫', '頮', '頯', '頰', '頱', '頲', '頳', '頵', '頶', '頹', '頺', '頾', '頿', 
		'顀', '顁', '顂', '顃', '顄', '顅', '顇', '顈', '顉', '顊', '顐', '顑', '顒', '顓', '顖', '顗', 
		'顙', '顚', '顜', '顝', '顟', '顠', '顡', '顢', '顣', '顤', '顥', '顦', '顨', '顩', '顪', '顬', 
		'顭', '顮', '顲', '页', '顶', '顷', '顸', '项', '顺', '须', '顼', '顽', '顾', '顿', '颀', '颁', 
		'颂', '颃', '预', '颅', '领', '颇', '颈', '颉', '颊', '颋', '颌', '颍', '颎', '颏', '颐', '频', 
		'颒', '颓', '颔', '颕', '颖', '颗', '题', '颙', '颚', '颛', '颜', '额', '颞', '颟', '颠', '颡', 
		'颢', '颣', '颤', '颥', '颦', '颧', '颩', '颫', '颬', '颭', '颮', '颰', '颲', '颳', '颴', '颵', 
		'颷', '颸', '颹', '颺', '颻', '颼', '颽', '颾', '颿', '飀', '飁', '飂', '飅', '飇', '飈', '飉', 
		'飊', '飋', '飌', '飍', '风', '飏', '飐', '飑', '飒', '飓', '飔', '飕', '飖', '飗', '飘', '飙', 
		'飚', '飝', '飞', '飠', '飡', '飣', '飤', '飥', '飦', '飧', '飨', '飪', '飬', '飰', '飱', '飳', 
		'飵', '飶', '飷', '飸', '飹', '飺', '飻', '飿', '餀', '餁', '餂', '餄', '餆', '餇', '餈', '餋', 
		'餍', '餎', '餏', '餑', '餕', '餖', '餗', '餙', '餚', '餛', '餜', '餟', '餢', '餣', '餥', '餦', 
		'餧', '餩', '餪', '餫', '餭', '餯', '餰', '餱', '餲', '餳', '餴', '餵', '餶', '餷', '餸', '餹', 
		'餺', '餻', '餼', '餿', '饀', '饁', '饃', '饄', '饆', '饇', '饈', '饊', '饍', '饎', '饏', '饓', 
		'饔', '饖', '饘', '饙', '饚', '饛', '饜', '饝', '饞', '饟', '饠', '饡', '饢', '饣', '饤', '饥', 
		'饦', '饧', '饨', '饩', '饪', '饫', '饬', '饭', '饮', '饯', '饰', '饱', '饲', '饳', '饴', '饵', 
		'饶', '饷', '饸', '饹', '饺', '饻', '饼', '饽', '饾', '饿', '馀', '馁', '馂', '馃', '馄', '馅', 
		'馆', '馇', '馈', '馉', '馊', '馋', '馌', '馍', '馎', '馏', '馐', '馑', '馒', '馓', '馔', '馕', 
		'馚', '馛', '馜', '馝', '馞', '馟', '馠', '馡', '馢', '馣', '馤', '馦', '馧', '馩', '馪', '馫', 
		'馯', '馰', '馱', '馲', '馵', '馶', '馷', '馸', '馹', '馺', '馻', '馽', '馾', '馿', '駀', '駂', 
		'駃', '駇', '駉', '駊', '駋', '駌', '駍', '駎', '駏', '駓', '駔', '駖', '駗', '駙', '駚', '駜', 
		'駞', '駠', '駡', '駣', '駤', '駥', '駦', '駧', '駨', '駩', '駪', '駫', '駬', '駯', '駰', '駳', 
		'駴', '駵', '駶', '駷', '駹', '駺', '駼', '駽', '駾', '騀', '騂', '騃', '騄', '騆', '騇', '騈', 
		'騉', '騊', '騋', '騌', '騍', '騐', '騑', '騔', '騕', '騖', '騗', '騘', '騚', '騛', '騜', '騝', 
		'騞', '騟', '騠', '騡', '騢', '騣', '騤', '騥', '騦', '騧', '騩', '騪', '騬', '騭', '騮', '騯', 
		'騱', '騲', '騳', '騴', '騵', '騶', '騸', '騹', '騺', '騻', '騼', '騽', '騿', '驁', '驄', '驆', 
		'驇', '驈', '驉', '驊', '驋', '驌', '驎', '驏', '驐', '驑', '驒', '驓', '驔', '驖', '驘', '驙', 
		'驜', '驝', '驞', '驠', '驡', '驣', '驦', '驧', '驨', '马', '驭', '驮', '驯', '驰', '驱', '驲', 
		'驳', '驴', '驵', '驶', '驷', '驸', '驹', '驺', '驻', '驼', '驽', '驾', '驿', '骀', '骁', '骂', 
		'骃', '骄', '骅', '骆', '骇', '骈', '骉', '骊', '骋', '验', '骍', '骎', '骏', '骐', '骑', '骒', 
		'骓', '骔', '骕', '骖', '骗', '骘', '骙', '骚', '骛', '骜', '骝', '骞', '骟', '骠', '骡', '骢', 
		'骣', '骤', '骥', '骦', '骧', '骩', '骪', '骫', '骬', '骮', '骯', '骱', '骲', '骳', '骴', '骵', 
		'骶', '骷', '骹', '骺', '骻', '骽', '骾', '骿', '髁', '髂', '髃', '髅', '髆', '髇', '髈', '髉', 
		'髊', '髋', '髌', '髍', '髎', '髐', '髒', '髕', '髖', '髗', '髙', '髚', '髛', '髜', '髝', '髠', 
		'髡', '髤', '髥', '髧', '髨', '髩', '髬', '髰', '髲', '髳', '髵', '髶', '髸', '髹', '髺', '髼', 
		'髽', '髾', '髿', '鬀', '鬁', '鬂', '鬃', '鬄', '鬅', '鬇', '鬈', '鬉', '鬊', '鬋', '鬌', '鬍', 
		'鬎', '鬏', '鬐', '鬑', '鬒', '鬓', '鬔', '鬕', '鬖', '鬗', '鬙', '鬛', '鬜', '鬝', '鬞', '鬠', 
		'鬡', '鬤', '鬦', '鬫', '鬬', '鬭', '鬰', '鬳', '鬴', '鬵', '鬶', '鬷', '鬸', '鬹', '鬺', '鬽', 
		'鬾', '鬿', '魀', '魆', '魇', '魈', '魉', '魊', '魋', '魌', '魐', '魒', '魓', '魕', '魖', '魗', 
		'魙', '魛', '魜', '魝', '魞', '魟', '魠', '魡', '魢', '魣', '魤', '魥', '魦', '魧', '魨', '魩', 
		'魪', '魫', '魬', '魭', '魮', '魰', '魱', '魲', '魳', '魵', '魶', '魷', '魸', '魹', '魺', '魻', 
		'魼', '魽', '魾', '魿', '鮀', '鮁', '鮂', '鮄', '鮅', '鮆', '鮇', '鮈', '鮉', '鮊', '鮋', '鮌', 
		'鮍', '鮏', '鮐', '鮔', '鮕', '鮘', '鮙', '鮚', '鮛', '鮜', '鮝', '鮞', '鮡', '鮢', '鮣', '鮤', 
		'鮥', '鮦', '鮧', '鮩', '鮬', '鮯', '鮰', '鮱', '鮲', '鮳', '鮵', '鮶', '鮷', '鮸', '鮺', '鮻', 
		'鮼', '鮽', '鮾', '鮿', '鯁', '鯂', '鯃', '鯄', '鯅', '鯇', '鯈', '鯋', '鯌', '鯍', '鯎', '鯐', 
		'鯓', '鯕', '鯗', '鯘', '鯙', '鯚', '鯜', '鯝', '鯞', '鯟', '鯠', '鯥', '鯦', '鯧', '鯩', '鯪', 
		'鯫', '鯬', '鯭', '鯮', '鯯', '鯳', '鯴', '鯶', '鯷', '鯸', '鯹', '鯺', '鯻', '鯼', '鯽', '鯾', 
		'鯿', '鰀', '鰁', '鰂', '鰃', '鰅', '鰇', '鰋', '鰎', '鰏', '鰑', '鰖', '鰗', '鰘', '鰙', '鰚', 
		'鰜', '鰝', '鰞', '鰟', '鰠', '鰢', '鰣', '鰦', '鰧', '鰨', '鰩', '鰪', '鰫', '鰬', '鰱', '鰳', 
		'鰴', '鰵', '鰶', '鰷', '鰸', '鰼', '鰽', '鰿', '鱀', '鱁', '鱂', '鱃', '鱄', '鱅', '鱉', '鱊', 
		'鱋', '鱌', '鱍', '鱎', '鱏', '鱐', '鱑', '鱓', '鱔', '鱕', '鱖', '鱘', '鱙', '鱛', '鱜', '鱝', 
		'鱞', '鱟', '鱡', '鱢', '鱣', '鱤', '鱥', '鱦', '鱨', '鱩', '鱪', '鱫', '鱬', '鱭', '鱮', '鱯', 
		'鱰', '鱱', '鱲', '鱳', '鱴', '鱵', '鱷', '鱹', '鱺', '鱻', '鱼', '鱽', '鱾', '鱿', '鲀', '鲁', 
		'鲂', '鲃', '鲄', '鲅', '鲆', '鲇', '鲈', '鲉', '鲊', '鲋', '鲌', '鲍', '鲎', '鲏', '鲐', '鲑', 
		'鲒', '鲓', '鲔', '鲕', '鲖', '鲗', '鲘', '鲙', '鲚', '鲛', '鲜', '鲝', '鲞', '鲟', '鲠', '鲡', 
		'鲢', '鲣', '鲤', '鲥', '鲦', '鲧', '鲨', '鲩', '鲪', '鲫', '鲬', '鲭', '鲮', '鲯', '鲰', '鲱', 
		'鲲', '鲳', '鲴', '鲵', '鲶', '鲷', '鲸', '鲹', '鲺', '鲻', '鲼', '鲽', '鲾', '鲿', '鳀', '鳁', 
		'鳂', '鳃', '鳄', '鳅', '鳆', '鳇', '鳈', '鳉', '鳊', '鳋', '鳌', '鳍', '鳎', '鳏', '鳐', '鳑', 
		'鳒', '鳓', '鳔', '鳕', '鳖', '鳗', '鳘', '鳙', '鳚', '鳛', '鳜', '鳝', '鳞', '鳟', '鳠', '鳡', 
		'鳢', '鳣', '鳤', '鳦', '鳨', '鳪', '鳭', '鳮', '鳯', '鳱', '鳲', '鳵', '鳷', '鳸', '鳹', '鳺', 
		'鳻', '鳼', '鳽', '鳾', '鳿', '鴀', '鴁', '鴂', '鴄', '鴅', '鴊', '鴋', '鴌', '鴍', '鴏', '鴐', 
		'鴑', '鴓', '鴔', '鴖', '鴗', '鴘', '鴙', '鴚', '鴜', '鴝', '鴞', '鴠', '鴡', '鴢', '鴤', '鴥', 
		'鴧', '鴩', '鴭', '鴮', '鴯', '鴰', '鴱', '鴲', '鴳', '鴴', '鴵', '鴶', '鴷', '鴸', '鴹', '鴺', 
		'鴼', '鴽', '鵀', '鵂', '鵃', '鵅', '鵇', '鵉', '鵊', '鵋', '鵌', '鵍', '鵎', '鵏', '鵒', '鵓', 
		'鵔', '鵕', '鵖', '鵗', '鵘', '鵚', '鵛', '鵟', '鵢', '鵣', '鵥', '鵦', '鵧', '鵨', '鵩', '鵪', 
		'鵫', '鵭', '鵮', '鵰', '鵱', '鵳', '鵴', '鵵', '鵶', '鵷', '鵸', '鵹', '鵻', '鵼', '鵽', '鵾', 
		'鵿', '鶀', '鶁', '鶂', '鶃', '鶄', '鶅', '鶆', '鶈', '鶊', '鶋', '鶌', '鶍', '鶎', '鶐', '鶑', 
		'鶒', '鶓', '鶔', '鶕', '鶖', '鶗', '鶘', '鶙', '鶛', '鶜', '鶝', '鶞', '鶟', '鶠', '鶡', '鶢', 
		'鶣', '鶥', '鶦', '鶧', '鶨', '鶪', '鶬', '鶭', '鶮', '鶰', '鶱', '鶳', '鶵', '鶶', '鶷', '鶹', 
		'鶼', '鶽', '鶾', '鶿', '鷀', '鷃', '鷅', '鷇', '鷈', '鷉', '鷊', '鷋', '鷌', '鷍', '鷎', '鷐', 
		'鷑', '鷒', '鷔', '鷕', '鷖', '鷗', '鷘', '鷚', '鷛', '鷜', '鷝', '鷞', '鷟', '鷠', '鷡', '鷢', 
		'鷣', '鷤', '鷥', '鷧', '鷨', '鷩', '鷪', '鷫', '鷬', '鷮', '鷰', '鷱', '鷳', '鷴', '鷵', '鷶', 
		'鷷', '鷻', '鷼', '鷾', '鷿', '鸀', '鸁', '鸂', '鸃', '鸄', '鸅', '鸆', '鸇', '鸈', '鸉', '鸊', 
		'鸋', '鸌', '鸍', '鸎', '鸏', '鸐', '鸑', '鸒', '鸓', '鸔', '鸕', '鸖', '鸗', '鸘', '鸙', '鸜', 
		'鸝', '鸟', '鸠', '鸡', '鸢', '鸣', '鸤', '鸥', '鸦', '鸧', '鸨', '鸩', '鸪', '鸫', '鸬', '鸭', 
		'鸮', '鸯', '鸰', '鸱', '鸲', '鸳', '鸴', '鸵', '鸶', '鸷', '鸸', '鸹', '鸺', '鸻', '鸼', '鸽', 
		'鸾', '鸿', '鹀', '鹁', '鹂', '鹃', '鹄', '鹅', '鹆', '鹇', '鹈', '鹉', '鹊', '鹋', '鹌', '鹍', 
		'鹎', '鹏', '鹐', '鹑', '鹒', '鹓', '鹔', '鹕', '鹖', '鹗', '鹘', '鹙', '鹚', '鹛', '鹜', '鹝', 
		'鹞', '鹟', '鹠', '鹡', '鹢', '鹣', '鹤', '鹥', '鹦', '鹧', '鹨', '鹩', '鹪', '鹫', '鹬', '鹭', 
		'鹮', '鹯', '鹰', '鹱', '鹲', '鹳', '鹴', '鹶', '鹷', '鹺', '鹻', '鹼', '鹾', '麀', '麂', '麃', 
		'麄', '麅', '麆', '麇', '麉', '麊', '麍', '麎', '麏', '麐', '麔', '麖', '麘', '麙', '麚', '麛', 
		'麜', '麞', '麠', '麡', '麢', '麣', '麤', '麧', '麨', '麫', '麬', '麮', '麯', '麰', '麱', '麲', 
		'麳', '麴', '麵', '麶', '麷', '麽', '黀', '黁', '黂', '黃', '黅', '黆', '黇', '黈', '黉', '黊', 
		'黋', '黑', '黓', '黕', '黖', '黗', '黚', '黟', '黡', '黢', '黣', '黤', '黦', '黧', '黩', '黪', 
		'黫', '黬', '黭', '黮', '黰', '黱', '黲', '黳', '黵', '黸', '黺', '黾', '黿', '鼀', '鼁', '鼂', 
		'鼃', '鼄', '鼅', '鼆', '鼉', '鼊', '鼋', '鼌', '鼍', '鼏', '鼐', '鼑', '鼒', '鼔', '鼖', '鼗', 
		'鼘', '鼙', '鼚', '鼛', '鼜', '鼝', '鼞', '鼟', '鼢', '鼣', '鼤', '鼥', '鼦', '鼧', '鼨', '鼩', 
		'鼪', '鼫', '鼭', '鼮', '鼯', '鼰', '鼱', '鼲', '鼳', '鼴', '鼵', '鼶', '鼷', '鼸', '鼹', '鼺', 
		'鼼', '鼽', '鼿', '齀', '齁', '齂', '齃', '齄', '齅', '齆', '齇', '齈', '齉', '齌', '齍', '齐', 
		'齑', '齓', '齕', '齖', '齗', '齘', '齙', '齚', '齛', '齜', '齝', '齞', '齤', '齥', '齨', '齩', 
		'齫', '齭', '齮', '齯', '齰', '齱', '齳', '齴', '齵', '齸', '齹', '齺', '齻', '齼', '齽', '齾', 
		'齿', '龀', '龁', '龂', '龃', '龄', '龅', '龆', '龇', '龈', '龉', '龊', '龋', '龌', '龎', '龏', 
		'龐', '龑', '龒', '龓', '龔', '龖', '龗', '龘', '龙', '龚', '龛', '龞', '龟', '龡', '龢', '龣', 
		'龤', '龥', '龦', '龧', '龨', '龩', '龪', '龫', '龬', '龭', '龮', '龯', '龰', '龱', '龲', '龳', 
		'龴', '龵', '龶', '龷', '龸', '龹', '龺', '龻', '龼', '龽', '龾', '龿', '鿀', '鿁', '鿂', '鿃', 
		'鿄', '鿅', '鿆', '鿇', '鿈', '鿉', '鿊', '鿋', '鿌', '鿍', '鿎', '鿏', '鿐', '鿑', '鿒', '鿓', 
		'鿔', '鿕', '鿖', '鿗', '鿘', '鿙', '鿚', '鿛', '鿜', '鿝', '鿞', '鿟', '鿠', '鿡', '鿢', '鿣', 
		'鿤', '鿥', '鿦', '鿧', '鿨', '鿩', '鿪', '鿫', '鿬', '鿭', '鿮', '鿯', '鿰', '鿱', '鿲', '鿳', 
		'鿴', '鿵', '鿶', '鿷', '鿸', '鿹', '鿺', '鿻', '鿼', '鿽', '鿾', '鿿', '㐀', '㐁', '㐂', '㐃', 
		'㐄', '㐅', '㐆', '㐇', '㐈', '㐉', '㐊', '㐋', '㐌', '㐍', '㐎', '㐏', '㐐', '㐑', '㐒', '㐓', 
		'㐔', '㐕', '㐖', '㐗', '㐘', '㐙', '㐚', '㐛', '㐜', '㐝', '㐞', '㐟', '㐠', '㐡', '㐢', '㐣', 
		'㐤', '㐥', '㐦', '㐧', '㐨', '㐩', '㐪', '㐫', '㐬', '㐭', '㐮', '㐯', '㐰', '㐱', '㐲', '㐳', 
		'㐴', '㐵', '㐶', '㐷', '㐸', '㐹', '㐺', '㐻', '㐼', '㐽', '㐾', '㐿', '㑀', '㑁', '㑂', '㑃', 
		'㑄', '㑅', '㑆', '㑇', '㑈', '㑉', '㑊', '㑋', '㑌', '㑍', '㑎', '㑏', '㑐', '㑑', '㑒', '㑓', 
		'㑔', '㑕', '㑖', '㑗', '㑘', '㑙', '㑚', '㑛', '㑜', '㑝', '㑞', '㑟', '㑠', '㑡', '㑢', '㑣', 
		'㑤', '㑥', '㑦', '㑧', '㑨', '㑩', '㑪', '㑫', '㑬', '㑭', '㑮', '㑯', '㑰', '㑱', '㑲', '㑳', 
		'㑴', '㑵', '㑶', '㑷', '㑸', '㑹', '㑺', '㑻', '㑼', '㑽', '㑾', '㑿', '㒀', '㒁', '㒂', '㒃', 
		'㒄', '㒅', '㒆', '㒇', '㒈', '㒉', '㒊', '㒋', '㒌', '㒍', '㒎', '㒏', '㒐', '㒑', '㒒', '㒓', 
		'㒔', '㒕', '㒖', '㒗', '㒘', '㒙', '㒚', '㒛', '㒜', '㒝', '㒞', '㒟', '㒠', '㒡', '㒢', '㒣', 
		'㒤', '㒥', '㒦', '㒧', '㒨', '㒩', '㒪', '㒫', '㒬', '㒭', '㒮', '㒯', '㒰', '㒱', '㒲', '㒳', 
		'㒴', '㒵', '㒶', '㒷', '㒸', '㒹', '㒺', '㒻', '㒼', '㒽', '㒾', '㒿', '㓀', '㓁', '㓂', '㓃', 
		'㓄', '㓅', '㓆', '㓇', '㓈', '㓉', '㓊', '㓋', '㓌', '㓍', '㓎', '㓏', '㓐', '㓑', '㓒', '㓓', 
		'㓔', '㓕', '㓖', '㓗', '㓘', '㓙', '㓚', '㓛', '㓜', '㓝', '㓞', '㓟', '㓠', '㓡', '㓢', '㓣', 
		'㓤', '㓥', '㓦', '㓧', '㓨', '㓩', '㓪', '㓫', '㓬', '㓭', '㓮', '㓯', '㓰', '㓱', '㓲', '㓳', 
		'㓴', '㓵', '㓶', '㓷', '㓸', '㓹', '㓺', '㓻', '㓼', '㓽', '㓾', '㓿', '㔀', '㔁', '㔂', '㔃', 
		'㔄', '㔅', '㔆', '㔇', '㔈', '㔉', '㔊', '㔋', '㔌', '㔍', '㔎', '㔏', '㔐', '㔑', '㔒', '㔓', 
		'㔔', '㔕', '㔖', '㔗', '㔘', '㔙', '㔚', '㔛', '㔜', '㔝', '㔞', '㔟', '㔠', '㔡', '㔢', '㔣', 
		'㔤', '㔥', '㔦', '㔧', '㔨', '㔩', '㔪', '㔫', '㔬', '㔭', '㔮', '㔯', '㔰', '㔱', '㔲', '㔳', 
		'㔴', '㔵', '㔶', '㔷', '㔸', '㔹', '㔺', '㔻', '㔼', '㔽', '㔾', '㔿', '㕀', '㕁', '㕂', '㕃', 
		'㕄', '㕅', '㕆', '㕇', '㕈', '㕉', '㕊', '㕋', '㕌', '㕍', '㕎', '㕏', '㕐', '㕑', '㕒', '㕓', 
		'㕔', '㕕', '㕖', '㕗', '㕘', '㕙', '㕚', '㕛', '㕜', '㕝', '㕞', '㕟', '㕠', '㕡', '㕢', '㕣', 
		'㕤', '㕥', '㕦', '㕧', '㕨', '㕩', '㕪', '㕫', '㕬', '㕭', '㕮', '㕯', '㕰', '㕱', '㕲', '㕳', 
		'㕴', '㕵', '㕶', '㕷', '㕸', '㕹', '㕺', '㕻', '㕼', '㕽', '㕾', '㕿', '㖀', '㖁', '㖂', '㖃', 
		'㖄', '㖅', '㖆', '㖇', '㖈', '㖉', '㖊', '㖋', '㖌', '㖍', '㖎', '㖏', '㖐', '㖑', '㖒', '㖓', 
		'㖔', '㖕', '㖖', '㖗', '㖘', '㖙', '㖚', '㖛', '㖜', '㖝', '㖞', '㖟', '㖠', '㖡', '㖢', '㖣', 
		'㖤', '㖥', '㖦', '㖧', '㖨', '㖩', '㖪', '㖫', '㖬', '㖭', '㖮', '㖯', '㖰', '㖱', '㖲', '㖳', 
		'㖴', '㖵', '㖶', '㖷', '㖸', '㖹', '㖺', '㖻', '㖼', '㖽', '㖾', '㖿', '㗀', '㗁', '㗂', '㗃', 
		'㗄', '㗅', '㗆', '㗇', '㗈', '㗉', '㗊', '㗋', '㗌', '㗍', '㗎', '㗏', '㗐', '㗑', '㗒', '㗓', 
		'㗔', '㗕', '㗖', '㗗', '㗘', '㗙', '㗚', '㗛', '㗜', '㗝', '㗞', '㗟', '㗠', '㗡', '㗢', '㗣', 
		'㗤', '㗥', '㗦', '㗧', '㗨', '㗩', '㗪', '㗫', '㗬', '㗭', '㗮', '㗯', '㗰', '㗱', '㗲', '㗳', 
		'㗴', '㗵', '㗶', '㗷', '㗸', '㗹', '㗺', '㗻', '㗼', '㗽', '㗾', '㗿', '㘀', '㘁', '㘂', '㘃', 
		'㘄', '㘅', '㘆', '㘇', '㘈', '㘉', '㘊', '㘋', '㘌', '㘍', '㘎', '㘏', '㘐', '㘑', '㘒', '㘓', 
		'㘔', '㘕', '㘖', '㘗', '㘘', '㘙', '㘚', '㘛', '㘜', '㘝', '㘞', '㘟', '㘠', '㘡', '㘢', '㘣', 
		'㘤', '㘥', '㘦', '㘧', '㘨', '㘩', '㘪', '㘫', '㘬', '㘭', '㘮', '㘯', '㘰', '㘱', '㘲', '㘳', 
		'㘴', '㘵', '㘶', '㘷', '㘸', '㘹', '㘺', '㘻', '㘼', '㘽', '㘾', '㘿', '㙀', '㙁', '㙂', '㙃', 
		'㙄', '㙅', '㙆', '㙇', '㙈', '㙉', '㙊', '㙋', '㙌', '㙍', '㙎', '㙏', '㙐', '㙑', '㙒', '㙓', 
		'㙔', '㙕', '㙖', '㙗', '㙘', '㙙', '㙚', '㙛', '㙜', '㙝', '㙞', '㙟', '㙠', '㙡', '㙢', '㙣', 
		'㙤', '㙥', '㙦', '㙧', '㙨', '㙩', '㙪', '㙫', '㙬', '㙭', '㙮', '㙯', '㙰', '㙱', '㙲', '㙳', 
		'㙴', '㙵', '㙶', '㙷', '㙸', '㙹', '㙺', '㙻', '㙼', '㙽', '㙾', '㙿', '㚀', '㚁', '㚂', '㚃', 
		'㚄', '㚅', '㚆', '㚇', '㚈', '㚉', '㚊', '㚋', '㚌', '㚍', '㚎', '㚏', '㚐', '㚑', '㚒', '㚓', 
		'㚔', '㚕', '㚖', '㚗', '㚘', '㚙', '㚚', '㚛', '㚜', '㚝', '㚞', '㚟', '㚠', '㚡', '㚢', '㚣', 
		'㚤', '㚥', '㚦', '㚧', '㚨', '㚩', '㚪', '㚫', '㚬', '㚭', '㚮', '㚯', '㚰', '㚱', '㚲', '㚳', 
		'㚴', '㚵', '㚶', '㚷', '㚸', '㚹', '㚺', '㚻', '㚼', '㚽', '㚾', '㚿', '㛀', '㛁', '㛂', '㛃', 
		'㛄', '㛅', '㛆', '㛇', '㛈', '㛉', '㛊', '㛋', '㛌', '㛍', '㛎', '㛏', '㛐', '㛑', '㛒', '㛓', 
		'㛔', '㛕', '㛖', '㛗', '㛘', '㛙', '㛚', '㛛', '㛜', '㛝', '㛞', '㛟', '㛠', '㛡', '㛢', '㛣', 
		'㛤', '㛥', '㛦', '㛧', '㛨', '㛩', '㛪', '㛫', '㛬', '㛭', '㛮', '㛯', '㛰', '㛱', '㛲', '㛳', 
		'㛴', '㛵', '㛶', '㛷', '㛸', '㛹', '㛺', '㛻', '㛼', '㛽', '㛾', '㛿', '㜀', '㜁', '㜂', '㜃', 
		'㜄', '㜅', '㜆', '㜇', '㜈', '㜉', '㜊', '㜋', '㜌', '㜍', '㜎', '㜏', '㜐', '㜑', '㜒', '㜓', 
		'㜔', '㜕', '㜖', '㜗', '㜘', '㜙', '㜚', '㜛', '㜜', '㜝', '㜞', '㜟', '㜠', '㜡', '㜢', '㜣', 
		'㜤', '㜥', '㜦', '㜧', '㜨', '㜩', '㜪', '㜫', '㜬', '㜭', '㜮', '㜯', '㜰', '㜱', '㜲', '㜳', 
		'㜴', '㜵', '㜶', '㜷', '㜸', '㜹', '㜺', '㜻', '㜼', '㜽', '㜾', '㜿', '㝀', '㝁', '㝂', '㝃', 
		'㝄', '㝅', '㝆', '㝇', '㝈', '㝉', '㝊', '㝋', '㝌', '㝍', '㝎', '㝏', '㝐', '㝑', '㝒', '㝓', 
		'㝔', '㝕', '㝖', '㝗', '㝘', '㝙', '㝚', '㝛', '㝜', '㝝', '㝞', '㝟', '㝠', '㝡', '㝢', '㝣', 
		'㝤', '㝥', '㝦', '㝧', '㝨', '㝩', '㝪', '㝫', '㝬', '㝭', '㝮', '㝯', '㝰', '㝱', '㝲', '㝳', 
		'㝴', '㝵', '㝶', '㝷', '㝸', '㝹', '㝺', '㝻', '㝼', '㝽', '㝾', '㝿', '㞀', '㞁', '㞂', '㞃', 
		'㞄', '㞅', '㞆', '㞇', '㞈', '㞉', '㞊', '㞋', '㞌', '㞍', '㞎', '㞏', '㞐', '㞑', '㞒', '㞓', 
		'㞔', '㞕', '㞖', '㞗', '㞘', '㞙', '㞚', '㞛', '㞜', '㞝', '㞞', '㞟', '㞠', '㞡', '㞢', '㞣', 
		'㞤', '㞥', '㞦', '㞧', '㞨', '㞩', '㞪', '㞫', '㞬', '㞭', '㞮', '㞯', '㞰', '㞱', '㞲', '㞳', 
		'㞴', '㞵', '㞶', '㞷', '㞸', '㞹', '㞺', '㞻', '㞼', '㞽', '㞾', '㞿', '㟀', '㟁', '㟂', '㟃', 
		'㟄', '㟅', '㟆', '㟇', '㟈', '㟉', '㟊', '㟋', '㟌', '㟍', '㟎', '㟏', '㟐', '㟑', '㟒', '㟓', 
		'㟔', '㟕', '㟖', '㟗', '㟘', '㟙', '㟚', '㟛', '㟜', '㟝', '㟞', '㟟', '㟠', '㟡', '㟢', '㟣', 
		'㟤', '㟥', '㟦', '㟧', '㟨', '㟩', '㟪', '㟫', '㟬', '㟭', '㟮', '㟯', '㟰', '㟱', '㟲', '㟳', 
		'㟴', '㟵', '㟶', '㟷', '㟸', '㟹', '㟺', '㟻', '㟼', '㟽', '㟾', '㟿', '㠀', '㠁', '㠂', '㠃', 
		'㠄', '㠅', '㠆', '㠇', '㠈', '㠉', '㠊', '㠋', '㠌', '㠍', '㠎', '㠏', '㠐', '㠑', '㠒', '㠓', 
		'㠔', '㠕', '㠖', '㠗', '㠘', '㠙', '㠚', '㠛', '㠜', '㠝', '㠞', '㠟', '㠠', '㠡', '㠢', '㠣', 
		'㠤', '㠥', '㠦', '㠧', '㠨', '㠩', '㠪', '㠫', '㠬', '㠭', '㠮', '㠯', '㠰', '㠱', '㠲', '㠳', 
		'㠴', '㠵', '㠶', '㠷', '㠸', '㠹', '㠺', '㠻', '㠼', '㠽', '㠾', '㠿', '㡀', '㡁', '㡂', '㡃', 
		'㡄', '㡅', '㡆', '㡇', '㡈', '㡉', '㡊', '㡋', '㡌', '㡍', '㡎', '㡏', '㡐', '㡑', '㡒', '㡓', 
		'㡔', '㡕', '㡖', '㡗', '㡘', '㡙', '㡚', '㡛', '㡜', '㡝', '㡞', '㡟', '㡠', '㡡', '㡢', '㡣', 
		'㡤', '㡥', '㡦', '㡧', '㡨', '㡩', '㡪', '㡫', '㡬', '㡭', '㡮', '㡯', '㡰', '㡱', '㡲', '㡳', 
		'㡴', '㡵', '㡶', '㡷', '㡸', '㡹', '㡺', '㡻', '㡼', '㡽', '㡾', '㡿', '㢀', '㢁', '㢂', '㢃', 
		'㢄', '㢅', '㢆', '㢇', '㢈', '㢉', '㢊', '㢋', '㢌', '㢍', '㢎', '㢏', '㢐', '㢑', '㢒', '㢓', 
		'㢔', '㢕', '㢖', '㢗', '㢘', '㢙', '㢚', '㢛', '㢜', '㢝', '㢞', '㢟', '㢠', '㢡', '㢢', '㢣', 
		'㢤', '㢥', '㢦', '㢧', '㢨', '㢩', '㢪', '㢫', '㢬', '㢭', '㢮', '㢯', '㢰', '㢱', '㢲', '㢳', 
		'㢴', '㢵', '㢶', '㢷', '㢸', '㢹', '㢺', '㢻', '㢼', '㢽', '㢾', '㢿', '㣀', '㣁', '㣂', '㣃', 
		'㣄', '㣅', '㣆', '㣇', '㣈', '㣉', '㣊', '㣋', '㣌', '㣍', '㣎', '㣏', '㣐', '㣑', '㣒', '㣓', 
		'㣔', '㣕', '㣖', '㣗', '㣘', '㣙', '㣚', '㣛', '㣜', '㣝', '㣞', '㣟', '㣠', '㣡', '㣢', '㣣', 
		'㣤', '㣥', '㣦', '㣧', '㣨', '㣩', '㣪', '㣫', '㣬', '㣭', '㣮', '㣯', '㣰', '㣱', '㣲', '㣳', 
		'㣴', '㣵', '㣶', '㣷', '㣸', '㣹', '㣺', '㣻', '㣼', '㣽', '㣾', '㣿', '㤀', '㤁', '㤂', '㤃', 
		'㤄', '㤅', '㤆', '㤇', '㤈', '㤉', '㤊', '㤋', '㤌', '㤍', '㤎', '㤏', '㤐', '㤑', '㤒', '㤓', 
		'㤔', '㤕', '㤖', '㤗', '㤘', '㤙', '㤚', '㤛', '㤜', '㤝', '㤞', '㤟', '㤠', '㤡', '㤢', '㤣', 
		'㤤', '㤥', '㤦', '㤧', '㤨', '㤩', '㤪', '㤫', '㤬', '㤭', '㤮', '㤯', '㤰', '㤱', '㤲', '㤳', 
		'㤴', '㤵', '㤶', '㤷', '㤸', '㤹', '㤺', '㤻', '㤼', '㤽', '㤾', '㤿', '㥀', '㥁', '㥂', '㥃', 
		'㥄', '㥅', '㥆', '㥇', '㥈', '㥉', '㥊', '㥋', '㥌', '㥍', '㥎', '㥏', '㥐', '㥑', '㥒', '㥓', 
		'㥔', '㥕', '㥖', '㥗', '㥘', '㥙', '㥚', '㥛', '㥜', '㥝', '㥞', '㥟', '㥠', '㥡', '㥢', '㥣', 
		'㥤', '㥥', '㥦', '㥧', '㥨', '㥩', '㥪', '㥫', '㥬', '㥭', '㥮', '㥯', '㥰', '㥱', '㥲', '㥳', 
		'㥴', '㥵', '㥶', '㥷', '㥸', '㥹', '㥺', '㥻', '㥼', '㥽', '㥾', '㥿', '㦀', '㦁', '㦂', '㦃', 
		'㦄', '㦅', '㦆', '㦇', '㦈', '㦉', '㦊', '㦋', '㦌', '㦍', '㦎', '㦏', '㦐', '㦑', '㦒', '㦓', 
		'㦔', '㦕', '㦖', '㦗', '㦘', '㦙', '㦚', '㦛', '㦜', '㦝', '㦞', '㦟', '㦠', '㦡', '㦢', '㦣', 
		'㦤', '㦥', '㦦', '㦧', '㦨', '㦩', '㦪', '㦫', '㦬', '㦭', '㦮', '㦯', '㦰', '㦱', '㦲', '㦳', 
		'㦴', '㦵', '㦶', '㦷', '㦸', '㦹', '㦺', '㦻', '㦼', '㦽', '㦾', '㦿', '㧀', '㧁', '㧂', '㧃', 
		'㧄', '㧅', '㧆', '㧇', '㧈', '㧉', '㧊', '㧋', '㧌', '㧍', '㧎', '㧏', '㧐', '㧑', '㧒', '㧓', 
		'㧔', '㧕', '㧖', '㧗', '㧘', '㧙', '㧚', '㧛', '㧜', '㧝', '㧞', '㧟', '㧠', '㧡', '㧢', '㧣', 
		'㧤', '㧥', '㧦', '㧧', '㧨', '㧩', '㧪', '㧫', '㧬', '㧭', '㧮', '㧯', '㧰', '㧱', '㧲', '㧳', 
		'㧴', '㧵', '㧶', '㧷', '㧸', '㧹', '㧺', '㧻', '㧼', '㧽', '㧾', '㧿', '㨀', '㨁', '㨂', '㨃', 
		'㨄', '㨅', '㨆', '㨇', '㨈', '㨉', '㨊', '㨋', '㨌', '㨍', '㨎', '㨏', '㨐', '㨑', '㨒', '㨓', 
		'㨔', '㨕', '㨖', '㨗', '㨘', '㨙', '㨚', '㨛', '㨜', '㨝', '㨞', '㨟', '㨠', '㨡', '㨢', '㨣', 
		'㨤', '㨥', '㨦', '㨧', '㨨', '㨩', '㨪', '㨫', '㨬', '㨭', '㨮', '㨯', '㨰', '㨱', '㨲', '㨳', 
		'㨴', '㨵', '㨶', '㨷', '㨸', '㨹', '㨺', '㨻', '㨼', '㨽', '㨾', '㨿', '㩀', '㩁', '㩂', '㩃', 
		'㩄', '㩅', '㩆', '㩇', '㩈', '㩉', '㩊', '㩋', '㩌', '㩍', '㩎', '㩏', '㩐', '㩑', '㩒', '㩓', 
		'㩔', '㩕', '㩖', '㩗', '㩘', '㩙', '㩚', '㩛', '㩜', '㩝', '㩞', '㩟', '㩠', '㩡', '㩢', '㩣', 
		'㩤', '㩥', '㩦', '㩧', '㩨', '㩩', '㩪', '㩫', '㩬', '㩭', '㩮', '㩯', '㩰', '㩱', '㩲', '㩳', 
		'㩴', '㩵', '㩶', '㩷', '㩸', '㩹', '㩺', '㩻', '㩼', '㩽', '㩾', '㩿', '㪀', '㪁', '㪂', '㪃', 
		'㪄', '㪅', '㪆', '㪇', '㪈', '㪉', '㪊', '㪋', '㪌', '㪍', '㪎', '㪏', '㪐', '㪑', '㪒', '㪓', 
		'㪔', '㪕', '㪖', '㪗', '㪘', '㪙', '㪚', '㪛', '㪜', '㪝', '㪞', '㪟', '㪠', '㪡', '㪢', '㪣', 
		'㪤', '㪥', '㪦', '㪧', '㪨', '㪩', '㪪', '㪫', '㪬', '㪭', '㪮', '㪯', '㪰', '㪱', '㪲', '㪳', 
		'㪴', '㪵', '㪶', '㪷', '㪸', '㪹', '㪺', '㪻', '㪼', '㪽', '㪾', '㪿', '㫀', '㫁', '㫂', '㫃', 
		'㫄', '㫅', '㫆', '㫇', '㫈', '㫉', '㫊', '㫋', '㫌', '㫍', '㫎', '㫏', '㫐', '㫑', '㫒', '㫓', 
		'㫔', '㫕', '㫖', '㫗', '㫘', '㫙', '㫚', '㫛', '㫜', '㫝', '㫞', '㫟', '㫠', '㫡', '㫢', '㫣', 
		'㫤', '㫥', '㫦', '㫧', '㫨', '㫩', '㫪', '㫫', '㫬', '㫭', '㫮', '㫯', '㫰', '㫱', '㫲', '㫳', 
		'㫴', '㫵', '㫶', '㫷', '㫸', '㫹', '㫺', '㫻', '㫼', '㫽', '㫾', '㫿', '㬀', '㬁', '㬂', '㬃', 
		'㬄', '㬅', '㬆', '㬇', '㬈', '㬉', '㬊', '㬋', '㬌', '㬍', '㬎', '㬏', '㬐', '㬑', '㬒', '㬓', 
		'㬔', '㬕', '㬖', '㬗', '㬘', '㬙', '㬚', '㬛', '㬜', '㬝', '㬞', '㬟', '㬠', '㬡', '㬢', '㬣', 
		'㬤', '㬥', '㬦', '㬧', '㬨', '㬩', '㬪', '㬫', '㬬', '㬭', '㬮', '㬯', '㬰', '㬱', '㬲', '㬳', 
		'㬴', '㬵', '㬶', '㬷', '㬸', '㬹', '㬺', '㬻', '㬼', '㬽', '㬾', '㬿', '㭀', '㭁', '㭂', '㭃', 
		'㭄', '㭅', '㭆', '㭇', '㭈', '㭉', '㭊', '㭋', '㭌', '㭍', '㭎', '㭏', '㭐', '㭑', '㭒', '㭓', 
		'㭔', '㭕', '㭖', '㭗', '㭘', '㭙', '㭚', '㭛', '㭜', '㭝', '㭞', '㭟', '㭠', '㭡', '㭢', '㭣', 
		'㭤', '㭥', '㭦', '㭧', '㭨', '㭩', '㭪', '㭫', '㭬', '㭭', '㭮', '㭯', '㭰', '㭱', '㭲', '㭳', 
		'㭴', '㭵', '㭶', '㭷', '㭸', '㭹', '㭺', '㭻', '㭼', '㭽', '㭾', '㭿', '㮀', '㮁', '㮂', '㮃', 
		'㮄', '㮅', '㮆', '㮇', '㮈', '㮉', '㮊', '㮋', '㮌', '㮍', '㮎', '㮏', '㮐', '㮑', '㮒', '㮓', 
		'㮔', '㮕', '㮖', '㮗', '㮘', '㮙', '㮚', '㮛', '㮜', '㮝', '㮞', '㮟', '㮠', '㮡', '㮢', '㮣', 
		'㮤', '㮥', '㮦', '㮧', '㮨', '㮩', '㮪', '㮫', '㮬', '㮭', '㮮', '㮯', '㮰', '㮱', '㮲', '㮳', 
		'㮴', '㮵', '㮶', '㮷', '㮸', '㮹', '㮺', '㮻', '㮼', '㮽', '㮾', '㮿', '㯀', '㯁', '㯂', '㯃', 
		'㯄', '㯅', '㯆', '㯇', '㯈', '㯉', '㯊', '㯋', '㯌', '㯍', '㯎', '㯏', '㯐', '㯑', '㯒', '㯓', 
		'㯔', '㯕', '㯖', '㯗', '㯘', '㯙', '㯚', '㯛', '㯜', '㯝', '㯞', '㯟', '㯠', '㯡', '㯢', '㯣', 
		'㯤', '㯥', '㯦', '㯧', '㯨', '㯩', '㯪', '㯫', '㯬', '㯭', '㯮', '㯯', '㯰', '㯱', '㯲', '㯳', 
		'㯴', '㯵', '㯶', '㯷', '㯸', '㯹', '㯺', '㯻', '㯼', '㯽', '㯾', '㯿', '㰀', '㰁', '㰂', '㰃', 
		'㰄', '㰅', '㰆', '㰇', '㰈', '㰉', '㰊', '㰋', '㰌', '㰍', '㰎', '㰏', '㰐', '㰑', '㰒', '㰓', 
		'㰔', '㰕', '㰖', '㰗', '㰘', '㰙', '㰚', '㰛', '㰜', '㰝', '㰞', '㰟', '㰠', '㰡', '㰢', '㰣', 
		'㰤', '㰥', '㰦', '㰧', '㰨', '㰩', '㰪', '㰫', '㰬', '㰭', '㰮', '㰯', '㰰', '㰱', '㰲', '㰳', 
		'㰴', '㰵', '㰶', '㰷', '㰸', '㰹', '㰺', '㰻', '㰼', '㰽', '㰾', '㰿', '㱀', '㱁', '㱂', '㱃', 
		'㱄', '㱅', '㱆', '㱇', '㱈', '㱉', '㱊', '㱋', '㱌', '㱍', '㱎', '㱏', '㱐', '㱑', '㱒', '㱓', 
		'㱔', '㱕', '㱖', '㱗', '㱘', '㱙', '㱚', '㱛', '㱜', '㱝', '㱞', '㱟', '㱠', '㱡', '㱢', '㱣', 
		'㱤', '㱥', '㱦', '㱧', '㱨', '㱩', '㱪', '㱫', '㱬', '㱭', '㱮', '㱯', '㱰', '㱱', '㱲', '㱳', 
		'㱴', '㱵', '㱶', '㱷', '㱸', '㱹', '㱺', '㱻', '㱼', '㱽', '㱾', '㱿', '㲀', '㲁', '㲂', '㲃', 
		'㲄', '㲅', '㲆', '㲇', '㲈', '㲉', '㲊', '㲋', '㲌', '㲍', '㲎', '㲏', '㲐', '㲑', '㲒', '㲓', 
		'㲔', '㲕', '㲖', '㲗', '㲘', '㲙', '㲚', '㲛', '㲜', '㲝', '㲞', '㲟', '㲠', '㲡', '㲢', '㲣', 
		'㲤', '㲥', '㲦', '㲧', '㲨', '㲩', '㲪', '㲫', '㲬', '㲭', '㲮', '㲯', '㲰', '㲱', '㲲', '㲳', 
		'㲴', '㲵', '㲶', '㲷', '㲸', '㲹', '㲺', '㲻', '㲼', '㲽', '㲾', '㲿', '㳀', '㳁', '㳂', '㳃', 
		'㳄', '㳅', '㳆', '㳇', '㳈', '㳉', '㳊', '㳋', '㳌', '㳍', '㳎', '㳏', '㳐', '㳑', '㳒', '㳓', 
		'㳔', '㳕', '㳖', '㳗', '㳘', '㳙', '㳚', '㳛', '㳜', '㳝', '㳞', '㳟', '㳠', '㳡', '㳢', '㳣', 
		'㳤', '㳥', '㳦', '㳧', '㳨', '㳩', '㳪', '㳫', '㳬', '㳭', '㳮', '㳯', '㳰', '㳱', '㳲', '㳳', 
		'㳴', '㳵', '㳶', '㳷', '㳸', '㳹', '㳺', '㳻', '㳼', '㳽', '㳾', '㳿', '㴀', '㴁', '㴂', '㴃', 
		'㴄', '㴅', '㴆', '㴇', '㴈', '㴉', '㴊', '㴋', '㴌', '㴍', '㴎', '㴏', '㴐', '㴑', '㴒', '㴓', 
		'㴔', '㴕', '㴖', '㴗', '㴘', '㴙', '㴚', '㴛', '㴜', '㴝', '㴞', '㴟', '㴠', '㴡', '㴢', '㴣', 
		'㴤', '㴥', '㴦', '㴧', '㴨', '㴩', '㴪', '㴫', '㴬', '㴭', '㴮', '㴯', '㴰', '㴱', '㴲', '㴳', 
		'㴴', '㴵', '㴶', '㴷', '㴸', '㴹', '㴺', '㴻', '㴼', '㴽', '㴾', '㴿', '㵀', '㵁', '㵂', '㵃', 
		'㵄', '㵅', '㵆', '㵇', '㵈', '㵉', '㵊', '㵋', '㵌', '㵍', '㵎', '㵏', '㵐', '㵑', '㵒', '㵓', 
		'㵔', '㵕', '㵖', '㵗', '㵘', '㵙', '㵚', '㵛', '㵜', '㵝', '㵞', '㵟', '㵠', '㵡', '㵢', '㵣', 
		'㵤', '㵥', '㵦', '㵧', '㵨', '㵩', '㵪', '㵫', '㵬', '㵭', '㵮', '㵯', '㵰', '㵱', '㵲', '㵳', 
		'㵴', '㵵', '㵶', '㵷', '㵸', '㵹', '㵺', '㵻', '㵼', '㵽', '㵾', '㵿', '㶀', '㶁', '㶂', '㶃', 
		'㶄', '㶅', '㶆', '㶇', '㶈', '㶉', '㶊', '㶋', '㶌', '㶍', '㶎', '㶏', '㶐', '㶑', '㶒', '㶓', 
		'㶔', '㶕', '㶖', '㶗', '㶘', '㶙', '㶚', '㶛', '㶜', '㶝', '㶞', '㶟', '㶠', '㶡', '㶢', '㶣', 
		'㶤', '㶥', '㶦', '㶧', '㶨', '㶩', '㶪', '㶫', '㶬', '㶭', '㶮', '㶯', '㶰', '㶱', '㶲', '㶳', 
		'㶴', '㶵', '㶶', '㶷', '㶸', '㶹', '㶺', '㶻', '㶼', '㶽', '㶾', '㶿', '㷀', '㷁', '㷂', '㷃', 
		'㷄', '㷅', '㷆', '㷇', '㷈', '㷉', '㷊', '㷋', '㷌', '㷍', '㷎', '㷏', '㷐', '㷑', '㷒', '㷓', 
		'㷔', '㷕', '㷖', '㷗', '㷘', '㷙', '㷚', '㷛', '㷜', '㷝', '㷞', '㷟', '㷠', '㷡', '㷢', '㷣', 
		'㷤', '㷥', '㷦', '㷧', '㷨', '㷩', '㷪', '㷫', '㷬', '㷭', '㷮', '㷯', '㷰', '㷱', '㷲', '㷳', 
		'㷴', '㷵', '㷶', '㷷', '㷸', '㷹', '㷺', '㷻', '㷼', '㷽', '㷾', '㷿', '㸀', '㸁', '㸂', '㸃', 
		'㸄', '㸅', '㸆', '㸇', '㸈', '㸉', '㸊', '㸋', '㸌', '㸍', '㸎', '㸏', '㸐', '㸑', '㸒', '㸓', 
		'㸔', '㸕', '㸖', '㸗', '㸘', '㸙', '㸚', '㸛', '㸜', '㸝', '㸞', '㸟', '㸠', '㸡', '㸢', '㸣', 
		'㸤', '㸥', '㸦', '㸧', '㸨', '㸩', '㸪', '㸫', '㸬', '㸭', '㸮', '㸯', '㸰', '㸱', '㸲', '㸳', 
		'㸴', '㸵', '㸶', '㸷', '㸸', '㸹', '㸺', '㸻', '㸼', '㸽', '㸾', '㸿', '㹀', '㹁', '㹂', '㹃', 
		'㹄', '㹅', '㹆', '㹇', '㹈', '㹉', '㹊', '㹋', '㹌', '㹍', '㹎', '㹏', '㹐', '㹑', '㹒', '㹓', 
		'㹔', '㹕', '㹖', '㹗', '㹘', '㹙', '㹚', '㹛', '㹜', '㹝', '㹞', '㹟', '㹠', '㹡', '㹢', '㹣', 
		'㹤', '㹥', '㹦', '㹧', '㹨', '㹩', '㹪', '㹫', '㹬', '㹭', '㹮', '㹯', '㹰', '㹱', '㹲', '㹳', 
		'㹴', '㹵', '㹶', '㹷', '㹸', '㹹', '㹺', '㹻', '㹼', '㹽', '㹾', '㹿', '㺀', '㺁', '㺂', '㺃', 
		'㺄', '㺅', '㺆', '㺇', '㺈', '㺉', '㺊', '㺋', '㺌', '㺍', '㺎', '㺏', '㺐', '㺑', '㺒', '㺓', 
		'㺔', '㺕', '㺖', '㺗', '㺘', '㺙', '㺚', '㺛', '㺜', '㺝', '㺞', '㺟', '㺠', '㺡', '㺢', '㺣', 
		'㺤', '㺥', '㺦', '㺧', '㺨', '㺩', '㺪', '㺫', '㺬', '㺭', '㺮', '㺯', '㺰', '㺱', '㺲', '㺳', 
		'㺴', '㺵', '㺶', '㺷', '㺸', '㺹', '㺺', '㺻', '㺼', '㺽', '㺾', '㺿', '㻀', '㻁', '㻂', '㻃', 
		'㻄', '㻅', '㻆', '㻇', '㻈', '㻉', '㻊', '㻋', '㻌', '㻍', '㻎', '㻏', '㻐', '㻑', '㻒', '㻓', 
		'㻔', '㻕', '㻖', '㻗', '㻘', '㻙', '㻚', '㻛', '㻜', '㻝', '㻞', '㻟', '㻠', '㻡', '㻢', '㻣', 
		'㻤', '㻥', '㻦', '㻧', '㻨', '㻩', '㻪', '㻫', '㻬', '㻭', '㻮', '㻯', '㻰', '㻱', '㻲', '㻳', 
		'㻴', '㻵', '㻶', '㻷', '㻸', '㻹', '㻺', '㻻', '㻼', '㻽', '㻾', '㻿', '㼀', '㼁', '㼂', '㼃', 
		'㼄', '㼅', '㼆', '㼇', '㼈', '㼉', '㼊', '㼋', '㼌', '㼍', '㼎', '㼏', '㼐', '㼑', '㼒', '㼓', 
		'㼔', '㼕', '㼖', '㼗', '㼘', '㼙', '㼚', '㼛', '㼜', '㼝', '㼞', '㼟', '㼠', '㼡', '㼢', '㼣', 
		'㼤', '㼥', '㼦', '㼧', '㼨', '㼩', '㼪', '㼫', '㼬', '㼭', '㼮', '㼯', '㼰', '㼱', '㼲', '㼳', 
		'㼴', '㼵', '㼶', '㼷', '㼸', '㼹', '㼺', '㼻', '㼼', '㼽', '㼾', '㼿', '㽀', '㽁', '㽂', '㽃', 
		'㽄', '㽅', '㽆', '㽇', '㽈', '㽉', '㽊', '㽋', '㽌', '㽍', '㽎', '㽏', '㽐', '㽑', '㽒', '㽓', 
		'㽔', '㽕', '㽖', '㽗', '㽘', '㽙', '㽚', '㽛', '㽜', '㽝', '㽞', '㽟', '㽠', '㽡', '㽢', '㽣', 
		'㽤', '㽥', '㽦', '㽧', '㽨', '㽩', '㽪', '㽫', '㽬', '㽭', '㽮', '㽯', '㽰', '㽱', '㽲', '㽳', 
		'㽴', '㽵', '㽶', '㽷', '㽸', '㽹', '㽺', '㽻', '㽼', '㽽', '㽾', '㽿', '㾀', '㾁', '㾂', '㾃', 
		'㾄', '㾅', '㾆', '㾇', '㾈', '㾉', '㾊', '㾋', '㾌', '㾍', '㾎', '㾏', '㾐', '㾑', '㾒', '㾓', 
		'㾔', '㾕', '㾖', '㾗', '㾘', '㾙', '㾚', '㾛', '㾜', '㾝', '㾞', '㾟', '㾠', '㾡', '㾢', '㾣', 
		'㾤', '㾥', '㾦', '㾧', '㾨', '㾩', '㾪', '㾫', '㾬', '㾭', '㾮', '㾯', '㾰', '㾱', '㾲', '㾳', 
		'㾴', '㾵', '㾶', '㾷', '㾸', '㾹', '㾺', '㾻', '㾼', '㾽', '㾾', '㾿', '㿀', '㿁', '㿂', '㿃', 
		'㿄', '㿅', '㿆', '㿇', '㿈', '㿉', '㿊', '㿋', '㿌', '㿍', '㿎', '㿏', '㿐', '㿑', '㿒', '㿓', 
		'㿔', '㿕', '㿖', '㿗', '㿘', '㿙', '㿚', '㿛', '㿜', '㿝', '㿞', '㿟', '㿠', '㿡', '㿢', '㿣', 
		'㿤', '㿥', '㿦', '㿧', '㿨', '㿩', '㿪', '㿫', '㿬', '㿭', '㿮', '㿯', '㿰', '㿱', '㿲', '㿳', 
		'㿴', '㿵', '㿶', '㿷', '㿸', '㿹', '㿺', '㿻', '㿼', '㿽', '㿾', '㿿', '䀀', '䀁', '䀂', '䀃', 
		'䀄', '䀅', '䀆', '䀇', '䀈', '䀉', '䀊', '䀋', '䀌', '䀍', '䀎', '䀏', '䀐', '䀑', '䀒', '䀓', 
		'䀔', '䀕', '䀖', '䀗', '䀘', '䀙', '䀚', '䀛', '䀜', '䀝', '䀞', '䀟', '䀠', '䀡', '䀢', '䀣', 
		'䀤', '䀥', '䀦', '䀧', '䀨', '䀩', '䀪', '䀫', '䀬', '䀭', '䀮', '䀯', '䀰', '䀱', '䀲', '䀳', 
		'䀴', '䀵', '䀶', '䀷', '䀸', '䀹', '䀺', '䀻', '䀼', '䀽', '䀾', '䀿', '䁀', '䁁', '䁂', '䁃', 
		'䁄', '䁅', '䁆', '䁇', '䁈', '䁉', '䁊', '䁋', '䁌', '䁍', '䁎', '䁏', '䁐', '䁑', '䁒', '䁓', 
		'䁔', '䁕', '䁖', '䁗', '䁘', '䁙', '䁚', '䁛', '䁜', '䁝', '䁞', '䁟', '䁠', '䁡', '䁢', '䁣', 
		'䁤', '䁥', '䁦', '䁧', '䁨', '䁩', '䁪', '䁫', '䁬', '䁭', '䁮', '䁯', '䁰', '䁱', '䁲', '䁳', 
		'䁴', '䁵', '䁶', '䁷', '䁸', '䁹', '䁺', '䁻', '䁼', '䁽', '䁾', '䁿', '䂀', '䂁', '䂂', '䂃', 
		'䂄', '䂅', '䂆', '䂇', '䂈', '䂉', '䂊', '䂋', '䂌', '䂍', '䂎', '䂏', '䂐', '䂑', '䂒', '䂓', 
		'䂔', '䂕', '䂖', '䂗', '䂘', '䂙', '䂚', '䂛', '䂜', '䂝', '䂞', '䂟', '䂠', '䂡', '䂢', '䂣', 
		'䂤', '䂥', '䂦', '䂧', '䂨', '䂩', '䂪', '䂫', '䂬', '䂭', '䂮', '䂯', '䂰', '䂱', '䂲', '䂳', 
		'䂴', '䂵', '䂶', '䂷', '䂸', '䂹', '䂺', '䂻', '䂼', '䂽', '䂾', '䂿', '䃀', '䃁', '䃂', '䃃', 
		'䃄', '䃅', '䃆', '䃇', '䃈', '䃉', '䃊', '䃋', '䃌', '䃍', '䃎', '䃏', '䃐', '䃑', '䃒', '䃓', 
		'䃔', '䃕', '䃖', '䃗', '䃘', '䃙', '䃚', '䃛', '䃜', '䃝', '䃞', '䃟', '䃠', '䃡', '䃢', '䃣', 
		'䃤', '䃥', '䃦', '䃧', '䃨', '䃩', '䃪', '䃫', '䃬', '䃭', '䃮', '䃯', '䃰', '䃱', '䃲', '䃳', 
		'䃴', '䃵', '䃶', '䃷', '䃸', '䃹', '䃺', '䃻', '䃼', '䃽', '䃾', '䃿', '䄀', '䄁', '䄂', '䄃', 
		'䄄', '䄅', '䄆', '䄇', '䄈', '䄉', '䄊', '䄋', '䄌', '䄍', '䄎', '䄏', '䄐', '䄑', '䄒', '䄓', 
		'䄔', '䄕', '䄖', '䄗', '䄘', '䄙', '䄚', '䄛', '䄜', '䄝', '䄞', '䄟', '䄠', '䄡', '䄢', '䄣', 
		'䄤', '䄥', '䄦', '䄧', '䄨', '䄩', '䄪', '䄫', '䄬', '䄭', '䄮', '䄯', '䄰', '䄱', '䄲', '䄳', 
		'䄴', '䄵', '䄶', '䄷', '䄸', '䄹', '䄺', '䄻', '䄼', '䄽', '䄾', '䄿', '䅀', '䅁', '䅂', '䅃', 
		'䅄', '䅅', '䅆', '䅇', '䅈', '䅉', '䅊', '䅋', '䅌', '䅍', '䅎', '䅏', '䅐', '䅑', '䅒', '䅓', 
		'䅔', '䅕', '䅖', '䅗', '䅘', '䅙', '䅚', '䅛', '䅜', '䅝', '䅞', '䅟', '䅠', '䅡', '䅢', '䅣', 
		'䅤', '䅥', '䅦', '䅧', '䅨', '䅩', '䅪', '䅫', '䅬', '䅭', '䅮', '䅯', '䅰', '䅱', '䅲', '䅳', 
		'䅴', '䅵', '䅶', '䅷', '䅸', '䅹', '䅺', '䅻', '䅼', '䅽', '䅾', '䅿', '䆀', '䆁', '䆂', '䆃', 
		'䆄', '䆅', '䆆', '䆇', '䆈', '䆉', '䆊', '䆋', '䆌', '䆍', '䆎', '䆏', '䆐', '䆑', '䆒', '䆓', 
		'䆔', '䆕', '䆖', '䆗', '䆘', '䆙', '䆚', '䆛', '䆜', '䆝', '䆞', '䆟', '䆠', '䆡', '䆢', '䆣', 
		'䆤', '䆥', '䆦', '䆧', '䆨', '䆩', '䆪', '䆫', '䆬', '䆭', '䆮', '䆯', '䆰', '䆱', '䆲', '䆳', 
		'䆴', '䆵', '䆶', '䆷', '䆸', '䆹', '䆺', '䆻', '䆼', '䆽', '䆾', '䆿', '䇀', '䇁', '䇂', '䇃', 
		'䇄', '䇅', '䇆', '䇇', '䇈', '䇉', '䇊', '䇋', '䇌', '䇍', '䇎', '䇏', '䇐', '䇑', '䇒', '䇓', 
		'䇔', '䇕', '䇖', '䇗', '䇘', '䇙', '䇚', '䇛', '䇜', '䇝', '䇞', '䇟', '䇠', '䇡', '䇢', '䇣', 
		'䇤', '䇥', '䇦', '䇧', '䇨', '䇩', '䇪', '䇫', '䇬', '䇭', '䇮', '䇯', '䇰', '䇱', '䇲', '䇳', 
		'䇴', '䇵', '䇶', '䇷', '䇸', '䇹', '䇺', '䇻', '䇼', '䇽', '䇾', '䇿', '䈀', '䈁', '䈂', '䈃', 
		'䈄', '䈅', '䈆', '䈇', '䈈', '䈉', '䈊', '䈋', '䈌', '䈍', '䈎', '䈏', '䈐', '䈑', '䈒', '䈓', 
		'䈔', '䈕', '䈖', '䈗', '䈘', '䈙', '䈚', '䈛', '䈜', '䈝', '䈞', '䈟', '䈠', '䈡', '䈢', '䈣', 
		'䈤', '䈥', '䈦', '䈧', '䈨', '䈩', '䈪', '䈫', '䈬', '䈭', '䈮', '䈯', '䈰', '䈱', '䈲', '䈳', 
		'䈴', '䈵', '䈶', '䈷', '䈸', '䈹', '䈺', '䈻', '䈼', '䈽', '䈾', '䈿', '䉀', '䉁', '䉂', '䉃', 
		'䉄', '䉅', '䉆', '䉇', '䉈', '䉉', '䉊', '䉋', '䉌', '䉍', '䉎', '䉏', '䉐', '䉑', '䉒', '䉓', 
		'䉔', '䉕', '䉖', '䉗', '䉘', '䉙', '䉚', '䉛', '䉜', '䉝', '䉞', '䉟', '䉠', '䉡', '䉢', '䉣', 
		'䉤', '䉥', '䉦', '䉧', '䉨', '䉩', '䉪', '䉫', '䉬', '䉭', '䉮', '䉯', '䉰', '䉱', '䉲', '䉳', 
		'䉴', '䉵', '䉶', '䉷', '䉸', '䉹', '䉺', '䉻', '䉼', '䉽', '䉾', '䉿', '䊀', '䊁', '䊂', '䊃', 
		'䊄', '䊅', '䊆', '䊇', '䊈', '䊉', '䊊', '䊋', '䊌', '䊍', '䊎', '䊏', '䊐', '䊑', '䊒', '䊓', 
		'䊔', '䊕', '䊖', '䊗', '䊘', '䊙', '䊚', '䊛', '䊜', '䊝', '䊞', '䊟', '䊠', '䊡', '䊢', '䊣', 
		'䊤', '䊥', '䊦', '䊧', '䊨', '䊩', '䊪', '䊫', '䊬', '䊭', '䊮', '䊯', '䊰', '䊱', '䊲', '䊳', 
		'䊴', '䊵', '䊶', '䊷', '䊸', '䊹', '䊺', '䊻', '䊼', '䊽', '䊾', '䊿', '䋀', '䋁', '䋂', '䋃', 
		'䋄', '䋅', '䋆', '䋇', '䋈', '䋉', '䋊', '䋋', '䋌', '䋍', '䋎', '䋏', '䋐', '䋑', '䋒', '䋓', 
		'䋔', '䋕', '䋖', '䋗', '䋘', '䋙', '䋚', '䋛', '䋜', '䋝', '䋞', '䋟', '䋠', '䋡', '䋢', '䋣', 
		'䋤', '䋥', '䋦', '䋧', '䋨', '䋩', '䋪', '䋫', '䋬', '䋭', '䋮', '䋯', '䋰', '䋱', '䋲', '䋳', 
		'䋴', '䋵', '䋶', '䋷', '䋸', '䋹', '䋺', '䋻', '䋼', '䋽', '䋾', '䋿', '䌀', '䌁', '䌂', '䌃', 
		'䌄', '䌅', '䌆', '䌇', '䌈', '䌉', '䌊', '䌋', '䌌', '䌍', '䌎', '䌏', '䌐', '䌑', '䌒', '䌓', 
		'䌔', '䌕', '䌖', '䌗', '䌘', '䌙', '䌚', '䌛', '䌜', '䌝', '䌞', '䌟', '䌠', '䌡', '䌢', '䌣', 
		'䌤', '䌥', '䌦', '䌧', '䌨', '䌩', '䌪', '䌫', '䌬', '䌭', '䌮', '䌯', '䌰', '䌱', '䌲', '䌳', 
		'䌴', '䌵', '䌶', '䌷', '䌸', '䌹', '䌺', '䌻', '䌼', '䌽', '䌾', '䌿', '䍀', '䍁', '䍂', '䍃', 
		'䍄', '䍅', '䍆', '䍇', '䍈', '䍉', '䍊', '䍋', '䍌', '䍍', '䍎', '䍏', '䍐', '䍑', '䍒', '䍓', 
		'䍔', '䍕', '䍖', '䍗', '䍘', '䍙', '䍚', '䍛', '䍜', '䍝', '䍞', '䍟', '䍠', '䍡', '䍢', '䍣', 
		'䍤', '䍥', '䍦', '䍧', '䍨', '䍩', '䍪', '䍫', '䍬', '䍭', '䍮', '䍯', '䍰', '䍱', '䍲', '䍳', 
		'䍴', '䍵', '䍶', '䍷', '䍸', '䍹', '䍺', '䍻', '䍼', '䍽', '䍾', '䍿', '䎀', '䎁', '䎂', '䎃', 
		'䎄', '䎅', '䎆', '䎇', '䎈', '䎉', '䎊', '䎋', '䎌', '䎍', '䎎', '䎏', '䎐', '䎑', '䎒', '䎓', 
		'䎔', '䎕', '䎖', '䎗', '䎘', '䎙', '䎚', '䎛', '䎜', '䎝', '䎞', '䎟', '䎠', '䎡', '䎢', '䎣', 
		'䎤', '䎥', '䎦', '䎧', '䎨', '䎩', '䎪', '䎫', '䎬', '䎭', '䎮', '䎯', '䎰', '䎱', '䎲', '䎳', 
		'䎴', '䎵', '䎶', '䎷', '䎸', '䎹', '䎺', '䎻', '䎼', '䎽', '䎾', '䎿', '䏀', '䏁', '䏂', '䏃', 
		'䏄', '䏅', '䏆', '䏇', '䏈', '䏉', '䏊', '䏋', '䏌', '䏍', '䏎', '䏏', '䏐', '䏑', '䏒', '䏓', 
		'䏔', '䏕', '䏖', '䏗', '䏘', '䏙', '䏚', '䏛', '䏜', '䏝', '䏞', '䏟', '䏠', '䏡', '䏢', '䏣', 
		'䏤', '䏥', '䏦', '䏧', '䏨', '䏩', '䏪', '䏫', '䏬', '䏭', '䏮', '䏯', '䏰', '䏱', '䏲', '䏳', 
		'䏴', '䏵', '䏶', '䏷', '䏸', '䏹', '䏺', '䏻', '䏼', '䏽', '䏾', '䏿', '䐀', '䐁', '䐂', '䐃', 
		'䐄', '䐅', '䐆', '䐇', '䐈', '䐉', '䐊', '䐋', '䐌', '䐍', '䐎', '䐏', '䐐', '䐑', '䐒', '䐓', 
		'䐔', '䐕', '䐖', '䐗', '䐘', '䐙', '䐚', '䐛', '䐜', '䐝', '䐞', '䐟', '䐠', '䐡', '䐢', '䐣', 
		'䐤', '䐥', '䐦', '䐧', '䐨', '䐩', '䐪', '䐫', '䐬', '䐭', '䐮', '䐯', '䐰', '䐱', '䐲', '䐳', 
		'䐴', '䐵', '䐶', '䐷', '䐸', '䐹', '䐺', '䐻', '䐼', '䐽', '䐾', '䐿', '䑀', '䑁', '䑂', '䑃', 
		'䑄', '䑅', '䑆', '䑇', '䑈', '䑉', '䑊', '䑋', '䑌', '䑍', '䑎', '䑏', '䑐', '䑑', '䑒', '䑓', 
		'䑔', '䑕', '䑖', '䑗', '䑘', '䑙', '䑚', '䑛', '䑜', '䑝', '䑞', '䑟', '䑠', '䑡', '䑢', '䑣', 
		'䑤', '䑥', '䑦', '䑧', '䑨', '䑩', '䑪', '䑫', '䑬', '䑭', '䑮', '䑯', '䑰', '䑱', '䑲', '䑳', 
		'䑴', '䑵', '䑶', '䑷', '䑸', '䑹', '䑺', '䑻', '䑼', '䑽', '䑾', '䑿', '䒀', '䒁', '䒂', '䒃', 
		'䒄', '䒅', '䒆', '䒇', '䒈', '䒉', '䒊', '䒋', '䒌', '䒍', '䒎', '䒏', '䒐', '䒑', '䒒', '䒓', 
		'䒔', '䒕', '䒖', '䒗', '䒘', '䒙', '䒚', '䒛', '䒜', '䒝', '䒞', '䒟', '䒠', '䒡', '䒢', '䒣', 
		'䒤', '䒥', '䒦', '䒧', '䒨', '䒩', '䒪', '䒫', '䒬', '䒭', '䒮', '䒯', '䒰', '䒱', '䒲', '䒳', 
		'䒴', '䒵', '䒶', '䒷', '䒸', '䒹', '䒺', '䒻', '䒼', '䒽', '䒾', '䒿', '䓀', '䓁', '䓂', '䓃', 
		'䓄', '䓅', '䓆', '䓇', '䓈', '䓉', '䓊', '䓋', '䓌', '䓍', '䓎', '䓏', '䓐', '䓑', '䓒', '䓓', 
		'䓔', '䓕', '䓖', '䓗', '䓘', '䓙', '䓚', '䓛', '䓜', '䓝', '䓞', '䓟', '䓠', '䓡', '䓢', '䓣', 
		'䓤', '䓥', '䓦', '䓧', '䓨', '䓩', '䓪', '䓫', '䓬', '䓭', '䓮', '䓯', '䓰', '䓱', '䓲', '䓳', 
		'䓴', '䓵', '䓶', '䓷', '䓸', '䓹', '䓺', '䓻', '䓼', '䓽', '䓾', '䓿', '䔀', '䔁', '䔂', '䔃', 
		'䔄', '䔅', '䔆', '䔇', '䔈', '䔉', '䔊', '䔋', '䔌', '䔍', '䔎', '䔏', '䔐', '䔑', '䔒', '䔓', 
		'䔔', '䔕', '䔖', '䔗', '䔘', '䔙', '䔚', '䔛', '䔜', '䔝', '䔞', '䔟', '䔠', '䔡', '䔢', '䔣', 
		'䔤', '䔥', '䔦', '䔧', '䔨', '䔩', '䔪', '䔫', '䔬', '䔭', '䔮', '䔯', '䔰', '䔱', '䔲', '䔳', 
		'䔴', '䔵', '䔶', '䔷', '䔸', '䔹', '䔺', '䔻', '䔼', '䔽', '䔾', '䔿', '䕀', '䕁', '䕂', '䕃', 
		'䕄', '䕅', '䕆', '䕇', '䕈', '䕉', '䕊', '䕋', '䕌', '䕍', '䕎', '䕏', '䕐', '䕑', '䕒', '䕓', 
		'䕔', '䕕', '䕖', '䕗', '䕘', '䕙', '䕚', '䕛', '䕜', '䕝', '䕞', '䕟', '䕠', '䕡', '䕢', '䕣', 
		'䕤', '䕥', '䕦', '䕧', '䕨', '䕩', '䕪', '䕫', '䕬', '䕭', '䕮', '䕯', '䕰', '䕱', '䕲', '䕳', 
		'䕴', '䕵', '䕶', '䕷', '䕸', '䕹', '䕺', '䕻', '䕼', '䕽', '䕾', '䕿', '䖀', '䖁', '䖂', '䖃', 
		'䖄', '䖅', '䖆', '䖇', '䖈', '䖉', '䖊', '䖋', '䖌', '䖍', '䖎', '䖏', '䖐', '䖑', '䖒', '䖓', 
		'䖔', '䖕', '䖖', '䖗', '䖘', '䖙', '䖚', '䖛', '䖜', '䖝', '䖞', '䖟', '䖠', '䖡', '䖢', '䖣', 
		'䖤', '䖥', '䖦', '䖧', '䖨', '䖩', '䖪', '䖫', '䖬', '䖭', '䖮', '䖯', '䖰', '䖱', '䖲', '䖳', 
		'䖴', '䖵', '䖶', '䖷', '䖸', '䖹', '䖺', '䖻', '䖼', '䖽', '䖾', '䖿', '䗀', '䗁', '䗂', '䗃', 
		'䗄', '䗅', '䗆', '䗇', '䗈', '䗉', '䗊', '䗋', '䗌', '䗍', '䗎', '䗏', '䗐', '䗑', '䗒', '䗓', 
		'䗔', '䗕', '䗖', '䗗', '䗘', '䗙', '䗚', '䗛', '䗜', '䗝', '䗞', '䗟', '䗠', '䗡', '䗢', '䗣', 
		'䗤', '䗥', '䗦', '䗧', '䗨', '䗩', '䗪', '䗫', '䗬', '䗭', '䗮', '䗯', '䗰', '䗱', '䗲', '䗳', 
		'䗴', '䗵', '䗶', '䗷', '䗸', '䗹', '䗺', '䗻', '䗼', '䗽', '䗾', '䗿', '䘀', '䘁', '䘂', '䘃', 
		'䘄', '䘅', '䘆', '䘇', '䘈', '䘉', '䘊', '䘋', '䘌', '䘍', '䘎', '䘏', '䘐', '䘑', '䘒', '䘓', 
		'䘔', '䘕', '䘖', '䘗', '䘘', '䘙', '䘚', '䘛', '䘜', '䘝', '䘞', '䘟', '䘠', '䘡', '䘢', '䘣', 
		'䘤', '䘥', '䘦', '䘧', '䘨', '䘩', '䘪', '䘫', '䘬', '䘭', '䘮', '䘯', '䘰', '䘱', '䘲', '䘳', 
		'䘴', '䘵', '䘶', '䘷', '䘸', '䘹', '䘺', '䘻', '䘼', '䘽', '䘾', '䘿', '䙀', '䙁', '䙂', '䙃', 
		'䙄', '䙅', '䙆', '䙇', '䙈', '䙉', '䙊', '䙋', '䙌', '䙍', '䙎', '䙏', '䙐', '䙑', '䙒', '䙓', 
		'䙔', '䙕', '䙖', '䙗', '䙘', '䙙', '䙚', '䙛', '䙜', '䙝', '䙞', '䙟', '䙠', '䙡', '䙢', '䙣', 
		'䙤', '䙥', '䙦', '䙧', '䙨', '䙩', '䙪', '䙫', '䙬', '䙭', '䙮', '䙯', '䙰', '䙱', '䙲', '䙳', 
		'䙴', '䙵', '䙶', '䙷', '䙸', '䙹', '䙺', '䙻', '䙼', '䙽', '䙾', '䙿', '䚀', '䚁', '䚂', '䚃', 
		'䚄', '䚅', '䚆', '䚇', '䚈', '䚉', '䚊', '䚋', '䚌', '䚍', '䚎', '䚏', '䚐', '䚑', '䚒', '䚓', 
		'䚔', '䚕', '䚖', '䚗', '䚘', '䚙', '䚚', '䚛', '䚜', '䚝', '䚞', '䚟', '䚠', '䚡', '䚢', '䚣', 
		'䚤', '䚥', '䚦', '䚧', '䚨', '䚩', '䚪', '䚫', '䚬', '䚭', '䚮', '䚯', '䚰', '䚱', '䚲', '䚳', 
		'䚴', '䚵', '䚶', '䚷', '䚸', '䚹', '䚺', '䚻', '䚼', '䚽', '䚾', '䚿', '䛀', '䛁', '䛂', '䛃', 
		'䛄', '䛅', '䛆', '䛇', '䛈', '䛉', '䛊', '䛋', '䛌', '䛍', '䛎', '䛏', '䛐', '䛑', '䛒', '䛓', 
		'䛔', '䛕', '䛖', '䛗', '䛘', '䛙', '䛚', '䛛', '䛜', '䛝', '䛞', '䛟', '䛠', '䛡', '䛢', '䛣', 
		'䛤', '䛥', '䛦', '䛧', '䛨', '䛩', '䛪', '䛫', '䛬', '䛭', '䛮', '䛯', '䛰', '䛱', '䛲', '䛳', 
		'䛴', '䛵', '䛶', '䛷', '䛸', '䛹', '䛺', '䛻', '䛼', '䛽', '䛾', '䛿', '䜀', '䜁', '䜂', '䜃', 
		'䜄', '䜅', '䜆', '䜇', '䜈', '䜉', '䜊', '䜋', '䜌', '䜍', '䜎', '䜏', '䜐', '䜑', '䜒', '䜓', 
		'䜔', '䜕', '䜖', '䜗', '䜘', '䜙', '䜚', '䜛', '䜜', '䜝', '䜞', '䜟', '䜠', '䜡', '䜢', '䜣', 
		'䜤', '䜥', '䜦', '䜧', '䜨', '䜩', '䜪', '䜫', '䜬', '䜭', '䜮', '䜯', '䜰', '䜱', '䜲', '䜳', 
		'䜴', '䜵', '䜶', '䜷', '䜸', '䜹', '䜺', '䜻', '䜼', '䜽', '䜾', '䜿', '䝀', '䝁', '䝂', '䝃', 
		'䝄', '䝅', '䝆', '䝇', '䝈', '䝉', '䝊', '䝋', '䝌', '䝍', '䝎', '䝏', '䝐', '䝑', '䝒', '䝓', 
		'䝔', '䝕', '䝖', '䝗', '䝘', '䝙', '䝚', '䝛', '䝜', '䝝', '䝞', '䝟', '䝠', '䝡', '䝢', '䝣', 
		'䝤', '䝥', '䝦', '䝧', '䝨', '䝩', '䝪', '䝫', '䝬', '䝭', '䝮', '䝯', '䝰', '䝱', '䝲', '䝳', 
		'䝴', '䝵', '䝶', '䝷', '䝸', '䝹', '䝺', '䝻', '䝼', '䝽', '䝾', '䝿', '䞀', '䞁', '䞂', '䞃', 
		'䞄', '䞅', '䞆', '䞇', '䞈', '䞉', '䞊', '䞋', '䞌', '䞍', '䞎', '䞏', '䞐', '䞑', '䞒', '䞓', 
		'䞔', '䞕', '䞖', '䞗', '䞘', '䞙', '䞚', '䞛', '䞜', '䞝', '䞞', '䞟', '䞠', '䞡', '䞢', '䞣', 
		'䞤', '䞥', '䞦', '䞧', '䞨', '䞩', '䞪', '䞫', '䞬', '䞭', '䞮', '䞯', '䞰', '䞱', '䞲', '䞳', 
		'䞴', '䞵', '䞶', '䞷', '䞸', '䞹', '䞺', '䞻', '䞼', '䞽', '䞾', '䞿', '䟀', '䟁', '䟂', '䟃', 
		'䟄', '䟅', '䟆', '䟇', '䟈', '䟉', '䟊', '䟋', '䟌', '䟍', '䟎', '䟏', '䟐', '䟑', '䟒', '䟓', 
		'䟔', '䟕', '䟖', '䟗', '䟘', '䟙', '䟚', '䟛', '䟜', '䟝', '䟞', '䟟', '䟠', '䟡', '䟢', '䟣', 
		'䟤', '䟥', '䟦', '䟧', '䟨', '䟩', '䟪', '䟫', '䟬', '䟭', '䟮', '䟯', '䟰', '䟱', '䟲', '䟳', 
		'䟴', '䟵', '䟶', '䟷', '䟸', '䟹', '䟺', '䟻', '䟼', '䟽', '䟾', '䟿', '䠀', '䠁', '䠂', '䠃', 
		'䠄', '䠅', '䠆', '䠇', '䠈', '䠉', '䠊', '䠋', '䠌', '䠍', '䠎', '䠏', '䠐', '䠑', '䠒', '䠓', 
		'䠔', '䠕', '䠖', '䠗', '䠘', '䠙', '䠚', '䠛', '䠜', '䠝', '䠞', '䠟', '䠠', '䠡', '䠢', '䠣', 
		'䠤', '䠥', '䠦', '䠧', '䠨', '䠩', '䠪', '䠫', '䠬', '䠭', '䠮', '䠯', '䠰', '䠱', '䠲', '䠳', 
		'䠴', '䠵', '䠶', '䠷', '䠸', '䠹', '䠺', '䠻', '䠼', '䠽', '䠾', '䠿', '䡀', '䡁', '䡂', '䡃', 
		'䡄', '䡅', '䡆', '䡇', '䡈', '䡉', '䡊', '䡋', '䡌', '䡍', '䡎', '䡏', '䡐', '䡑', '䡒', '䡓', 
		'䡔', '䡕', '䡖', '䡗', '䡘', '䡙', '䡚', '䡛', '䡜', '䡝', '䡞', '䡟', '䡠', '䡡', '䡢', '䡣', 
		'䡤', '䡥', '䡦', '䡧', '䡨', '䡩', '䡪', '䡫', '䡬', '䡭', '䡮', '䡯', '䡰', '䡱', '䡲', '䡳', 
		'䡴', '䡵', '䡶', '䡷', '䡸', '䡹', '䡺', '䡻', '䡼', '䡽', '䡾', '䡿', '䢀', '䢁', '䢂', '䢃', 
		'䢄', '䢅', '䢆', '䢇', '䢈', '䢉', '䢊', '䢋', '䢌', '䢍', '䢎', '䢏', '䢐', '䢑', '䢒', '䢓', 
		'䢔', '䢕', '䢖', '䢗', '䢘', '䢙', '䢚', '䢛', '䢜', '䢝', '䢞', '䢟', '䢠', '䢡', '䢢', '䢣', 
		'䢤', '䢥', '䢦', '䢧', '䢨', '䢩', '䢪', '䢫', '䢬', '䢭', '䢮', '䢯', '䢰', '䢱', '䢲', '䢳', 
		'䢴', '䢵', '䢶', '䢷', '䢸', '䢹', '䢺', '䢻', '䢼', '䢽', '䢾', '䢿', '䣀', '䣁', '䣂', '䣃', 
		'䣄', '䣅', '䣆', '䣇', '䣈', '䣉', '䣊', '䣋', '䣌', '䣍', '䣎', '䣏', '䣐', '䣑', '䣒', '䣓', 
		'䣔', '䣕', '䣖', '䣗', '䣘', '䣙', '䣚', '䣛', '䣜', '䣝', '䣞', '䣟', '䣠', '䣡', '䣢', '䣣', 
		'䣤', '䣥', '䣦', '䣧', '䣨', '䣩', '䣪', '䣫', '䣬', '䣭', '䣮', '䣯', '䣰', '䣱', '䣲', '䣳', 
		'䣴', '䣵', '䣶', '䣷', '䣸', '䣹', '䣺', '䣻', '䣼', '䣽', '䣾', '䣿', '䤀', '䤁', '䤂', '䤃', 
		'䤄', '䤅', '䤆', '䤇', '䤈', '䤉', '䤊', '䤋', '䤌', '䤍', '䤎', '䤏', '䤐', '䤑', '䤒', '䤓', 
		'䤔', '䤕', '䤖', '䤗', '䤘', '䤙', '䤚', '䤛', '䤜', '䤝', '䤞', '䤟', '䤠', '䤡', '䤢', '䤣', 
		'䤤', '䤥', '䤦', '䤧', '䤨', '䤩', '䤪', '䤫', '䤬', '䤭', '䤮', '䤯', '䤰', '䤱', '䤲', '䤳', 
		'䤴', '䤵', '䤶', '䤷', '䤸', '䤹', '䤺', '䤻', '䤼', '䤽', '䤾', '䤿', '䥀', '䥁', '䥂', '䥃', 
		'䥄', '䥅', '䥆', '䥇', '䥈', '䥉', '䥊', '䥋', '䥌', '䥍', '䥎', '䥏', '䥐', '䥑', '䥒', '䥓', 
		'䥔', '䥕', '䥖', '䥗', '䥘', '䥙', '䥚', '䥛', '䥜', '䥝', '䥞', '䥟', '䥠', '䥡', '䥢', '䥣', 
		'䥤', '䥥', '䥦', '䥧', '䥨', '䥩', '䥪', '䥫', '䥬', '䥭', '䥮', '䥯', '䥰', '䥱', '䥲', '䥳', 
		'䥴', '䥵', '䥶', '䥷', '䥸', '䥹', '䥺', '䥻', '䥼', '䥽', '䥾', '䥿', '䦀', '䦁', '䦂', '䦃', 
		'䦄', '䦅', '䦆', '䦇', '䦈', '䦉', '䦊', '䦋', '䦌', '䦍', '䦎', '䦏', '䦐', '䦑', '䦒', '䦓', 
		'䦔', '䦕', '䦖', '䦗', '䦘', '䦙', '䦚', '䦛', '䦜', '䦝', '䦞', '䦟', '䦠', '䦡', '䦢', '䦣', 
		'䦤', '䦥', '䦦', '䦧', '䦨', '䦩', '䦪', '䦫', '䦬', '䦭', '䦮', '䦯', '䦰', '䦱', '䦲', '䦳', 
		'䦴', '䦵', '䦶', '䦷', '䦸', '䦹', '䦺', '䦻', '䦼', '䦽', '䦾', '䦿', '䧀', '䧁', '䧂', '䧃', 
		'䧄', '䧅', '䧆', '䧇', '䧈', '䧉', '䧊', '䧋', '䧌', '䧍', '䧎', '䧏', '䧐', '䧑', '䧒', '䧓', 
		'䧔', '䧕', '䧖', '䧗', '䧘', '䧙', '䧚', '䧛', '䧜', '䧝', '䧞', '䧟', '䧠', '䧡', '䧢', '䧣', 
		'䧤', '䧥', '䧦', '䧧', '䧨', '䧩', '䧪', '䧫', '䧬', '䧭', '䧮', '䧯', '䧰', '䧱', '䧲', '䧳', 
		'䧴', '䧵', '䧶', '䧷', '䧸', '䧹', '䧺', '䧻', '䧼', '䧽', '䧾', '䧿', '䨀', '䨁', '䨂', '䨃', 
		'䨄', '䨅', '䨆', '䨇', '䨈', '䨉', '䨊', '䨋', '䨌', '䨍', '䨎', '䨏', '䨐', '䨑', '䨒', '䨓', 
		'䨔', '䨕', '䨖', '䨗', '䨘', '䨙', '䨚', '䨛', '䨜', '䨝', '䨞', '䨟', '䨠', '䨡', '䨢', '䨣', 
		'䨤', '䨥', '䨦', '䨧', '䨨', '䨩', '䨪', '䨫', '䨬', '䨭', '䨮', '䨯', '䨰', '䨱', '䨲', '䨳', 
		'䨴', '䨵', '䨶', '䨷', '䨸', '䨹', '䨺', '䨻', '䨼', '䨽', '䨾', '䨿', '䩀', '䩁', '䩂', '䩃', 
		'䩄', '䩅', '䩆', '䩇', '䩈', '䩉', '䩊', '䩋', '䩌', '䩍', '䩎', '䩏', '䩐', '䩑', '䩒', '䩓', 
		'䩔', '䩕', '䩖', '䩗', '䩘', '䩙', '䩚', '䩛', '䩜', '䩝', '䩞', '䩟', '䩠', '䩡', '䩢', '䩣', 
		'䩤', '䩥', '䩦', '䩧', '䩨', '䩩', '䩪', '䩫', '䩬', '䩭', '䩮', '䩯', '䩰', '䩱', '䩲', '䩳', 
		'䩴', '䩵', '䩶', '䩷', '䩸', '䩹', '䩺', '䩻', '䩼', '䩽', '䩾', '䩿', '䪀', '䪁', '䪂', '䪃', 
		'䪄', '䪅', '䪆', '䪇', '䪈', '䪉', '䪊', '䪋', '䪌', '䪍', '䪎', '䪏', '䪐', '䪑', '䪒', '䪓', 
		'䪔', '䪕', '䪖', '䪗', '䪘', '䪙', '䪚', '䪛', '䪜', '䪝', '䪞', '䪟', '䪠', '䪡', '䪢', '䪣', 
		'䪤', '䪥', '䪦', '䪧', '䪨', '䪩', '䪪', '䪫', '䪬', '䪭', '䪮', '䪯', '䪰', '䪱', '䪲', '䪳', 
		'䪴', '䪵', '䪶', '䪷', '䪸', '䪹', '䪺', '䪻', '䪼', '䪽', '䪾', '䪿', '䫀', '䫁', '䫂', '䫃', 
		'䫄', '䫅', '䫆', '䫇', '䫈', '䫉', '䫊', '䫋', '䫌', '䫍', '䫎', '䫏', '䫐', '䫑', '䫒', '䫓', 
		'䫔', '䫕', '䫖', '䫗', '䫘', '䫙', '䫚', '䫛', '䫜', '䫝', '䫞', '䫟', '䫠', '䫡', '䫢', '䫣', 
		'䫤', '䫥', '䫦', '䫧', '䫨', '䫩', '䫪', '䫫', '䫬', '䫭', '䫮', '䫯', '䫰', '䫱', '䫲', '䫳', 
		'䫴', '䫵', '䫶', '䫷', '䫸', '䫹', '䫺', '䫻', '䫼', '䫽', '䫾', '䫿', '䬀', '䬁', '䬂', '䬃', 
		'䬄', '䬅', '䬆', '䬇', '䬈', '䬉', '䬊', '䬋', '䬌', '䬍', '䬎', '䬏', '䬐', '䬑', '䬒', '䬓', 
		'䬔', '䬕', '䬖', '䬗', '䬘', '䬙', '䬚', '䬛', '䬜', '䬝', '䬞', '䬟', '䬠', '䬡', '䬢', '䬣', 
		'䬤', '䬥', '䬦', '䬧', '䬨', '䬩', '䬪', '䬫', '䬬', '䬭', '䬮', '䬯', '䬰', '䬱', '䬲', '䬳', 
		'䬴', '䬵', '䬶', '䬷', '䬸', '䬹', '䬺', '䬻', '䬼', '䬽', '䬾', '䬿', '䭀', '䭁', '䭂', '䭃', 
		'䭄', '䭅', '䭆', '䭇', '䭈', '䭉', '䭊', '䭋', '䭌', '䭍', '䭎', '䭏', '䭐', '䭑', '䭒', '䭓', 
		'䭔', '䭕', '䭖', '䭗', '䭘', '䭙', '䭚', '䭛', '䭜', '䭝', '䭞', '䭟', '䭠', '䭡', '䭢', '䭣', 
		'䭤', '䭥', '䭦', '䭧', '䭨', '䭩', '䭪', '䭫', '䭬', '䭭', '䭮', '䭯', '䭰', '䭱', '䭲', '䭳', 
		'䭴', '䭵', '䭶', '䭷', '䭸', '䭹', '䭺', '䭻', '䭼', '䭽', '䭾', '䭿', '䮀', '䮁', '䮂', '䮃', 
		'䮄', '䮅', '䮆', '䮇', '䮈', '䮉', '䮊', '䮋', '䮌', '䮍', '䮎', '䮏', '䮐', '䮑', '䮒', '䮓', 
		'䮔', '䮕', '䮖', '䮗', '䮘', '䮙', '䮚', '䮛', '䮜', '䮝', '䮞', '䮟', '䮠', '䮡', '䮢', '䮣', 
		'䮤', '䮥', '䮦', '䮧', '䮨', '䮩', '䮪', '䮫', '䮬', '䮭', '䮮', '䮯', '䮰', '䮱', '䮲', '䮳', 
		'䮴', '䮵', '䮶', '䮷', '䮸', '䮹', '䮺', '䮻', '䮼', '䮽', '䮾', '䮿', '䯀', '䯁', '䯂', '䯃', 
		'䯄', '䯅', '䯆', '䯇', '䯈', '䯉', '䯊', '䯋', '䯌', '䯍', '䯎', '䯏', '䯐', '䯑', '䯒', '䯓', 
		'䯔', '䯕', '䯖', '䯗', '䯘', '䯙', '䯚', '䯛', '䯜', '䯝', '䯞', '䯟', '䯠', '䯡', '䯢', '䯣', 
		'䯤', '䯥', '䯦', '䯧', '䯨', '䯩', '䯪', '䯫', '䯬', '䯭', '䯮', '䯯', '䯰', '䯱', '䯲', '䯳', 
		'䯴', '䯵', '䯶', '䯷', '䯸', '䯹', '䯺', '䯻', '䯼', '䯽', '䯾', '䯿', '䰀', '䰁', '䰂', '䰃', 
		'䰄', '䰅', '䰆', '䰇', '䰈', '䰉', '䰊', '䰋', '䰌', '䰍', '䰎', '䰏', '䰐', '䰑', '䰒', '䰓', 
		'䰔', '䰕', '䰖', '䰗', '䰘', '䰙', '䰚', '䰛', '䰜', '䰝', '䰞', '䰟', '䰠', '䰡', '䰢', '䰣', 
		'䰤', '䰥', '䰦', '䰧', '䰨', '䰩', '䰪', '䰫', '䰬', '䰭', '䰮', '䰯', '䰰', '䰱', '䰲', '䰳', 
		'䰴', '䰵', '䰶', '䰷', '䰸', '䰹', '䰺', '䰻', '䰼', '䰽', '䰾', '䰿', '䱀', '䱁', '䱂', '䱃', 
		'䱄', '䱅', '䱆', '䱇', '䱈', '䱉', '䱊', '䱋', '䱌', '䱍', '䱎', '䱏', '䱐', '䱑', '䱒', '䱓', 
		'䱔', '䱕', '䱖', '䱗', '䱘', '䱙', '䱚', '䱛', '䱜', '䱝', '䱞', '䱟', '䱠', '䱡', '䱢', '䱣', 
		'䱤', '䱥', '䱦', '䱧', '䱨', '䱩', '䱪', '䱫', '䱬', '䱭', '䱮', '䱯', '䱰', '䱱', '䱲', '䱳', 
		'䱴', '䱵', '䱶', '䱷', '䱸', '䱹', '䱺', '䱻', '䱼', '䱽', '䱾', '䱿', '䲀', '䲁', '䲂', '䲃', 
		'䲄', '䲅', '䲆', '䲇', '䲈', '䲉', '䲊', '䲋', '䲌', '䲍', '䲎', '䲏', '䲐', '䲑', '䲒', '䲓', 
		'䲔', '䲕', '䲖', '䲗', '䲘', '䲙', '䲚', '䲛', '䲜', '䲝', '䲞', '䲟', '䲠', '䲡', '䲢', '䲣', 
		'䲤', '䲥', '䲦', '䲧', '䲨', '䲩', '䲪', '䲫', '䲬', '䲭', '䲮', '䲯', '䲰', '䲱', '䲲', '䲳', 
		'䲴', '䲵', '䲶', '䲷', '䲸', '䲹', '䲺', '䲻', '䲼', '䲽', '䲾', '䲿', '䳀', '䳁', '䳂', '䳃', 
		'䳄', '䳅', '䳆', '䳇', '䳈', '䳉', '䳊', '䳋', '䳌', '䳍', '䳎', '䳏', '䳐', '䳑', '䳒', '䳓', 
		'䳔', '䳕', '䳖', '䳗', '䳘', '䳙', '䳚', '䳛', '䳜', '䳝', '䳞', '䳟', '䳠', '䳡', '䳢', '䳣', 
		'䳤', '䳥', '䳦', '䳧', '䳨', '䳩', '䳪', '䳫', '䳬', '䳭', '䳮', '䳯', '䳰', '䳱', '䳲', '䳳', 
		'䳴', '䳵', '䳶', '䳷', '䳸', '䳹', '䳺', '䳻', '䳼', '䳽', '䳾', '䳿', '䴀', '䴁', '䴂', '䴃', 
		'䴄', '䴅', '䴆', '䴇', '䴈', '䴉', '䴊', '䴋', '䴌', '䴍', '䴎', '䴏', '䴐', '䴑', '䴒', '䴓', 
		'䴔', '䴕', '䴖', '䴗', '䴘', '䴙', '䴚', '䴛', '䴜', '䴝', '䴞', '䴟', '䴠', '䴡', '䴢', '䴣', 
		'䴤', '䴥', '䴦', '䴧', '䴨', '䴩', '䴪', '䴫', '䴬', '䴭', '䴮', '䴯', '䴰', '䴱', '䴲', '䴳', 
		'䴴', '䴵', '䴶', '䴷', '䴸', '䴹', '䴺', '䴻', '䴼', '䴽', '䴾', '䴿', '䵀', '䵁', '䵂', '䵃', 
		'䵄', '䵅', '䵆', '䵇', '䵈', '䵉', '䵊', '䵋', '䵌', '䵍', '䵎', '䵏', '䵐', '䵑', '䵒', '䵓', 
		'䵔', '䵕', '䵖', '䵗', '䵘', '䵙', '䵚', '䵛', '䵜', '䵝', '䵞', '䵟', '䵠', '䵡', '䵢', '䵣', 
		'䵤', '䵥', '䵦', '䵧', '䵨', '䵩', '䵪', '䵫', '䵬', '䵭', '䵮', '䵯', '䵰', '䵱', '䵲', '䵳', 
		'䵴', '䵵', '䵶', '䵷', '䵸', '䵹', '䵺', '䵻', '䵼', '䵽', '䵾', '䵿', '䶀', '䶁', '䶂', '䶃', 
		'䶄', '䶅', '䶆', '䶇', '䶈', '䶉', '䶊', '䶋', '䶌', '䶍', '䶎', '䶏', '䶐', '䶑', '䶒', '䶓', 
		'䶔', '䶕', '䶖', '䶗', '䶘', '䶙', '䶚', '䶛', '䶜', '䶝', '䶞', '䶟', '䶠', '䶡', '䶢', '䶣', 
		'䶤', '䶥', '䶦', '䶧', '䶨', '䶩', '䶪', '䶫', '䶬', '䶭', '䶮', '䶯', '䶰', '䶱', '䶲', '䶳', 
		'䶴', '䶵', '豈', '更', '車', '賈', '滑', '串', '句', '龜', '龜', '契', '金', '喇', '奈', '懶', 
		'癩', '羅', '蘿', '螺', '裸', '邏', '樂', '洛', '烙', '珞', '落', '酪', '駱', '亂', '卵', '欄', 
		'爛', '蘭', '鸞', '嵐', '濫', '藍', '襤', '拉', '臘', '蠟', '廊', '朗', '浪', '狼', '郎', '來', 
		'冷', '勞', '擄', '櫓', '爐', '盧', '老', '蘆', '虜', '路', '露', '魯', '鷺', '碌', '祿', '綠', 
		'菉', '錄', '鹿', '論', '壟', '弄', '籠', '聾', '牢', '磊', '賂', '雷', '壘', '屢', '樓', '淚', 
		'漏', '累', '縷', '陋', '勒', '肋', '凜', '凌', '稜', '綾', '菱', '陵', '讀', '拏', '樂', '諾', 
		'丹', '寧', '怒', '率', '異', '北', '磻', '便', '復', '不', '泌', '數', '索', '參', '塞', '省', 
		'葉', '說', '殺', '辰', '沈', '拾', '若', '掠', '略', '亮', '兩', '凉', '梁', '糧', '良', '諒', 
		'量', '勵', '呂', '女', '廬', '旅', '濾', '礪', '閭', '驪', '麗', '黎', '力', '曆', '歷', '轢', 
		'年', '憐', '戀', '撚', '漣', '煉', '璉', '秊', '練', '聯', '輦', '蓮', '連', '鍊', '列', '劣', 
		'咽', '烈', '裂', '說', '廉', '念', '捻', '殮', '簾', '獵', '令', '囹', '寧', '嶺', '怜', '玲', 
		'瑩', '羚', '聆', '鈴', '零', '靈', '領', '例', '禮', '醴', '隸', '惡', '了', '僚', '寮', '尿', 
		'料', '樂', '燎', '療', '蓼', '遼', '龍', '暈', '阮', '劉', '杻', '柳', '流', '溜', '琉', '留', 
		'硫', '紐', '類', '六', '戮', '陸', '倫', '崙', '淪', '輪', '律', '慄', '栗', '率', '隆', '利', 
		'吏', '履', '易', '李', '梨', '泥', '理', '痢', '罹', '裏', '裡', '里', '離', '匿', '溺', '吝', 
		'燐', '璘', '藺', '隣', '鱗', '麟', '林', '淋', '臨', '立', '笠', '粒', '狀', '炙', '識', '什', 
		'茶', '刺', '切', '度', '拓', '糖', '宅', '洞', '暴', '輻', '行', '降', '見', '廓', '兀', '嗀', 
		'﨎', '﨏', '塚', '﨑', '晴', '﨓', '﨔', '凞', '猪', '益', '礼', '神', '祥', '福', '靖', '精', 
		'羽', '﨟', '蘒', '﨡', '諸', '﨣', '﨤', '逸', '都', '﨧', '﨨', '﨩', '飯', '飼', '館', '鶴', 
		'郞', '隷', '侮', '僧', '免', '勉', '勤', '卑', '喝', '嘆', '器', '塀', '墨', '層', '屮', '悔', 
		'慨', '憎', '懲', '敏', '既', '暑', '梅', '海', '渚', '漢', '煮', '爫', '琢', '碑', '社', '祉', 
		'祈', '祐', '祖', '祝', '禍', '禎', '穀', '突', '節', '練', '縉', '繁', '署', '者', '臭', '艹', 
		'艹', '著', '褐', '視', '謁', '謹', '賓', '贈', '辶', '逸', '難', '響', '頻', '恵', '𤋮', '舘', 
		'﩮', '﩯', '並', '况', '全', '侀', '充', '冀', '勇', '勺', '喝', '啕', '喙', '嗢', '塚', '墳', 
		'奄', '奔', '婢', '嬨', '廒', '廙', '彩', '徭', '惘', '慎', '愈', '憎', '慠', '懲', '戴', '揄', 
		'搜', '摒', '敖', '晴', '朗', '望', '杖', '歹', '殺', '流', '滛', '滋', '漢', '瀞', '煮', '瞧', 
		'爵', '犯', '猪', '瑱', '甆', '画', '瘝', '瘟', '益', '盛', '直', '睊', '着', '磌', '窱', '節', 
		'类', '絛', '練', '缾', '者', '荒', '華', '蝹', '襁', '覆', '視', '調', '諸', '請', '謁', '諾', 
		'諭', '謹', '變', '贈', '輸', '遲', '醙', '鉶', '陼', '難', '靖', '韛', '響', '頋', '頻', '鬒', 
		'龜', '𢡊', '𢡄', '𣏕', '㮝', '䀘', '䀹', '𥉉', '𥳐', '𧻓', '齃', '龎', '﫚', '﫛', '﫜', '﫝', 
		'﫞', '﫟', '﫠', '﫡', '﫢', '﫣', '﫤', '﫥', '﫦', '﫧', '﫨', '﫩', '﫪', '﫫', '﫬', '﫭', 
		'﫮', '﫯', '﫰', '﫱', '﫲', '﫳', '﫴', '﫵', '﫶', '﫷', '﫸', '﫹', '﫺', '﫻', '﫼', '﫽', 
		'﫾', '﫿'  );

	return( \@NotJIS_X_0208_KANJI );
}
