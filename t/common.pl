use strict;
use warnings;

use utf8;
use Encode;
use open IO  => ':utf8';

use File::Temp;

my $fnametemp = 'jawptoolXXXX';


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

1;
