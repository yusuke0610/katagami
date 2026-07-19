"""メモ本文の決定論的サマリ生成。

LLM 等の外部サービスを使わない純ロジック（ミューテーションテスト / TDD の対象）。
サンプルドメインにおける「決定論的ビジネスロジック層」の配置例。
"""

# サマリの最大長（超過分は末尾を省略記号に置き換える）
_MAX_LENGTH = 80

# 文末とみなす区切り文字（最初の 1 文をサマリとして優先する）
_SENTENCE_DELIMITERS = ("。", "\n")


def summarize(body: str) -> str:
    """本文から短いサマリを決定論的に生成する。

    規則:
    - 前後の空白を除去した本文が空なら空文字を返す
    - 最初の文（``。`` または改行まで。区切り文字自体は含めない）を候補にする
    - 候補が最大長を超える場合は最大長で切り、末尾に ``…`` を付ける
    """
    text = body.strip()
    if not text:
        return ""

    first_sentence = text
    for delimiter in _SENTENCE_DELIMITERS:
        index = first_sentence.find(delimiter)
        if index != -1:
            first_sentence = first_sentence[:index]

    first_sentence = first_sentence.strip()
    if len(first_sentence) > _MAX_LENGTH:
        return first_sentence[:_MAX_LENGTH] + "…"
    return first_sentence
