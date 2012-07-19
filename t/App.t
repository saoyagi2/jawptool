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
# JAWP::Appクラス
################################################################################

{
	# useテスト
	use_ok( 'JAWP', 'use JAWP' );

	# メソッド呼び出しテスト
	{
		foreach my $method ( 'Run', 'Usage', 'LintTitle', 'LintText', 'LintIndex',
			'LintRedirect', 'Statistic', 'StatisticReportSub1', 'StatisticReportSub2',
			'StatisticReportSub3', 'TitleList', 'LivingNoref', 'LongTermRequest', 'Person',
			'NoIndex', 'IndexStatistic', 'Aimai', 'ShortPage', 'LonelyPage' ) {
			ok( JAWP::App->can($method), "JAWP::App(メソッド呼び出し,$method)" );
		}
	}
}
