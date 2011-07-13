#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use Encode;
use open IO  => ":utf8";

{
	my( $ifh, $ofh, $line, $out, $li );

	if( @ARGV < 2 ) {
		usage();
	}

	open $ifh, '<', $ARGV[0] or die;
	open $ofh, '>', $ARGV[1] or die;

	print $ofh <<"HTMLHEAD";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<html lang="ja">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<meta http-equiv="Content-Style-Type" content="text/css">
<meta http-equiv="Content-Script-Type" content="text/javascript">
<link rel="stylesheet" href="jawptool.css" type="text/css" title="base">
<title>jawptool report($ARGV[0])</title>
</head>
<body>
HTMLHEAD

	$li = 0;
	while( $line = <$ifh> ) {
		chomp $line;

		$out = '';
		if( $line =~ /^=([^=]+)=$/ ) {
			$out = "<h1>$1</h1>";
		}
		elsif( $line =~ /^==([^=]+)==$/ ) {
			$out = "<h2>$1</h2>";
		}
		elsif( $line =~ /^\*(.*)$/ ) {
			if( !$li ) {
				$out = '<ul>';
				$li = 1;
			}
			$out .= "<li>$1</li>";
		}
		elsif( $line =~ /^$/ ) {
			if( $li ) {
				$out = '</ul>';
				$li = 0;
			}
		}
		else {
			$out = $line;
		}

		$out =~ s/\[\[(.*?)\]\]/"<a href=\"http:\/\/ja.wikipedia.org\/wiki\/" . EncodeURL($1) . "\">$1<\/a>"/eg;
		print $ofh "$out\n";
	}
	if( $li ) {
		$out = '</ul>';
		$li = 0;
	}

	print $ofh <<'HTMLFOOT';
<script type="text/javascript">
var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
</script>
<script type="text/javascript">
try {
var pageTracker = _gat._getTracker("UA-7675398-5");
pageTracker._trackPageview();
} catch(err) {}</script>
</body>
</html>
HTMLFOOT

	close $ifh;
	close $ofh;
}

sub usage {
	print <<'STR';
report2html reportfile htmlfile
STR
	exit;
}

sub EncodeURL {
	my $str = shift;

	$str = Encode::encode( 'utf-8', $str );
	$str =~ s/([^\w ])/'%'.unpack('H2', $1)/eg;
	$str =~ tr/ /_/;
	$str = Encode::decode( 'utf-8', $str );

	return $str;
}
