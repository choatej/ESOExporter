import pytest

from esoexporter import luadata
from esoexporter.luadata import LuaDataError


def test_nested_tables_strings_numbers_and_booleans() -> None:
    source = (
        b'-- comment\nG =\n{\n\t["a"] = { ["b"] = "x\\"y\\n", ["c"] = -1.5e2, ["d"] = true },\n'
        b"\t[7] = 0x10,\n}\n"
    )
    assert luadata.loads(source) == {"G": {"a": {"b": 'x"y\n', "c": -150.0, "d": True}, "7": 16}}


def test_sequential_keys_become_a_list_and_empty_tables_a_dict() -> None:
    data = luadata.loads(
        b'G = { ["l"] = { "a", "b", [3] = "c" }, ["e"] = {}, ["h"] = { [2] = "x" } }'
    )
    assert data["G"] == {"l": ["a", "b", "c"], "e": {}, "h": {"2": "x"}}


def test_nil_values_are_dropped() -> None:
    assert luadata.loads(b'G = { ["a"] = nil, ["b"] = 1 }') == {"G": {"b": 1}}


def test_strings_are_utf8_and_support_decimal_escapes_and_long_brackets() -> None:
    source = 'G = { "é€", "\\195\\169", [==[\nline]]x]==] }'.encode()
    assert luadata.loads(source)["G"] == ["é€", "é", "line]]x"]


@pytest.mark.parametrize(
    "source",
    [b"G = os.execute('x')", b"G = { f = function() end }", b"G = 1 + 2", b"G = {", b'G = "x'],
)
def test_rejects_code_and_malformed_input(source: bytes) -> None:
    with pytest.raises(LuaDataError):
        luadata.loads(source)


def test_rejects_deep_nesting_without_recursion_error() -> None:
    with pytest.raises(LuaDataError):
        luadata.loads(b"G = " + b"{" * 5000 + b"}" * 5000)
