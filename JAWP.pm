use 5.8.0;
use strict;
use warnings;

use utf8;
use Encode;
use open IO  => ":utf8";

use Data::Dumper;

our $VERSION = '0.13';


################################################################################
# JAWP::Articleクラス
################################################################################

package JAWP::Article;


# コンストラクタ
sub new {
	my $class = shift;
	my $self;

	$self = bless( { 'title'=>'', 'timestamp'=>'', 'text'=>'' }, $class );

	return $self;
}


# タイトル代入
# param $title
sub SetTitle {
	my( $self, $title ) = @_;

	$title =~ s/_/ /g;
	$self->{'title'} = JAWP::Util::UnescapeHTML( $title );
}


# タイムスタンプ代入
# param $timestamp
sub SetTimestamp {
	my( $self, $timestamp ) = @_;

	$self->{'timestamp'} = $timestamp;
}


# テキスト代入
# param $text
sub SetText {
	my( $self, $text ) = @_;

	$text = JAWP::Util::UnescapeHTML( $text );
	while( $text =~ /<!--(.*?)-->/s ) {
		my $tmp = $1;
		$tmp =~ s/[^\n]//g;
		$text =~ s/<!--(.*?)-->/$tmp/s;
	}

	$self->{'text'} = $text;
}


# リダイレクト判別
# return 真偽値
sub IsRedirect {
	my $self = shift;

	return $self->{'text'} =~ /^(#|＃)(REDIRECT|転送)/i;
}


# 曖昧さ回避判別
# return 真偽値
sub IsAimai {
	my $self = shift;

	return $self->{'text'} =~ /\{\{(aimai|Aimai|人名の曖昧さ回避|地名の曖昧さ回避|山の曖昧さ回避)/;
}


# 存命人物記事判別
# param $article 記事データ
# return 真偽値
sub IsLiving {
	my $self = shift;

	return $self->{'text'} =~ /\[\[Category:存命人物/i || $self->{'text'} =~ /\{\{(blp|Blp)/;
}


# 出典の無い記事判別
# param $article 記事データ
# return 真偽値
sub IsNoref {
	my $self = shift;

	return !( $self->{'text'} =~ /^==+.*(参考|文献|資料|書籍|図書|注|註|出典|典拠|出所|原典|ソース|情報源|引用元|論拠|参照).*==+$/m || $self->{'text'} =~ /<ref/ );
}


# 生没同日判別
# param $article 記事データ
# return 真偽値
sub IsSeibotsuDoujitsu {
	my $self = shift;

	if( $self->{'text'} =~ /\{\{死亡年月日と没年齢\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\}\}/ ) {
		if( $2 == $5 && $3 == $6 ) {
			return 1;
		}
	}

	return 0;
}


# 索引判別
# param $article 記事データ
# return 真偽値
sub IsIndex {
	my $self = shift;

	return index( $self->{'title'}, 'Wikipedia:索引' ) == 0;
}


# 名前空間取得
# return 名前空間
sub Namespace {
	my $self = shift;

	if( $self->{'title'} =~ /^(利用者|Wikipedia|ファイル|MediaWiki|Template|Help|Category|Portal|プロジェクト|ノート|利用者‐会話|Wikipedia‐ノート|ファイル‐ノート|MediaWiki‐ノート|Template‐ノート|Help‐ノート|Category‐ノート|Portal‐ノート|プロジェクト‐ノート):/ ) {
		return $1;
	}
	else {
		return '標準';
	}
}


# 経過時間取得
# param $time 時刻
# return 経過時間(YYYY-MM-DDTHH:MM:SSZ形式)
sub GetPassTime {
	my( $self, $time ) = @_;
	my $passtime;
	my @time;

	@time = gmtime( $time );
	if( $self->{'timestamp'} =~ /(\d{4})\-(\d{2})\-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z/ ) {
		$time[0] = $time[0] - $6;
		if( $time[0] < 0 ) {
			$time[0] += 60;
			$time[1]--;
		}
		$time[1] = $time[1] - $5;
		if( $time[1] < 0 ) {
			$time[1] += 60;
			$time[2]--;
		}
		$time[2] = $time[2] - $4;
		if( $time[2] < 0 ) {
			$time[2] += 60;
			$time[3]--;
		}
		$time[3] = $time[3] - $3;
		if( $time[3] < 0 ) {
			$time[3] += 30;
			$time[4]--;
		}
		$time[4] = $time[4] + 1 - $2;
		if( $time[4] < 0 ) {
			$time[4] += 12;
			$time[5]--;
		}
		$time[5] = $time[5] + 1900 - $1;

		if( $time[5] >= 0 ) {
			$passtime = sprintf( "%04d-%02d-%02dT%02d:%02d:%02dZ", $time[5], $time[4], $time[3], $time[2], $time[1], $time[0] );
		}
		else {
			$passtime = '0000-00-00T00:00:00Z';
		}
	}
	else {
		$passtime = '0000-00-00T00:00:00Z';
	}

	return $passtime;
}


# タイトル文法チェック
# param $article 記事データ
# param $titlelist タイトルリスト
# return $datalist_ref 結果配列へのリファレンス
sub LintTitle {
	my $self = shift;
	my( @result, $n, $c, $code, $str );

	if( $self->Namespace ne '標準' ) {
		return \@result;
	}

	if( !( $self->IsRedirect ) ) {
		if( $self->{'title'} =~ /（[^（]+）$/ ) {
			push @result, '曖昧さ回避の記事であればカッコは半角でないといけません';
		}
		if( $self->{'title'} =~ /[^ ]\(([^\(]+)\)$/ || $self->{'title'} =~ /  \(([^\(]+)\)$/ ) {
			if( !( $1 =~ /^[IVX,]+$/ ) ) {
				push @result, '曖昧さ回避の記事であればカッコの前のスペースはひとつでないといけません';
			}
		}
		if( $self->{'title'} =~ /^(株式会社|有限会社|合名会社|合資会社|合同会社)/ || $self->{'title'} =~ /(株式会社|有限会社|合名会社|合資会社|合同会社)$/ ) {
			push @result, '会社の記事であれば法的地位を示す語句を含むことは推奨されません';
		}
		if( $self->{'title'} =~ /[，．！？＆＠]/ ) {
			push @result, '全角記号の使用は推奨されません';
		}
		if( $self->{'title'} =~ /[Ａ-Ｚａ-ｚ０-９]/ ) {
			push @result, '全角英数字の使用は推奨されません';
		}
		if( $self->{'title'} =~ /[ｱ-ﾝﾞﾟｧ-ｫｬ-ｮｰ｡｢｣､]/ ) {
			push @result, '半角カタカナの使用は推奨されません';
		}
		if( $self->{'title'} =~ /[ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩ]/ ) {
			push @result, 'ローマ数字はアルファベットを組み合わせましょう';
		}
		if( $self->{'title'} =~ /[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳]/ ) {
			push @result, '丸付き数字の使用は推奨されません';
		}

		for( $n = 0; $n < length( $self->{'title'} ); $n++ ) {
			$c = substr( $self->{'title'}, $n, 1 );
			$code = ord( $c );
			if( ( $code >= 0x4e00 && $code <= 0x9FFF ) || ( $code >= 0x3400 && $code <= 0x4DB5 )
				|| ( $code >= 0xF900 && $code <= 0xFAFF ) ) {
				$str = Encode::encode( 'jis0208-raw', $c, Encode::FB_XMLCREF );
				if( index( $str, '&#x' ) >= 0 ) {
					push @result, sprintf( "%s(U+%04X) はJIS X 0208外の文字です", $c, $code );
				}
			}
		}
	}

	for( $n = 0; $n < length( $self->{'title'} ); $n++ ) {
		$c = substr( $self->{'title'}, $n, 1 );
		if( ord( $c ) >= 65536 ) {
			push @result, "$c は基本多言語面外の文字です";
		}
	}

	return \@result;
}


# 文法チェック
# param $article 記事データ
# param $titlelist JAWP::TitleListオブジェクト
# return $datalist_ref 結果配列へのリファレンス
sub LintText {
	my( $self, $titlelist ) = @_;
	my( $text, $checktimestamp, @time, @result, $text2, $n, @lines, @lines2, $headlevel, $prevheadlevel, $code, $defaultsort, %category, %interlink, $previnterlink, $mode, $prevmode );

	if( $self->Namespace ne '標準' || $self->IsRedirect ) {
		return \@result;
	}

	$text = $self->{'text'};
	while( $text =~ /<(math|code|pre|nowiki)(.*?)(\/math|\/code|\/pre|\/nowiki)>/is ) {
		my $tmp = $2;
		$tmp =~ s/[^\n]//g;
		$text =~ s/<(math|code|pre|nowiki)(.*?)(\/math|\/code|\/pre|\/nowiki)>/$tmp/is;
	}

	@lines = split( /\n/, $text );
	$text2 = $text;
	while( $text2 =~ s/\[([^[]+?)\]/ $1 /sg ){}
	while( $text2 =~ s/\{([^{]+?)\}/ $1 /sg ){}
	@lines2 = split( /\n/, $text2 );
	if( @lines != @lines2 ) {
		push @result, '行数不一致(プログラムの問題)';
		return \@result;
	}

	$headlevel = $prevheadlevel = 1;
	$defaultsort = '';
	$prevmode = 'text';
	for( $n = 1; $n < @lines + 1; $n++ ) {
		if( $lines[$n - 1] eq '' || $lines[$n - 1] =~ /^\s*\{\{.*\}\}\s*$/ ) {
			$mode = '';
		}
		else {
			$mode = 'text';
		}

		if( $lines[$n - 1] =~ /^(=+)[^=]+(=+)$/ ) {
			if( length( $1 ) != length( $2 ) ) {
				push @result, "見出し記法の左右の=の数が一致しません($n)";
			}
			else {
				$headlevel = length( $1 );
				if( $headlevel == 1 ) {
					push @result, "レベル1の見出しがあります($n)";
				}
				if( $headlevel >= 3 && $headlevel - $prevheadlevel >= 2 ) {
					push @result, sprintf( "レベル%dの見出しの前にレベル%dの見出しが必要です($n)", $headlevel, $headlevel - 1 );
				}
				$prevheadlevel = $headlevel;
			}
		}
		if( $lines[$n - 1] =~ /ISBN[0-9]/i ) {
			push @result, "ISBN記法では、ISBNと数字の間に半角スペースが必要です($n)";
		}
		if( $lines[$n - 1] =~ /ISBN[ =]([0-9X\-]+)/i ) {
			$code = $1;
			$code =~ s/\-//g;
			if( length( $code ) != 10 && length( $code ) != 13 ) {
				push @result, "ISBNは10桁もしくは13桁でないといけません($n)";
			}
		}
		if( $lines[$n - 1] =~ /['’]\d\d年/ ) {
			push @result, "西暦は全桁表示が推奨されます($n)";
		}
		if( index( $lines[$n - 1], '<!--' ) >= 0 ) {
			push @result, "閉じられていないコメントタグがあります($n)";
		}
		while( $lines[$n - 1] =~ /\{\{(DEFAULTSORT|デフォルトソート):(.*?)\}\}/g ) {
			if( $2 eq '' ) {
				push @result, "デフォルトソートではソートキーが必須です($n)";
			}
			if( $2 =~ /[ぁぃぅぇぉっゃゅょゎがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽー]/ ) {
				push @result, "ソートキーには濁音、半濁音、吃音、長音は使用しないことが推奨されます($n)";
			}
			if( $defaultsort ne '' ) {
				push @result, "デフォルトソートが複数存在します($n)";
			}
			$defaultsort = 'set';
		}
		while( $lines[$n - 1] =~ /\[\[(Category|カテゴリ):(.*?)(|\|.*?)\]\]/ig ) {
			if( defined( $category{$2} ) ) {
				push @result, "既に使用されているカテゴリです($n)";
			}
			if( !defined( $titlelist->{'Category'}->{$2} ) ) {
				push @result, "($2)は存在しないカテゴリです($n)";
			}
			$category{$2} = 1;
			if( $3 =~ /[ぁぃぅぇぉっゃゅょゎがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽー]/ ) {
				push @result, "ソートキーには濁音、半濁音、吃音、長音は使用しないことが推奨されます($n)";
			}
			$mode = 'category';
		}
		while( $lines[$n - 1] =~ /\[\[(Template|テンプレート):(.*?)(|\|.*?)\]\]/ig ) {
			if( !defined( $titlelist->{'Template'}->{$2} ) ) {
				push @result, "($2)は存在しないテンプレートです($n)";
			}
		}
		if( $lines[$n - 1] =~ /[，．！？＆＠]/ ) {
			push @result, "全角記号の使用は推奨されません($n)";
		}
		if( $lines[$n - 1] =~ /[Ａ-Ｚａ-ｚ０-９]/ ) {
			push @result, "全角英数字の使用は推奨されません($n)";
		}
		if( $lines[$n - 1] =~ /[ｱ-ﾝﾞﾟｧ-ｫｬ-ｮｰ｡｢｣､]/ ) {
			push @result, "半角カタカナの使用は推奨されません($n)";
		}
		if( $lines[$n - 1] =~ /[ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩ]/ ) {
			push @result, "ローマ数字はアルファベットを組み合わせましょう($n)";
		}
		if( $lines[$n - 1] =~ /[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳]/ ) {
			push @result, "丸付き数字の使用は推奨されません($n)";
		}
		if( $lines[$n - 1] =~ /\[\[(aa|aar|ab|abk|ace|ach|ada|ady|ae|af|afa|afh|afr|ain|ak|aka|akk|alb|ale|alg|als|alt|am|amh|an|ang|apa|ar|ara|arc|arg|arm|arn|arp|art|arw|arz|as|asm|ast|ath|aus|av|ava|ave|awa|ay|aym|az|aze|ba|bad|bai|bak|bal|bam|ban|baq|bar|bas|bat|bat\-smg|bcl|be|be\-x\-old|bej|bel|bem|ben|ber|bg|bh|bho|bi|bih|bik|bin|bis|bjn|bla|bm|bn|bnt|bo|bod|bos|bpy|br|bra|bre|bs|bua|bug|bul|bur|bxr|byn|ca|cad|cai|car|cat|cau|cbk\-zam|cdo|ce|ceb|cel|ces|ch|cha|chb|che|chg|chi|chm|chn|cho|chr|chu|chv|chy|ckb|co|cop|cor|cos|cpe|cpf|cpp|cr|cre|crh|crp|cs|csb|cu|cus|cv|cy|cym|cze|da|dak|dan|dar|day|de|del|deu|dgr|din|diq|div|doi|dra|dsb|dua|dum|dut|dv|dyu|dz|dzo|ee|efi|egy|eka|el|ell|elx|eml|en|eng|enm|eo|epo|es|esk|est|et|eu|eus|ewe|ewo|ext|fa|fan|fao|fas|fat|ff|fi|fij|fin|fiu|fiu\-vro|fj|fo|fon|fr|fra|fre|frm|fro|frp|frr|frs|fry|ful|fur|fy|ga|gaa|gag|gan|gay|gd|gem|geo|ger|gez|gil|gl|gla|gle|glg|glk|glv|gmh|gn|goh|gon|gor|got|grb|grc|gre|grn|gu|guj|gv|ha|hai|hak|hat|hau|haw|he|heb|her|hi|hif|hil|him|hin|hit|hmn|hmo|ho|hr|hrv|hsb|ht|hu|hun|hup|hy|hye|hz|ia|iba|ibo|ice|id|ido|ie|ig|ii|iii|ijo|ik|iku|ile|ilo|ina|inc|ind|ine|inh|io|ipk|ira|iro|is|isl|it|ita|iu|ja|jav|jbo|jpn|jpr|jrb|jv|ka|kaa|kab|kac|kal|kam|kan|kar|kas|kat|kau|kaw|kaz|kbd|kg|kha|khi|khm|kho|ki|kik|kin|kir|kj|kk|kl|km|kmb|kn|ko|koi|kok|kom|kon|kor|kos|kpe|kr|krc|kro|kru|ks|ksh|ku|kua|kum|kur|kut|kv|kw|ky|la|lad|lah|lam|lao|lat|lav|lb|lbe|lez|lg|li|lij|lim|lin|lit|lmo|ln|lo|lol|loz|lt|ltg|ltz|lu|lub|lug|lui|lun|luo|lv|mac|mad|mag|mah|mai|mak|mal|man|mao|map|map\-bms|mar|mas|may|mdf|men|mg|mga|mh|mhr|mi|mic|min|mis|mk|mkd|mkh|ml|mlg|mlt|mn|mnc|mni|mno|mo|moh|mol|mon|mos|mr|mri|mrj|ms|msa|mt|mul|mun|mus|mwl|mwr|my|mya|myn|myv|mzn|na|nah|nai|nap|nau|nav|nb|nbl|nd|nde|ndo|nds|nds\-nl|ne|nep|new|ng|nic|niu|nl|nld|nn|nno|no|nob|nog|non|nor|nov|nr|nrm|nso|nub|nv|nwc|ny|nya|nym|nyn|nyo|nzi|oc|oci|oj|oji|ojp|om|or|ori|orm|os|osa|oss|ota|oto|pa|paa|pag|pal|pam|pan|pap|pau|pcd|pdc|peo|per|pfl|phn|pi|pih|pl|pli|pms|pnb|pnt|pol|pon|por|pra|pro|ps|pt|pus|qu|que|raj|rap|rar|rm|rmy|rn|ro|roa|roa\-rup|roa\-tara|roh|rom|ron|ru|rue|rum|run|rus|rw|sa|sad|sag|sah|sai|sal|sam|san|sc|scc|scn|sco|scr|sd|se|sel|sem|sg|sga|sgn|sh|shn|si|sid|simple|sin|sio|sit|sk|sl|sla|slk|slo|slv|sm|sma|sme|smi|smj|smn|smo|sms|sn|sna|snd|so|sog|som|son|sot|spa|sq|sqi|sr|srd|srn|srp|srr|ss|ssa|ssw|st|stq|su|suk|sun|sus|sux|sv|sw|swa|swe|syr|szl|ta|tah|tai|tam|tat|te|tel|tem|ter|tet|tg|tgk|tgl|th|tha|ti|tib|tig|tir|tiv|tju|tk|tkl|tl|tlh|tli|tmh|tn|to|tog|ton|tpi|tr|tru|ts|tsi|tsn|tso|tt|tuk|tum|tup|tur|tut|tw|twi|ty|tyv|udm|ug|uga|uig|uk|ukr|umb|und|ur|urd|uz|uzb|vai|ve|vec|ven|vi|vie|vls|vo|vol|vot|wa|wak|wal|war|was|wel|wen|wln|wo|wol|wuu|xal|xh|xho|yao|yap|yi|yid|yo|yor|za|zap|zea|zen|zh|zh\-classical|zh\-cn|zh\-min\-nan|nan|zh\-tw|zh\-yue|zha|zho|zu|zul|zun):.*\]\]/i ) {
			if( defined( $previnterlink ) && uc( $previnterlink ) gt uc( $1 ) ) {
				push @result, "言語間リンクはアルファベット順に並べることが推奨されます($n)";
			}
			if( defined( $interlink{uc($1)} ) ) {
				push @result, "言語間リンクが重複しています($n)";
			}
			$previnterlink = uc( $1 );
			$interlink{uc($1)} = 1;
			$mode = 'interlink';
		}
		if( index( $lines[$n - 1], 'http:///' ) >= 0 ) {
			push @result, "不正なURLです($n)";
		}

		foreach my $word ( JAWP::Util::GetLinkwordList( $lines[$n - 1] ) ) {
			if( defined( $titlelist->{'標準_曖昧'}->{$word} ) ) {
				push @result, "($word)のリンク先は曖昧さ回避です($n)";
			}
			if( defined( $titlelist->{'標準_リダイレクト'}->{$word} ) ) {
				push @result, "($word)のリンク先はリダイレクトです($n)";
			}
			if( $word =~ /^\d+年\d+月\d+日$/ ) {
				push @result, "年月日へのリンクは年と月日を分けることが推奨されます($n)";
			}
		}

		if( $lines2[$n - 1] =~ /[\[\]\{\}]/ ) {
			push @result, "空のリンクまたは閉じられていないカッコがあります($n)";
		}

		if( $mode eq 'text' && ( $prevmode eq 'category' || $prevmode eq 'interlink' ) ) {
			push @result, "本文、カテゴリ、言語間リンクの順に記述することが推奨されます($n)";
		}
		if( $mode eq 'category' && $prevmode eq 'interlink' ) {
			push @result, "本文、カテゴリ、言語間リンクの順に記述することが推奨されます($n)";
		}
		$prevmode = $mode;
	}

	if( ( $text =~ /<ref/i ) && !( $text =~ /<references/i || $text =~ /\{\{reflist/i ) ) {
		push @result, '<ref>要素があるのに<references>要素がありません';
	}

	if( !$self->IsAimai ) {
		my $teigi = 0;
		my $title = $self->{'title'};
		$title =~ s/ \(.*?\)//;
		while( $text =~ /'''(.*)'''/g ) {
			if( $1 =~ $title || $1 =~ lcfirst $title ) {
				$teigi = 1;
				last;
			}
			my $tmp = $1;
			$tmp =~ s/[ 　]//g;
			$tmp =~ s/_/ /g;
			if( $tmp =~ $title || $tmp =~ lcfirst $title ) {
				$teigi = 1;
				last;
			}
		}
		if( !$teigi ) {
			push @result, '定義文が見当たりません';
		}
		if( keys( %category ) + 0 == 0 ) {
			push @result, 'カテゴリが一つもありません';
		}
		if( $defaultsort eq '' ) {
			push @result, 'デフォルトソートがありません';
		}
		if( $self->IsNoref ) {
			push @result, '出典に関する節がありません';
		}
	}

	my( $cat存命, $cat生年, $cat没年, $temp死亡年月日, $生年, $没年 );

	$cat存命 = defined( $category{'存命人物'} );
	$cat生年 = defined( $category{'生年不明'} ) || grep { /^\d+年生$/ } keys %category;
	$cat没年 = defined( $category{'没年不明'} ) || grep { /^\d+年没$/ } keys %category;
	$temp死亡年月日 = $text =~ /{{死亡年月日と没年齢\|/;
	$生年 = $1 if( $text =~ /\[\[Category:(\d+)年生/i );
	$没年 = $1 if( $text =~ /\[\[Category:(\d+)年没/i );
	if( $cat存命 && ( $cat没年 || $temp死亡年月日 ) ) {
		push @result, "存命人物ではありません";
	}
	if( ( $cat存命 || $cat没年 ) && !$cat生年 ) {
		push @result, "生年のカテゴリがありません";
	}
	if( $cat生年 && !$cat存命 && !$cat没年 ) {
		push @result, "存命人物または没年のカテゴリがありません";
	}
	if( defined( $生年 ) && $生年 >= 1903 && defined( $没年 ) && !$temp死亡年月日 ) {
		push @result, "(死亡年月日と没年齢)のテンプレートを使うと便利です";
	}

	return \@result;
}




################################################################################
# JAWP::TitleListクラス
################################################################################

package JAWP::TitleList;


# コンストラクタ
sub new {
	my $class = shift;
	my $self;

	$self = bless( { 'allcount'=>0,

		'標準'=>{}, '標準_曖昧'=>{}, '標準_リダイレクト'=>{},
		'利用者'=>{}, 'Wikipedia'=>{}, 'ファイル'=>{}, 'MediaWiki'=>{},
		'Template'=>{}, 'Help'=>{}, 'Category'=>{}, 'Portal'=>{}, 'プロジェクト'=>{},

		'ノート'=>{}, '利用者‐会話'=>{}, 'Wikipedia‐ノート'=>{}, 'ファイル‐ノート'=>{},
		'MediaWiki‐ノート'=>{}, 'Template‐ノート'=>{}, 'Help‐ノート'=>{},
		'Category‐ノート'=>{}, 'Portal‐ノート'=>{}, 'プロジェクト‐ノート'=>{}
		}, $class );

	return $self;
}


################################################################################
# JAWP::DataFileクラス
################################################################################

package JAWP::DataFile;


# コンストラクタ
sub new {
	my( $class, $filename ) = @_;
	my( $self, $fh );

	return if( !$filename );

	open $fh, '<', $filename or return;

	$self = bless( { 'filename'=>$filename, 'fh'=>$fh }, $class );

	return $self;
}


# Article取得
# return 取得成功時はJAWP::Article、失敗時はundef
sub GetArticle {
	my $self = shift;
	my $article = new JAWP::Article;
	my $fh = $self->{'fh'};
	my( $text, $flag );

	$flag = 0;
	while( <$fh> ) {
		if( /<title>(.*)<\/title>/ ) {
			$article->SetTitle( $1 );
			$flag |= 1;
		}
		if( /<timestamp>(.*)<\/timestamp>/ ) {
			$article->SetTimestamp( $1 );
			$flag |= 2;
		}
		if( /<text xml:space="preserve">(.*)<\/text>/ ) {
			$article->SetText( $1 );
			$flag |= 4;
		}
		elsif( /<text xml:space="preserve">(.*)/ ) {
			$text = "$1\n";
			while( <$fh> ) {
				if( /(.*)<\/text>/ ) {
					$text .= $1;
					last;
				}
				else {
					$text .= $_;
				}
			}
			$article->SetText( $text );
			$flag |= 4;
		}

		return $article if( $flag == 7 );
	}

	close( $self->{'fh'} ) or return;
	open $self->{'fh'}, '<', $self->{'filename'} or return;

	return;
}


# TitleList取得
# return TitleList
sub GetTitleList {
	my $self = shift;
	my $titlelist = new JAWP::TitleList;
	my( $n, $article, $namespace );

	$n = 1;
	while( $article = $self->GetArticle ) {
		print "$n\r";$n++;

		$titlelist->{'allcount'}++;

		$namespace = $article->Namespace;
		if( $namespace eq '標準' ) {
			if( $article->IsRedirect ) {
				$titlelist->{'標準_リダイレクト'}->{$article->{'title'}} = 1;
			}
			else {
				$titlelist->{'標準'}->{$article->{'title'}} = 1;

				if( $article->IsAimai ) {
					$titlelist->{'標準_曖昧'}->{$article->{'title'}} = 1;
				}
			}
		}
		else {
			$article->{'title'} =~ /:(.*)$/;
			$titlelist->{$namespace}->{$1} = 1;
		}
	}
	print "\n";

	return $titlelist;
}


################################################################################
# JAWP::ReportFileクラス
################################################################################

package JAWP::ReportFile;


# コンストラクタ
# param $filename レポートファイル名
sub new {
	my( $class, $filename ) = @_;
	my( $self, $fh );

	return if( !defined( $filename ) );
	open $fh, '>', $filename or return;

	$self = bless(
		{ 'filename'=>$filename, 'fh'=>$fh }, $class );

	return $self;
}


# Wiki形式レポート出力
# param $title レポート見出し
# param $data_ref レポートデータへのリファレンス
# return 成功なら1、失敗なら0
sub OutputWiki {
	my( $self, $title, $data_ref ) = @_;
	my $fh;

	return 0 if( !$title || !$data_ref || ref( $data_ref) ne 'SCALAR' );

	$fh = $self->{'fh'};
	print $fh "== $title ==\n" or return 0;
	print $fh "$$data_ref\n" or return 0;
	print $fh "\n" or return 0;

	return 1;
}


# Wiki形式リストレポート出力
# param $title レポート見出し
# param $datalist_ref レポートデータ配列へのリファレンス
# return 成功なら1、失敗なら0
sub OutputWikiList {
	my( $self, $title, $datalist_ref ) = @_;
	my( $data, $fh );

	return 0 if( !$title || !$datalist_ref || ref( $datalist_ref) ne 'ARRAY' );

	$fh = $self->{'fh'};
	print $fh "== $title ==\n" or return 0;
	foreach $data ( @$datalist_ref ) {
		print $fh "*$data\n" or return 0;
	}
	print $fh "\n" or return 0;

	return 1;
}


# レポート直接出力
# param $text 文字列
# return 成功なら1、失敗なら0
sub OutputDirect {
	my( $self, $text ) = @_;
	my $fh;

	return 0 if( !$text );

	$fh = $self->{'fh'};
	print $fh $text or return 0;

	return 1;
}


################################################################################
# JAWP::Utilクラス
################################################################################

package JAWP::Util;


# HTMLアンエスケープ
# param $text 元テキスト
# return アンエスケープテキスト
sub UnescapeHTML {
	my $text = shift;
	my %table = (
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
		'&lceil;'=>'⌈', '&rceil;'=>'⌉', '&lfloor;'=>'⌊', '&rfloor;'=>'⌋', '&lang;'=>'〈', '&rang;'=>'〉', '&loz;'=>'◊', '&spades;'=>'♠', '&clubs;'=>'♣', '&hearts;'=>'♥', '&diams;'=>'♦'
	);

	$text =~ s/&amp;/&/g;
	$text =~ s/&amp;/&/g;

	$text =~ s/&#([0-9]+);/chr($1)/ge;
	$text =~ s/&#[xX]([0-9A-Fa-f]+);/chr(hex $1)/ge;

	$text =~ s/(&\w+;)/defined($table{$1}) ? $table{$1} : $1/eg;

	return $text;
}


# URLデコード
# param $text 元テキスト
# return デコードテキスト
sub DecodeURL {
	my $str = shift;

#	$str =~ tr/+/ /;
	$str = Encode::encode( 'utf-8', $str );
	$str =~ s/%([0-9a-fA-F][0-9a-fA-F])/pack("C",hex($1))/eg;
	$str = Encode::decode( 'utf-8', $str );

	return $str;
}


# ハッシュのソート
# param $hash_ref ハッシュへのリファレンス
# return ソート結果配列へのリファレンス
sub SortHash {
	my $hash_ref = shift;
	my @result;

	@result = sort { ( $hash_ref->{$b} <=> $hash_ref->{$a} ) } keys %$hash_ref;

	return \@result;
}


# ハッシュの文字列によるソート
# param $hash_ref ハッシュへのリファレンス
# return ソート結果配列へのリファレンス
sub SortHashByStr {
	my $hash_ref = shift;
	my @result;

	@result = sort { ( $hash_ref->{$a} cmp $hash_ref->{$b} ) } keys %$hash_ref;

	return \@result;
}


# リンク語リストの取得
# param $text 元テキスト
# return リンク語リスト
sub GetLinkwordList {
	my $text = shift;
	my( $word, @wordlist );

	while( $text =~ /\[\[(.*?)(\||\]\])/g ) {
		next if( $1 =~ /[\[\{\}]/ );
		$word = $1;
		$word =~ s/#.*?$//;
		$word =~ s/[_　‎]/ /g;
		$word =~ s/^( +|)(.*?)( +|)$/$2/;
		$word = ucfirst $word;

		push @wordlist, JAWP::Util::DecodeURL( $word );
	}

	return @wordlist;
}


# テンプレート呼出し語リストの取得
# param $text 元テキスト
# return リンク語リスト
sub GetTemplatewordList {
	my $text = shift;
	my( $word, @wordlist );

	while( $text =~ /\{\{(.*?)(\||\}\})/g ) {
		next if( $1 =~ /^(DEFAULTSORT|デフォルトソート)/ || $1 =~ /^Sakujo\// );
		$word = $1;
		$word =~ s/[_　‎]/ /g;
		$word =~ s/^( +|)(.*?)( +|)$/$2/;
		$word = ucfirst $word;

		push @wordlist, JAWP::Util::DecodeURL( $word );
	}

	return @wordlist;
}


# 外部リンクリストの取得
# param $text 元テキスト
# return 外部リンクリスト
sub GetExternallinkList {
	my $text = shift;
	my( @linklist );

	@linklist = $text =~ /s?https?:\/\/[-_.!~*'()a-zA-Z0-9;\/?:\@&=+\$,%#]+/g;

	return @linklist;
}


# URLのホストの取得
# param $url URL
# return ホスト
sub GetHost {
	my $url = shift;

	if( $url =~ /s?https?:\/\/([-_.!~*'()a-zA-Z0-9;?:\@&=+\$,%#]+)/ ) {
		return $1;
	}
	else {
		return;
	}
}


# リンク種別判別
# param $word リンク語
# param $titlelist JAWP::TitleListオブジェクト
# return リンク種別、リンク語
sub GetLinkType {
	my( $word, $titlelist ) = @_;

	if( defined( $titlelist->{'標準'}->{$word} ) ) {
		if( defined( $titlelist->{'標準_曖昧'}->{$word} ) ) {
			return( 'aimai', $word );
		}
		else {
			return( '標準', $word );
		}
	}
	elsif( defined( $titlelist->{'標準_リダイレクト'}->{$word} ) ) {
		return( 'redirect', $word );
	}
	elsif( $word =~ /^(Category|カテゴリ):(.*)/i ) {
		return( 'category', $2 ) if( defined( $titlelist->{'Category'}->{$2} ) );
	}
	elsif( $word =~ /^(ファイル|画像|メディア|file|image|media):(.*)/i ) {
		return( 'file', $2 ) if( defined( $titlelist->{'ファイル'}->{$2} ) );
	}
	elsif( $word =~ /^(Template|テンプレート):(.*)/i ) {
		return( 'template', $2 ) if( defined( $titlelist->{'Template'}->{$2} ) );
	}
	elsif( $word =~ /^(Help|ヘルプ|MediaWiki|Portal|Wikipedia|プロジェクト|Project):/i
		|| $word =~ /^(Special|特別|利用者|User|ノート|トーク|talk|利用者‐会話|利用者・トーク|User talk|Wikipedia‐ノート|Wikipedia・トーク|Wikipedia talk|ファイル‐ノート|ファイル・トーク|画像‐ノート|File talk|Image Talk|MediaWiki‐ノート|MediaWiki・トーク|MediaWiki talk|Template‐ノート|Template talk|Help‐ノート|Help talk|Category‐ノート|Category talk|カテゴリ・トーク|Portal‐ノート|Portal・トーク|Portal talk|プロジェクト‐ノート|Project talk):/i
		|| $word =~ /^(aa|aar|ab|abk|ace|ach|ada|ady|ae|af|afa|afh|afr|ain|ak|aka|akk|alb|ale|alg|als|alt|am|amh|an|ang|apa|ar|ara|arc|arg|arm|arn|arp|art|arw|arz|as|asm|ast|ath|aus|av|ava|ave|awa|ay|aym|az|aze|ba|bad|bai|bak|bal|bam|ban|baq|bar|bas|bat|bat\-smg|bcl|be|be\-x\-old|bej|bel|bem|ben|ber|bg|bh|bho|bi|bih|bik|bin|bis|bjn|bla|bm|bn|bnt|bo|bod|bos|bpy|br|bra|bre|bs|bua|bug|bul|bur|bxr|byn|ca|cad|cai|car|cat|cau|cbk\-zam|cdo|ce|ceb|cel|ces|ch|cha|chb|che|chg|chi|chm|chn|cho|chr|chu|chv|chy|ckb|co|cop|cor|cos|cpe|cpf|cpp|cr|cre|crh|crp|cs|csb|cu|cus|cv|cy|cym|cze|da|dak|dan|dar|day|de|del|deu|dgr|din|diq|div|doi|dra|dsb|dua|dum|dut|dv|dyu|dz|dzo|ee|efi|egy|eka|el|ell|elx|eml|en|eng|enm|eo|epo|es|esk|est|et|eu|eus|ewe|ewo|ext|fa|fan|fao|fas|fat|ff|fi|fij|fin|fiu|fiu\-vro|fj|fo|fon|fr|fra|fre|frm|fro|frp|frr|frs|fry|ful|fur|fy|ga|gaa|gag|gan|gay|gd|gem|geo|ger|gez|gil|gl|gla|gle|glg|glk|glv|gmh|gn|goh|gon|gor|got|grb|grc|gre|grn|gu|guj|gv|ha|hai|hak|hat|hau|haw|he|heb|her|hi|hif|hil|him|hin|hit|hmn|hmo|ho|hr|hrv|hsb|ht|hu|hun|hup|hy|hye|hz|ia|iba|ibo|ice|id|ido|ie|ig|ii|iii|ijo|ik|iku|ile|ilo|ina|inc|ind|ine|inh|io|ipk|ira|iro|is|isl|it|ita|iu|ja|jav|jbo|jpn|jpr|jrb|jv|ka|kaa|kab|kac|kal|kam|kan|kar|kas|kat|kau|kaw|kaz|kbd|kg|kha|khi|khm|kho|ki|kik|kin|kir|kj|kk|kl|km|kmb|kn|ko|koi|kok|kom|kon|kor|kos|kpe|kr|krc|kro|kru|ks|ksh|ku|kua|kum|kur|kut|kv|kw|ky|la|lad|lah|lam|lao|lat|lav|lb|lbe|lez|lg|li|lij|lim|lin|lit|lmo|ln|lo|lol|loz|lt|ltg|ltz|lu|lub|lug|lui|lun|luo|lv|mac|mad|mag|mah|mai|mak|mal|man|mao|map|map\-bms|mar|mas|may|mdf|men|mg|mga|mh|mhr|mi|mic|min|mis|mk|mkd|mkh|ml|mlg|mlt|mn|mnc|mni|mno|mo|moh|mol|mon|mos|mr|mri|mrj|ms|msa|mt|mul|mun|mus|mwl|mwr|my|mya|myn|myv|mzn|na|nah|nai|nap|nau|nav|nb|nbl|nd|nde|ndo|nds|nds\-nl|ne|nep|new|ng|nic|niu|nl|nld|nn|nno|no|nob|nog|non|nor|nov|nr|nrm|nso|nub|nv|nwc|ny|nya|nym|nyn|nyo|nzi|oc|oci|oj|oji|ojp|om|or|ori|orm|os|osa|oss|ota|oto|pa|paa|pag|pal|pam|pan|pap|pau|pcd|pdc|peo|per|pfl|phn|pi|pih|pl|pli|pms|pnb|pnt|pol|pon|por|pra|pro|ps|pt|pus|qu|que|raj|rap|rar|rm|rmy|rn|ro|roa|roa\-rup|roa\-tara|roh|rom|ron|ru|rue|rum|run|rus|rw|sa|sad|sag|sah|sai|sal|sam|san|sc|scc|scn|sco|scr|sd|se|sel|sem|sg|sga|sgn|sh|shn|si|sid|simple|sin|sio|sit|sk|sl|sla|slk|slo|slv|sm|sma|sme|smi|smj|smn|smo|sms|sn|sna|snd|so|sog|som|son|sot|spa|sq|sqi|sr|srd|srn|srp|srr|ss|ssa|ssw|st|stq|su|suk|sun|sus|sux|sv|sw|swa|swe|syr|szl|ta|tah|tai|tam|tat|te|tel|tem|ter|tet|tg|tgk|tgl|th|tha|ti|tib|tig|tir|tiv|tju|tk|tkl|tl|tlh|tli|tmh|tn|to|tog|ton|tpi|tr|tru|ts|tsi|tsn|tso|tt|tuk|tum|tup|tur|tut|tw|twi|ty|tyv|udm|ug|uga|uig|uk|ukr|umb|und|ur|urd|uz|uzb|vai|ve|vec|ven|vi|vie|vls|vo|vol|vot|wa|wak|wal|war|was|wel|wen|wln|wo|wol|wuu|xal|xh|xho|yao|yap|yi|yid|yo|yor|za|zap|zea|zen|zh|zh\-classical|zh\-cn|zh\-min\-nan|nan|zh\-tw|zh\-yue|zha|zho|zu|zul|zun):/i # 言語間リンク
		|| $word =~ /^(wikipedia|w|wiktionary|wikt|wikinews|n|wikibooks|b|wikiquote|q|wikisource|s|wikispecies|species|v|wikimedia|foundation|wmf|commons|meta|m|incubator|mw|bugzilla|mediazilla|translatewiki|betawiki|tools):/i # プロジェクト間リンク
		|| $word =~ /^(Rev|Sulutil|Testwiki|CentralWikia|Choralwiki|google|irc|Mail|Mailarchive|MarvelDatabase|MeatBall|MemoryAlpha|MozillaWiki|Uncyclopedia|Wikia|Wikitravel|IMDbTitle):/i
		|| $word =~ /^http:\/\//i
		|| $word =~ /^(\/|\.\.\/)/
		|| $word =~ /^[#:]/ ) {
		;
		return( 'none', $word );
	}
	else {
		return( 'redlink', $word );
	}

	return( 'none', $word );
}


# 見出し語リストの取得
# param $text 元テキスト
# return 見出し語リスト
sub GetHeadnameList {
	my $text = shift;
	my( @headnamelist );

while( $text =~ /^=+([^=]+?)=+$/mg ) {
        my $tmp = $1;
        $tmp =~ s/^ *//;
        $tmp =~ s/ *$//;
        if( $tmp ne '' ) {
			push @headnamelist, $tmp;
        }
	}

	return @headnamelist;
}


################################################################################
# JAWP::Appクラス
################################################################################

package JAWP::App;


# アプリ実行
# param @argv コマンドライン引数への配列
sub Run {
	my $self = shift;
	my @argv = @_;

	Usage() if( @argv <= 2 );

	if( $argv[0] eq 'lint-title' ) {
		LintTitle( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'lint-text' ) {
		LintText( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'statistic' ) {
		Statistic( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'titlelist' ) {
		TitleList( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'living-noref' ) {
		LivingNoref( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'passed-sakujo' ) {
		PassedSakujo( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'seibotsu-doujitsu' ) {
		SeibotsuDoujitsu( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'noindex' ) {
		NoIndex( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'index-redlink' ) {
		IndexRedlink( $argv[1], $argv[2] );
	}
	else {
		Usage();
	}
}


# Usage出力
# comment 関数終了時exitする
sub Usage {
	print <<"TEXT";
jawptool $VERSION

Usage: jawptool.pl command xmlfile reportfile

command:
  lint-title
  lint-text
  statistic
  titlelist
  living-noref
  passed-sakujo
  seibotsu-doujitsu
  noindex
  index-redlink
TEXT

	exit;
}


# タイトル文法チェック
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub LintTitle {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $report = new JAWP::ReportFile( $reportfile );
	my( $n, $article, $result_ref );

	$report->OutputDirect( <<"STR"
= 記事名lint =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile を記事名の誤りの可能性について検査したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

プログラムで機械的に検査しているため、修正すべきでない記事についても検出されている可能性は大いにあります。この一覧を元に修正を行う場合は、個別にその修正が行われるべきか、十分に検討してから行うようにお願いします。

STR
	);

	$n = 1;
	while( $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		$result_ref = $article->LintTitle;
		if( @$result_ref != 0 ) {
			$report->OutputWikiList( "[[$article->{'title'}]]", $result_ref );
		}
	}
	print "\n";
}


# 本文文法チェック
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub LintText {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $titlelist = $jawpdata->GetTitleList;
	my $report = new JAWP::ReportFile( $reportfile );
	my( $n, $article, $result_ref, $lintcount );

	foreach my $namespace ( '標準', '利用者', '利用者‐会話', 'Wikipedia', 'Wikipedia‐ノート', 'ファイル', 'ファイル‐ノート', 'MediaWiki', 'MediaWiki‐ノート', 'Template‐ノート', 'Help', 'Help‐ノート', 'Category‐ノート', 'Portal', 'Portal‐ノート', 'プロジェクト', 'プロジェクト‐ノート' ) {
		$titlelist->{$namespace} = {};
	}

	$report->OutputDirect( <<"STR"
= 記事本文lint =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile を本文の誤りの可能性について検査したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

プログラムで機械的に検査しているため、修正すべきでない記事についても検出されている可能性は大いにあります。この一覧を元に修正を行う場合は、個別にその修正が行われるべきか、十分に検討してから行うようにお願いします。

STR
	);

	$lintcount = 0;
	$n = 1;
	while( $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		$result_ref = $article->LintText( $titlelist );
		if( @$result_ref != 0 ) {
			$report->OutputWikiList( "[[$article->{'title'}]]", $result_ref );
			$lintcount++;
			if( $lintcount > 10000 ) {
				$report->OutputDirect( "以下省略\n" );
				last;
			}
		}
	}
	print "\n";
}


# データ統計
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub Statistic {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $titlelist = $jawpdata->GetTitleList;
	my $report = new JAWP::ReportFile( $reportfile );
	my( $n, $article, $text, $result_ref, $word, %count, @linkwordlist );
	my( %linkcount, $linktype, %headnamecount );

	$report->OutputDirect( <<"STR"
= 統計 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile を集計したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

同種の集計は他にも多数ありますが、集計基準が違うために、集計値に違いがある場合があります。特に、本レポートではテンプレート内で使用されているリンク、ファイル、テンプレートをカウントしていないため、差異が大きくなっている可能性があります。

STR
	);

	StatisticReportSub1( $titlelist, $report );

	foreach my $namespace ( '利用者', '利用者‐会話', 'Wikipedia', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki', 'MediaWiki‐ノート', 'Template‐ノート', 'Help', 'Help‐ノート', 'Category‐ノート', 'Portal', 'Portal‐ノート', 'プロジェクト', 'プロジェクト‐ノート' ) {
		$titlelist->{$namespace} = {};
	}

	$n = 1;
	foreach my $linktype ( '発リンク', '標準', 'aimai', 'redirect', 'category', 'file', 'template', 'redlink', 'externalhost' ) {
		$linkcount{$linktype} = {};
	}
	%headnamecount = ();
	while( $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		$article->{'text'} =~ s/<math.*?<\/math>//sg;
		$article->{'text'} =~ s/<pre.*?<\/pre>//sg;
		$article->{'text'} =~ s/<code.*?<\/code>//sg;
		$article->{'text'} =~ s/{{{.*?}}}//sg;

		%count = ();

		@linkwordlist = JAWP::Util::GetLinkwordList( $article->{'text'} );
		if( $article->Namespace eq '標準' ) {
			$linkcount{'発リンク'}->{$article->{'title'}} = @linkwordlist + 0;
		}
		foreach $word ( @linkwordlist ) {
			next if( ++$count{$word} > 1 );

			( $linktype, $word ) = JAWP::Util::GetLinkType( $word, $titlelist );
			$linkcount{$linktype}->{$word}++ if( $linktype ne 'none' );
		}

		foreach $word ( JAWP::Util::GetTemplatewordList( $article->{'text'} ) ) {
			next if( ++$count{$word} > 1 );

			$linkcount{template}->{$word}++ if( defined( $titlelist->{'Template'}->{$word} ) );
		}

		foreach $word ( JAWP::Util::GetExternallinkList( $article->{'text'} ) ) {
			$word = JAWP::Util::GetHost( $word );
			$linkcount{'externalhost'}->{$word}++ if( defined( $word ) );
		}

		foreach $word ( JAWP::Util::GetHeadnameList( $article->{'text'} ) ) {
			$headnamecount{$word}++;
		}
	}
	print "\n";

	undef $titlelist;

	StatisticReportSub2( '発リンク数ランキング', $linkcount{'発リンク'}, '', $report, 1 );
	$linkcount{'発リンク'} = {};
	StatisticReportSub2( '被リンク数ランキング', $linkcount{'標準'}, '', $report, 1 );
	$linkcount{'標準'} = {};
	StatisticReportSub2( 'リダイレクト呼出数ランキング', $linkcount{'redirect'}, '', $report, 1 );
	$linkcount{'redirect'} = {};
	StatisticReportSub2( '曖昧さ回避呼出数ランキング', $linkcount{'aimai'}, '', $report, 1 );
	$linkcount{'aimai'} = {};
	StatisticReportSub2( '赤リンク数ランキング', $linkcount{'redlink'}, '', $report, 1 );
	$linkcount{'redlink'} = {};
	StatisticReportSub2( 'カテゴリ使用数ランキング', $linkcount{'category'}, ':Category:', $report, 1 );
	$linkcount{'category'} = {};
	StatisticReportSub2( 'ファイル使用数ランキング', $linkcount{'file'}, ':ファイル:', $report, 1 );
	$linkcount{'file'} = {};
	StatisticReportSub2( 'テンプレート使用数ランキング', $linkcount{'template'}, ':Template:', $report, 1 );
	$linkcount{'template'} = {};
	StatisticReportSub2( '外部リンクホストランキング', $linkcount{'externalhost'}, '', $report, 0 );
	$linkcount{'externalhost'} = {};
	StatisticReportSub2( '見出し語ランキング', \%headnamecount, '', $report, 0 );
	%headnamecount = ();
}


# データ統計レポート出力サブモジュール1
# param $titlelist JAWP::TitleListオブジェクト
# param $report JAWP::Reportオブジェクト
sub StatisticReportSub1 {
	my( $titlelist, $report ) = @_;
	my $text;

	$text = sprintf( <<"TEXT"
{| class=\"wikitable\" style=\"text-align:right\"
! colspan=\"2\" | 本体 !! colspan=\"2\" | ノート
|-
! 名前 !! ファイル数 !! 名前 !! ファイル数
|-
|通常記事 || %d || ノート || %d
|-
|曖昧さ回避 || %d ||
|-
|リダイレクト || %d ||
|-
|利用者 || %d || 利用者‐会話 || %d
|-
|Wikipedia || %d || Wikipedia‐ノート || %d
|-
|ファイル || %d || ファイル‐ノート || %d
|-
|MediaWiki || %d || MediaWiki‐ノート || %d
|-
|Template || %d || Template‐ノート || %d
|-
|Help || %d || Help‐ノート || %d
|-
|Category || %d || Category‐ノート || %d
|-
|Portal || %d || Portal‐ノート || %d
|-
|プロジェクト || %d || プロジェクト‐ノート || %d
|}
全%d件
TEXT
		, ( keys %{ $titlelist->{'標準'} } ) + 0, ( keys %{ $titlelist->{'ノート'} } ) + 0
		, ( keys %{ $titlelist->{'標準_曖昧'} } ) + 0
		, ( keys %{ $titlelist->{'標準_リダイレクト'} } ) + 0
		, ( keys %{ $titlelist->{'利用者'} } ) + 0, ( keys %{ $titlelist->{'利用者‐会話'} } ) + 0
		, ( keys %{ $titlelist->{'Wikipedia'} } ) + 0, ( keys %{ $titlelist->{'Wikipedia‐ノート'} } ) + 0
		, ( keys %{ $titlelist->{'ファイル'} } ) + 0, ( keys %{ $titlelist->{'ファイル‐ノート'} } ) + 0
		, ( keys %{ $titlelist->{'MediaWiki'} } ) + 0, ( keys %{ $titlelist->{'MediaWiki‐ノート'} } ) + 0
		, ( keys %{ $titlelist->{'Template'} } ) + 0, ( keys %{ $titlelist->{'Template‐ノート'} } ) + 0
		, ( keys %{ $titlelist->{'Help'} } ) + 0, ( keys %{ $titlelist->{'Help‐ノート'} } ) + 0
		, ( keys %{ $titlelist->{'Category'} } ) + 0, ( keys %{ $titlelist->{'Category‐ノート'} } ) + 0
		, ( keys %{ $titlelist->{'Portal'} } ) + 0, ( keys %{ $titlelist->{'Portal‐ノート'} } ) + 0
		, ( keys %{ $titlelist->{'プロジェクト'} } ) + 0, ( keys %{ $titlelist->{'プロジェクト‐ノート'} } ) + 0
		, $titlelist->{'allcount'} );

	$report->OutputWiki( '名前空間別ファイル数', \$text );
}


# データ統計レポート出力サブモジュール2
# param $title レポートタイトル
# param $data_ref データハッシュへのリファレンス
# param $prefix リンク出力時のプレフィックス
# param $report JAWP::Reportオブジェクト
# param $innerlink 内部リンク化フラグ
sub StatisticReportSub2 {
	my( $title, $data_ref, $prefix, $report, $innerlink ) = @_;
	my( $data2_ref, $text );

	delete $data_ref->{''};
	$data2_ref = JAWP::Util::SortHash( $data_ref );
	if( @$data2_ref > 0 ) {
		$text .= "{{columns-list|2|\n";
		for my $i( 0..99 ) {
			last if( !defined( $data2_ref->[$i] ) );
			if( $innerlink ) {
				$text .= sprintf( "#[[$prefix%s]](%d)\n", $data2_ref->[$i], $data_ref->{$data2_ref->[$i]} );
			}
			else {
				$text .= sprintf( "#$prefix%s(%d)\n", $data2_ref->[$i], $data_ref->{$data2_ref->[$i]} );
			}
		}
		$text .= "}}\n";
	}
	$text .= sprintf( "全%d件", @$data2_ref + 0 );
	$report->OutputWiki( $title, \$text );
}


# タイトル一覧
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub TitleList {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $titlelist = $jawpdata->GetTitleList;
	my $report = new JAWP::ReportFile( $reportfile );
	my $namespace;
	my %varname = (
		'標準'=>'article', '標準_曖昧'=>'aimai', '標準_リダイレクト'=>'redirect',
		'利用者'=>'user', 'Wikipedia'=>'wikipedia', 'ファイル'=>'file', 'MediaWiki'=>'mediawiki',
		'Template'=>'template', 'Help'=>'help', 'Category'=>'category', 'Portal'=>'portal', 'プロジェクト'=>'project',

		'ノート'=>'note', '利用者‐会話'=>'user_talk', 'Wikipedia‐ノート'=>'wikipedia_note', 'ファイル‐ノート'=>'file_note',
		'MediaWiki‐ノート'=>'mediawiki_note', 'Template‐ノート'=>'template_note', 'Help‐ノート'=>'help_note',
		'Category‐ノート'=>'category_note', 'Portal‐ノート'=>'portal_note', 'プロジェクト‐ノート'=>'project_note' );

	foreach $namespace ( keys %varname ) {
		$Data::Dumper::Varname = $varname{$namespace};
		$report->OutputDirect( Data::Dumper::Dumper( $titlelist->{$namespace} ) );
		$titlelist->{$namespace} = {};
	}
}


# 出典の無い存命人物一覧
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub LivingNoref {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $report = new JAWP::ReportFile( $reportfile );
	my( $n, $article );
	my( $livingcount, $livingnorefcount, @livingnoreflist );

	$report->OutputDirect( <<"STR"
= 出典の無い存命人物一覧 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile から出典の無い存命人物を抽出したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	$livingcount = $livingnorefcount = 0;
	$n = 1;
	while( $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		if( $article->IsLiving ) {
			$livingcount++;
			if( $article->IsNoref ) {
				$livingnorefcount++;
				push @livingnoreflist, "[[$article->{'title'}]]";
			}
		}
	}
	print "\n";

	$report->OutputWikiList( "一覧", \@livingnoreflist );
	$report->OutputDirect( "存命人物記事数 $livingcount<br>\n" );
	$report->OutputDirect( "存命人物出典無し記事数 $livingnorefcount\n" );
}


# 長期間経過した削除依頼
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub PassedSakujo {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $report = new JAWP::ReportFile( $reportfile );
	my( $n, $article, $time, @datalist );

	$report->OutputDirect( <<"STR"
= 長期間経過した削除依頼 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile から長期間経過した削除依頼を抽出したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	$time = time();
	$n = 1;
	while( $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		next if( $article->Namespace ne '標準' );

		if( index( $article->{'text'}, '{{Sakujo/' ) >= 0 && $article->GetPassTime( $time ) gt '0000-03-00T00:00:00Z' ) {
			push @datalist, "[[$article->{'title'}]]";
		}
	}
	print "\n";

	$report->OutputWikiList( "一覧", \@datalist );
}


# 生没同日一覧
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub SeibotsuDoujitsu {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $report = new JAWP::ReportFile( $reportfile );
	my( $n, $article, $seibotsudoujitsu_text, @datalist );

	$report->OutputDirect( <<"STR"
= 生没同日人物一覧 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile から生没同日の人物を抽出したもので、[[生没同日]]の記事作成の支援を行うためのものです。「死亡年月日と没年齢テンプレート」の記載を元に抽出しているため、抽出漏れもありえます。あくまでも支援ツールの一つとしてお使い下さい。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	$n = 1;
	while( $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		next if( $article->Namespace ne '標準' );

		if( $article->{'title'} eq '生没同日' ) {
			$seibotsudoujitsu_text = $article->{'text'}
		}
		if( $article->IsSeibotsuDoujitsu ) {
			push @datalist, $article->{'title'};
		}
	}
	print "\n";

	@datalist = map { "[[$_]]" } grep { !( $seibotsudoujitsu_text =~ /$_/ ) } @datalist;
	$report->OutputWikiList( "一覧", \@datalist );
}


# 索引未登録記事一覧
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub NoIndex {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $report = new JAWP::ReportFile( $reportfile );
	my( %titlelist, $n, $article, @datalist );

	$report->OutputDirect( <<"STR"
= 索引未登録記事一覧 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile から索引に登録されていない記事を抽出したもので、[[Wikipedia:索引]]の支援を行うためのものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	$n = 1;
	while( $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		if( $article->Namespace eq '標準' && !$article->IsRedirect ) {
			if( $article->{'text'} =~ /\{\{(DEFAULTSORT|デフォルトソート):(.*?)\}\}/ ) {
				$titlelist{$article->{'title'}} = $2;
				$titlelist{$article->{'title'}} =~ s/[ 　]//g;
			}
			else {
				$titlelist{$article->{'title'}} = $article->{'title'};
			}
		}
	}
	print "\n";

	$n = 1;
	while( $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		next if( !$article->IsIndex );

		foreach my $word ( JAWP::Util::GetLinkwordList( $article->{'text'} ) ) {
			delete $titlelist{$word};
		}
	}
	print "\n";

	@datalist = map { "[[$_]]" } @{ JAWP::Util::SortHashByStr( \%titlelist ) };
	$report->OutputWikiList( "一覧", \@datalist );
	$report->OutputDirect( sprintf( "記事数 %d\n", @datalist + 0 ) );
}


# 索引赤リンク一覧
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub IndexRedlink {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $report = new JAWP::ReportFile( $reportfile );
	my( %titlelist, $n, $article, @datalist );

	$report->OutputDirect( <<"STR"
= 索引赤リンク一覧 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile から索引中の赤リンクを抽出したもので、[[Wikipedia:索引]]の支援を行うためのものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	$n = 1;
	while( $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		$titlelist{$article->{'title'}} = 1;
	}
	print "\n";

	$n = 1;
	while( $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		next if( !$article->IsIndex );

		@datalist = ();
		foreach my $word ( JAWP::Util::GetLinkwordList( $article->{'text'} ) ) {
			if( $word ne '' && !defined( $titlelist{$word} ) ) {
				push @datalist, "[[$word]]";
			}
		}
		if( @datalist != 0 ) {
			$report->OutputWikiList( "[[$article->{'title'}]]", \@datalist );
		}
	}
	print "\n";
}


1;
