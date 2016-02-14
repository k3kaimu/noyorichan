# のよりちゃん

[ひばりちゃん](https://github.com/tut-cc/hibarichan)にインスパイアされた感じのTwitterマルコフ連鎖botです．
ひばりちゃんと異なる点として，直前3単語を利用して次の1単語をランダムに決定しているため，文法的に自然な文章になりやすいという特徴があります．
また，botの学習・ツイート・リプライなどの各機能をそれぞれスレッドに分割することでエラーに堅牢になっています(たぶん)．

# 使用ライブラリ

* [TinySegmenter written in D](https://gist.github.com/repeatedly/33a74fcc922a1ae529ec)  by [Masahiro Nakagawa](https://github.com/repeatedly)
* [msgpack-d](https://github.com/msgpack/msgpack-d) by [Masahiro Nakagawa](https://github.com/repeatedly)
* [carbon](https://github.com/k3kaimu/carbon)
* [graphite](https://github.com/k3kaimu/graphite)

# ビルド方法

~~~~
$ dub
~~~~
