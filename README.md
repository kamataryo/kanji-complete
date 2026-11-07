# kanji-complété

漢字やかなのファイル名を、かなやローマ字の「読み」で補完する zsh プラグインです。ひらがなとカタカナも区別せずに補完します。

## インストール

```zsh
git clone https://github.com/kamataryo/kanji-complete ~/.kanji-complété
```

`~/.zshrc` に追記します。

```zsh
autoload -Uz compinit && compinit
source ~/.kanji-complété/kanji-complété.plugin.zsh
```

読みで補完するには mecab（または kakasi）が必要です。

```zsh
brew install mecab mecab-ipadic
```

## 補完例

```
ls てす<TAB>     →  ls テスト.txt
ls 東京た<TAB>   →  ls 東京タワー.txt
ls ぎじ<TAB>     →  ls 議事録.md
ls gijir<TAB>    →  ls 議事録.md
ls tuku<TAB>     →  ls 机.txt
```

ローマ字読みが不要なら `zstyle ':completion:*' yomi-romaji no` を追記してください。
