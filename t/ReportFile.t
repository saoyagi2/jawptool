use strict;
use warnings;

use lib ".";

use utf8;
use Encode;
use open IO  => ':utf8';
binmode Test::More->builder->output, ':utf8';
binmode Test::More->builder->failure_output, ':utf8';
binmode Test::More->builder->todo_output, ':utf8';

use Test::More( 'no_plan' );

require 't/common.pl';


################################################################################
# JAWP::ReportFileクラス
################################################################################

{
	# useテスト
	use_ok( 'JAWP', 'use JAWP' );

	# メソッド呼び出しテスト
	{
		foreach my $method ( 'new', 'OutputWiki', 'OutputWikiList', 'OutputDirect' ) {
			ok( JAWP::ReportFile->can($method), "JAWP::ReportFile(メソッド呼び出し,$method)" );
		}
	}

	# 空new失敗確認テスト
	{
		my $report;
		eval {
			$report = new JAWP::ReportFile;
		};

		ok( !defined( $report ), 'JAWP::ReportFile(空new)' );
		like( $@, qr/No such file or directory at JAWP\.pm/, 'JAWP::ReportFile(空new)' );
	}

	# open失敗確認テスト
	{
		my $report;
		eval {
			$report = new JAWP::ReportFile( '/' );
		};

		ok( !defined( $report ), 'JAWP::ReportFile(open失敗)' );
		like( $@, qr/Is a directory at JAWP\.pm/, 'JAWP::ReportFile(open失敗)' );
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

	# OutputWikiテスト(エラー)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );

			close $report->{'fh'};
			eval {
				$report->OutputWiki( 'title1', \( '' ) );
			};
			like( $@, qr/Bad file descriptor at JAWP\.pm/, 'JAWP::ReportFile::OutputWiki(エラー)' );
		}
		unlink( $fname ) or die $!;
	}

	# OutputWikiListテスト(空配列データ)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );

			$report->OutputWikiList( 'title', [] );
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

			$report->OutputWikiList( 'title', [ 'あいうえお', 'かきくけこ', 'さしすせそ' ] );
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

			$report->OutputWikiList( 'title1', [ 'あいうえお', 'かきくけこ', 'さしすせそ' ] );
			$report->OutputWikiList( 'title2', [ 'abcde', '01234' ] );
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

	# OutputWikiListテスト(エラー)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );

			close $report->{'fh'};
			eval {
				$report->OutputWikiList( 'title1', [] );
			};
			like( $@, qr/Bad file descriptor at JAWP\.pm/, 'JAWP::ReportFile::OutputWiki(エラー)' );
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

	# OutputDirectテスト(エラー)
	{
		my $fname = GetTempFilename();
		{
			my $report = new JAWP::ReportFile( $fname );

			close $report->{'fh'};
			eval {
				$report->OutputDirect( 'title1', '' );
			};
			like( $@, qr/Bad file descriptor at JAWP\.pm/, 'JAWP::ReportFile::OutputWiki(エラー)' );
		}
		unlink( $fname ) or die $!;
	}
}
