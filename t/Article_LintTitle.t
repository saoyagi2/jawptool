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
# JAWP::Articleクラス
################################################################################

{
	# useテスト
	use_ok( 'JAWP', 'use JAWP' );

	# LintTitleテスト
	{
		my $article = new JAWP::Article;
		my $result_ref;

		# 戻り値の型確認
		$article->SetTitle( '' );
		$result_ref = $article->LintTitle;
		is( ref $result_ref, 'ARRAY', 'JAWP::Article::LintTitle(空文字列:リファレンス種別)' );

		# 標準記事空間以外は無視確認
		foreach my $namespace ( '利用者', 'Wikipedia', 'ファイル', 'MediaWiki', 'Template', 'Help', 'Category', 'Portal', 'プロジェクト', 'ノート', '利用者‐会話', 'Wikipedia‐ノート', 'ファイル‐ノート', 'MediaWiki‐ノート', 'Template‐ノート', 'Help‐ノート', 'Category‐ノート', 'Portal‐ノート', 'プロジェクト‐ノート' ) {
			$article->SetTitle( "$namespace:①" );
			$result_ref = $article->LintTitle;
			is_deeply( $result_ref, [], "JAWP::Article::LintTitle(標準記事空間以外無視,$namespace)" );
		}

		# リダイレクト記事は無視確認
		{
			$article->SetText( '#redirect[[転送先]]' );
			foreach my $type ( '株式会社', '有限会社', '合名会社', '合資会社', '合同会社' ) {
				my $title;

				$title = "あいうえお" . $type;
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [], "JAWP::Article::LintTitle(リダイレクト無視,$title)" );

				$title = $type . "あいうえお";
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [], "JAWP::Article::LintTitle(リダイレクト無視,$title)" );
			}
			{
				my $title = '～';
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [], "JAWP::Article::LintTitle(リダイレクト無視,$title)" );
			}
			foreach my $title ( '髙' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [], "JAWP::Article::LintTitle(リダイレクト無視,$title)" );
			}
		}

		# 曖昧さ回避テスト
		{
			$article->SetText( '' );
			foreach my $title ( '記事名（曖昧さ回避）' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ '曖昧さ回避の記事であればカッコは半角でないといけません' ], "JAWP::Article::LintTitle(曖昧さ回避,$title)" );
			}
			$article->SetText( '' );
			foreach my $title ( '記事名(I)', '記事名  (I)', '記事名(V)', '記事名  (V)', '記事名(X)', '記事名  (X)', '記事名(,)', '記事名  (,)' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [], "JAWP::Article::LintTitle(曖昧さ回避,$title)" );
			}
			$article->SetText( '' );
			foreach my $title ( '記事名(曖昧さ回避)', '記事名  (曖昧さ回避)' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ '曖昧さ回避の記事であればカッコの前のスペースはひとつでないといけません' ], "JAWP::Article::LintTitle(曖昧さ回避,$title)" );
			}
		}

		# 記事名に使用できる文字・文言テスト
		{
			$article->SetText( '' );
			foreach my $type ( '株式会社', '有限会社', '合名会社', '合資会社', '合同会社' ) {
				my $title;

				$title = $type;
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [], "JAWP::Article::LintTitle(文字・文言,$title)" );

				$title = "あいうえお" . $type;
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ '会社の記事であれば法的地位を示す語句を含むことは推奨されません' ], "JAWP::Article::LintTitle(文字・文言,$title)" );

				$title = $type . "あいうえお";
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ '会社の記事であれば法的地位を示す語句を含むことは推奨されません' ], "JAWP::Article::LintTitle(文字・文言,$title)" );
			}
			$article->SetText( '' );
			foreach my $title ( '　', '，', '．', '！', '？', '＆', '＠' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ '全角スペース、全角記号の使用は推奨されません' ], "JAWP::Article::LintTitle(文字・文言,$title)" );
			}
			$article->SetText( '' );
			foreach my $title ( 'Ａ', 'Ｚ', 'ａ', 'ｚ', '０', '９' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ '全角英数字の使用は推奨されません' ], "JAWP::Article::LintTitle(文字・文言,$title)" );
			}
			$article->SetText( '' );
			foreach my $title ( 'ｱ', 'ﾝ', 'ﾞ', 'ﾟ', 'ｧ', 'ｫ', 'ｬ', 'ｮ', '｡', '｢', '｣', '､' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ '半角カタカナの使用は推奨されません' ], "JAWP::Article::LintTitle(文字・文言,$title)" );
			}
			$article->SetText( '' );
			foreach my $title ( 'Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ', 'Ⅶ', 'Ⅷ', 'Ⅸ', 'Ⅹ' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ 'ローマ数字はアルファベットを組み合わせましょう' ], "JAWP::Article::LintTitle(文字・文言,$title)" );
			}
			$article->SetText( '' );
			foreach my $title ( '①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩', '⑪', '⑫', '⑬', '⑭', '⑮', '⑯', '⑰', '⑱', '⑲', '⑳' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ '丸付き数字の使用は推奨されません' ], "JAWP::Article::LintTitle(文字・文言,$title)" );
			}
			$article->SetText( '' );
			foreach my $title ( '「', '」', '『', '』', '〔', '〕', '〈', '〉', '《', '》', '【', '】' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ '括弧の使用は推奨されません' ], "JAWP::Article::LintTitle(文字・文言,$title)" );
			}
			{
				my $title = '～';
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ '波記号は〜(U+301C)を使用しましょう' ], "JAWP::Article::LintTitle(文字・文言,$title)" );
			}
			{
				my $title;

				foreach $title ( 'あへ', 'あべ', 'あぺ', 'アヘ', 'アベ', 'アペ', 'あ・ヘ', 'あ・ベ', 'あ・ペ', 'ヘ・あ', 'ベ・あ', 'ペ・あ', 'ア・へ', 'ア・べ', 'ア・ぺ', 'へ・ア', 'べ・ア', 'ぺ・ア', 'ア・力', 'ア・工', 'ア・口', 'ア・二', '力・ア', '工・ア', '口・ア', '二・ア' ) {
					$article->SetTitle( $title );
					$result_ref = $article->LintTitle;
					is_deeply( $result_ref, [], "JAWP::Article::LintTitle(文字・文言,$title)" );
				}
				foreach $title ( 'あヘ', 'あベ', 'あペ', 'ヘあ', 'ベあ', 'ペあ' ) {
					$article->SetTitle( $title );
					$result_ref = $article->LintTitle;
					is_deeply( $result_ref, [ '平仮名と「ヘ/ベ/ペ(片仮名)」が隣接しています' ], "JAWP::Article::LintTitle(文字・文言,$title)" );
				}
				foreach $title ( 'アへ', 'アべ', 'アぺ', 'へア', 'べア', 'ぺア' ) {
					$article->SetTitle( $title );
					$result_ref = $article->LintTitle;
					is_deeply( $result_ref, [ '片仮名と「へ/べ/ぺ(平仮名)」が隣接しています' ], "JAWP::Article::LintTitle(文字・文言,$title)" );
				}
				foreach $title ( 'ア力', 'ア工', 'ア口', 'ア二', '力ア', '工ア', '口ア', '二ア' ) {
					$article->SetTitle( $title );
					$result_ref = $article->LintTitle;
					is_deeply( $result_ref, [ '片仮名と「力/工/口/二(漢字)」が隣接しています' ], "JAWP::Article::LintTitle(文字・文言,$title)" );
				}
			}
			$article->SetText( '' );
			foreach my $title ( '高' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [], "JAWP::Article::LintTitle(文字・文言,$title)" );
			}
			$article->SetText( '' );
			foreach my $title ( '髙' ) {
				$article->SetTitle( $title );
				$result_ref = $article->LintTitle;
				is_deeply( $result_ref, [ sprintf( "%s(U+%04X) はJIS X 0208外の文字です", $title, ord( $title ) ) ], "JAWP::Article::LintTitle(文字・文言,$title)" );
			}
			$article->SetText( '' );
			$article->SetTitle( chr( 65536 ) );
			$result_ref = $article->LintTitle;
			is_deeply( $result_ref, [ sprintf( "%s は基本多言語面外の文字です", chr( 65536 ) ) ], "JAWP::Article::LintTitle(文字・文言,chr( 65536 ))" );
		}
	}
}
