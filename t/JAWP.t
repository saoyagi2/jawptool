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


################################################################################
# JAWP
################################################################################

{
	# useテスト
	use_ok( 'JAWP', 'use JAWP' );

	done_testing;
}
