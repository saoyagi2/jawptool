#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Encode;
use open IO  => ':utf8';
binmode Test::More->builder->output, ':utf8';
binmode Test::More->builder->failure_output, ':utf8';
binmode Test::More->builder->todo_output, ':utf8';

use Test::More( 'no_plan' );


################################################################################
# JAWP::Articleクラス
################################################################################

{
	# useテスト
	use_ok( 'JAWP', 'use JAWP' );

	# メソッド呼び出しテスト
	{
		foreach my $method ( 'new', 'SetTitle', 'SetTimestamp', 'SetText', 'IsRedirect', 'IsAimai', 'IsLiving', 'IsNoref', 'GetPassTime', 'LintTitle', 'LintText', 'LintIndex', 'Person' ) {
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

		foreach my $text ( '#redirect[[転送先]]', '#REDIRECT[[転送先]]', '#転送[[転送先]]', '#リダイレクト[[転送先]]', '＃redirect[[転送先]]', '＃REDIRECT[[転送先]]', '＃転送[[転送先]]', '＃リダイレクト[[転送先]]' ) {
			$article->SetText( $text );
			ok( $article->IsRedirect, "JAWP::Article::IsRedirect($text)" );
			$article->SetText( " $text" );
			ok( $article->IsRedirect, "JAWP::Article::IsRedirect(' $text')" );
			$article->SetText( "\n$text" );
			ok( $article->IsRedirect, "JAWP::Article::IsRedirect('\\n$text')" );
		}
	}

	# IsSoftRedirectテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( !$article->IsSoftRedirect, 'JAWP::Article::IsSoftRedirect(空文字列)' );

		foreach my $text ( '{{softredirect|wikt:転送先}}', '{{Softredirect|wikt:転送先}}', '{{wiktionary redirect}}', '{{Wiktionary redirect}}', '{{wtr}}', '{{Wtr}}' ) {
			$article->SetText( $text );
			ok( $article->IsSoftRedirect, "JAWP::Article::IsSoftRedirect($text)" );
		}
	}

	# IsAimaiテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( !$article->IsAimai, 'JAWP::Article::IsAimai(空文字列)' );

		foreach my $text ( '{{aimai}}', '{{Aimai}}', '{{disambig}}', '{{Disambig}}', '{{ChemAimai}}', '{{chemAimai}}', '{{曖昧さ回避}}', '{{人名の曖昧さ回避}}', '{{地名の曖昧さ回避}}', '{{小学校の曖昧さ回避}}' ) {
			$article->SetText( $text );
			ok( $article->IsAimai, "JAWP::Article::IsAimai($text)" );
		}
	}

	# IsLivingテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( !$article->IsLiving, 'JAWP::Article::IsLiving(空文字列)' );

		foreach my $text ( '[[Category:存命人物]]', '[[category:存命人物]]', '[[カテゴリ:存命人物]]', '{{Blp}}', '{{blp}}', '{{BLP unsourced}}', '{{bLP unsourced}}' ) {
			$article->SetText( $text );
			ok( $article->IsLiving, "JAWP::Article::IsLiving($text)" );
		}
	}

	# IsNorefテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( $article->IsNoref, 'JAWP::Article::IsNoref(空文字列)' );

		foreach my $text ( '参考', '文献', '資料', '書籍', '図書', '注', '註', '出典', '典拠', '出所', '原典', 'ソース', '情報源', '引用元', '論拠', '参照' ) {
			$article->SetText( "あああ\n== $text ==\nいいい\n" );
			ok( !$article->IsNoref, "JAWP::Article::IsNoref(== $text ==)" );

			$article->SetText( "あああ\n== $text == \nいいい\n" );
			ok( !$article->IsNoref, "JAWP::Article::IsNoref(== $text == )" );

			$article->SetText( "あああ\n== $text ==a\nいいい\n" );
			ok( $article->IsNoref, "JAWP::Article::IsNoref(== $text ==a)" );

			$article->SetText( "あああ\n == $text ==\nいいい\n" );
			ok( $article->IsNoref, "JAWP::Article::IsNoref( == $text ==)" );
		}

		foreach my $text ( '<ref>', '<REF>', '<references />', '<REFERENCES />' ) {
			$article->SetText( "あああ\n== $text ==\nいいい\n" );
			ok( !$article->IsNoref, "JAWP::Article::IsNoref($text)" );
		}
	}

	# GetRefStatテスト
	{
		my $article = new JAWP::Article;
		my( $count, $size );

		$article->SetText( '' );
		( $count, $size ) = $article->GetRefStat;
		is( $count, 0, 'JAWP::Article::GetRefStat(空文字列,count)' );
		is( $size, 0, 'JAWP::Article::GetRefStat(空文字列,size)' );

		$article->SetText( 'abcde' );
		( $count, $size ) = $article->GetRefStat;
		is( $count, 0, 'JAWP::Article::GetRefStat(abcde,count)' );
		is( $size, 0, 'JAWP::Article::GetRefStat(abcde,size)' );

		$article->SetText( 'abcde<ref>123</ref>' );
		( $count, $size ) = $article->GetRefStat;
		is( $count, 1, 'JAWP::Article::GetRefStat(abcde<ref>123</ref>,count)' );
		is( $size, 14, 'JAWP::Article::GetRefStat(abcde<ref>123</ref>,size)' );

		$article->SetText( 'abcde<ref name="123">123</ref>' );
		( $count, $size ) = $article->GetRefStat;
		is( $count, 1, 'JAWP::Article::GetRefStat(abcde<ref name="123">123</ref>,count)' );
		is( $size, 25, 'JAWP::Article::GetRefStat(abcde<ref name="123">123</ref>,size)' );

		$article->SetText( 'abcde<ref>123</ref><ref>123</ref>' );
		( $count, $size ) = $article->GetRefStat;
		is( $count, 2, 'JAWP::Article::GetRefStat(abcde<ref>123</ref><ref>123</ref>,count)' );
		is( $size, 28, 'JAWP::Article::GetRefStat(abcde<ref>123</ref><ref>123</ref>,size)' );
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

	# IsSakujoテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( !$article->IsSakujo, 'JAWP::Article::IsSakujo(空文字列)' );

		$article->SetText( 'sakujo' );
		ok( !$article->IsSakujo, 'JAWP::Article::IsSakujo(sakujo)' );

		$article->SetText( '{{Sakujo/' );
		ok( $article->IsSakujo, 'JAWP::Article::IsSakujo({{Sakujo/)' );

		$article->SetText( '{{sakujo/' );
		ok( $article->IsSakujo, 'JAWP::Article::IsSakujo({{sakujo/)' );
	}

	# IsMoveテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( !$article->IsMove, 'JAWP::Article::IsMove(空文字列)' );

		$article->SetText( '改名提案' );
		ok( !$article->IsMove, 'JAWP::Article::IsMove(改名提案)' );

		$article->SetText( '{{改名提案' );
		ok( $article->IsMove, 'JAWP::Article::IsMove({{改名提案)' );
	}

	# IsMergeテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( !$article->IsMerge, 'JAWP::Article::IsMerge(空文字列)' );

		$article->SetText( '統合提案' );
		ok( !$article->IsMerge, 'JAWP::Article::IsMerge(統合提案)' );

		$article->SetText( 'Mergefrom' );
		ok( !$article->IsMerge, 'JAWP::Article::IsMerge(Mergefrom)' );

		$article->SetText( 'Mergeto' );
		ok( !$article->IsMerge, 'JAWP::Article::IsMerge(Mergeto)' );

		$article->SetText( '{{統合提案' );
		ok( $article->IsMerge, 'JAWP::Article::IsMerge({{統合提案)' );

		$article->SetText( '{{Mergefrom' );
		ok( $article->IsMerge, 'JAWP::Article::IsMerge({{Mergefrom)' );

		$article->SetText( '{{Mergeto' );
		ok( $article->IsMerge, 'JAWP::Article::IsMerge({{Mergeto)' );
	}

	# IsDivisionテスト
	{
		my $article = new JAWP::Article;

		$article->SetText( '' );
		ok( !$article->IsDivision, 'JAWP::Article::IsDivision(空文字列)' );

		$article->SetText( '分割提案' );
		ok( !$article->IsDivision, 'JAWP::Article::IsDivision(分割提案)' );

		$article->SetText( '{{分割提案' );
		ok( $article->IsDivision, 'JAWP::Article::IsDivision({{分割提案)' );
	}

	# Namespaceテスト
	{
		my $article = new JAWP::Article;

		$article->SetTitle( '' );
		is( $article->Namespace, '標準', 'JAWP::Article::Namespace(空文字列)' );

		foreach my $namespace ( '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'モジュール', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート', 'モジュール‐ノート' ) {
			my $title = "$namespace:dummy";
			$article->SetTitle( $title );
			is( $article->Namespace, $namespace, "JAWP::Article::Namespace($title)" );
		}
	}

	# SubpageTypeテスト
	{
		my $article = new JAWP::Article;

		$article->SetTitle( '' );
		is( $article->SubpageType, '', 'JAWP::Article::SubpageType(空文字列)' );

		$article->SetTitle( 'Wikipedia:井戸端/subj/dummy' );
		is( $article->SubpageType, '井戸端', 'JAWP::Article::SubpageType(Wikipedia:井戸端/subj/dummy)' );

		$article->SetTitle( 'Wikipedia:削除依頼/dummy' );
		is( $article->SubpageType, '削除依頼', 'JAWP::Article::SubpageType(Wikipedia:削除依頼/dummy)' );

		$article->SetTitle( 'Wikipedia:CheckUser依頼/dummy' );
		is( $article->SubpageType, 'CheckUser依頼', 'JAWP::Article::SubpageType(Wikipedia:CheckUser依頼/dummy)' );

		$article->SetTitle( 'Wikipedia:チェックユーザー依頼/dummy' );
		is( $article->SubpageType, 'CheckUser依頼', 'JAWP::Article::SubpageType(Wikipedia:チェックユーザー依頼/dummy)' );

		$article->SetTitle( 'Wikipedia:投稿ブロック依頼/dummy' );
		is( $article->SubpageType, '投稿ブロック依頼', 'JAWP::Article::SubpageType(Wikipedia:投稿ブロック依頼/dummy)' );

		$article->SetTitle( 'Wikipedia:管理者への立候補/dummy' );
		is( $article->SubpageType, '管理者への立候補', 'JAWP::Article::SubpageType(Wikipedia:管理者への立候補/dummy)' );

		$article->SetTitle( 'Wikipedia:コメント依頼/dummy' );
		is( $article->SubpageType, 'コメント依頼', 'JAWP::Article::SubpageType(Wikipedia:コメント依頼/dummy)' );

		$article->SetTitle( 'Wikipedia:査読依頼/dummy' );
		is( $article->SubpageType, '査読依頼', 'JAWP::Article::SubpageType(Wikipedia:査読依頼/dummy)' );
	}

	# GetPassTimeテスト
	{
		my $article = new JAWP::Article;

		$article->SetTimestamp( '' );
		is( $article->GetPassTime( 1293840000 ), '0000-00-00T00:00:00Z', 'JAWP::Article::GetPassTime()' );

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

		$article->SetTimestamp( '2011-01-02T00:00:00Z' );
		is( $article->GetPassTime( 1293840000 ), '0000-00-00T00:00:00Z', 'JAWP::Article::GetPassTime(2011-01-01T00:00:00Z)' );
	}

	# LintTextテスト
	{
		my $article = new JAWP::Article;
		my $titlelist = new JAWP::TitleList;
		my $result_ref;

		$titlelist->{'標準_リダイレクト'}->{'転送語'} = 1;
		$titlelist->{'標準_リダイレクト'}->{'Abc 転送語'} = 1;
		$titlelist->{'標準_曖昧'}->{'曖昧さ回避語'} = 1;
		$titlelist->{'標準_曖昧'}->{'Abc 曖昧さ回避語'} = 1;
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
		$titlelist->{'Category'}->{'Abc'} = 1;
		$titlelist->{'ファイル'}->{'ファイル'} = 1;
		$titlelist->{'ファイル'}->{'Abc'} = 1;
		$titlelist->{'Template'}->{'Reflist'} = 1;
		$titlelist->{'Template'}->{'Aimai'} = 1;
		$titlelist->{'Template'}->{'Abc'} = 1;
		$titlelist->{'Template'}->{'死亡年月日と没年齢'} = 1;
		$titlelist->{'Template'}->{'テンプレート'} = 1;

		# 戻り値の型確認
		$article->SetTitle( '標準' );
		$article->SetText( '' );
		$result_ref = $article->LintTitle;
		is( ref $result_ref, 'ARRAY', 'JAWP::Article::LintText(空文字列:リファレンス種別)' );

		# 標準記事空間以外は無視確認
		foreach my $namespace ( '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'モジュール', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート', 'モジュール‐ノート' ) {
			$article->SetTitle( "$namespace:TEST" );
			$article->SetText( '' );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], "JAWP::Article::LintText(標準記事空間以外無視,$namespace)" );
		}

		# リダイレクト記事は無視確認
		$article->SetTitle( '標準' );
		$article->SetText( '#redirect[[転送先]]' );
		$result_ref = $article->LintText( $titlelist );
		is_deeply( $result_ref, [], 'JAWP::Article::LintText(リダイレクト無視)' );

		# 特定タグ内は無視確認
		{
			foreach my $tag ( 'math', 'code', 'pre', 'nowiki' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "<$tag>\n= あああ =\n</$tag>\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText($tag 内無視)" );

				$article->SetTitle( '標準' );
				$article->SetText( "<$tag>\nあああ\n</$tag>\n= いいい =\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ 'レベル1の見出しがあります(4)' ], "JAWP::Article::LintText($tag 内無視,行数の不動)" );

				$article->SetTitle( '標準' );
				$article->SetText( "<$tag>\nあああ\n</$tag>\n= いいい =\n<$tag>\nううう\n</$tag>{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ 'レベル1の見出しがあります(4)' ], "JAWP::Article::LintText($tag 内無視,タグ複数)" );
			}
		}

		# 見出しテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n= いいい =\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'レベル1の見出しがあります(2)' ], 'JAWP::Article::LintText(見出しレベル1)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n= いいい = \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'レベル1の見出しがあります(2)' ], 'JAWP::Article::LintText(見出しレベル1,後ろスペースあり)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n = いいい = \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル1,無効)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n= いいい =a\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル1,無効2)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル2)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n == いいい == \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル2,無効)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル3)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n=== いいい ===\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'レベル3の見出しの前にレベル2の見出しが必要です(2)' ], 'JAWP::Article::LintText(見出しレベル3,レベル違反(3))' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n === いいい === \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル3,無効)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル4)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n==== えええ ====\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'レベル4の見出しの前にレベル3の見出しが必要です(3)' ], 'JAWP::Article::LintText(見出しレベル4,レベル違反(2-4))' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n==== いいい ====\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'レベル4の見出しの前にレベル3の見出しが必要です(2)' ], 'JAWP::Article::LintText(見出しレベル4,レベル違反(4))' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n ==== いいい ==== \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル4,無効)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n===== おおお =====\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル5)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n===== おおお =====\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'レベル5の見出しの前にレベル4の見出しが必要です(4)' ], 'JAWP::Article::LintText(見出しレベル5,レベル違反(2-3-5))' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n===== いいい =====\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'レベル5の見出しの前にレベル4の見出しが必要です(2)' ], 'JAWP::Article::LintText(見出しレベル5,レベル違反(5))' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n ===== いいい ===== \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル5,無効)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n===== おおお =====\n====== かかか ======\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル6)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n====== かかか ======\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'レベル6の見出しの前にレベル5の見出しが必要です(5)' ], 'JAWP::Article::LintText(見出しレベル6,レベル違反(2-3-4-6))' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n====== いいい ======\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'レベル6の見出しの前にレベル5の見出しが必要です(2)' ], 'JAWP::Article::LintText(見出しレベル6,レベル違反(6))' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n ====== いいい ====== \nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(見出しレベル6,無効)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい ==\n=== ううう ===\n==== えええ ====\n===== おおお =====\n====== かかか ======\n======= ききき =======\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ '見出しレベルは6までです(7)' ], 'JAWP::Article::LintText(見出しレベル7)' );

			$article->SetTitle( '標準' );
			$article->SetText( "あああ\n== いいい =\nううう\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ '見出し記法の左右の=の数が一致しません(2)' ], 'JAWP::Article::LintText(見出しレベル左右不一致)' );
		}

		# ISBN記法テスト
		{
			foreach my $code ( '0123456789', '0-12-345678-9', '012345678901X', '012-3-45-678901-X' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "ISBN $code\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(ISBN,' ',$code)" );

				$article->SetTitle( '標準' );
				$article->SetText( "ISBN=$code\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(ISBN,'=',$code)" );

				$article->SetTitle( '標準' );
				$article->SetText( "ISBN$code\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ 'ISBN記法では、ISBNと数字の間に半角スペースが必要です(1)' ], "JAWP::Article::LintText(ISBN,半角スペース無し,$code)" );
			}

			$article->SetTitle( '標準' );
			$article->SetText( "ISBN 012345678\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'ISBNは10桁もしくは13桁でないといけません(1)' ], 'JAWP::Article::LintText(ISBN,桁数違反)' );
		}

		# 西暦記述テスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "2011年\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(西暦)' );

			$article->SetTitle( '標準' );
			$article->SetText( "'11年\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ '西暦は全桁表示が推奨されます(1)' ], 'JAWP::Article::LintText(西暦,2桁,半角クォート)' );

			$article->SetTitle( '標準' );
			$article->SetText( "’11年\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ '西暦は全桁表示が推奨されます(1)' ], 'JAWP::Article::LintText(西暦,2桁,全角クォート)' );
		}

		# 不正コメントタグテスト
		{
			foreach my $tag ( '<!--', '-->' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "$tag\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '閉じられていないコメントタグがあります(1)' ], 'JAWP::Article::LintText(不正コメント)' );
			}
		}

		# ソートキーテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "{{DEFAULTSORT:あああ}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(ソートキー,DEFAULTSORT)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{デフォルトソート:あああ}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(ソートキー,デフォルトソート)' );

			foreach my $type ( 'Category', 'category', 'カテゴリ' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:カテゴリ|あああ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(ソートキー,$type)" );
			}

			foreach my $char ( 'ぁ', 'ぃ', 'ぅ', 'ぇ', 'ぉ', 'っ', 'ゃ', 'ゅ', 'ょ', 'ゎ', 'が', 'ぎ', 'ぐ', 'げ', 'ご', 'ざ', 'じ', 'ず', 'ぜ', 'ぞ', 'だ', 'ぢ', 'づ', 'で', 'ど', 'ば', 'び', 'ぶ', 'べ', 'ぼ', 'ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ', 'ー' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "{{DEFAULTSORT:あああ$char}}\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ 'ソートキーには濁音、半濁音、吃音、長音は清音化することが推奨されます(1)' ], "JAWP::Article::LintText(ソートキー,濁音、半濁音、吃音、長音,DEFAULTSORT,$char)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{デフォルトソート:あああ$char}}\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ 'ソートキーには濁音、半濁音、吃音、長音は清音化することが推奨されます(1)' ], "JAWP::Article::LintText(ソートキー,濁音、半濁音、吃音、長音,デフォルトソート,$char)" );

				foreach my $type ( 'Category', 'category', 'カテゴリ' ) {
					$article->SetTitle( '標準' );
					$article->SetText( "{{aimai}}\n[[$type:カテゴリ|あああ$char]]\n" );
					$result_ref = $article->LintText( $titlelist );
					is_deeply( $result_ref, [ 'ソートキーには濁音、半濁音、吃音、長音は清音化することが推奨されます(2)' ], "JAWP::Article::LintText(ソートキー,濁音、半濁音、吃音、長音,$type,$char)" );
				}
			}
		}

		# デフォルトソートテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "{{DEFAULTSORT:あああ}}\n{{DEFAULTSORT:あああ}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'デフォルトソートが複数存在します(2)' ], 'JAWP::Article::LintText(デフォルトソート,複数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{DEFAULTSORT:あああ}}\n{{デフォルトソート:あああ}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'デフォルトソートが複数存在します(2)' ], 'JAWP::Article::LintText(デフォルトソート,複数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{デフォルトソート:あああ}}\n{{デフォルトソート:あああ}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'デフォルトソートが複数存在します(2)' ], 'JAWP::Article::LintText(デフォルトソート,複数)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{DEFAULTSORT:}}\n\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'デフォルトソートではソートキーが必須です(1)' ], 'JAWP::Article::LintText(デフォルトソート,ソートキー無し)' );

			$article->SetTitle( '標準' );
			$article->SetText( "{{デフォルトソート:}}\n\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'デフォルトソートではソートキーが必須です(1)' ], 'JAWP::Article::LintText(デフォルトソート,ソートキー無し)' );
		}

		# カテゴリテスト
		{
			foreach my $type ( 'Category', 'category', 'カテゴリ' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:カテゴリ1]]\n[[$type:カテゴリ2]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText($type,カテゴリ1,カテゴリ2)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:abc]]\n\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText($type,abc)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:カテゴリ1]][[$type:カテゴリ2]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText($type,同一行)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:カテゴリ]]\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '既に使用されているカテゴリです(3)' ], "JAWP::Article::LintText($type,重複指定,カテゴリ)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:Abc]]\n[[$type:abc]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '既に使用されているカテゴリです(3)' ], "JAWP::Article::LintText($type,重複指定,Abc,abc)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:カテゴリ]][[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '既に使用されているカテゴリです(2)' ], "JAWP::Article::LintText($type,重複指定,同一行,カテゴリ)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:Abc]][[$type:abc]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '既に使用されているカテゴリです(2)' ], "JAWP::Article::LintText($type,重複指定,同一行,Abc,abc)" );

				$article->SetTitle( '標準' );
				$article->SetText( "{{aimai}}\n[[$type:カテゴリ3]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '(カテゴリ3)は存在しないカテゴリです(2)' ], "JAWP::Article::LintText($type,不存在)" );
			}
		}

		# 使用できる文字・文言テスト
		{
			$article->SetTitle( '標準' );
			foreach my $char ( '，', '．', '！', '？', '＆', '＠' ) {
				$article->SetText( "$char\n{{aimai}}\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '全角記号の使用は推奨されません(1)' ], "JAWP::Article::LintText(全角記号,$char)" );
			}
			$article->SetTitle( '標準' );
			foreach my $char ( 'Ａ', 'Ｚ', 'ａ', 'ｚ', '０', '９' ) {
				$article->SetText( "$char\n{{aimai}}\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '全角英数字の使用は推奨されません(1)' ], "JAWP::Article::LintText(全角英数字,$char)" );
			}
			$article->SetTitle( '標準' );
			foreach my $char ( 'ｱ', 'ﾝ', 'ﾞ', 'ﾟ', 'ｧ', 'ｫ', 'ｬ', 'ｮ', '｡', '｢', '｣', '､' ) {
				$article->SetText( "$char\n{{aimai}}\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '半角カタカナの使用は推奨されません(1)' ], "JAWP::Article::LintText(半角カタカナ,$char)" );
			}
			$article->SetTitle( '標準' );
			foreach my $char ( 'Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ', 'Ⅶ', 'Ⅷ', 'Ⅸ', 'Ⅹ' ) {
				$article->SetText( "$char\n{{aimai}}\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ 'ローマ数字はアルファベットを組み合わせましょう(1)' ], "JAWP::Article::LintText(ローマ数字,$char)" );
			}
			$article->SetTitle( '標準' );
			foreach my $char ( '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩', '⑪', '⑫', '⑬', '⑭', '⑮', '⑯', '⑰', '⑱', '⑲', '⑳' ) {
				$article->SetText( "$char\n{{aimai}}\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '丸付き数字の使用は推奨されません(1)' ], "JAWP::Article::LintText(丸付き数字,$char)" );
			}
		}

		# 曖昧さ回避リンクテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "[[標準]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(曖昧さ回避リンク,標準)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[曖昧さ回避語]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ '(曖昧さ回避語)のリンク先は曖昧さ回避です(1)' ], 'JAWP::Article::LintText(曖昧さ回避リンク,曖昧さ回避語)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[abc 曖昧さ回避語]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ '(Abc 曖昧さ回避語)のリンク先は曖昧さ回避です(1)' ], 'JAWP::Article::LintText(曖昧さ回避リンク,abc 曖昧さ回避語)' );
		}

		# 年月日リンクテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "[[2011年]][[1月1日]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(年月日リンク,[[2011年]][[1月1日]])' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[2011年1月1日は元旦]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(年月日リンク,[[2011年1月1日は元旦]])' );

			$article->SetTitle( '標準' );
			$article->SetText( "[[2011年1月1日]]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ '年月日へのリンクは年と月日を分けることが推奨されます(1)' ], 'JAWP::Article::LintText(リダイレクトリンク,[[2011年1月1日]])' );
		}

		# 不正URLテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "[http://www.yahoo.co.jp/]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(不正URL,http://www.yahoo.co.jp/)' );

			$article->SetTitle( '標準' );
			$article->SetText( "[http:///www.yahoo.co.jp/]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ '不正なURLです(1)' ], 'JAWP::Article::LintText(不正URL,http:///www.yahoo.co.jp/)' );
		}

		# カッコ対応テスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "[ ]\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(カッコ対応,[ ])' );

			$article->SetTitle( '標準' );
			$article->SetText( "{ }\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(カッコ対応,{ })' );

			foreach my $subtext ( '[', ']', '[[', ']]', '{', '}', '{{', '}}', '[}', '{]' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "$subtext\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '空のリンクまたは閉じられていないカッコがあります(1)' ], "JAWP::Article::LintText(カッコ対応,$subtext)" );
			}
		}

		# リファレンステスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "<ref>あああ</ref>\n<references/>\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(リファレンス,<references/>)' );

			$article->SetTitle( '標準' );
			$article->SetText( "<ref>あああ</ref>\n{{reflist}}\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintText(リファレンス,{{reflist}})' );

			$article->SetTitle( '標準' );
			$article->SetText( "<ref>あああ</ref>\n{{aimai}}" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ '<ref>要素があるのに<references>要素がありません' ], 'JAWP::Article::LintText(リファレンス,不存在)' );
		}

		# 定義文テスト
		{
			foreach my $type ( 'Category', 'category', 'カテゴリ' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '定義文が見当たりません' ], "JAWP::Article::LintText(定義文,'標準'-'',$type)" );

				$article->SetTitle( '標準' );
				$article->SetText( "'''あああ'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '定義文が見当たりません' ], "JAWP::Article::LintText(定義文,'標準'-'''あああ''',$type)" );

				$article->SetTitle( '標準' );
				$article->SetText( "'''標 準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'標準'-'''標 準''',$type)" );

				$article->SetTitle( '標準' );
				$article->SetText( "''' 標準 '''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'標準'-''' 標準 ''',$type)" );

				$article->SetTitle( '標 準' );
				$article->SetText( "''' 標 準 '''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'標 準'-''' 標 準 ''',$type)" );

				$article->SetTitle( '標準' );
				$article->SetText( "'''あああ'''\n''' 標準 '''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'標準'-'''あああ'''\n''' 標準 ''',$type)" );

				$article->SetTitle( '標準 (曖昧さ回避)' );
				$article->SetText( "'''標準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'標準 (曖昧さ回避)'-'''標準''',$type)" );

				$article->SetTitle( 'Abc' );
				$article->SetText( "'''Abc'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'Abc'-'''Abc''',$type)" );

				$article->SetTitle( 'Abc' );
				$article->SetText( "'''abc'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'Abc'-'''abc''',$type)" );

				$article->SetTitle( 'abc' );
				$article->SetText( "'''Abc'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '定義文が見当たりません' ], "JAWP::Article::LintText(定義文,'abc'-'''Abc''',$type)" );

				$article->SetTitle( 'abc' );
				$article->SetText( "'''abc'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'abc'-'''abc''',$type)" );

				$article->SetTitle( 'Shift JIS' );
				$article->SetText( "'''Shift JIS'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'Shift JIS'-'''Shift_JIS''',$type)" );

				$article->SetTitle( 'Shift JIS' );
				$article->SetText( "'''Shift_JIS'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'Shift JIS'-'''Shift_JIS''',$type)" );

				$article->SetTitle( 'Shift_JIS' );
				$article->SetText( "'''Shift JIS'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'Shift JIS'-'''Shift_JIS''',$type)" );

				$article->SetTitle( 'Shift_JIS' );
				$article->SetText( "'''Shift_JIS'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(定義文,'Shift JIS'-'''Shift_JIS''',$type)" );
			}
		}

		# カテゴリ、デフォルトソート、出典なしテスト
		{
			$article->SetTitle( '標準' );
			$article->SetText( "'''標準'''\n== 出典 ==\n{{DEFAULTSORT:あああ}}\n" );
			$result_ref = $article->LintText( $titlelist );
			is_deeply( $result_ref, [ 'カテゴリが一つもありません' ], 'JAWP::Article::LintText(カテゴリ無し)' );

			foreach my $type ( 'Category', 'category', 'カテゴリ' ) {
				$article->SetTitle( '標準' );
				$article->SetText( "'''標準'''\n== 出典 ==\n[[$type:カテゴリ]]" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ 'デフォルトソートがありません' ], "JAWP::Article::LintText(デフォルトソート無し,$type)" );

				$article->SetTitle( '標準' );
				$article->SetText( "'''標準'''\n{{DEFAULTSORT:あああ}}\n[[$type:カテゴリ]]\n" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '出典に関する節がありません' ], "JAWP::Article::LintText(出典無し,$type)" );
			}
		}

		# 生没年カテゴリテスト
		{
			foreach my $type ( 'Category', 'category', 'カテゴリ' ) {
				foreach my $subtext ( "[[$type:2001年生]]\n[[$type:存命人物]]\n{{生年月日と年齢|2001|1|1}}", "[[$type:生年不明]]\n[[$type:存命人物]]", "[[$type:2001年生]]\n[[$type:2011年没]]\n{{死亡年月日と没年齢|2001|1|1|2011|12|31}}", "[[$type:2001年生]]\n[[$type:2011年没]]\n{{没年齢|2001|1|1|2011|12|31}}", "[[$type:生年不明]]\n[[$type:2011年没]]", "[[$type:2001年生]]\n[[$type:没年不明]]", "[[$type:生年不明]]\n[[$type:没年不明]]" ) {
					$article->SetTitle( '標準' );
					$article->SetText( "$subtext\n{{aimai}}" );
					$result_ref = $article->LintText( $titlelist );
					is_deeply( $result_ref, [], "JAWP::Article::LintText(生没年カテゴリ,$subtext,$type)" );
				}

				foreach my $subtext ( "[[$type:2001年生]]\n[[$type:2011年没]]\n[[$type:存命人物]]\n{{死亡年月日と没年齢|2001|1|1|2011|12|31}}", "[[$type:2001年生]]\n[[$type:没年不明]]\n[[$type:存命人物]]", "[[$type:生年不明]]\n[[$type:2011年没]]\n[[$type:存命人物]]", "[[$type:生年不明]]\n[[$type:没年不明]]\n[[$type:存命人物]]", "[[$type:2001年生]]\n[[$type:存命人物]]\n{{死亡年月日と没年齢|2001|1|1|2011|12|31}}" ) {
					$article->SetTitle( '標準' );
					$article->SetText( "$subtext\n{{aimai}}" );
					$result_ref = $article->LintText( $titlelist );
					is_deeply( $result_ref, [ '存命人物ではありません' ], "JAWP::Article::LintText(生没年カテゴリ,存命人物ではありません,$subtext,$type)" );
				}

				foreach my $subtext ( "[[$type:存命人物]]", "[[$type:2011年没]]", "[[$type:没年不明]]" ) {
					$article->SetTitle( '標準' );
					$article->SetText( "$subtext\n{{aimai}}" );
					$result_ref = $article->LintText( $titlelist );
					is_deeply( $result_ref, [ '生年のカテゴリがありません' ], "JAWP::Article::LintText(生没年カテゴリ,生年のカテゴリがありません,$subtext,$type)" );
				}

				foreach my $subtext ( "[[$type:2001年生]]", "[[$type:生年不明]]" ) {
					$article->SetTitle( '標準' );
					$article->SetText( "$subtext\n{{aimai}}" );
					$result_ref = $article->LintText( $titlelist );
					is_deeply( $result_ref, [ '存命人物または没年のカテゴリがありません' ], "JAWP::Article::LintText(生没年カテゴリ,存命人物または没年のカテゴリがありません,$subtext,$type)" );
				}

				foreach my $subtext ( "[[$type:2001年生]]\n[[$type:2011年没]]\n{{死亡年月日と没年齢|2002|1|1|2011|12|31}}", "[[$type:2001年生]]\n[[$type:2011年没]]\n{{没年齢|2002|1|1|2011|12|31}}", "[[$type:2001年生]]\n[[$type:存命人物]]\n{{生年月日と年齢|2002|1|1}}" ) {
					$article->SetTitle( '標準' );
					$article->SetText( "$subtext\n{{aimai}}" );
					$result_ref = $article->LintText( $titlelist );
					is_deeply( $result_ref, [ '(生年月日と年齢or死亡年月日と没年齢or没年齢)テンプレートと生年のカテゴリが一致しません' ], "JAWP::Article::LintText(生没年カテゴリ,テンプレートと生年のカテゴリ不一致,$subtext,$type)" );
				}

				foreach my $subtext ("[[$type:2001年生]]\n[[$type:2011年没]]\n{{死亡年月日と没年齢|2001|1|1|2012|12|31}}", "[[$type:2001年生]]\n[[$type:2011年没]]\n{{没年齢|2001|1|1|2012|12|31}}" ) {
					$article->SetTitle( '標準' );
					$article->SetText( "$subtext\n{{aimai}}" );
					$result_ref = $article->LintText( $titlelist );
					is_deeply( $result_ref, [ '(死亡年月日と没年齢or没年齢)テンプレートと没年のカテゴリが一致しません' ], "JAWP::Article::LintText(生没年カテゴリ,テンプレートと没年のカテゴリ不一致,$subtext,$type)" );
				}

				$article->SetTitle( '標準' );
				$article->SetText( "[[$type:2001年生]]\n[[$type:存命人物]]\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '(生年月日と年齢)のテンプレートを使うと便利です' ], "JAWP::Article::LintText(生没年カテゴリ,2001年生-存命人物,テンプレート未使用,$type)" );

				$article->SetTitle( '標準' );
				$article->SetText( "[[$type:1900年生]]\n[[$type:1902年没]]\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [], "JAWP::Article::LintText(生没年カテゴリ,1900年生-1902年没,テンプレート範囲外,$type)" );

				$article->SetTitle( '標準' );
				$article->SetText( "[[$type:2001年生]]\n[[$type:2011年没]]\n{{aimai}}" );
				$result_ref = $article->LintText( $titlelist );
				is_deeply( $result_ref, [ '(死亡年月日と没年齢)のテンプレートを使うと便利です' ], "JAWP::Article::LintText(生没年カテゴリ,2001年生-2011年没,テンプレート未使用,$type)" );
			}
		}
	}

	# LintIndexテスト
	{
		my $article = new JAWP::Article;
		my $titlelist = new JAWP::TitleList;
		my $result_ref;

		$titlelist->{'標準'}->{'記事'} = 1;

		# 戻り値の型確認
		$article->SetTitle( '' );
		$article->SetText( '' );
		$result_ref = $article->LintIndex( $titlelist );
		is( ref $result_ref, 'ARRAY', 'JAWP::Article::LintIndex(空文字列:リファレンス種別)' );

		# 索引記事以外は無視確認
		$article->SetTitle( 'aaa' );
		$article->SetText( '' );
		$result_ref = $article->LintIndex( $titlelist );
		is_deeply( $result_ref, [], 'JAWP::Article::LintIndex(非索引)' );

		# 索引トップは無視確認
		$article->SetTitle( 'Wikipedia:索引' );
		$article->SetText( '' );
		$result_ref = $article->LintIndex( $titlelist );
		is_deeply( $result_ref, [], 'JAWP::Article::LintIndex(索引トップ)' );

		# 見出しテスト
		{
			# 見出し正常
			$article->SetTitle( 'Wikipedia:索引 あ' );
			$article->SetText( "==ああ==\n==あい==\n" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintIndex(見出し正常)' );

			# 見出し正常
			$article->SetTitle( 'Wikipedia:索引 あ' );
			$article->SetText( "==ああ== \n==あい== \n" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintIndex(見出し正常,後ろスペースあり)' );

			# 見出し正常
			$article->SetTitle( 'Wikipedia:索引 記号' );
			$article->SetText( "==記号==" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintIndex(見出し正常,記号)' );

			# 見出し違反(前スペースあり)
			$article->SetTitle( 'Wikipedia:索引 あ' );
			$article->SetText( " == い ==\n" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintIndex(見出し違反,前スペースあり,警告無し)' );

			# 見出し違反(後ろスペース以外あり)
			$article->SetTitle( 'Wikipedia:索引 あ' );
			$article->SetText( "== い ==a\n" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintIndex(見出し違反,後ろスペース以外あり,警告無し)' );

			# 見出し違反(記事名不一致)
			$article->SetTitle( 'Wikipedia:索引 あ' );
			$article->SetText( "== い ==\n" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [ '見出し(い)が記事名に一致しません(1)' ], 'JAWP::Article::LintIndex(見出し違反(記事名不一致))' );

			# 見出し違反(濁音、半濁音、吃音、拗音、長音)
			foreach my $head ( 'あが', 'あぱ', 'あっ', 'あゃ', 'あー' ) {
				$article->SetTitle( 'Wikipedia:索引 あ' );
				$article->SetText( "== $head ==\n" );
				$result_ref = $article->LintIndex( $titlelist );
				is_deeply( $result_ref, [ "見出し($head)は濁音、半濁音、吃音、拗音、長音を使っています(1)" ], "JAWP::Article::LintIndex(見出し違反(濁音、半濁音、吃音、拗音、長音:$head))" );
			}

			# 見出し違反(順序違反)
			$article->SetTitle( 'Wikipedia:索引 あ' );
			$article->SetText( "== あい ==\n== ああ ==\n" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [ '見出し(ああ)があいうえお順ではありません(2)' ], 'JAWP::Article::LintIndex(見出し違反(順序違反))' );
		}

		# 項目テスト
		{
			# 項目正常
			$article->SetTitle( 'Wikipedia:索引 あ' );
			$article->SetText( "*[[記事]]（きじ）【分野】\n" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintIndex(項目正常)' );

			# リダイレクト正常
			$article->SetTitle( 'Wikipedia:索引 あ' );
			$article->SetText( "*[[記事]]（きじ）⇒[[記事]]\n" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [], 'JAWP::Article::LintIndex(リダイレクト正常)' );

			# 赤リンク
			$article->SetTitle( 'Wikipedia:索引 あ' );
			$article->SetText( "*[[あああ]]【分野】\n" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [ '(あああ)は赤リンクです(1)' ], 'JAWP::Article::LintIndex(赤リンク)' );

			# 読み仮名無し
			$article->SetTitle( 'Wikipedia:索引 あ' );
			$article->SetText( "*[[記事]]【分野】\n" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [ '読み仮名がありません(1)' ], 'JAWP::Article::LintIndex(読み仮名無し)' );

			# 分野名無し
			$article->SetTitle( 'Wikipedia:索引 あ' );
			$article->SetText( "*[[記事]]（きじ）\n" );
			$result_ref = $article->LintIndex( $titlelist );
			is_deeply( $result_ref, [ '分野名がありません(1)' ], 'JAWP::Article::LintIndex(分野名無)' );
		}
	}

	# Personテスト
	{
		my $article = new JAWP::Article;
		my @list;

		# 空文字列
		$article->SetTitle( '' );
		$article->SetText( '' );
		@list = $article->Person;
		is_deeply( \@list, [], 'JAWP::Article::Person(空文字列)' );

		# 標準記事空間以外は無視
		$article->SetTitle( 'Wikipedia:dummy' );
		$article->SetText( '' );
		@list = $article->Person;
		is_deeply( \@list, [], 'JAWP::Article::Person(Wikipedia:dummy)' );

		# 誕生、死去
		$article->SetTitle( '標準' );
		$article->SetText( '{{生年月日と年齢|2001|1|1}}' );
		@list = $article->Person;
		is_deeply( \@list, [ '2001年誕生', '1月1日誕生' ], 'JAWP::Article::Person({{生年月日と年齢|2001|1|1}})' );

		$article->SetTitle( '標準' );
		$article->SetText( '{{死亡年月日と没年齢|2001|1|1|2011|12|31}}' );
		@list = $article->Person;
		is_deeply( \@list, [ '2001年誕生', '1月1日誕生', '2011年死去', '12月31日死去' ], 'JAWP::Article::Person({{死亡年月日と没年齢|2001|1|1|2011|12|31}})' );

		$article->SetTitle( '標準' );
		$article->SetText( '{{没年齢|2001|1|1|2011|12|31}}' );
		@list = $article->Person;
		is_deeply( \@list, [ '2001年誕生', '1月1日誕生', '2011年死去', '12月31日死去' ], 'JAWP::Article::Person({{没年齢|2001|1|1|2011|12|31}})' );

		foreach my $cat ( 'Category', 'カテゴリ' ) {
			my $text;

			$text = "[[$cat:2001年生]]";
			$article->SetTitle( '標準' );
			$article->SetText( $text );
			@list = $article->Person;
			is_deeply( \@list, [ '2001年誕生' ], "JAWP::Article::Person($text)" );

			$text = "[[$cat:2011年没]]";
			$article->SetTitle( '標準' );
			$article->SetText( $text );
			@list = $article->Person;
			is_deeply( \@list, [ '2011年死去' ], "JAWP::Article::Person($text)" );

			$text = "{生年月日と年齢|2001|1|1}}\n[[$cat:2002年生]]";
			$article->SetTitle( '標準' );
			$article->SetText( "{{生年月日と年齢|2001|1|1}}\n[[$cat:2002年生]]" );
			@list = $article->Person;
			is_deeply( \@list, [ '2001年誕生', '1月1日誕生' ], "JAWP::Article::Person($text)" );

			$text = "{{生年月日と年齢|2001|1|1}}\n[[$cat:2012年没]]";
			$article->SetTitle( '標準' );
			$article->SetText( $text );
			@list = $article->Person;
			is_deeply( \@list, [ '2001年誕生', '1月1日誕生', '2012年死去' ], "JAWP::Article::Person($text)" );

			$text = "{{死亡年月日と没年齢|2001|1|1|2011|12|31}}\n[[$cat:2012年没]]";
			$article->SetTitle( '標準' );
			$article->SetText( $text );
			@list = $article->Person;
			is_deeply( \@list, [ '2001年誕生', '1月1日誕生', '2011年死去', '12月31日死去' ], "JAWP::Article::Person({{死亡年月日と没年齢|2001|1|1|2011|12|31}}\n[[$cat:2012年没]])" );

			$text = "{{没年齢|2001|1|1|2011|12|31}}\n[[$cat:2012年没]]";
			$article->SetTitle( '標準' );
			$article->SetText( $text );
			@list = $article->Person;
			is_deeply( \@list, [ '2001年誕生', '1月1日誕生', '2011年死去', '12月31日死去' ], "JAWP::Article::Person({{没年齢|2001|1|1|2011|12|31}}\n[[$cat:2012年没]])" );
		}

		# 出身都道府県
		foreach my $cat ( 'Category', 'カテゴリ' ) {
			my $text = "[[$cat:東京都出身の人物]]";
			$article->SetTitle( '標準' );
			$article->SetText( $text );
			@list = $article->Person;
			is_deeply( \@list, [ '東京都出身の人物' ], "JAWP::Article::Person($text)" );
		}
	}
}
