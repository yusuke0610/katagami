"""summarize（決定論的サマリ生成）のテスト。

TDD 対象（[tool.mutmut] only_mutate スコープ）のロジック。
主要分岐（空 / 1 文抽出 / 区切りなし / 最大長超過）を網羅する。
"""

from app.services.notes.summarizer import summarize


def test_empty_body_returns_empty_string() -> None:
    assert summarize("") == ""
    assert summarize("   \n  ") == ""


def test_first_sentence_is_extracted_by_kuten() -> None:
    assert summarize("最初の文。二番目の文。") == "最初の文"


def test_first_line_is_extracted_by_newline() -> None:
    assert summarize("一行目\n二行目") == "一行目"


def test_body_without_delimiter_is_returned_as_is() -> None:
    assert summarize("区切りのない短い本文") == "区切りのない短い本文"


def test_long_sentence_is_truncated_with_ellipsis() -> None:
    body = "あ" * 100
    result = summarize(body)
    assert result == "あ" * 80 + "…"
    assert len(result) == 81


def test_leading_whitespace_is_stripped() -> None:
    assert summarize("  本文です。続き。") == "本文です"
