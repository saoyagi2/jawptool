#!/usr/bin/perl

use strict;
use warnings;

use utf8;

use Encode;
use open IO  => ":utf8";

{
	my( $ifh, $ofh, $line, $out, $closer );

	if( @ARGV < 2 ) {
		usage();
	}

	open $ifh, '<', $ARGV[0] or die;
	open $ofh, '>', $ARGV[1] or die;

	print $ofh <<"HTMLHEAD";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="ja">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title>jawptool report($ARGV[0])</title>
</head>
<body>
HTMLHEAD

	$closer = '';
	while( $line = <$ifh> ) {
		chomp $line;

		$out = '';
		if( $line =~ /^(=+)([^=]+)=+ *$/ ) {
			$out .= "$closer\n";
			$out .= sprintf( "<h%d>%s</h%d>", length( $1 ), $2, length( $1 ) );
			$closer = '';
		}
		elsif( $line =~ /^(\*+)(.*)$/ ) {
			if( $closer ne '</ul>' x length( $1 ) ) {
				$out .= "$closer\n";
				$out .= '<ul>' x length( $1 ) . "\n";
				$closer = '</ul>' x length( $1 );
			}
			$out .= "<li>$2</li>";
		}
		elsif( $line =~ /^(#+)(.*)$/ ) {
			if( $closer ne '</ol>' x length( $1 ) ) {
				$out .= "$closer\n";
				$out .= '<ol>' x length( $1 ) . "\n";
				$closer = '</ol>' x length( $1 );
			}
			$out .= "<li>$2</li>";
		}
		elsif( $line =~ /^;(.*)$/ ) {
			if( $closer ne '</dl>' ) {
				$out .= "$closer\n";
				$out .= "<dl>\n";
				$closer = '</dl>';
			}
			$out .= "<dt>$1</dt>";
		}
		elsif( $line =~ /^:(.*)$/ ) {
			if( $closer ne '</dl>' ) {
				$out .= "$closer\n";
				$out .= "<dl>\n";
				$closer = '</dl>';
			}
			$out .= "<dd>$1</dd>";
		}
		elsif( $line eq '<pre>' ) {
			if( $closer ) {
				print $ofh "$closer\n";
				$closer = '';
			}
			print $ofh "$line\n";
			while( $line = <$ifh> ) {
				chomp $line;
				print $ofh "$line\n";
				last if( $line eq '</pre>' );
			}
		}
		elsif( $line eq '----' ) {
			if( $closer ) {
				print $ofh "$closer\n";
				$closer = '';
			}
			print $ofh "<hr>\n";
		}
		elsif( $line eq '' ) {
			$out = $closer;
			$closer = '';
		}
		else {
			if( $closer ne '</p>' ) {
				$out .= "$closer\n";
				$out .= "<p>\n";
				$closer = '</p>';
			}
			$out .= $line;
		}

		$out =~ s/[^\[](s?https?:\/\/[-_.!~*'()a-zA-Z0-9;\/?:\@&=+\$,%#]+)/<a href="$1">$1<\/a>/g;
		$out =~ s/\[\[(.*?)\]\]/"<a href=\"http:\/\/ja.wikipedia.org\/wiki\/" . EncodeURL($1) . "\">$1<\/a>"/eg;
		$out =~ s/\[(.*?) (.*?)\]/<a href="$1">$2<\/a>/g;
		$out =~ s/\[(.*?)\]/<a href="$1">$1<\/a>/g;
		$out =~ s/'''(.*?)'''/<b>$1<\/b>/g;
		print $ofh "$out\n";
	}
	if( $closer ) {
		print $ofh "$closer\n";
	}

	print $ofh <<'HTMLFOOT';
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
