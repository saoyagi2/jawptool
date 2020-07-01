#!/usr/bin/env perl

use strict;
use warnings;

use utf8;

use lib ".";
use JAWP;

JAWP::CGIApp->Run( 'linttext' );
