import unittest

from esoexporter import luadata
from esoexporter.luadata import LuaDataError


class ParseTests(unittest.TestCase):
    def test_nested_tables_strings_numbers_and_booleans(self):
        data = luadata.loads(
            b'-- comment\nG =\n{\n\t["a"] = { ["b"] = "x\\"y\\n", ["c"] = -1.5e2, ["d"] = true },\n\t[7] = 0x10,\n}\n'
        )
        self.assertEqual(data, {"G": {"a": {"b": 'x"y\n', "c": -150.0, "d": True}, "7": 16}})

    def test_sequential_keys_become_a_list_and_empty_tables_a_dict(self):
        data = luadata.loads(b'G = { ["l"] = { "a", "b", [3] = "c" }, ["e"] = {}, ["h"] = { [2] = "x" } }')
        self.assertEqual(data["G"], {"l": ["a", "b", "c"], "e": {}, "h": {"2": "x"}})

    def test_nil_values_are_dropped(self):
        self.assertEqual(luadata.loads(b'G = { ["a"] = nil, ["b"] = 1 }'), {"G": {"b": 1}})

    def test_strings_are_utf8_and_support_decimal_escapes_and_long_brackets(self):
        data = luadata.loads('G = { "é€", "\\195\\169", [==[\nline]]x]==] }'.encode("utf-8"))
        self.assertEqual(data["G"], ["é€", "é", "line]]x"])

    def test_rejects_code(self):
        for source in (b"G = os.execute('x')", b"G = { f = function() end }", b"G = 1 + 2", b"G = {", b'G = "x'):
            with self.subTest(source=source), self.assertRaises(LuaDataError):
                luadata.loads(source)

    def test_rejects_deep_nesting_without_recursion_error(self):
        with self.assertRaises(LuaDataError):
            luadata.loads(b"G = " + b"{" * 5000 + b"}" * 5000)


if __name__ == "__main__":
    unittest.main()
