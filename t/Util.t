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
# JAWP::Utilクラス
################################################################################

{
	# useテスト
	use_ok( 'JAWP', 'use JAWP' );

	# メソッド呼び出しテスト
	{
		foreach my $method ( 'UnescapeHTML', 'DecodeURL', 'SortHash',
			'GetLinkwordList', 'GetTemplatewordList', 'GetExternallinkList',
			'GetHost', 'GetLinkType', 'GetHeadList', 'GetIDList', 'GetTalkTimestampList' ) {
			ok( JAWP::Util->can($method), "JAWP::Util(メソッド呼び出し,$method)" );
		}
	}

	# UnescapeHTMLテスト
	{
		is( JAWP::Util::UnescapeHTML( 'abcdef') , 'abcdef', 'JAWP::Util::UnescapeHTML(無変換,abcdef)' );
		is( JAWP::Util::UnescapeHTML( '&amp') , '&amp', 'JAWP::Util::UnescapeHTML(無変換,&amp)' );

		my( $key, $value );
		my $charref = GetCharacterReference();
		while( ( $key, $value ) = each( %$charref ) ) {
			is( JAWP::Util::UnescapeHTML( $key ), $value, "JAWP::Util::UnescapeHTML($key)" );
		}

		is( JAWP::Util::UnescapeHTML( '&#34;&#38;&#60;&#62;' ), '"&<>', 'JAWP::Util::UnescapeHTML(数値文字参照)' );
		is( JAWP::Util::UnescapeHTML( '&amp;lt;' ), '<', 'JAWP::Util::UnescapeHTML(二重エスケープ)' );
	}

	# DecodeURLテスト
	{
		is( JAWP::Util::DecodeURL( 'abcdef') , 'abcdef', 'JAWP::Util::DecodeURL(abcdef)' );
		is( JAWP::Util::DecodeURL( '%E7%89%B9%E5%88%A5:') , '特別:', 'JAWP::Util::DecodeURL(%E7%89%B9%E5%88%A5:)' );
	}

	# SortHashテスト
	{
		my %numhash = ( 'a'=>2, 'b'=>1, 'c'=>3 );
		my %strhash = ( 'a'=>'う', 'b'=>'あ', 'c'=>'い' );

		my $sorted = JAWP::Util::SortHash( \%numhash );
		is_deeply( $sorted, [ 'b', 'a', 'c' ], 'JAWP::Util::SortHash(配列要素,デフォルト(bynum,昇順))' );

		$sorted = JAWP::Util::SortHash( \%numhash, 1 );
		is_deeply( $sorted, [ 'b', 'a', 'c' ], 'JAWP::Util::SortHash(配列要素,デフォルト(bynum,昇順))' );

		$sorted = JAWP::Util::SortHash( \%numhash, 1, 1 );
		is_deeply( $sorted, [ 'b', 'a', 'c' ], 'JAWP::Util::SortHash(配列要素,デフォルト(bynum,昇順))' );

		$sorted = JAWP::Util::SortHash( \%numhash, 1, 0 );
		is_deeply( $sorted, [ 'c', 'a', 'b' ], 'JAWP::Util::SortHash(配列要素,デフォルト(bynum,降順))' );

		$sorted = JAWP::Util::SortHash( \%strhash, 0 );
		is_deeply( $sorted, [ 'b', 'c', 'a' ], 'JAWP::Util::SortHash(配列要素,デフォルト(bystr,昇順))' );

		$sorted = JAWP::Util::SortHash( \%strhash, 0, 1 );
		is_deeply( $sorted, [ 'b', 'c', 'a' ], 'JAWP::Util::SortHash(配列要素,デフォルト(bystr,昇順))' );

		$sorted = JAWP::Util::SortHash( \%strhash, 0, 0 );
		is_deeply( $sorted, [ 'a', 'c', 'b' ], 'JAWP::Util::SortHash(配列要素,デフォルト(bystr,降順))' );
	}

	# GetLinkwordListテスト
	{
		my $result_ref;

		foreach my $str ( '', 'あああ', '[あああ]', '[[あああ', '[[]]', '[[#abc]]' ) {
			$result_ref = JAWP::Util::GetLinkwordList( $str );
			is_deeply( $result_ref, [], "JAWP::Util::GetLinkwordList($str)" );
		}

		foreach my $str ( '[[あああ]]', '[[   あああ]]', '[[あああ   ]]', '[[   あああ   ]]') {
			$result_ref = JAWP::Util::GetLinkwordList( $str );
			is_deeply( $result_ref, [ 'あああ' ], "JAWP::Util::GetLinkwordList($str)" );
		}

		$result_ref = JAWP::Util::GetLinkwordList( '[[あ   ああ]]' );
		is_deeply( $result_ref, [ 'あ ああ' ], 'JAWP::Util::GetLinkwordList([[あ   ああ]])' );

		$result_ref = JAWP::Util::GetLinkwordList( 'あああ[[いいい]]ううう' );
		is_deeply( $result_ref, [ 'いいい' ], 'JAWP::Util::GetLinkwordList(あああ[[いいい]]ううう)' );

		$result_ref = JAWP::Util::GetLinkwordList( '[[あああ|いいい]]' );
		is_deeply( $result_ref, [ 'あああ' ], 'JAWP::Util::GetLinkwordList([[あああ|いいい]])' );

		$result_ref = JAWP::Util::GetLinkwordList( '[[あああ]]いいい[[ううう]]' );
		is_deeply( $result_ref, [ 'あああ', 'ううう' ], 'JAWP::Util::GetLinkwordList([[あああ]]いいい[[ううう]]' );

		$result_ref = JAWP::Util::GetLinkwordList( "[[あああ]]\nいいい\n[[ううう]]\n" );
		is_deeply( $result_ref, [ 'あああ', 'ううう' ], 'JAWP::Util::GetLinkwordList([[あああ]]\nいいい\n[[ううう]]\n)' );

		$result_ref = JAWP::Util::GetLinkwordList( '[[あああ#]]' );
		is_deeply( $result_ref, [ 'あああ' ], 'JAWP::Util::GetLinkwordList([[あああ#]],withouthead)' );

		$result_ref = JAWP::Util::GetLinkwordList( '[[あああ#いいい]]' );
		is_deeply( $result_ref, [ 'あああ' ], 'JAWP::Util::GetLinkwordList([[あああ#いいい]],withouthead)' );

		$result_ref = JAWP::Util::GetLinkwordList( '[[あああ#]]', 1 );
		is_deeply( $result_ref, [ 'あああ#' ], 'JAWP::Util::GetLinkwordList([[あああ#]],withhead)' );

		$result_ref = JAWP::Util::GetLinkwordList( '[[あああ#いいい]]', 1 );
		is_deeply( $result_ref, [ 'あああ#いいい' ], 'JAWP::Util::GetLinkwordList([[あああ#いいい]],withhead)' );

		$result_ref = JAWP::Util::GetLinkwordList( '[[あああ#.E5.8D.97.E8.9B.AE.E6.BC.AC.E3.81.91]]', 1 );
		is_deeply( $result_ref, [ 'あああ#南蛮漬け' ], 'JAWP::Util::GetLinkwordList([[あああ#.E5.8D.97.E8.9B.AE.E6.BC.AC.E3.81.91]],withhead)' );

		$result_ref = JAWP::Util::GetLinkwordList( '[[あああ#.E5.8D.97.E8.9B.AE.E6.BC.AC.E3.81.91]]', 1 );
		is_deeply( $result_ref, [ 'あああ#南蛮漬け' ], 'JAWP::Util::GetLinkwordList([[あああ#.E5.8D.97.E8.9B.AE.E6.BC.AC.E3.81.91]],withhead)' );
	}

	# GetTemplatewordListテスト
	{
		my $result_ref;

		foreach my $str ( '', 'あああ', '{あああ}', '{{あああ', '{{デフォルトソート:あああ}}', '{{DEFAULTSORT:あああ}}', '{{}}' ) {
			$result_ref = JAWP::Util::GetTemplatewordList( $str );
			is_deeply( $result_ref, [], "JAWP::Util::GetTemplatewordList($str)" );
		}

		$result_ref = JAWP::Util::GetTemplatewordList( '{{あああ}}' );
		is_deeply( $result_ref, [ 'あああ' ], 'JAWP::Util::GetTemplatewordList({{あああ}})' );

		$result_ref = JAWP::Util::GetTemplatewordList( 'あああ{{いいい}}ううう' );
		is_deeply( $result_ref, [ 'いいい' ], 'JAWP::Util::GetTemplatewordList(あああ{{いいい}}ううう)' );

		$result_ref = JAWP::Util::GetTemplatewordList( '{{あああ|いいい}}' );
		is_deeply( $result_ref, [ 'あああ' ], 'JAWP::Util::GetTemplatewordList({{あああ|いいい}})' );

		$result_ref = JAWP::Util::GetTemplatewordList( '{{あああ}}いいい{{ううう}}' );
		is_deeply( $result_ref, [ 'あああ', 'ううう' ], 'JAWP::Util::GetTemplatewordList({{あああ}}いいい{{ううう}})' );

		$result_ref = JAWP::Util::GetTemplatewordList( "{{あああ}}\nいいい\n{{ううう}}\n" );
		is_deeply( $result_ref, [ 'あああ', 'ううう' ], 'JAWP::Util::GetTemplatewordList({{あああ}}\nいいい\n{{ううう}}\n)' );
	}

	# GetExternallinkListテスト
	{
		my $result_ref;

		$result_ref = JAWP::Util::GetExternallinkList( '' );
		is_deeply( $result_ref, [], 'JAWP::Util::GetExternallinkList(空文字列)' );

		$result_ref = JAWP::Util::GetExternallinkList( 'あああ' );
		is_deeply( $result_ref, [], 'JAWP::Util::GetExternallinkList(あああ)' );

		$result_ref = JAWP::Util::GetExternallinkList( 'あああ http://www.yahoo.co.jp いいい' );
		is_deeply( $result_ref, [ 'http://www.yahoo.co.jp' ], 'JAWP::Util::GetExternallinkList(あああ http://www.yahoo.co.jp いいい)' );

		$result_ref = JAWP::Util::GetExternallinkList( 'あああ http://www.yahoo.co.jp/aaa/bbb http://www.google.co.jp/ccc/ddd いいい' );
		is_deeply( $result_ref, [ 'http://www.yahoo.co.jp/aaa/bbb', 'http://www.google.co.jp/ccc/ddd' ], 'JAWP::Util::GetExternallinkList(あああ http://www.yahoo.co.jp/aaa/bbb http://www.google.co.jp/ccc/ddd いいい)' );
	}

	# GetHostテスト
	{
		my $host;

		foreach my $url ( 'http://www.yahoo.co.jp', 'http://www.yahoo.co.jp/', 'http://www.yahoo.co.jp/aaa/bbb', 'https://www.yahoo.co.jp', 'https://www.yahoo.co.jp/', 'https://www.yahoo.co.jp/aaa/bbb' ) {
			$host = JAWP::Util::GetHost( $url );
			is( $host, 'www.yahoo.co.jp', "JAWP::Util::GetHost($url)" );
		}
	}

	# GetLinkTypeテスト
	{
		my( $linktype, $word );
		my $titlelist = new JAWP::TitleList;

		$titlelist->{'標準'} = { '標準記事'=>1, 'Abc_article'=>1, '曖昧記事'=>1, 'Abc_aimai'=>1 };
		$titlelist->{'標準_曖昧'} = { '曖昧記事'=>1, 'Abc_aimai'=>1 };
		$titlelist->{'標準_リダイレクト'} = { 'リダイレクト記事'=>1, 'Abc_redirect'=>1 };
		$titlelist->{'ファイル'} = { 'ファイル名'=>1, 'Abc_file'=>1 };
		$titlelist->{'Template'} = { 'テンプレート名'=>1, 'Abc_template'=>1 };
		$titlelist->{'Category'} = { 'カテゴリ名'=>1, 'Abc_category'=>1 };

		( $linktype, $word ) = JAWP::Util::GetLinkType( '', $titlelist );
		is( $linktype , 'redlink', 'JAWP::Util::GetLinkType(空文字列:linktype)' );
		is( $word, '', 'JAWP::Util::GetLinkType(空文字列:word)' );

		( $linktype, $word ) = JAWP::Util::GetLinkType( '標準記事', $titlelist );
		is( $linktype , '標準', 'JAWP::Util::GetLinkType(標準記事:linktype)' );
		is( $word, '標準記事', 'JAWP::Util::GetLinkType(標準記事:word)' );

		( $linktype, $word ) = JAWP::Util::GetLinkType( 'abc_article', $titlelist );
		is( $linktype , '標準', 'JAWP::Util::GetLinkType(abc_article:linktype)' );
		is( $word, 'Abc_article', 'JAWP::Util::GetLinkType(abc_article:word)' );

		( $linktype, $word ) = JAWP::Util::GetLinkType( '曖昧記事', $titlelist );
		is( $linktype , 'aimai', 'JAWP::Util::GetLinkType(曖昧記事:linktype)' );
		is( $word, '曖昧記事', 'JAWP::Util::GetLinkType(曖昧記事:word)' );

		( $linktype, $word ) = JAWP::Util::GetLinkType( 'abc_aimai', $titlelist );
		is( $linktype , 'aimai', 'JAWP::Util::GetLinkType(abc_aimai:linktype)' );
		is( $word, 'Abc_aimai', 'JAWP::Util::GetLinkType(abc_aimai:word)' );

		( $linktype, $word ) = JAWP::Util::GetLinkType( 'リダイレクト記事', $titlelist );
		is( $linktype , 'redirect', 'JAWP::Util::GetLinkType(リダイレクト記事:linktype)' );
		is( $word, 'リダイレクト記事', 'JAWP::Util::GetLinkType(リダイレクト記事:word)' );

		( $linktype, $word ) = JAWP::Util::GetLinkType( 'abc_redirect', $titlelist );
		is( $linktype , 'redirect', 'JAWP::Util::GetLinkType(abc_redirect:linktype)' );
		is( $word, 'Abc_redirect', 'JAWP::Util::GetLinkType(abc_redirect:word)' );

		foreach my $type ( 'Category', 'カテゴリ' ) {
			( $linktype, $word ) = JAWP::Util::GetLinkType( "$type:カテゴリ名", $titlelist );
			is( $linktype , 'category', "JAWP::Util::GetLinkType(カテゴリ名,$type:linktype)" );
			is( $word, 'カテゴリ名', "JAWP::Util::GetLinkType(カテゴリ名,$type:word)" );

			( $linktype, $word ) = JAWP::Util::GetLinkType( "$type:abc_category", $titlelist );
			is( $linktype , 'category', "JAWP::Util::GetLinkType(abc_category,$type:linktype)" );
			is( $word, 'Abc_category', "JAWP::Util::GetLinkType(abc_category,$type:word)" );
		}

		foreach my $type ( 'ファイル', '画像', 'メディア', 'file', 'image', 'media' ) {
			( $linktype, $word ) = JAWP::Util::GetLinkType( "$type:ファイル名", $titlelist );
			is( $linktype , 'file', "JAWP::Util::GetLinkType(ファイル名,$type:linktype)" );
			is( $word, 'ファイル名', "JAWP::Util::GetLinkType(ファイル名,$type:word)" );

			( $linktype, $word ) = JAWP::Util::GetLinkType( "$type:abc_file", $titlelist );
			is( $linktype , 'file', "JAWP::Util::GetLinkType(abc_file,$type:linktype)" );
			is( $word, 'Abc_file', "JAWP::Util::GetLinkType(abc_file,$type:word)" );
		}

		foreach my $type ( 'Template', 'テンプレート' ) {
			( $linktype, $word ) = JAWP::Util::GetLinkType( "$type:テンプレート名", $titlelist );
			is( $linktype , 'template', "JAWP::Util::GetLinkType(テンプレート名,$type:linktype)" );
			is( $word, 'テンプレート名', "JAWP::Util::GetLinkType(テンプレート名,$type:word)" );

			( $linktype, $word ) = JAWP::Util::GetLinkType( "$type:abc_template", $titlelist );
			is( $linktype , 'template', "JAWP::Util::GetLinkType(abc_template,$type:linktype)" );
			is( $word, 'Abc_template', "JAWP::Util::GetLinkType(abc_template,$type:word)" );
		}

		( $linktype, $word ) = JAWP::Util::GetLinkType( '赤リンク記事', $titlelist );
		is( $linktype , 'redlink', 'JAWP::Util::GetLinkType(赤リンク記事:linktype)' );
		is( $word, '赤リンク記事', 'JAWP::Util::GetLinkType(赤リンク記事:word)' );

		foreach my $type (
			'Help', 'ヘルプ', 'MediaWiki', 'Portal', 'Wikipedia', 'プロジェクト', 'Project',
			'Special', '特別', '利用者', 'User', 'ノート', 'トーク', 'talk', '利用者‐会話', '利用者・トーク', 'User talk', 'Wikipedia‐ノート', 'Wikipedia・トーク', 'Wikipedia talk', 'ファイル‐ノート', 'ファイル・トーク', '画像‐ノート', 'File talk', 'Image Talk', 'MediaWiki‐ノート', 'MediaWiki・トーク', 'MediaWiki talk', 'Template‐ノート', 'Template talk', 'Help‐ノート', 'Help talk', 'Category‐ノート', 'Category talk', 'カテゴリ・トーク', 'Portal‐ノート', 'Portal・トーク', 'Portal talk', 'プロジェクト‐ノート', 'Project talk',
			'aa', 'ab', 'ace', 'af', 'ak', 'als', 'am', 'an', 'ang', 'ar', 'arc', 'arz', 'as', 'ast', 'av', 'ay', 'az', 'ba', 'bar', 'bat-smg', 'bcl', 'be', 'be-x-old', 'bg', 'bh', 'bi', 'bjn', 'bm', 'bn', 'bo', 'bpy', 'br', 'bs', 'bug', 'bxr', 'ca', 'cbk-zam', 'cdo', 'ce', 'ceb', 'ch', 'cho', 'chr', 'chy', 'ckb', 'co', 'cr', 'crh', 'cs', 'csb', 'cu', 'cv', 'cy', 'da', 'de', 'diq', 'dsb', 'dv', 'dz', 'ee', 'el', 'eml', 'en', 'eo', 'es', 'et', 'eu', 'ext', 'fa', 'ff', 'fi', 'fiu-vro', 'fj', 'fo', 'fr', 'frp', 'frr', 'fur', 'fy', 'ga', 'gag', 'gan', 'gd', 'gl', 'glk', 'gn', 'got', 'gu', 'gv', 'ha', 'hak', 'haw', 'he', 'hi', 'hif', 'ho', 'hr', 'hsb', 'ht', 'hu', 'hy', 'hz', 'ia', 'id', 'ie', 'ig', 'ii', 'ik', 'ilo', 'io', 'is', 'it', 'iu', 'ja', 'jbo', 'jp', 'jv', 'ka', 'kaa', 'kab', 'kbd', 'kg', 'ki', 'kj', 'kk', 'kl', 'km', 'kn', 'ko', 'koi', 'kr', 'krc', 'ks', 'ksh', 'ku', 'kv', 'kw', 'ky', 'la', 'lad', 'lb', 'lbe', 'lg', 'li', 'lij', 'lmo', 'ln', 'lo', 'lt', 'ltg', 'lv', 'map-bms', 'mdf', 'mg', 'mhr', 'mi', 'mk', 'ml', 'mn', 'mo', 'mr', 'mrj', 'ms', 'mt', 'mwl', 'my', 'myv', 'mzn', 'na', 'nah', 'nan', 'nap', 'nb', 'nds', 'nds-nl', 'ne', 'new', 'ng', 'nl', 'nn', 'no', 'nov', 'nrm', 'nso', 'nv', 'ny', 'oc', 'om', 'or', 'os', 'pa', 'pag', 'pam', 'pap', 'pcd', 'pdc', 'pfl', 'pi', 'pih', 'pl', 'pms', 'pnb', 'pnt', 'ps', 'pt', 'qu', 'rm', 'rmy', 'rn', 'ro', 'roa-rup', 'roa-tara', 'ru', 'rue', 'rw', 'sa', 'sah', 'sc', 'scn', 'sco', 'sd', 'se', 'sg', 'sh', 'si', 'simple', 'sk', 'sl', 'sm', 'sn', 'so', 'sq', 'sr', 'srn', 'ss', 'st', 'stq', 'su', 'sv', 'sw', 'szl', 'ta', 'te', 'tet', 'tg', 'th', 'ti', 'tk', 'tl', 'tn', 'to', 'tpi', 'tr', 'ts', 'tt', 'tum', 'tw', 'ty', 'udm', 'ug', 'uk', 'ur', 'uz', 've', 'vec', 'vi', 'vls', 'vo', 'wa', 'war', 'wo', 'wuu', 'xal', 'xh', 'xmf', 'yi', 'yo', 'za', 'zea', 'zh', 'zh-cfr', 'zh-classical', 'zh-cn', 'zh-min-nan', 'zh-tw', 'zh-yue', 'zu',
			'acronym', 'appropedia', 'arxiv', 'b', 'betawiki', 'betawikiversity', 'botwiki', 'bugzilla', 'centralwikia', 'choralwiki', 'citizendium', 'commons', 'comune', 'cz', 'dictionary', 'doi', 'evowiki', 'finalfantasy', 'foundation', 'google', 'imdbname', 'imdbtitle', 'incubator', 'irc', 'ircrc', 'iso639-3', 'jameshoward', 'luxo', 'm', 'mail', 'mailarchive', 'marveldatabase', 'meatball', 'mediazilla', 'memoryalpha', 'minnan', 'mozillawiki', 'mw', 'n', 'oeis', 'oldwikisource', 'orthodoxwiki', 'otrswiki', 'outreach', 'planetmath', 'q', 'rev', 's', 'scores', 'sep11', 'smikipedia', 'species', 'strategy', 'strategywiki', 'sulutil', 'svn', 'tenwiki', 'testwiki', 'tools', 'translatewiki', 'tswiki', 'usability', 'v', 'w', 'wiki', 'wikia', 'wikiasite', 'wikibooks', 'wikicities', 'wikifur', 'wikilivres', 'wikimedia', 'wikinews', 'wikinvest', 'wikiquote', 'wikisource', 'wikispecies', 'wikispot', 'wikitech', 'wikitravel', 'wikiversity', 'wikiwikiweb', 'wikt', 'wiktionary', 'wipipedia', 'wm2005', 'wm2006', 'wm2007', 'wm2008', 'wm2009', 'wm2010', 'wm2011', 'wm2012', 'wmania', 'wmf', 'wookieepedia' ) {
			( $linktype, $word ) = JAWP::Util::GetLinkType( "$type:記事名", $titlelist );
			is( $linktype , 'none', "JAWP::Util::GetLinkType(記事名,$type:linktype)" );
			is( $word, "$type:記事名", "JAWP::Util::GetLinkType(記事名,$type:word)" );
		}

		( $linktype, $word ) = JAWP::Util::GetLinkType( 'http://記事名', $titlelist );
		is( $linktype , 'none', "JAWP::Util::GetLinkType('http://記事名':linktype)" );
		is( $word, 'http://記事名', "JAWP::Util::GetLinkType('http://記事名':word)" );

		( $linktype, $word ) = JAWP::Util::GetLinkType( '/', $titlelist );
		is( $linktype , 'none', "JAWP::Util::GetLinkType('/':linktype)" );
		is( $word, '/', "JAWP::Util::GetLinkType('/':word)" );

		( $linktype, $word ) = JAWP::Util::GetLinkType( '../', $titlelist );
		is( $linktype , 'none', "JAWP::Util::GetLinkType('../':linktype)" );
		is( $word, '../', "JAWP::Util::GetLinkType('../':word)" );

		( $linktype, $word ) = JAWP::Util::GetLinkType( '#name', $titlelist );
		is( $linktype , 'none', "JAWP::Util::GetLinkType('#name':linktype)" );
		is( $word, '#name', "JAWP::Util::GetLinkType('#name':word)" );

		( $linktype, $word ) = JAWP::Util::GetLinkType( ':es:test', $titlelist );
		is( $linktype , 'none', "JAWP::Util::GetLinkType(':es:test':linktype)" );
		is( $word, ':es:test', "JAWP::Util::GetLinkType(':es:test':word)" );
	}

	# GetHeadListテスト
	{
		my $result_ref;

		$result_ref = JAWP::Util::GetHeadList( '' );
		is_deeply( $result_ref, [], 'JAWP::Util::GetHeadList(空文字列)' );

		$result_ref = JAWP::Util::GetHeadList( 'あああ' );
		is_deeply( $result_ref, [], 'JAWP::Util::GetHeadList(あああ)' );

		$result_ref = JAWP::Util::GetHeadList( '= =' );
		is_deeply( $result_ref, [], 'JAWP::Util::GetHeadList(= =)' );

		$result_ref = JAWP::Util::GetHeadList( "あああ\n==見出し==\nいいい" );
		is_deeply( $result_ref, [ '見出し' ], 'JAWP::Util::GetHeadList(あああ\n==見出し==\nいいい)' );

		$result_ref = JAWP::Util::GetHeadList( "あああ\n==見出し==\n== 見出し2 ==\nいいい" );
		is_deeply( $result_ref, [ '見出し', '見出し2' ], 'JAWP::Util::GetHeadList(あああ\n==見出し==\n== 見出し2 ==\nいいい)' );

		$result_ref = JAWP::Util::GetHeadList( "あああ\n==見 出 し==\nいいい" );
		is_deeply( $result_ref, [ '見 出 し' ], 'JAWP::Util::GetHeadList(あああ\n==見 出 し==\nいいい)' );

		$result_ref = JAWP::Util::GetHeadList( "あああ\n==見 出 し== \nいいい" );
		is_deeply( $result_ref, [ '見 出 し' ], 'JAWP::Util::GetHeadList(あああ\n==見 出 し== \nいいい)' );

		$result_ref = JAWP::Util::GetHeadList( "あああ\n ==見 出 し==\nいいい" );
		is_deeply( $result_ref, [], 'JAWP::Util::GetHeadList(あああ\n ==見 出 し==a\nいいい)' );

		$result_ref = JAWP::Util::GetHeadList( "あああ\n==見 出 し==a\nいいい" );
		is_deeply( $result_ref, [], 'JAWP::Util::GetHeadList(あああ\n==見 出 し==a\nいいい)' );
	}

	# GetIDListテスト
	{
		my $result_ref;

		$result_ref = JAWP::Util::GetIDList( '' );
		is_deeply( $result_ref, [], 'JAWP::Util::GetIDList(空文字列)' );

		$result_ref = JAWP::Util::GetIDList( 'あああ' );
		is_deeply( $result_ref, [], 'JAWP::Util::GetIDList(あああ)' );

		$result_ref = JAWP::Util::GetIDList( '<span id="aaa">' );
		is_deeply( $result_ref, [ 'aaa' ], 'JAWP::Util::GetIDList(<span id="aaa">)' );

		$result_ref = JAWP::Util::GetIDList( '<span id=" aaa ">' );
		is_deeply( $result_ref, [ 'aaa' ], 'JAWP::Util::GetIDList(<span id=" aaa ">)' );

		$result_ref = JAWP::Util::GetIDList( '<span id="aaa"><span id="bbb">' );
		is_deeply( $result_ref, [ 'aaa', 'bbb' ], 'JAWP::Util::GetIDList(<span id="aaa"><span id="bbb">)' );
	}

	# GetTalkTimestampListテスト
	{
		my $result_ref;

		$result_ref = JAWP::Util::GetTalkTimestampList( '' );
		is_deeply( $result_ref, [], 'JAWP::Util::GetTalkTimestampList(空文字列)' );

		$result_ref = JAWP::Util::GetTalkTimestampList( 'あああ' );
		is_deeply( $result_ref, [], 'JAWP::Util::GetTalkTimestampList(あああ)' );

		$result_ref = JAWP::Util::GetTalkTimestampList( '2011年8月2日 (火) 14:14 (UTC)' );
		is_deeply( $result_ref, [ '2011-08-02T14:14:00Z' ], 'JAWP::Util::GetTalkTimestampList(2011年8月2日 (火) 14:14 (UTC))' );

		$result_ref = JAWP::Util::GetTalkTimestampList( '２０１１年８月２日 (火) １４:１４ (UTC)' );
		is_deeply( $result_ref, [], 'JAWP::Util::GetTalkTimestampList(２０１１年８月２日 (火) １４:１４ (UTC))' );

		$result_ref = JAWP::Util::GetTalkTimestampList( '2011年8月2日 (火) 14:14 (UTC)あああ2011年8月7日 (日) 14:55 (UTC)' );
		is_deeply( $result_ref, [ '2011-08-02T14:14:00Z', '2011-08-07T14:55:00Z' ], 'JAWP::Util::GetTalkTimestampList(2011年8月2日 (火) 14:14 (UTC)あああ2011年8月7日 (日) 14:55 (UTC))' );
	}

	# GetBytesテスト
	{
		my $bytes;

		$bytes = JAWP::Util::GetBytes( '' );
		is( $bytes, 0, "JAWP::Util::GetBytes( '' )" );

		$bytes = JAWP::Util::GetBytes( 'abc' );
		is( $bytes, 3, "JAWP::Util::GetBytes( 'abc' )" );

		$bytes = JAWP::Util::GetBytes( 'あいうえお' );
		is( $bytes, 15, "JAWP::Util::GetBytes( 'あいうえお' )" );
	}
}


