#!/usr/bin/perl

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


################################################################################
# JAWP::TitleListクラス
################################################################################

{
	# useテスト
	use_ok( 'JAWP', 'use JAWP' );

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
