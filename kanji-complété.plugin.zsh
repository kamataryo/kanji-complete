# kanji-complété — 漢字やかなのファイル名を、かな・ローマ字の「読み」で補完する zsh プラグイン
#
#   source /path/to/kanji-complété.plugin.zsh     # compinit の前でも後でもよい
#
# zstyle ':completion:*' completer の _complete を _yomi に置き換える。_yomi は次の 2 つを合わせた候補を出す
#   _kana  ひらがな⇔カタカナを区別しない、ふつうの補完（ファイル名以外にも効く）
#   読み   漢字やかなを含むファイル名を読みで補完する（要 mecab または kakasi）
#            かなで入力     → 読みと前方一致
#            英小文字で入力 → ローマ字読みと前方一致（ヘボン式・訓令式どちらでも。si/shi, tu/tsu, nn/n など）
#                             不要なら zstyle ':completion:*' yomi-romaji no
#
# completer を自分で設定している場合は、その設定より後で source すること。

# ---- _kana ----------------------------------------------------------------

_kana() {
  [[ $PREFIX$SUFFIX == *[ぁ-ゖァ-ヶ]* ]] || return 1

  local c pat= ret=1
  local opre=$PREFIX osuf=$SUFFIX
  for c in ${(s::)${(Q)PREFIX}}; do
    if [[ $c == [ぁ-ゖ] ]]; then
      pat+="[$c${(#)$(( #c + 0x60 ))}]"
    elif [[ $c == [ァ-ヶ] ]]; then
      pat+="[${(#)$(( #c - 0x60 ))}$c]"
    else
      pat+=${(b)c}
    fi
  done

  PREFIX=$pat
  compstate[pattern_match]='*'
  _complete && ret=0
  (( ret )) && { PREFIX=$opre; SUFFIX=$osuf; compstate[pattern_match]='' }
  return ret
}

# ---- _yomi ----------------------------------------------------------------

# カタカナ → ローマ字の表
typeset -gA _yomi_rtab
() {
  emulate -L zsh
  local -a kana roma
  kana=( ア イ ウ エ オ カ キ ク ケ コ サ シ ス セ ソ タ チ ツ テ ト ナ ニ ヌ ネ ノ
         ハ ヒ フ ヘ ホ マ ミ ム メ モ ヤ ユ ヨ ラ リ ル レ ロ ワ ヰ ヱ ヲ ン
         ガ ギ グ ゲ ゴ ザ ジ ズ ゼ ゾ ダ ヂ ヅ デ ド バ ビ ブ ベ ボ パ ピ プ ペ ポ
         ァ ィ ゥ ェ ォ ャ ュ ョ ヮ ヴ ヵ ヶ )
  roma=( a i u e o ka ki ku ke ko sa shi su se so ta chi tsu te to na ni nu ne no
         ha hi fu he ho ma mi mu me mo ya yu yo ra ri ru re ro wa i e o n
         ga gi gu ge go za ji zu ze zo da ji zu de do ba bi bu be bo pa pi pu pe po
         a i u e o ya yu yo wa vu ka ke )
  _yomi_rtab=( ${kana:^roma}
    # 拗音など 2 文字の組
    キャ kya キュ kyu キョ kyo シャ sha シュ shu ショ sho シェ she
    チャ cha チュ chu チョ cho チェ che ニャ nya ニュ nyu ニョ nyo
    ヒャ hya ヒュ hyu ヒョ hyo ミャ mya ミュ myu ミョ myo
    リャ rya リュ ryu リョ ryo ギャ gya ギュ gyu ギョ gyo
    ジャ ja ジュ ju ジョ jo ジェ je ヂャ ja ヂュ ju ヂョ jo
    ビャ bya ビュ byu ビョ byo ピャ pya ピュ pyu ピョ pyo
    ファ fa フィ fi フェ fe フォ fo ティ ti ディ di トゥ tu ドゥ du
    ウィ wi ウェ we ウォ wo ヴァ va ヴィ vi ヴェ ve ヴォ vo )
}

