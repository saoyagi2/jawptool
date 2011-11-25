#!/usr/bin/perl

use strict;
use warnings;

use utf8;
use Encode;
use open IO  => ':utf8';
binmode Test::More->builder->output, ':utf8';
binmode Test::More->builder->failure_output, ':utf8';
binmode Test::More->builder->todo_output, ':utf8';

use Test::More;

require 't/common.pl';


################################################################################
# JAWP::DataFileクラス
################################################################################

{
	# useテスト
	use_ok( 'JAWP', 'use JAWP' );

	# メソッド呼び出しテスト
	{
		foreach my $method ( 'new', 'GetArticle', 'GetTitleList' ) {
			ok( JAWP::DataFile->can($method), "JAWP::DataFile(メソッド呼び出し,$method)" );
		}
	}

	# 空new失敗確認テスト
	{
		my $data;
		eval {
			$data = new JAWP::DataFile;
		};

		ok( !defined( $data ), 'JAWP::DataFile(空new)' );
		like( $@, qr/No such file or directory at JAWP\.pm/, 'JAWP::DataFile(空new)' );
	}

	# open失敗確認テスト
	{
		my $fname = GetTempFilename();
		unlink( $fname ) or die;

		my $data;
		eval {
			$data = new JAWP::DataFile( $fname );
		};

		ok( !defined( $data ), 'JAWP::DataFile(open失敗)' );
		like( $@, qr/No such file or directory at JAWP\.pm/, 'JAWP::DataFile(open失敗)' );
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

			is_deeply( $article, { 'title'=>'真記事名', 'timestamp'=>'2011-01-01T00:00:00Z', 'text'=>'本文' }, 'JAWP::DataFile::GetArticle(要素重複XMLファイル)' );

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

			is_deeply( $article, { 'title'=>'記事名', 'timestamp'=>'2011-01-01T00:00:00Z', 'text'=>'本文' }, 'JAWP::DataFile::GetArticle(要素逆順XMLファイル)' );

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

			is_deeply( $article, { 'title'=>'記事名', 'timestamp'=>'2011-01-01T00:00:00Z', 'text'=>'本文' }, 'JAWP::DataFile::GetArticle(2周読み込み,1周目1記事目取得)' );

			$article = $data->GetArticle;
			ok( !defined( $article ), 'JAWP::DataFile::GetArticle(2周読み込み,1周目2記事目取得)' );

			$article = $data->GetArticle;

			is_deeply( $article, { 'title'=>'記事名', 'timestamp'=>'2011-01-01T00:00:00Z', 'text'=>'本文' }, 'JAWP::DataFile::GetArticle(2周読み込み,2周目1記事目取得)' );

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

			is_deeply( $article, { 'title'=>'記事名', 'timestamp'=>'2011-01-01T00:00:00Z', 'text'=>"\n本文1\n本文2\n本文3\n" }, 'JAWP::DataFile::GetArticle(本文複数行)' );

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

			is_deeply( $article, { 'title'=>'記事名', 'timestamp'=>'2011-01-01T00:00:00Z', 'text'=>"\n本文1\n\n\n\n真本文3\n" }, 'JAWP::DataFile::GetArticle(コメント除去)' );

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

			is_deeply( $article, { 'title'=>'記事名1', 'timestamp'=>'2011-01-01T00:00:01Z', 'text'=>'本文1' }, 'JAWP::DataFile::GetArticle(2記事読み込み,1記事目)' );

			$article = $data->GetArticle;

			is_deeply( $article, { 'title'=>'記事名2', 'timestamp'=>'2011-01-01T00:00:02Z', 'text'=>'本文2' }, 'JAWP::DataFile::GetArticle(2記事読み込み,2記事目)' );

			$article = $data->GetArticle;
			ok( !defined( $article ), 'JAWP::DataFile::GetArticle(2記事読み込み,3記事目取得)' );

			unlink( $fname ) or die $!;
		}

		# エラー(途中close)
		{
			my $fname = WriteTestXMLFile( '' );
			my $data = new JAWP::DataFile( $fname );
			close $data->{'fh'};
			eval {
				my $article = $data->GetArticle;
			};
			like( $@, qr/Bad file descriptor at JAWP\.pm/, 'JAWP::GetArticle(途中close)' );

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

			is_deeply( $titlelist, { 'allcount'=>0, '標準'=>{}, '標準_曖昧'=>{}, '標準_リダイレクト'=>{}, '利用者'=>{}, 'Wikipedia'=>{}, 'ファイル'=>{}, 'MediaWiki'=>{}, 'Template'=>{}, 'Help'=>{}, 'Category'=>{}, 'Portal'=>{}, 'プロジェクト'=>{}, 'ノート'=>{}, '利用者‐会話'=>{}, 'Wikipedia‐ノート'=>{}, 'ファイル‐ノート'=>{}, 'MediaWiki‐ノート'=>{}, 'Template‐ノート'=>{}, 'Help‐ノート'=>{}, 'Category‐ノート'=>{}, 'Portal‐ノート'=>{}, 'プロジェクト‐ノート'=>{} }, 'JAWP::DataFile::GetTitleList(空XMLファイル)' );

			unlink( $fname ) or die $!;
		}

		# xml要素のみXMLファイル
		{
			my $fname = WriteTestXMLFile( '<xml></xml>' );
			my $data = new JAWP::DataFile( $fname );
			my $titlelist = $data->GetTitleList;

			is_deeply( $titlelist, { 'allcount'=>0, '標準'=>{}, '標準_曖昧'=>{}, '標準_リダイレクト'=>{}, '利用者'=>{}, 'Wikipedia'=>{}, 'ファイル'=>{}, 'MediaWiki'=>{}, 'Template'=>{}, 'Help'=>{}, 'Category'=>{}, 'Portal'=>{}, 'プロジェクト'=>{}, 'ノート'=>{}, '利用者‐会話'=>{}, 'Wikipedia‐ノート'=>{}, 'ファイル‐ノート'=>{}, 'MediaWiki‐ノート'=>{}, 'Template‐ノート'=>{}, 'Help‐ノート'=>{}, 'Category‐ノート'=>{}, 'Portal‐ノート'=>{}, 'プロジェクト‐ノート'=>{} }, 'JAWP::DataFile::GetTitleList(xml要素のみXMLファイル)' );

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

			is_deeply( $titlelist, { 'allcount'=>22, '標準'=>{ '標準A'=>1, '標準 曖昧A'=>1 }, '標準_曖昧'=>{ '標準 曖昧A'=>1 }, '標準_リダイレクト'=>{ 'A'=>1 }, '利用者'=>{ 'A'=>1 }, 'Wikipedia'=>{ 'A'=>1 }, 'ファイル'=>{ 'A'=>1 }, 'MediaWiki'=>{ 'A'=>1 }, 'Template'=>{ 'A'=>1 }, 'Help'=>{ 'A'=>1 }, 'Category'=>{ 'A'=>1 }, 'Portal'=>{ 'A'=>1 }, 'プロジェクト'=>{ 'A'=>1 }, 'ノート'=>{ 'A'=>1 }, '利用者‐会話'=>{ 'A'=>1 }, 'Wikipedia‐ノート'=>{ 'A'=>1 }, 'ファイル‐ノート'=>{ 'A'=>1 }, 'MediaWiki‐ノート'=>{ 'A'=>1 }, 'Template‐ノート'=>{ 'A'=>1 }, 'Help‐ノート'=>{ 'A'=>1 }, 'Category‐ノート'=>{ 'A'=>1 }, 'Portal‐ノート'=>{ 'A'=>1 }, 'プロジェクト‐ノート'=>{ 'A'=>1 } }, 'JAWP::DataFile::GetTitleList(標準XMLファイル)' );

			unlink( $fname ) or die $!;
		}

		# 見出しありXMLファイル
		{
			my $str = <<'STR';
<xml>
	<title>A</title>
	<timestamp>2011-01-01T00:00:00Z</timestamp>
	<text xml:space="preserve">==見出し1==

== 見出し 2 ==</text>
</xml>
STR
			my $fname = WriteTestXMLFile( $str );

			# withouthead
			{
				my $data = new JAWP::DataFile( $fname );
				my $titlelist = $data->GetTitleList;

				is_deeply( $titlelist, { 'allcount'=>1, '標準'=>{ 'A'=>1 }, '標準_曖昧'=>{}, '標準_リダイレクト'=>{}, '利用者'=>{}, 'Wikipedia'=>{}, 'ファイル'=>{}, 'MediaWiki'=>{}, 'Template'=>{}, 'Help'=>{}, 'Category'=>{}, 'Portal'=>{}, 'プロジェクト'=>{}, 'ノート'=>{}, '利用者‐会話'=>{}, 'Wikipedia‐ノート'=>{}, 'ファイル‐ノート'=>{}, 'MediaWiki‐ノート'=>{}, 'Template‐ノート'=>{}, 'Help‐ノート'=>{}, 'Category‐ノート'=>{}, 'Portal‐ノート'=>{}, 'プロジェクト‐ノート'=>{} }, 'JAWP::DataFile::GetTitleList(見出しありXMLファイル,withouthead)' );
			}

			# withhead
			{
				my $data = new JAWP::DataFile( $fname );
				my $titlelist = $data->GetTitleList( 1 );

				is_deeply( $titlelist, { 'allcount'=>1, '標準'=>{ 'A'=>1, 'A#見出し1'=>1, 'A#見出し 2'=>1 }, '標準_曖昧'=>{}, '標準_リダイレクト'=>{}, '利用者'=>{}, 'Wikipedia'=>{}, 'ファイル'=>{}, 'MediaWiki'=>{}, 'Template'=>{}, 'Help'=>{}, 'Category'=>{}, 'Portal'=>{}, 'プロジェクト'=>{}, 'ノート'=>{}, '利用者‐会話'=>{}, 'Wikipedia‐ノート'=>{}, 'ファイル‐ノート'=>{}, 'MediaWiki‐ノート'=>{}, 'Template‐ノート'=>{}, 'Help‐ノート'=>{}, 'Category‐ノート'=>{}, 'Portal‐ノート'=>{}, 'プロジェクト‐ノート'=>{} }, 'JAWP::DataFile::GetTitleList(見出しありXMLファイル,withhead)' );
			}

			unlink( $fname ) or die $!;
		}
	}

	done_testing;
}