# 文字実体参照取得
sub GetCharacterReference {
	my %CharacterReference = (
		# マークアップ
		'&quot;'=>'"', '&lt;'=>'<', '&gt;'=>'>',
		# ISO-8859-1 ラテン
		'&nbsp;'=>' ', '&iexcl;'=>'¡', '&cent;'=>'￠', '&pound;'=>'￡', '&curren;'=>'¤', '&yen;'=>'\\', '&brvbar;'=>'￤', '&sect;'=>'§', '&uml;'=>'¨', '&copy;'=>'©', '&ordf;'=>'ª', '&laquo;'=>'«', '&not;'=>'￢', '&shy;'=>'­', '&reg;'=>'®', '&macr;'=>'¯', '&deg;'=>'°', '&plusmn;'=>'±', '&sup2;'=>'²', '&sup3;'=>'³', '&acute;'=>'´', '&micro;'=>'µ', '&para;'=>'¶', '&middot;'=>'·', '&cedil;'=>'¸', '&sup1;'=>'¹', '&ordm;'=>'º', '&raquo;'=>'»', '&frac14;'=>'¼', '&frac12;'=>'½', '&frac34;'=>'¾', '&iquest;'=>'¿', '&Agrave;'=>'À', '&Aacute;'=>'Á', '&Acirc;'=>'Â', '&Atilde;'=>'Ã', '&Auml;'=>'Ä', '&Aring;'=>'Å', '&AElig;'=>'Æ', '&Ccedil;'=>'Ç', '&Egrave;'=>'È', '&Eacute;'=>'É', '&Ecirc;'=>'Ê', '&Euml;'=>'Ë', '&Igrave;'=>'Ì', '&Iacute;'=>'Í', '&Icirc;'=>'Î', '&Iuml;'=>'Ï', '&ETH;'=>'Ð', '&Ntilde;'=>'Ñ', '&Ograve;'=>'Ò', '&Oacute;'=>'Ó', '&Ocirc;'=>'Ô', '&Otilde;'=>'Õ', '&Ouml;'=>'Ö', '&times;'=>'×', '&Oslash;'=>'Ø', '&Ugrave;'=>'Ù', '&Uacute;'=>'Ú', '&Ucirc;'=>'Û', '&Uuml;'=>'Ü', '&Yacute;'=>'Ý', '&THORN;'=>'Þ', '&szlig;'=>'ß', '&agrave;'=>'à', '&aacute;'=>'á', '&acirc;'=>'â', '&atilde;'=>'ã', '&auml;'=>'ä', '&aring;'=>'å', '&aelig;'=>'æ', '&ccedil;'=>'ç', '&egrave;'=>'è', '&eacute;'=>'é', '&ecirc;'=>'ê', '&euml;'=>'ë', '&igrave;'=>'ì', '&iacute;'=>'í', '&icirc;'=>'î', '&iuml;'=>'ï', '&eth;'=>'ð', '&ntilde;'=>'ñ', '&ograve;'=>'ò', '&oacute;'=>'ó', '&ocirc;'=>'ô', '&otilde;'=>'õ', '&ouml;'=>'ö', '&divide;'=>'÷', '&oslash;'=>'ø', '&ugrave;'=>'ù', '&uacute;'=>'ú', '&ucirc;'=>'û', '&uuml;'=>'ü', '&yacute;'=>'ý', '&thorn;'=>'þ', '&yuml;'=>'ÿ',
		# ラテン拡張
		'&OElig;'=>'Œ', '&oelig;'=>'œ', '&Scaron;'=>'Š', '&scaron;'=>'š', '&Yuml;'=>'Ÿ', '&circ;'=>'ˆ', '&tilde;'=>'˜', '&fnof;'=>'ƒ',
		# ギリシア文字
		'&Alpha;'=>'Α', '&Beta;'=>'Β', '&Gamma;'=>'Γ', '&Delta;'=>'Δ', '&Epsilon;'=>'Ε', '&Zeta;'=>'Ζ', '&Eta;'=>'Η', '&Theta;'=>'Θ', '&Iota;'=>'Ι', '&Kappa;'=>'Κ', '&Lambda;'=>'Λ', '&Mu;'=>'Μ', '&Nu;'=>'Ν', '&Xi;'=>'Ξ', '&Omicron;'=>'Ο', '&Pi;'=>'Π', '&Rho;'=>'Ρ', '&Sigma;'=>'Σ', '&Tau;'=>'Τ', '&Upsilon;'=>'Υ', '&Phi;'=>'Φ', '&Chi;'=>'Χ', '&Psi;'=>'Ψ', '&Omega;'=>'Ω', '&alpha;'=>'α', '&beta;'=>'β', '&gamma;'=>'γ', '&delta;'=>'δ', '&epsilon;'=>'ε', '&zeta;'=>'ζ', '&eta;'=>'η', '&theta;'=>'θ', '&iota;'=>'ι', '&kappa;'=>'κ', '&lambda;'=>'λ', '&mu;'=>'μ', '&nu;'=>'ν', '&xi;'=>'ξ', '&omicron;'=>'ο', '&pi;'=>'π', '&rho;'=>'ρ', '&sigmaf;'=>'ς', '&sigma;'=>'σ', '&tau;'=>'τ', '&upsilon;'=>'υ', '&phi;'=>'φ', '&chi;'=>'χ', '&psi;'=>'ψ', '&omega;'=>'ω', '&thetasym;'=>'ϑ', '&upsih;'=>'ϒ', '&piv;'=>'ϖ',
		# 一般記号と国際化用の制御文字
		'&ensp;'=>' ', '&emsp;'=>' ', '&thinsp;'=>' ', '&zwnj;'=>'‌', '&zwj;'=>'‍', '&lrm;'=>'‎', '&rlm;'=>'‏', '&ndash;'=>'–', '&mdash;'=>'―', '&lsquo;'=>'‘', '&rsquo;'=>'’', '&sbquo;'=>'‚', '&ldquo;'=>'“', '&rdquo;'=>'”', '&bdquo;'=>'„', '&dagger;'=>'†', '&Dagger;'=>'‡', '&bull;'=>'•', '&hellip;'=>'…', '&permil;'=>'‰', '&prime;'=>'′', '&Prime;'=>'″', '&lsaquo;'=>'‹', '&rsaquo;'=>'›', '&oline;'=>'~', '&frasl;'=>'⁄', '&euro;'=>'€', '&image;'=>'ℑ', '&ewierp;'=>'℘', '&real;'=>'ℜ', '&trade;'=>'™', '&alefsym;'=>'ℵ', '&larr;'=>'←', '&uarr;'=>'↑', '&rarr;'=>'→', '&darr;'=>'↓', '&harr;'=>'↔', '&crarr;'=>'↵', '&lArr;'=>'⇐', '&uArr;'=>'⇑', '&rArr;'=>'⇒', '&dArr;'=>'⇓', '&hArr;'=>'⇔',
		# 数学記号
		'&forall;'=>'∀', '&part;'=>'∂', '&exist;'=>'∃', '&empty;'=>'∅', '&nabla;'=>'∇', '&isin;'=>'∈', '&notin;'=>'∉', '&ni;'=>'∋', '&prod;'=>'∏', '&sum;'=>'∑', '&minus;'=>'－', '&lowast;'=>'∗', '&radic;'=>'√', '&prop;'=>'∝', '&infin;'=>'∞', '&ang;'=>'∠', '&and;'=>'∧', '&or;'=>'∨', '&cap;'=>'∩', '&cup;'=>'∪', '&int;'=>'∫', '&there4;'=>'∴', '&sim;'=>'∼', '&cong;'=>'≅', '&asymp;'=>'≈', '&ne;'=>'≠', '&equiv;'=>'≡', '&le;'=>'≤', '&ge;'=>'≥', '&sub;'=>'⊂', '&sup;'=>'⊃', '&nsub;'=>'⊄', '&sube;'=>'⊆', '&supe;'=>'⊇', '&oplus;'=>'⊕', '&otimes;'=>'⊗', '&perp;'=>'⊥', '&sdot;'=>'⋅',
		# シンボル
		'&lceil;'=>'⌈', '&rceil;'=>'⌉', '&lfloor;'=>'⌊', '&rfloor;'=>'⌋', '&lang;'=>'〈', '&rang;'=>'〉', '&loz;'=>'◊', '&spades;'=>'♠', '&clubs;'=>'♣', '&hearts;'=>'♥', '&diams;'=>'♦' );

	return( \%CharacterReference );
}