# カタカナ → ローマ字（REPLY に返す）
_yomi_to_romaji() {
  local s=$1 out= r one two
  local -i i=1 n=${#1} sokuon=0
  while (( i <= n )); do
    one=${s[i]} two=${s[i,i+1]}
    if (( i < n )) && [[ -n ${_yomi_rtab[$two]} ]]; then
      r=${_yomi_rtab[$two]}; (( i += 2 ))
    elif [[ $one == ッ ]]; then
      sokuon=1; (( i++ )); continue
    elif [[ -n ${_yomi_rtab[$one]} ]]; then
      r=${_yomi_rtab[$one]}; (( i++ ))
    else
      r=${(L)one}; (( i++ ))
    fi
    (( sokuon )) && { r=${r[1]}$r; sokuon=0 }   # ッカ → kka
    out+=$r
  done
  REPLY=$out
}

# ローマ字の表記ゆれをそろえる（入力側と読み側の両方にかける）
_yomi_norm() {
  local s=${(L)1}
  s=${s//[-\'ー]/}          # 長音・区切りは無視
  s=${s//nn/n}
  s=${s//sy/sh}; s=${s//si/shi}
  s=${s//ty/ch}; s=${s//ti/chi}; s=${s//tu/tsu}
  s=${s//zy/j};  s=${s//jy/j};   s=${s//zi/ji}
  s=${s//(#b)(#s)hu/fu}; s=${s//(#b)([^sc])hu/${match[1]}fu}
  s=${s//tch/cch}            # ッチ: tchi / cchi どちらでも
  REPLY=$s
}

# ひらがな → カタカナ（REPLY に返す）
_yomi_kata() {
  local c out=
  for c in ${(s::)1}; do
    [[ $c == [ぁ-ゖ] ]] && out+=${(#)$(( #c + 0x60 ))} || out+=$c
  done
  REPLY=$out
}

# _complete の代わりに入る completer。ふつうの補完（かなの入力なら _kana）に、読みで当たったファイル名を足す
_yomi() {
  local opre=$PREFIX osuf=$SUFFIX ret=1
  _kana || _complete && ret=0
  PREFIX=$opre SUFFIX=$osuf   # _kana が成功すると PREFIX がパターンのまま残る
  [[ $_comp_tags == *(files|directories)* ]] || return ret   # ファイル名を補完する場面だけ
  _yomi_files || return ret
  # 候補の共通部分がディレクトリまでしかないまま差し込むと入力が消えるので、そのときは一覧だけ出す（次の TAB でメニュー）
  local d=; [[ $opre == */* ]] && d=${opre%/*}/
  [[ $compstate[insert] == *unambiguous && $compstate[unambiguous] != ${d}?* ]] && compstate[insert]=
  return 0
}

_yomi_files() {
  # 読み（カタカナ）を得るコマンド
  local -a yomicmd
  if (( $+commands[mecab] )); then
    yomicmd=( mecab -Oyomi )
  elif (( $+commands[kakasi] )); then
    yomicmd=( kakasi -i utf8 -o utf8 -JK -HK )
  else
    return 1
  fi

  local word=${(Q)PREFIX} dir= rawdir= base lit key mode
  [[ $word == */* ]] && { dir=${word%/*}/; rawdir=${PREFIX%/*}/ }   # rawdir は入力どおり（~ やエスケープを保つ）
  base=${word##*/}
  [[ -n $base ]] || return 1
  _yomi_kata $base; lit=$REPLY   # 入力をカタカナにそろえたもの

  if [[ $base == *[ぁ-ゖァ-ヶ]* ]]; then
    mode=kana key=$lit
  elif [[ $base == [A-Za-z0-9._\'-]## ]] &&
       zstyle -T ":completion:${curcontext}:" yomi-romaji; then
    mode=romaji
    _yomi_norm $base; key=$REPLY
  else
    return 1
  fi

  # 対象ディレクトリの中で、漢字かかなを含む名前だけを読み変換にかける
  local -a files yomi hits
  if [[ $_comp_tags == *files* ]]; then
    files=( ${~dir:-./}*(N:t) )
  else
    files=( ${~dir:-./}*(N-/:t) )   # cd などディレクトリだけを補完する場面
  fi
  files=( ${(M)files:#*[一-鿿々〆ぁ-ゖァ-ヶ]*} )
  (( $#files )) || return 1

  yomi=( "${(@f)$(print -rl -- $files | $yomicmd)}" )
  (( $#yomi == $#files )) || return 1

  local -i i
  for (( i = 1; i <= $#files; i++ )); do
    _yomi_kata $files[i]; [[ $REPLY == ${lit}* ]] && continue   # 名前そのものが当たるものは _kana か _complete が拾っている
    if [[ $mode == romaji ]]; then
      _yomi_to_romaji ${yomi[i]}; _yomi_norm $REPLY
      [[ $REPLY == ${key}* ]] && hits+=( $files[i] )
    else
      [[ ${yomi[i]} == ${key}* ]] && hits+=( $files[i] )
    fi
  done
  (( $#hits )) || return 1

  local xdir=${~dir:-./}   # -W に渡す前に ~ を展開しておく（引用符の中では展開されない）
  compadd -U -Q -f -W $xdir ${rawdir:+-p} ${rawdir:+$rawdir} -- "${(@q)hits}"
}

# ---- completer に差し込む（何度 source しても重複しない） -------------------

() {
  emulate -L zsh
  local -a c
  zstyle -g c ':completion:*' completer || c=( _complete _ignored )   # zsh の既定値
  c=( ${${c:#_kana}/#%_yomi*/_complete} )   # 2 回目からは _yomi の位置を _complete とみなす
  c[${c[(i)_complete]}]=_yomi:complete   # :complete で文脈名を complete のまま保ち、':completion::complete:*' の設定を効かせる。_complete が無ければ末尾に足す
  zstyle ':completion:*' completer $c
}
