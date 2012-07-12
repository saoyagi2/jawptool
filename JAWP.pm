use 5.8.0;
use strict;
use warnings;

use utf8;
use Encode;
use open IO  => ":utf8";

use CGI;

our $VERSION = '0.22';


################################################################################
# JAWP::Articleクラス
################################################################################

package JAWP::Article;


# コンストラクタ
sub new {
	my $class = shift;

	my $self = bless( { 'title'=>'', 'timestamp'=>'', 'text'=>'' }, $class );

	return( $self );
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

	return( $self->{'text'} =~ /^\s*(#|＃)(REDIRECT|転送|リダイレクト)/i );
}


# ソフトリダイレクト判別
# return 真偽値
sub IsSoftRedirect {
	my $self = shift;

	return( index( $self->{'text'}, '{{softredirect|' ) != -1 );
}


# 曖昧さ回避判別
# return 真偽値
sub IsAimai {
	my $self = shift;

	return( $self->{'text'} =~ /\{\{(disambig|Disambig|aimai|Aimai|曖昧さ回避|人名の曖昧さ回避|地名の曖昧さ回避|山の曖昧さ回避)/ );
}


# 存命人物記事判別
# return 真偽値
sub IsLiving {
	my $self = shift;

	return( $self->{'text'} =~ /\[\[(Category|カテゴリ):存命人物/i || $self->{'text'} =~ /\{\{(blp|Blp)/ );
}


# 出典の無い記事判別
# return 真偽値
sub IsNoref {
	my $self = shift;

	return( !( grep( /(参考|文献|資料|書籍|図書|注|註|出典|典拠|出所|原典|ソース|情報源|引用元|論拠|参照)/, @{ JAWP::Util::GetHeadList( $self->{'text'} ) } ) || $self->{'text'} =~ /<ref/ ) );
}


# 誕生日取得
# return 年、月、日(不存在なら0,0,0)
sub GetBirthday {
	my $self = shift;

	if( $self->{'text'} =~ /\{\{生年月日と年齢\|([0-9]+)\|([0-9]+)\|([0-9]+)/ ) {
		return( $1, $2, $3 );
	}
	if( $self->{'text'} =~ /\{\{(死亡年月日と没年齢|没年齢)\|([0-9]+)\|([0-9]+)\|([0-9]+)\|([0-9]+)\|([0-9]+)\|([0-9]+)\}\}/ ) {
		return( $2, $3, $4 );
	}

	return( 0, 0, 0 );
}


# 死亡日取得
# return 年、月、日(不存在なら0,0,0)
sub GetDeathday {
	my $self = shift;

	if( $self->{'text'} =~ /\{\{(死亡年月日と没年齢|没年齢)\|([0-9]+)\|([0-9]+)\|([0-9]+)\|([0-9]+)\|([0-9]+)\|([0-9]+)\}\}/ ) {
		return( $5, $6, $7 );
	}

	return( 0, 0, 0 );
}


# 索引判別
# return 真偽値
sub IsIndex {
	my $self = shift;

	return( index( $self->{'title'}, 'Wikipedia:索引' ) == 0 );
}


# 削除依頼タグ判別
# return 真偽値
sub IsSakujo {
	my $self = shift;

	return( index( $self->{'text'}, '{{Sakujo/' ) >= 0 || index( $self->{'text'}, '{{sakujo/' ) >= 0 );
}


# 名前空間取得
# return 名前空間
sub Namespace {
	my $self = shift;

	if( $self->{'title'} =~ /^(利用者|Wikipedia|ファイル|MediaWiki|Template|Help|Category|Portal|プロジェクト|ノート|利用者‐会話|Wikipedia‐ノート|ファイル‐ノート|MediaWiki‐ノート|Template‐ノート|Help‐ノート|Category‐ノート|Portal‐ノート|プロジェクト‐ノート):/ ) {
		return( $1 );
	}
	else {
		return( '標準' );
	}
}


# サブページ種別取得
# return サブページ種別
sub SubpageType {
	my $self = shift;
	my %typelist = ( 'Wikipedia:井戸端/subj/'=>'井戸端', 'Wikipedia:削除依頼/'=>'削除依頼', 'Wikipedia:CheckUser依頼/'=>'CheckUser依頼', 'Wikipedia:チェックユーザー依頼/'=>'CheckUser依頼', 'Wikipedia:投稿ブロック依頼/'=>'投稿ブロック依頼', 'Wikipedia:管理者への立候補/'=>'管理者への立候補', 'Wikipedia:コメント依頼/'=>'コメント依頼', 'Wikipedia:査読依頼/'=>'査読依頼' );

	foreach my $key ( keys %typelist ) {
		if( index( $self->{'title'}, $key ) == 0 ) {
			return( $typelist{$key} );
		}
	}

	return( '' );
}


# 経過時間取得
# param $time 時刻
# return 経過時間(YYYY-MM-DDTHH:MM:SSZ形式)
sub GetPassTime {
	my( $self, $time ) = @_;

	my @time = gmtime( $time );
	my $passtime = '0000-00-00T00:00:00Z';
	if( $self->{'timestamp'} =~ /([0-9]{4})\-([0-9]{2})\-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})Z/ ) {
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
	}

	return( $passtime );
}


# タイトル文法チェック
# param $titlelist タイトルリスト
# return 結果配列へのリファレンス
sub LintTitle {
	my $self = shift;
	my @result;

	if( $self->Namespace ne '標準' ) {
		return( \@result );
	}

	if( $self->{'title'} =~ /（[^（]+）$/ ) {
		push @result, '曖昧さ回避の記事であればカッコは半角でないといけません';
	}
	if( $self->{'title'} =~ /[^ ]\(([^\(]+)\)$/ || $self->{'title'} =~ /  \(([^\(]+)\)$/ ) {
		if( !( $1 =~ /^[IVX,]+$/ ) ) {
			push @result, '曖昧さ回避の記事であればカッコの前のスペースはひとつでないといけません';
		}
	}
	if( $self->{'title'} =~ /[　，．！？＆＠＃]/ ) {
		push @result, '全角スペース、全角記号の使用は推奨されません';
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
	if( $self->{'title'} =~ /[「」『』〔〕〈〉《》【】]/ ) {
		push @result, '括弧の使用は推奨されません';
	}
	if( $self->{'title'} =~ /[ぁ-ゔ][ヘベペ]/ || $self->{'title'} =~ /[ヘベペ][ぁ-ゔ]/ ) {
		push @result, '平仮名と「ヘ/ベ/ペ(片仮名)」が隣接しています';
	}
	if( $self->{'title'} =~ /[ァ-ヺ][へべぺ]/ || $self->{'title'} =~ /[へべぺ][ァ-ヺ]/ ) {
		push @result, '片仮名と「へ/べ/ぺ(平仮名)」が隣接しています';
	}
	if( $self->{'title'} =~ /[ァ-ヺ][力工口二]/ || $self->{'title'} =~ /[力工口二][ァ-ヺ]/ ) {
		push @result, '片仮名と「力/工/口/二(漢字)」が隣接しています';
	}

	if( !( $self->IsRedirect ) ) {
		if( $self->{'title'} =~ /^(株式会社|有限会社|合名会社|合資会社|合同会社)./ || $self->{'title'} =~ /.(株式会社|有限会社|合名会社|合資会社|合同会社)$/ ) {
			push @result, '会社の記事であれば法的地位を示す語句を含むことは推奨されません';
		}
		if( index( $self->{'title'}, '～' ) >= 0 ) {
			push @result, '波記号は〜(U+301C)を使用しましょう';
		}
		for( my $n = 0; $n < length( $self->{'title'} ); $n++ ) {
			my $c = substr( $self->{'title'}, $n, 1 );
			my $code = ord( $c );
			if( ( $code >= 0x4e00 && $code <= 0x9FFF ) || ( $code >= 0x3400 && $code <= 0x4DB5 )
				|| ( $code >= 0xF900 && $code <= 0xFAFF ) ) {
				my $str = Encode::encode( 'jis0208-raw', $c, Encode::FB_XMLCREF );
				if( index( $str, '&#x' ) >= 0 ) {
					push @result, sprintf( "%s(U+%04X) はJIS X 0208外の文字です", $c, $code );
				}
			}
		}
	}

	for( my $n = 0; $n < length( $self->{'title'} ); $n++ ) {
		my $c = substr( $self->{'title'}, $n, 1 );
		if( ord( $c ) >= 65536 ) {
			push @result, "$c は基本多言語面外の文字です";
		}
	}

	return( \@result );
}


# 本文文法チェック
# param $titlelist JAWP::TitleListオブジェクト
# return 結果配列へのリファレンス
sub LintText {
	my( $self, $titlelist ) = @_;
	my @result;

	if( $self->Namespace ne '標準' || $self->IsRedirect ) {
		return( \@result );
	}

	my $text = $self->{'text'};
	while( $text =~ /<(math|code|pre|nowiki)(.*?)(\/math|\/code|\/pre|\/nowiki)>/is ) {
		my $tmp = $2;
		$tmp =~ s/[^\n]//g;
		$text =~ s/<(math|code|pre|nowiki)(.*?)(\/math|\/code|\/pre|\/nowiki)>/$tmp/is;
	}
	my @lines = split( /\n/, $text );

	my @lines2;
	{
		my $text2 = $text;
		while( $text2 =~ s/\[([^[]+?)\]/ $1 /sg ){}
		while( $text2 =~ s/\{([^{]+?)\}/ $1 /sg ){}
		@lines2 = split( /\n/, $text2 );
		if( @lines != @lines2 ) {
			push @result, '行数不一致(プログラムの問題)';
			return( \@result );
		}
	}

	my $prevheadlevel = 1;
	my $defaultsort = '';
	my $prevmode = 'text';
	my( $mode, %category, %interlink, $previnterlink );
	for( my $n = 1; $n < @lines + 1; $n++ ) {
		my $mode = ( $lines[$n - 1] eq '' || $lines[$n - 1] =~ /^\s*\{\{.*\}\}\s*$/ ) ? '' : 'text';

		if( $lines[$n - 1] =~ /^(=+)[^=]+(=+) *$/ ) {
			if( length( $1 ) != length( $2 ) ) {
				push @result, "見出し記法の左右の=の数が一致しません($n)";
			}
			else {
				my $headlevel = length( $1 );
				if( $headlevel == 1 ) {
					push @result, "レベル1の見出しがあります($n)";
				}
				if( $headlevel > 6 ) {
					push @result, "見出しレベルは6までです($n)";
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
			my $code = $1;
			$code =~ s/\-//g;
			if( length( $code ) != 10 && length( $code ) != 13 ) {
				push @result, "ISBNは10桁もしくは13桁でないといけません($n)";
			}
		}
		if( $lines[$n - 1] =~ /['’]\d\d年/ ) {
			push @result, "西暦は全桁表示が推奨されます($n)";
		}
		if( index( $lines[$n - 1], '<!--' ) >= 0 || index( $lines[$n - 1], '-->' ) >= 0 ) {
			push @result, "閉じられていないコメントタグがあります($n)";
		}
		while( $lines[$n - 1] =~ /\{\{(DEFAULTSORT|デフォルトソート):(.*?)\}\}/g ) {
			if( $2 eq '' ) {
				push @result, "デフォルトソートではソートキーが必須です($n)";
			}
			if( $2 =~ /[ぁぃぅぇぉっゃゅょゎがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽー]/ ) {
				push @result, "ソートキーには濁音、半濁音、吃音、長音は清音化することが推奨されます($n)";
			}
			if( $defaultsort ne '' ) {
				push @result, "デフォルトソートが複数存在します($n)";
			}
			$defaultsort = 'set';
		}
		while( $lines[$n - 1] =~ /\[\[(Category|カテゴリ):(.*?)(|\|.*?)\]\]/ig ) {
			my $word = ucfirst( $2 );
			if( defined( $category{$word} ) ) {
				push @result, "既に使用されているカテゴリです($n)";
			}
			if( !defined( $titlelist->{'Category'}->{$word} ) ) {
				push @result, "($2)は存在しないカテゴリです($n)";
			}
			$category{$word} = 1;
			if( $3 =~ /[ぁぃぅぇぉっゃゅょゎがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽー]/ ) {
				push @result, "ソートキーには濁音、半濁音、吃音、長音は清音化することが推奨されます($n)";
			}
			$mode = 'category';
		}
		while( $lines[$n - 1] =~ /\[\[(Template|テンプレート):(.*?)(|\|.*?)\]\]/ig ) {
			my $word = ucfirst( $2 );
			if( !defined( $titlelist->{'Template'}->{$word} ) ) {
				push @result, "($word)は存在しないテンプレートです($n)";
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
		if( $lines[$n - 1] =~ /\[\[(aa|ab|ace|af|ak|als|am|an|ang|ar|arc|arz|as|ast|av|ay|az|ba|bar|bat\-smg|bcl|be|be\-x\-old|bg|bh|bi|bjn|bm|bn|bo|bpy|br|bs|bug|bxr|ca|cbk\-zam|cdo|ce|ceb|ch|cho|chr|chy|ckb|co|cr|crh|cs|csb|cu|cv|cy|da|de|diq|dsb|dv|dz|ee|el|eml|en|eo|es|et|eu|ext|fa|ff|fi|fiu\-vro|fj|fo|fr|frp|frr|fur|fy|ga|gag|gan|gd|gl|glk|gn|got|gu|gv|ha|hak|haw|he|hi|hif|ho|hr|hsb|ht|hu|hy|hz|ia|id|ie|ig|ii|ik|ilo|io|is|it|iu|ja|jbo|jp|jv|ka|kaa|kab|kbd|kg|ki|kj|kk|kl|km|kn|ko|koi|kr|krc|ks|ksh|ku|kv|kw|ky|la|lad|lb|lbe|lg|li|lij|lmo|ln|lo|lt|ltg|lv|map\-bms|mdf|mg|mhr|mi|mk|ml|mn|mo|mr|mrj|ms|mt|mwl|my|myv|mzn|na|nah|nan|nap|nb|nds|nds\-nl|ne|new|ng|nl|nn|no|nov|nrm|nso|nv|ny|oc|om|or|os|pa|pag|pam|pap|pcd|pdc|pfl|pi|pih|pl|pms|pnb|pnt|ps|pt|qu|rm|rmy|rn|ro|roa\-rup|roa\-tara|ru|rue|rw|sa|sah|sc|scn|sco|sd|se|sg|sh|si|simple|sk|sl|sm|sn|so|sq|sr|srn|ss|st|stq|su|sv|sw|szl|ta|te|tet|tg|th|ti|tk|tl|tn|to|tpi|tr|ts|tt|tum|tw|ty|udm|ug|uk|ur|uz|ve|vec|vi|vls|vo|wa|war|wo|wuu|xal|xh|xmf|yi|yo|za|zea|zh|zh\-cfr|zh\-classical|zh\-cn|zh\-min\-nan|zh\-tw|zh\-yue|zu):.*\]\]/i ) {
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

		foreach my $word ( @{ JAWP::Util::GetLinkwordList( $lines[$n - 1], 1 ) } ) {
			if( defined( $titlelist->{'標準_曖昧'}->{$word} ) ) {
				push @result, "($word)のリンク先は曖昧さ回避です($n)";
			}
			if( defined( $titlelist->{'標準_リダイレクト'}->{$word} ) ) {
				push @result, "($word)のリンク先はリダイレクトです($n)";
			}
			if( $word =~ /^[0-9]+年[0-9]+月[0-9]+日$/ ) {
				push @result, "年月日へのリンクは年と月日を分けることが推奨されます($n)";
			}
			if( index( $word, '#' ) >= 0 ) {
				my $linktype;
				( $linktype, $word ) = JAWP::Util::GetLinkType( $word, $titlelist );
				if( $linktype eq 'redlink' ) {
					push @result, "リンク先の節がありません($n)";
				}
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
		if( $self->{'title'} ne '' && !$teigi ) {
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

	my $cat存命 = defined( $category{'存命人物'} );
	my $cat生年 = defined( $category{'生年不明'} ) || grep { /^[0-9]+年生$/ } keys %category;
	my $cat没年 = defined( $category{'没年不明'} ) || grep { /^[0-9]+年没$/ } keys %category;
	my $temp生年月日 = ( index( $text, '{{生年月日と年齢|' ) >= 0 );
	my $temp死亡年月日 = ( index( $text, '{{死亡年月日と没年齢|' ) >= 0 || index( $text, '{{没年齢|' ) >= 0 );
	my $生年 = $1 if( $text =~ /\[\[Category:([0-9]+)年生/i );
	my $没年 = $1 if( $text =~ /\[\[Category:([0-9]+)年没/i );
	my( $y, $m, $d );

	if( $cat存命 && ( $cat没年 || $temp死亡年月日 ) ) {
		push @result, '存命人物ではありません';
	}
	if( ( $cat存命 || $cat没年 ) && !$cat生年 ) {
		push @result, '生年のカテゴリがありません';
	}
	if( $cat生年 && !$cat存命 && !$cat没年 ) {
		push @result, '存命人物または没年のカテゴリがありません';
	}
	if( defined( $生年 ) && $cat存命 && !$cat没年 && !$temp死亡年月日 && !$temp生年月日 ) {
		push @result, '(生年月日と年齢)のテンプレートを使うと便利です';
	}
	if( defined( $生年 ) && $生年 >= 1903 && defined( $没年 ) && !$temp死亡年月日 ) {
		push @result, '(死亡年月日と没年齢)のテンプレートを使うと便利です';
	}
	( $y, $m, $d ) = $self->GetBirthday;
	if( $y != 0 && $m != 0 && $d != 0 && defined( $生年 ) && $y != $生年 ) {
		push @result, '(生年月日と年齢or死亡年月日と没年齢or没年齢)テンプレートと生年のカテゴリが一致しません';
	}
	( $y, $m, $d ) = $self->GetDeathday;
	if( $y != 0 && $m != 0 && $d != 0 && defined( $没年 ) && $y != $没年 ) {
		push @result, '(死亡年月日と没年齢or没年齢)テンプレートと没年のカテゴリが一致しません';
	}

	return( \@result );
}


# 索引文法チェック
# param $titlelist タイトルリスト
# return 結果配列へのリファレンス
sub LintIndex {
	my( $self, $titlelist ) = @_;
	my @result;

	return( \@result ) if( !$self->IsIndex || $self->{'title'} eq 'Wikipedia:索引' );

	my $title;
	if( $self->{'title'} =~ /Wikipedia:索引 ([あ-ん]+)$/ ) {
		$title = $1;
	}

	my $text = $self->{'text'};
	while( $text =~ /<(math|code|pre|nowiki)(.*?)(\/math|\/code|\/pre|\/nowiki)>/is ) {
		my $tmp = $2;
		$tmp =~ s/[^\n]//g;
		$text =~ s/<(math|code|pre|nowiki)(.*?)(\/math|\/code|\/pre|\/nowiki)>/$tmp/is;
	}

	my @lines = split( /\n/, $text );
	my $prevhead = '';
	for( my $n = 1; $n < @lines + 1; $n++ ) {
		my $headlist_ref = JAWP::Util::GetHeadList( $lines[$n - 1] );
		if( defined( $title ) && @$headlist_ref != 0 ) {
			my $head = $headlist_ref->[0];
			if( $head =~ /[ぁぃぅぇぉっゃゅょゎがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽー]/ ) {
				push @result, "見出し($head)は濁音、半濁音、吃音、拗音、長音を使っています($n)";
			}
			if( $head =~ /^[あ-ん]+$/ ) {
				if( index( $head, $title ) != 0 ) {
					push @result, "見出し($head)が記事名に一致しません($n)";
				}
				if( $prevhead gt $head ) {
					push @result, "見出し($head)があいうえお順ではありません($n)";
				}
				$prevhead = $head;
			}
		}
		if( index( $lines[$n - 1], '*' ) == 0 ) {
			my $wordlist_ref = JAWP::Util::GetLinkwordList( $lines[$n - 1] );
			if( @$wordlist_ref + 0 != 0 ) {
				foreach( @$wordlist_ref ) {
					my ( $linktype, $word ) = JAWP::Util::GetLinkType( $_, $titlelist );
					if( $linktype eq 'redlink' ) {
						push @result, "($word)は赤リンクです($n)";
					}
				}
				$wordlist_ref->[0] =~ s/ \(.+\)$//;
				if( index( $wordlist_ref->[0], 'Wikipedia:索引' ) < 0 ) {
					if( !( $wordlist_ref->[0] =~ /^[ぁ-ゟァ-ヿA-Za-z!"#\$%&'\(\)\*\+,\-\.\/！”＃＄％＆’\（\）＋，．／：；＜＝＞\？\｛\｜\｝・ 　]+$/ ) && !( $lines[$n - 1] =~ /(\(|\（)(\[\[|)[ぁ-ゟァ-ヿ=\-]+(\]\]|)(\)|\）)/ ) ) {
						push @result, "読み仮名がありません($n)";
					}
					if( $lines[$n - 1] =~ /【(.+)】/ ) {
						if( $1 eq '曖昧' ) {
							push @result, "【曖昧】より【曖昧さ回避】が推奨されます($n)";
						}
					}
					elsif( index( $lines[$n - 1], '⇒' ) < 0 ) {
						push @result, "分野名がありません($n)";
					}
				}
			}
		}
	}

	return( \@result );
}


# 人物記事属性一覧取得
# return 属性リスト
sub Person {
	my $self = shift;
	my @list;

	return( @list ) if( $self->Namespace ne '標準' );

	my( $by, $bm, $bd ) = $self->GetBirthday;
	if( $by != 0 && $bm != 0 && $bd != 0 ) {
		push @list, sprintf( "%d年誕生", $by );
		push @list, sprintf( "%d月%d日誕生", $bm, $bd );
	}
	elsif( $self->{'text'} =~ /\[\[(Category|カテゴリ):([0-9]+)年生/i ) {
		push @list, sprintf( "%d年誕生", $2 );
	}
	my( $dy, $dm, $dd ) = $self->GetDeathday;
	if( $dy != 0 && $dm != 0 && $dd != 0 ) {
		push @list, sprintf( "%d年死去", $dy );
		push @list, sprintf( "%d月%d日死去", $dm, $dd );
	}
	elsif( $self->{'text'} =~ /\[\[(Category|カテゴリ):([0-9]+)年没/i ) {
		push @list, sprintf( "%d年死去", $2 );
	}
	if( $bm != 0 && $bd != 0 && $bm == $dm && $bd == $dd ) {
		push @list, '生没同日';
	}
	if( $self->{'text'} =~ /\[\[(Category|カテゴリ):(.*)([都道府県])出身の人物/i ) {
		push @list, sprintf( "%s%s出身の人物", $2, $3 );
	}

	return( @list );
}


################################################################################
# JAWP::TitleListクラス
################################################################################

package JAWP::TitleList;


# コンストラクタ
sub new {
	my $class = shift;

	my $self = bless( {
		'allcount'=>0,

		'標準'=>{}, '標準_曖昧'=>{}, '標準_リダイレクト'=>{},
		'利用者'=>{}, 'Wikipedia'=>{}, 'ファイル'=>{}, 'MediaWiki'=>{},
		'Template'=>{}, 'Help'=>{}, 'Category'=>{}, 'Portal'=>{}, 'プロジェクト'=>{},

		'ノート'=>{}, '利用者‐会話'=>{}, 'Wikipedia‐ノート'=>{}, 'ファイル‐ノート'=>{},
		'MediaWiki‐ノート'=>{}, 'Template‐ノート'=>{}, 'Help‐ノート'=>{},
		'Category‐ノート'=>{}, 'Portal‐ノート'=>{}, 'プロジェクト‐ノート'=>{}
		}, $class );

	return( $self );
}


################################################################################
# JAWP::DataFileクラス
################################################################################

package JAWP::DataFile;


# コンストラクタ
sub new {
	my( $class, $filename ) = @_;

	my $fh;
	open $fh, '<', $filename or die $!;

	my $self = bless( { 'filename'=>$filename, 'fh'=>$fh }, $class );

	return( $self );
}


# Article取得
# return 取得成功時はJAWP::Article、失敗時はundef
sub GetArticle {
	my $self = shift;

	my $article = new JAWP::Article;
	my $fh = $self->{'fh'};
	my $flag = 0;
	my $element = '';
	my $data = '';

	while( my $line = <$fh> ) {
		if( index( $line, '<' ) == -1 ) {
			$data .= $line;
			next;
		}

		chomp $line;
		while( $line =~ /^([^<]*)<([^>]+)>(.*)$/ ) {
			$line = $3;

			my @words = split( /\s+/, $2 );
			if( substr( $words[0], 0, 1 ) eq '/' ) {
				# close
				if( $element eq substr( $words[0], 1 ) ) {
					$data .= $1;
					if( $element eq 'title' ) {
						$article->SetTitle( $data );
						$flag |= 1;
					}
					elsif( $element eq 'timestamp' ) {
						$article->SetTimestamp( $data );
						$flag |= 2;
					}
					elsif( $element eq 'text' ) {
						$article->SetText( $data );
						$flag |= 4;
					}
				}
				$element = '';
				$data = '';
			}
			elsif( $words[@words - 1] eq '/' ) {
				# empty
			}
			else {
				# open
				$element = $words[0];
				$data = '';
			}
		}
		$data .= "$line\n";

		return( $article ) if( $flag == 7 );
	}

	close( $self->{'fh'} ) or die $!;
	open $self->{'fh'}, '<', $self->{'filename'} or die $!;

	return( undef );
}


# TitleList取得
# param $withhead 節見出しフラグ。真なら含む、偽なら含まない
# return JAWP::TitleList
sub GetTitleList {
	my( $self, $withhead ) = @_;

	my $titlelist = new JAWP::TitleList;
	my $n = 1;
	while( my $article = $self->GetArticle ) {
		print "$n\r";$n++;

		$titlelist->{'allcount'}++;

		my $namespace = $article->Namespace;
		my $title;
		if( $namespace eq '標準' ) {
			$title = $article->{'title'};
			if( $article->IsRedirect ) {
				$titlelist->{'標準_リダイレクト'}->{$title} = 1;
			}
			else {
				$titlelist->{'標準'}->{$title} = 1;

				if( $article->IsAimai ) {
					$titlelist->{'標準_曖昧'}->{$title} = 1;
				}
			}
		}
		else {
			$article->{'title'} =~ /:(.*)$/;
			$title = $1;
			$titlelist->{$namespace}->{$title} = 1;
		}
		if( $withhead ) {
			foreach my $head ( @{ JAWP::Util::GetHeadList( $article->{'text'} ) }, @{ JAWP::Util::GetIDList( $article->{'text'} ) } ) {
				$titlelist->{$namespace}->{"$title#$head"} = 1;
			}
		}
	}
	print "\n";

	return( $titlelist );
}


################################################################################
# JAWP::ReportFileクラス
################################################################################

package JAWP::ReportFile;


# コンストラクタ
# param $filename レポートファイル名
sub new {
	my( $class, $filename ) = @_;

	my $fh;
	open $fh, '>', $filename or die $!;

	my $self = bless( { 'filename'=>$filename, 'fh'=>$fh }, $class );

	return( $self );
}


# Wiki形式レポート出力
# param $title レポート見出し
# param $data_ref レポートデータへのリファレンス
sub OutputWiki {
	my( $self, $title, $data_ref ) = @_;

	my $fh = $self->{'fh'};
	print $fh "== $title ==\n" or die $!;
	print $fh "$$data_ref\n" or die $!;
	print $fh "\n" or die $!;
}


# Wiki形式リストレポート出力
# param $title レポート見出し
# param $datalist_ref レポートデータ配列へのリファレンス
sub OutputWikiList {
	my( $self, $title, $datalist_ref ) = @_;

	my $fh = $self->{'fh'};
	print $fh "== $title ==\n" or die $!;
	foreach my $data ( @$datalist_ref ) {
		print $fh "*$data\n" or die $!;
	}
	print $fh "\n" or die $!;
}


# レポート直接出力
# param $text 文字列
sub OutputDirect {
	my( $self, $text ) = @_;

	my $fh = $self->{'fh'};
	print $fh $text or die $!;
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

	return( $text );
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

	return( $str );
}


# ハッシュのソート
# param $hash_ref ハッシュへのリファレンス
# param $by 比較タイプ。真なら数値、偽なら文字列。未定義なら数値
# param $order ソート順。真なら昇順、偽なら降順。未定義なら昇順
# return ソート結果配列へのリファレンス
sub SortHash {
	my( $hash_ref, $by, $order ) = @_;

	my @result;
	if( !defined( $by ) || $by ) {
		if( !defined( $order ) || $order ) {
			@result = sort { ( $hash_ref->{$a} <=> $hash_ref->{$b} ) } keys %$hash_ref;
		}
		else {
			@result = sort { ( $hash_ref->{$b} <=> $hash_ref->{$a} ) } keys %$hash_ref;
		}
	}
	else {
		if( !defined( $order ) || $order ) {
			@result = sort { ( $hash_ref->{$a} cmp $hash_ref->{$b} ) } keys %$hash_ref;
		}
		else {
			@result = sort { ( $hash_ref->{$b} cmp $hash_ref->{$a} ) } keys %$hash_ref;
		}
	}

	return( \@result );
}


# リンク語リストの取得
# param $text 元テキスト
# param $withhead 節見出しフラグ。真なら含む、偽なら含まない
# return リンク語リスト
sub GetLinkwordList {
	my( $text, $withhead ) = @_;

	my @wordlist;
	while( $text =~ /\[\[(.*?)(\||\]\])/g ) {
		next if( $1 =~ /[\[\{\}]/ );
		my $word = $1;
		if( $word =~ s/(#.*?)$// && $withhead && $1 ne '' ) {
			my $tmp = Encode::encode( 'utf-8', $1 );
			$tmp =~ s/\.([0-9a-fA-F][0-9a-fA-F])/pack("C",hex($1))/eg;
			$word .= Encode::decode( 'utf-8', $tmp );;
		}
		$word =~ s/[ _　‎]+/ /g;
		$word =~ s/^( +|)(.*?)( +|)$/$2/;
		$word = ucfirst( $word );

		if( $word ne '' ) {
			push @wordlist, JAWP::Util::DecodeURL( $word );
		}
	}

	return( \@wordlist );
}


# カテゴリ呼出し語リストの取得
# param $text 元テキスト
# return カテゴリリスト
sub GetCategorywordList {
	my $text = shift;

	my @wordlist;
	for my $word ( @{ JAWP::Util::GetLinkwordList( $text ) } ) {
		if( $word =~ /^(Category|カテゴリ):(.*)$/i ) {
			push @wordlist, $2;
		}
	}

	return( \@wordlist );
}


# テンプレート呼出し語リストの取得
# param $text 元テキスト
# return リンク語リスト
sub GetTemplatewordList {
	my $text = shift;

	my @wordlist;
	while( $text =~ /\{\{(.*?)(\||\}\})/g ) {
		next if( index( $1, 'DEFAULTSORT' ) == 0 || index( $1, 'デフォルトソート' ) == 0 );
		my $word = $1;
		$word =~ s/[_　‎]/ /g;
		$word =~ s/^( +|)(.*?)( +|)$/$2/;
		$word = ucfirst( $word );

		if( $word ne '' ) {
			push @wordlist, JAWP::Util::DecodeURL( $word );
		}
	}

	return( \@wordlist );
}


# 外部リンクリストの取得
# param $text 元テキスト
# return 外部リンクリスト
sub GetExternallinkList {
	my $text = shift;

	my @linklist = $text =~ /s?https?:\/\/[-_.!~*'()a-zA-Z0-9;\/?:\@&=+\$,%#]+/g;

	return( \@linklist );
}


# URLのホストの取得
# param $url URL
# return ホスト
sub GetHost {
	my $url = shift;

	if( $url =~ /s?https?:\/\/([-_.!~*'()a-zA-Z0-9;?:\@&=+\$,%#]+)/ ) {
		return( $1 );
	}
	else {
		return( undef );
	}
}


# リンク種別判別
# param $word リンク語
# param $titlelist JAWP::TitleListオブジェクト
# return リンク種別、リンク語
sub GetLinkType {
	my( $word, $titlelist ) = @_;

	my $pos = index( $word, ':' );
	my $ucword;
	if( $pos >= 0 ) {
		$ucword = substr( $word, 0, $pos + 1 ) . ucfirst( substr( $word, $pos + 1 ) );
	}
	else {
		$ucword = ucfirst( $word );
	}

	if( defined( $titlelist->{'標準'}->{$ucword} ) ) {
		if( defined( $titlelist->{'標準_曖昧'}->{$ucword} ) ) {
			return( 'aimai', $ucword );
		}
		else {
			return( '標準', $ucword );
		}
	}
	elsif( defined( $titlelist->{'標準_リダイレクト'}->{$ucword} ) ) {
		return( 'redirect', $ucword );
	}
	elsif( $ucword =~ /^(Category|カテゴリ):(.*)/i ) {
		return( 'category', $2 ) if( defined( $titlelist->{'Category'}->{$2} ) );
	}
	elsif( $ucword =~ /^(ファイル|画像|メディア|file|image|media):(.*)/i ) {
		return( 'file', $2 ) if( defined( $titlelist->{'ファイル'}->{$2} ) );
	}
	elsif( $ucword =~ /^(Template|テンプレート):(.*)/i ) {
		return( 'template', $2 ) if( defined( $titlelist->{'Template'}->{$2} ) );
	}
	elsif( $word =~ /^(Help|ヘルプ|MediaWiki|Portal|Wikipedia|プロジェクト|Project):/i
		|| $word =~ /^(Special|特別|利用者|User|ノート|トーク|talk|利用者‐会話|利用者・トーク|User talk|Wikipedia‐ノート|Wikipedia・トーク|Wikipedia talk|ファイル‐ノート|ファイル・トーク|画像‐ノート|File talk|Image Talk|MediaWiki‐ノート|MediaWiki・トーク|MediaWiki talk|Template‐ノート|Template talk|Help‐ノート|Help talk|Category‐ノート|Category talk|カテゴリ・トーク|Portal‐ノート|Portal・トーク|Portal talk|プロジェクト‐ノート|Project talk):/i
		|| $word =~ /^(aa|ab|ace|af|ak|als|am|an|ang|ar|arc|arz|as|ast|av|ay|az|ba|bar|bat\-smg|bcl|be|be\-x\-old|bg|bh|bi|bjn|bm|bn|bo|bpy|br|bs|bug|bxr|ca|cbk\-zam|cdo|ce|ceb|ch|cho|chr|chy|ckb|co|cr|crh|cs|csb|cu|cv|cy|da|de|diq|dsb|dv|dz|ee|el|eml|en|eo|es|et|eu|ext|fa|ff|fi|fiu\-vro|fj|fo|fr|frp|frr|fur|fy|ga|gag|gan|gd|gl|glk|gn|got|gu|gv|ha|hak|haw|he|hi|hif|ho|hr|hsb|ht|hu|hy|hz|ia|id|ie|ig|ii|ik|ilo|io|is|it|iu|ja|jbo|jp|jv|ka|kaa|kab|kbd|kg|ki|kj|kk|kl|km|kn|ko|koi|kr|krc|ks|ksh|ku|kv|kw|ky|la|lad|lb|lbe|lg|li|lij|lmo|ln|lo|lt|ltg|lv|map\-bms|mdf|mg|mhr|mi|mk|ml|mn|mo|mr|mrj|ms|mt|mwl|my|myv|mzn|na|nah|nan|nap|nb|nds|nds\-nl|ne|new|ng|nl|nn|no|nov|nrm|nso|nv|ny|oc|om|or|os|pa|pag|pam|pap|pcd|pdc|pfl|pi|pih|pl|pms|pnb|pnt|ps|pt|qu|rm|rmy|rn|ro|roa\-rup|roa\-tara|ru|rue|rw|sa|sah|sc|scn|sco|sd|se|sg|sh|si|simple|sk|sl|sm|sn|so|sq|sr|srn|ss|st|stq|su|sv|sw|szl|ta|te|tet|tg|th|ti|tk|tl|tn|to|tpi|tr|ts|tt|tum|tw|ty|udm|ug|uk|ur|uz|ve|vec|vi|vls|vo|wa|war|wo|wuu|xal|xh|xmf|yi|yo|za|zea|zh|zh\-cfr|zh\-classical|zh\-cn|zh\-min\-nan|zh\-tw|zh\-yue|zu):/i # 言語間リンク
		|| $word =~ /^(acronym|appropedia|arxiv|b|betawiki|betawikiversity|botwiki|bugzilla|centralwikia|choralwiki|citizendium|commons|comune|cz|dictionary|doi|evowiki|finalfantasy|foundation|google|imdbname|imdbtitle|incubator|irc|ircrc|iso639\-3|jameshoward|luxo|m|mail|mailarchive|marveldatabase|meatball|mediazilla|memoryalpha|minnan|mozillawiki|mw|n|oeis|oldwikisource|orthodoxwiki|otrswiki|outreach|planetmath|q|rev|s|scores|sep11|smikipedia|species|strategy|strategywiki|sulutil|svn|tenwiki|testwiki|tools|translatewiki|tswiki|usability|v|w|wiki|wikia|wikiasite|wikibooks|wikicities|wikifur|wikilivres|wikimedia|wikinews|wikinvest|wikiquote|wikisource|wikispecies|wikispot|wikitech|wikitravel|wikiversity|wikiwikiweb|wikt|wiktionary|wipipedia|wm2005|wm2006|wm2007|wm2008|wm2009|wm2010|wm2011|wm2012|wmania|wmf|wookieepedia):/i # 特殊リンク
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
# return 見出し語リスト配列へのリファレンス
sub GetHeadList {
	my $text = shift;

	my @headlist;
	while( $text =~ /^=+([^=]+?)=+ *$/mg ) {
        my $tmp = $1;
        $tmp =~ s/^ *//;
        $tmp =~ s/ *$//;
        if( $tmp ne '' ) {
			push @headlist, $tmp;
        }
	}

	return( \@headlist );
}


# idリストの取得
# param $text 元テキスト
# return idリスト配列へのリファレンス
sub GetIDList {
	my $text = shift;

	my @idlist;
	while( $text =~ /id="(.*?)"/g ) {
        my $tmp = $1;
        $tmp =~ s/^ *//;
        $tmp =~ s/ *$//;
        if( $tmp ne '' ) {
			push @idlist, $tmp;
        }
	}

	return( \@idlist );
}


# 発言タイムスタンプリストの取得
# param $text 元テキスト
# return 発言タイムスタンプリスト配列へのリファレンス
sub GetTalkTimestampList {
	my $text = shift;

	my @timestamplist;
	while( $text =~ /([0-9]{4})年([0-9]{1,2})月([0-9]{1,2})日.{5}([0-9]{2}):([0-9]{2}) \(UTC\)/g ) {
		push @timestamplist, sprintf( "%04d-%02d-%02dT%02d:%02d:00Z", $1, $2, $3, $4, $5 );
	}

	if( @timestamplist + 0 != 0 ) {
		@timestamplist = sort @timestamplist;
		return( \@timestamplist );
	}
	else {
		return( [] );
	}
}


# バイト数の取得
# param $text 元テキスト
# return バイト数
sub GetBytes {
	my $text = shift;

	return( length( Encode::encode( 'utf-8', $text ) ) );
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
	elsif( $argv[0] eq 'lint-redirect' ) {
		LintRedirect( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'lint-index' ) {
		LintIndex( $argv[1], $argv[2] );
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
	elsif( $argv[0] eq 'person' ) {
		Person( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'noindex' ) {
		NoIndex( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'index-list' ) {
		IndexList( $argv[1], $argv[2] );
	}
	elsif( $argv[0] eq 'aimai' ) {
		Aimai( $argv[1], $argv[2] );
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
  lint-redirect
  lint-index
  statistic
  titlelist
  living-noref
  passed-sakujo
  person
  noindex
  index-list
  aimai
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

	$report->OutputDirect( <<"STR"
= 記事名lint =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile を[http://sourceforge.jp/projects/jawptool/ jawptool $VERSION]にて記事名の誤りの可能性について検査したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

プログラムで機械的に検査しているため、修正すべきでない記事についても検出されている可能性は大いにあります。この一覧を元に修正を行う場合は、個別にその修正が行われるべきか、十分に検討してから行うようにお願いします。また、修正は必ず各方針・ガイドラインに従って行ってください。本プログラムの開発時より後に方針・ガイドラインが更新されている可能性もあることを留意下さい。

STR
	);

	my $n = 1;
	while( my $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		my $result_ref = $article->LintTitle;
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
	my $titlelist = $jawpdata->GetTitleList( 1 );
	my $report = new JAWP::ReportFile( $reportfile );

	$report->OutputDirect( <<"STR"
= 記事本文lint =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile を[http://sourceforge.jp/projects/jawptool/ jawptool $VERSION]にて本文の誤りの可能性について検査したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

プログラムで機械的に検査しているため、修正すべきでない記事についても検出されている可能性は大いにあります。この一覧を元に修正を行う場合は、個別にその修正が行われるべきか、十分に検討してから行うようにお願いします。また、修正は必ず各方針・ガイドラインに従って行ってください。本プログラムの開発時より後に方針・ガイドラインが更新されている可能性もあることを留意下さい。

STR
	);

	my $lintcount = 0;
	my $n = 1;
	while( my $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		my $result_ref = $article->LintText( $titlelist );
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


# リダイレクト文法チェック
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub LintRedirect {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $titlelist = $jawpdata->GetTitleList( 1 );
	my $report = new JAWP::ReportFile( $reportfile );

	$report->OutputDirect( <<"STR"
= リダイレクトlint =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile を[http://sourceforge.jp/projects/jawptool/ jawptool $VERSION]にてリダイレクトの誤りの可能性について検査したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

プログラムで機械的に検査しているため、修正すべきでない記事についても検出されている可能性は大いにあります。この一覧を元に修正を行う場合は、個別にその修正が行われるべきか、十分に検討してから行うようにお願いします。また、修正は必ず各方針・ガイドラインに従って行ってください。本プログラムの開発時より後に方針・ガイドラインが更新されている可能性もあることを留意下さい。

STR
	);

	my %result = ( 'aimai'=>[], 'note'=>[], 'redlink'=>[] );
	my $n = 1;
	while( my $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		next if( !$article->IsRedirect );

		my $wordlist_ref = JAWP::Util::GetLinkwordList( $article->{'text'}, 1 );
		if( @$wordlist_ref + 0 > 0 ) {
			my ( $linktype, $word ) = JAWP::Util::GetLinkType( $wordlist_ref->[0], $titlelist );
			if( $linktype eq 'redlink' ) {
				push @{$result{'redlink'}}, "[[$article->{'title'}]]⇒[[$word]]";
			}
		}
	}
	print "\n";
	$titlelist = undef;

	$report->OutputWikiList( '赤リンクへのリダイレクト', $result{'redlink'} );
}


# 索引文法チェック
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub LintIndex {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $titlelist = $jawpdata->GetTitleList;
	my $report = new JAWP::ReportFile( $reportfile );

	$report->OutputDirect( <<"STR"
= 索引文法lint =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile を[http://sourceforge.jp/projects/jawptool/ jawptool $VERSION]にて索引の誤りの可能性を検査したもので、[[Wikipedia:索引]]の支援を行うためのものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	foreach my $namespace ( '利用者', '利用者‐会話', 'Wikipedia', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki', 'MediaWiki‐ノート', 'Template‐ノート', 'Help', 'Help‐ノート', 'Category‐ノート', 'Portal', 'Portal‐ノート', 'プロジェクト', 'プロジェクト‐ノート' ) {
		$titlelist->{$namespace} = {};
	}

	my $n = 1;
	while( my $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		my $result_ref = $article->LintIndex( $titlelist );
		if( @$result_ref != 0 ) {
			$report->OutputWikiList( "[[$article->{'title'}]]", $result_ref );
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
	my $text;

	$report->OutputDirect( <<"STR"
= 統計 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile を[http://sourceforge.jp/projects/jawptool/ jawptool $VERSION]にて集計したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	$text = StatisticReportSub1( $titlelist, $report );
	$report->OutputWiki( '名前空間別ファイル数', \$text );
	foreach my $namespace ( '利用者', '利用者‐会話', 'Wikipedia', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki', 'MediaWiki‐ノート', 'Template‐ノート', 'Help', 'Help‐ノート', 'Category‐ノート', 'Portal', 'Portal‐ノート', 'プロジェクト', 'プロジェクト‐ノート' ) {
		$titlelist->{$namespace} = {};
	}

	my( %linkcount, %headcount );
	foreach my $linktype ( '発リンク', '標準', 'aimai', 'redirect', 'category', 'file', 'template', 'redlink', 'externalhost' ) {
		$linkcount{$linktype} = {};
	}
	my $timestamplist_ref;
	my( %subpagecount, %talkcount );
	foreach my $subpagetype ( '井戸端', '削除依頼', 'CheckUser依頼', '投稿ブロック依頼', '管理者への立候補', 'コメント依頼', '査読依頼' ) {
		$subpagecount{$subpagetype} = {};
		$talkcount{$subpagetype} = {};
	}
	my $n = 1;
	while( my $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		$article->{'text'} =~ s/<math.*?<\/math>//sg;
		$article->{'text'} =~ s/<pre.*?<\/pre>//sg;
		$article->{'text'} =~ s/<code.*?<\/code>//sg;
		$article->{'text'} =~ s/{{{.*?}}}//sg;

		my %count = ();
		my $linktype;
		my $linkwordlist_ref = JAWP::Util::GetLinkwordList( $article->{'text'} );
		if( $article->Namespace eq '標準' ) {
			$linkcount{'発リンク'}->{$article->{'title'}} = @$linkwordlist_ref + 0;
		}
		foreach my $word ( grep { ++$count{$_} == 1 } @$linkwordlist_ref ) {
			( $linktype, $word ) = JAWP::Util::GetLinkType( $word, $titlelist );
			$linkcount{$linktype}->{$word}++ if( $linktype ne 'none' );
		}

		foreach my $word ( grep { ++$count{$_} == 1 }@{ JAWP::Util::GetTemplatewordList( $article->{'text'} ) } ) {
			$linkcount{template}->{$word}++ if( defined( $titlelist->{'Template'}->{$word} ) );
		}

		foreach my $word ( @{ JAWP::Util::GetExternallinkList( $article->{'text'} ) } ) {
			$word = JAWP::Util::GetHost( $word );
			$linkcount{'externalhost'}->{$word}++ if( defined( $word ) );
		}

		foreach my $word ( @{ JAWP::Util::GetHeadList( $article->{'text'} ) } ) {
			$headcount{$word}++;
		}

		my $subpagetype = $article->SubpageType;
		if( $subpagetype ne '' ) {
			$timestamplist_ref = JAWP::Util::GetTalkTimestampList( $article->{'text'} );
			if( @$timestamplist_ref + 0 ) {
				$subpagecount{$subpagetype}->{substr( $timestamplist_ref->[0], 0, 7 )}++;
				$talkcount{$subpagetype}->{substr( $timestamplist_ref->[0], 0, 7 )} += ( @$timestamplist_ref + 0 );
			}
		}
	}
	print "\n";

	undef $titlelist;

	$text = StatisticReportSub2( $linkcount{'発リンク'}, '', 1 );
	$report->OutputWiki( '発リンク数ランキング', \$text );
	$linkcount{'発リンク'} = {};
	$text = StatisticReportSub2( $linkcount{'標準'}, '', 1 );
	$report->OutputWiki( '被リンク数ランキング', \$text );
	$linkcount{'標準'} = {};
	$text = StatisticReportSub2( $linkcount{'redirect'}, '', 1 );
	$report->OutputWiki( 'リダイレクト呼出数ランキング', \$text );
	$linkcount{'redirect'} = {};
	$text = StatisticReportSub2( $linkcount{'aimai'}, '', 1 );
	$report->OutputWiki( '曖昧さ回避呼出数ランキング', \$text );
	$linkcount{'aimai'} = {};
	$text = StatisticReportSub2( $linkcount{'redlink'}, '', 1 );
	$report->OutputWiki( '赤リンク数ランキング', \$text );
	$linkcount{'redlink'} = {};
	$text = StatisticReportSub2( $linkcount{'category'}, ':Category:', 1 );
	$report->OutputWiki( 'カテゴリ使用数ランキング', \$text );
	$linkcount{'category'} = {};
	$text = StatisticReportSub2( $linkcount{'file'}, ':ファイル:', 1 );
	$report->OutputWiki( 'ファイル使用数ランキング', \$text );
	$linkcount{'file'} = {};
	$text = StatisticReportSub2( $linkcount{'template'}, ':Template:', 1 );
	$report->OutputWiki( 'テンプレート使用数ランキング', \$text );
	$linkcount{'template'} = {};
	$text = StatisticReportSub2( $linkcount{'externalhost'}, '', 0 );
	$report->OutputWiki( '外部リンクホストランキング', \$text );
	$linkcount{'externalhost'} = {};
	$text = StatisticReportSub2( \%headcount, '', $report, 0 );
	$report->OutputWiki( '見出し語ランキング', \$text );
	%headcount = ();

	foreach my $subpagetype ( '井戸端', '削除依頼', 'CheckUser依頼', '投稿ブロック依頼', '管理者への立候補', 'コメント依頼', '査読依頼' ) {
		$text = StatisticReportSub3( $subpagecount{$subpagetype}, $talkcount{$subpagetype} );
		$report->OutputWiki( $subpagetype, \$text );
	}
}


# データ統計レポート出力サブモジュール1
# param $titlelist JAWP::TitleListオブジェクト
# return $text レポートテキスト
sub StatisticReportSub1 {
	my( $titlelist ) = @_;

	my $text = sprintf( <<"TEXT"
{| class="wikitable" style="text-align:right"
! colspan="2" | 本体 !! colspan="2" | ノート
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

	return( $text );
}


# データ統計レポート出力サブモジュール2
# param $data_ref データハッシュへのリファレンス
# param $prefix リンク出力時のプレフィックス
# param $innerlink 内部リンク化フラグ
# return $text レポートテキスト
sub StatisticReportSub2 {
	my( $data_ref, $prefix, $innerlink ) = @_;

	delete $data_ref->{''};
	my $data2_ref = JAWP::Util::SortHash( $data_ref, 1, 0 );
	my $text = '';
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

	return( $text );
}


# データ統計レポート出力サブモジュール3
# param $subpagecount_ref サブページ数ハッシュへのリファレンス
# param $talkcount_ref 発言数ハッシュへのリファレンス
# return $text レポートテキスト
sub StatisticReportSub3 {
	my( $subpagecount_ref, $talkcount_ref ) = @_;
	my $text = <<'TEXT';
{| class="wikitable" style="text-align:right"
! 年月 !! サブページ数 !! 発言数 !! 発言数/サブページ数
TEXT
	foreach my $ym ( sort keys %$subpagecount_ref ) {
		$text .= "|-\n";
		$text .= sprintf( "|%s || %d || %d || %2.1f\n", $ym, $subpagecount_ref->{$ym}, $talkcount_ref->{$ym}, $talkcount_ref->{$ym} / $subpagecount_ref->{$ym} );
	}
	$text .= '|}';

	return( $text );
}


# タイトル一覧
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub TitleList {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $titlelist = $jawpdata->GetTitleList;
	my %varname = (
		'標準'=>'article', '標準_曖昧'=>'aimai', '標準_リダイレクト'=>'redirect',
		'利用者'=>'user', 'Wikipedia'=>'wikipedia', 'ファイル'=>'file', 'MediaWiki'=>'mediawiki',
		'Template'=>'template', 'Help'=>'help', 'Category'=>'category', 'Portal'=>'portal', 'プロジェクト'=>'project',

		'ノート'=>'note', '利用者‐会話'=>'user_talk', 'Wikipedia‐ノート'=>'wikipedia_note', 'ファイル‐ノート'=>'file_note',
		'MediaWiki‐ノート'=>'mediawiki_note', 'Template‐ノート'=>'template_note', 'Help‐ノート'=>'help_note',
		'Category‐ノート'=>'category_note', 'Portal‐ノート'=>'portal_note', 'プロジェクト‐ノート'=>'project_note' );

	foreach my $namespace ( keys %varname ) {
		my $report = new JAWP::ReportFile( sprintf( "%s_%s.pl", $reportfile, $varname{$namespace} ) );
		$report->OutputDirect( "use utf8;\n" );
		$report->OutputDirect( "\$xmlfile = '$xmlfile';\n" );
		$report->OutputDirect( sprintf( "\$%s = {\n", $varname{$namespace} ) );
		foreach( keys %{$titlelist->{$namespace}} ) {
			s/\\/\\\\/g;
			s/'/\\'/g;
			$report->OutputDirect( "'$_'=>1,\n" );
		}
		$report->OutputDirect( "''=>1 };\n\n" );
	}
}


# 出典の無い存命人物一覧
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub LivingNoref {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $report = new JAWP::ReportFile( $reportfile );

	$report->OutputDirect( <<"STR"
= 出典の無い存命人物一覧 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile から[http://sourceforge.jp/projects/jawptool/ jawptool $VERSION]にて出典の無い存命人物を抽出したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	my $livingcount = 0;
	my $livingnorefcount = 0;
	my @livingnoreflist;
	my $n = 1;
	while( my $article = $jawpdata->GetArticle ) {
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

	$report->OutputWikiList( '一覧', \@livingnoreflist );
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

	$report->OutputDirect( <<"STR"
= 長期間経過した削除依頼 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile から[http://sourceforge.jp/projects/jawptool/ jawptool $VERSION]にて長期間経過した削除依頼を抽出したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	my $time = time();
	my @datalist;
	my $n = 1;
	while( my $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		next if( $article->Namespace ne '標準' );

		if( $article->IsSakujo && $article->GetPassTime( $time ) gt '0000-03-00T00:00:00Z' ) {
			push @datalist, "[[$article->{'title'}]]";
		}
	}
	print "\n";

	$report->OutputWikiList( '一覧', \@datalist );
}


# 人物一覧
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub Person {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $report = new JAWP::ReportFile( $reportfile );

	$report->OutputDirect( <<"STR"
= 人物一覧 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile から[http://sourceforge.jp/projects/jawptool/ jawptool $VERSION]にて人物一覧記事に未掲載の人物記事を抽出したもので、[[生没同日]]・年記事・月日記事都道府県記事の支援を行うためのものです。「死亡年月日と没年齢テンプレート」の記載を元に抽出しているため、抽出漏れもありえます。あくまでも支援ツールの一つとしてお使い下さい。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	my( %list, %linklist );
	my $n = 1;
	while( my $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		foreach my $key ( $article->Person ) {
			next if( $key =~ /[0-9]+月[0-9]+日[誕生|死去]/ || $key =~ /(19[0-9]{2}|[2-9][0-9]{3})年/  || $key =~ /[都道府県]出身の人物/ );
			if( !defined( $list{$key} ) ) {
				$list{$key} = [];
			}
			push @{$list{$key}}, $article->{'title'};
		}

		if( $article->{'title'} =~ /^([0-9]{1,3}|1[0-8][0-9]{2})年$/ || $article->{'title'} eq '生没同日' ) {
			$linklist{$article->{'title'}} = JAWP::Util::GetLinkwordList( $article->{'text'} );
		}
	}
	print "\n";

	my @datalist;

	foreach my $key ( sort grep { /^[0-9]+年$/ } keys %linklist ) {
		@datalist = ();
		foreach my $title ( @{$list{$key . '誕生'}} ) {
			if( !( grep { $_ eq $title } @{ $linklist{$key} } ) ) {
				push @datalist, "[[$title]]";
			}
		}
		if( @datalist + 0 != 0 ) {
			$report->OutputWikiList( "[[$key]](誕生)", \@datalist );
		}

		@datalist = ();
		foreach my $title ( @{$list{$key . '死去'}} ) {
			if( !( grep { $_ eq $title } @{ $linklist{$key} } ) ) {
				push @datalist, "[[$title]]";
			}
		}
		if( @datalist + 0 != 0 ) {
			$report->OutputWikiList( "[[$key]](死去)", \@datalist );
		}
	}

	@datalist = ();
	foreach my $title ( @{$list{'生没同日'}} ) {
		if( !( grep { $_ eq $title } @{ $linklist{'生没同日'} } ) ) {
			push @datalist, "[[$title]]";
		}
	}
	if( @datalist + 0 != 0 ) {
		$report->OutputWikiList( '[[生没同日]]', \@datalist );
	}
}


# 索引未登録記事一覧
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub NoIndex {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $report = new JAWP::ReportFile( $reportfile );

	$report->OutputDirect( <<"STR"
= 索引未登録記事一覧 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile から[http://sourceforge.jp/projects/jawptool/ jawptool $VERSION]にて索引に登録されていない記事を抽出したもので、[[Wikipedia:索引]]の支援を行うためのものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	my( %titlelist, %indextext );
	my $n = 1;
	while( my $article = $jawpdata->GetArticle ) {
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

		if( $article->IsIndex ) {
			$indextext{$article->{'title'}} = $article->{'text'};
		}
	}
	print "\n";

	foreach( keys %indextext ) {
		foreach my $word ( @{ JAWP::Util::GetLinkwordList( $indextext{$_} ) } ) {
			delete $titlelist{$word};
		}
	}

	my @datalist = map { "[[$_]]" } @{ JAWP::Util::SortHash( \%titlelist, 0, 1 ) };
	$report->OutputWikiList( '一覧', \@datalist );
	$report->OutputDirect( sprintf( "記事数 %d\n", @datalist + 0 ) );
}


# 索引一覧
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub IndexList {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $report = new JAWP::ReportFile( $reportfile );

	$report->OutputDirect( <<"STR"
= 索引一覧 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile から[http://sourceforge.jp/projects/jawptool/ jawptool $VERSION]にて索引の一覧を抽出したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

STR
	);

	my %indexlist;
	my $n = 1;
	while( my $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		next if( !$article->IsIndex );

		$indexlist{$article->{'title'}} = JAWP::Util::GetBytes( $article->{'text'} );
	}
	print "\n";

	my @datalist = map { "[[$_]]($indexlist{$_})" } @{ JAWP::Util::SortHash( \%indexlist, 1, 0 ) };
	$report->OutputWikiList( '一覧', \@datalist );
	$report->OutputDirect( sprintf( "索引数 %d\n", @datalist + 0 ) );
}


# 曖昧さ回避
# param $xmlfile 入力XMLファイル名
# param $reportfile レポートファイル名
sub Aimai {
	my( $xmlfile, $reportfile ) = @_;
	my $jawpdata = new JAWP::DataFile( $xmlfile );
	my $report = new JAWP::ReportFile( $reportfile );

	$report->OutputDirect( <<"STR"
= 曖昧さ回避 =
このレポートは http://dumps.wikimedia.org/jawiki/ にて公開されているウィキペディア日本語版データベースダンプ $xmlfile から[http://sourceforge.jp/projects/jawptool/ jawptool $VERSION]にて曖昧さ回避記事に登録されていない記事を抽出したものです。

過去の一時点でのダンプを対象に集計していますので、現在のウィキペディア日本語版の状態とは異なる可能性があります。

プログラムで機械的に検査しているため、掲載すべきでない記事についても検出されている可能性は大いにあります。この一覧を元に編集を行う場合は、個別にその編集が行われるべきか、十分に検討してから行うようにお願いします。

STR
	);

	my( %aimailist, %aimailinklist );
	my $n = 1;
	while( my $article = $jawpdata->GetArticle ) {
		print "$n\r"; $n++;

		next if( $article->Namespace ne '標準' );

		my $title = $article->{'title'};
		$title =~ s/ \(.*\)$//;
		if( $title =~ /立(.*)(高等学校|中学校|小学校)$/ ) {
			$title = "$1$2";
		}
		if( defined( $aimailist{$title} ) ) {
			push @{$aimailist{$title}}, $article->{'title'};
		}
		else {
			$aimailist{$title} = [ $article->{'title'} ];
		}

		if( $article->IsAimai ) {
			$aimailinklist{$article->{'title'}} = JAWP::Util::GetLinkwordList( $article->{'text'} );
		}
	}
	print "\n";

	foreach my $title ( keys %aimailinklist ) {
		my $title2 = $title;
		$title2 =~ s/ \(.*\)$//;
		my @datalist;
		foreach my $word ( @{$aimailist{$title2}} ) {
			if( !( grep { $word eq $_ } @{$aimailinklist{$title}} ) && $title ne $word ) {
				push @datalist, "[[$word]]";
			}
		}
		if( @datalist != 0 ) {
			$report->OutputWikiList( "[[$title]]", \@datalist );
		}
	}
}


################################################################################
# JAWP::CGIAppクラス
################################################################################

package JAWP::CGIApp;


# CGIアプリ実行
sub Run {
	my $cgi = new CGI;

	my $wikitext = Encode::decode( 'utf-8', $cgi->param( 'wikitext' ) );
	my $resulttext;
	if( $wikitext ) {
		$wikitext =~ s/\x0D\x0A|\x0D|\x0A/\n/g;
		my $titlelist = new JAWP::TitleList;
		if( -f 'titlelist_aimai.pl' ) {
			our $aimai;
			require 'titlelist_aimai.pl';
			$titlelist->{'標準_曖昧'} = $aimai;
		}
		if( -f 'titlelist_category.pl' ) {
			our $category;
			require 'titlelist_category.pl';
			$titlelist->{'Category'} = $category;
		}
		if( -f 'titlelist_template.pl' ) {
			our $template;
			require 'titlelist_template.pl';
			$titlelist->{'Template'} = $template;
		}
		my $article = new JAWP::Article;
		$article->SetText( $wikitext );
		my $result_ref = $article->LintText( $titlelist );

		$resulttext = '<p>■チェック結果</p><ul>';
		foreach( @$result_ref ) {
			$resulttext .= "<li>$_</li>";
		}
		$resulttext .= '</ul><hr>';

		$wikitext = $cgi->escapeHTML( $wikitext );
	}
	else {
		$resulttext = $wikitext = '';
	}

	print <<"HTML";
Content-Type: text/html; charset=utf-8;

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title>jawp-lint.cgi/ウィキペディア日本語版文法チェックCGI</title>
</head>
<body>
<h1>jawp-lint.cgi/ウィキペディア日本語版文法チェックCGI</h1>
<p>
このCGIは、ウィキペディア日本語版記事本文のウィキ文法及びスタイルが適切であるかどうかを調べるものです。プログラムで機械的に検査しているため、修正すべきでない記事についても検出されている可能性は大いにあります。このチェック結果を元に修正を行う場合は、個別にその修正が行われるべきか、十分に検討してから行うようにお願いします。また、修正は必ず各方針・ガイドラインに従って行ってください。本プログラムの開発時より後に方針・ガイドラインが更新されている可能性もあることを留意下さい。
</p>
<hr>
$resulttext
<form action="jawp-lint.cgi" method="post">
<p>■ウィキテキスト</p>
<textarea name="wikitext" style="width: 600px; height: 400px;">$wikitext</textarea>
<br>
<input type="submit" value="lint">
</form>
</body>
</html>
HTML
}


1;
