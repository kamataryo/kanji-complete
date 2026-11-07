# 動作確認: zsh -f test.zsh   （_yomi の確認に mecab か kakasi が要る）
zmodload zsh/zpty
local plugin=${0:A:h}/kanji-complété.plugin.zsh tmp=$(mktemp -d) fail=0 got
trap 'rm -rf $tmp' EXIT

# completer への差し込み（2 回読んでも重複しない）
got=$(zsh -fc "source $plugin; source $plugin; zstyle -g c ':completion:*' completer; print -r -- \$c")
[[ $got == '_yomi:complete _ignored' ]] || { print -r -- "NG completer: $got"; fail=1 }

# 入力 → TAB 後に期待するコマンドライン（末尾に |n を付けると候補の数も確かめる）
local -a cases=(
  'ls てす'      'ls テスト.txt |1'     # _kana: ひらがな → カタカナ（読みの側で重ならない）
  'ls 東京た'    'ls 東京タワー.txt '   # _kana: 漢字まじり
  'ls ぎじ'      'ls 議事録.md '        # _yomi: かな読み
  'ls gijir'     'ls 議事録.md '        # _yomi: ローマ字読み
  'ls tuku'      'ls 机.txt '           # _yomi: 訓令式
  'ls sub/かい'  'ls sub/会議.txt '     # _yomi: ディレクトリつき
  'ls kay'       'ls カヤック.txt '     # _yomi: かなだけの名前をローマ字読みで
  'ls ka'        'ls ka|2'              # _yomi: kamata と カヤック.txt の両方。入力は消さない
  'cd tuk'       'cd 月/'               # _yomi: cd ではディレクトリだけ（机.txt は出さない）
  'ls Doc'       'ls Documents/'        # ふつうの補完はそのまま
)
mkdir -p $tmp/Documents $tmp/sub $tmp/月
touch $tmp/{テスト.txt,東京タワー.txt,議事録.md,机.txt,カヤック.txt,kamata} $tmp/sub/会議.txt

zpty z env LC_ALL=ja_JP.UTF-8 TERM=xterm zsh -f -i || { print 'NG zpty が使えない'; exit 1 }
zpty -w z "PS1='READY> '"
zpty -r z got '*READY> '
zpty -w z "cd $tmp; autoload -Uz compinit; compinit -u -D; source $plugin"
zpty -w z "_dump() { print -r -- \"\$BUFFER|\$_lastcomp[nmatches]\" >> $tmp/out; BUFFER= }; zle -N _dump; bindkey '^Y' _dump; print SET''UP"
zpty -r z got '*SETUP*READY> '
local q want
for q want in $cases; do zpty -w -n z "$q"$'\t\x19'; done   # ^Y で行を書き出す（^X は ^Xc などの頭なので使わない）
zpty -w z "print DO''NE"
zpty -r z got '*DONE*READY> '
zpty -d z

local -a out=( "${(@f)$(<$tmp/out)}" )
local -i i
for (( i = 1; i <= $#cases / 2; i++ )); do
  q=$cases[2*i-1] want=$cases[2*i]
  [[ $out[i] == $want || ${out[i]%|*} == $want ]] && print -r -- "ok  $q" || { print -r -- "NG  $q → '$out[i]'（期待: '$want'）"; fail=1 }
done
exit $fail
