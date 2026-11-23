"""Read a SavedVariables file as data.

The game writes SavedVariables as Lua source: ``Name = { ... }`` assignments whose
values are tables, strings, numbers and booleans. A file from another person is
untrusted input, so this module never runs it. It is a small parser for that subset
of Lua and raises :class:`LuaDataError` on anything else.

Conversion to Python values:

* a table whose keys are exactly 1..n becomes a ``list``;
* any other table becomes a ``dict`` with string keys (numeric keys are written out as
  decimal text, because JSON objects only have string keys);
* an empty table becomes ``{}``, since Lua cannot tell an empty list from an empty
  object (the schema allows for this);
* ``nil`` values are dropped, as they are in Lua.
"""

from __future__ import annotations

import re

MAX_DEPTH = 64


class LuaDataError(ValueError):
    """The text is not a SavedVariables file this parser understands."""


_NUMBER = re.compile(r"-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)")
_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_LONG_OPEN = re.compile(r"\[(=*)\[")
_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


class _Parser:
    def __init__(self, text: str) -> None:
        self.text = text
        self.pos = 0

    def fail(self, message: str) -> LuaDataError:
        line = self.text.count("\n", 0, self.pos) + 1
        return LuaDataError(f"line {line}: {message}")

    def skip(self) -> None:
        text = self.text
        while self.pos < len(text):
            char = text[self.pos]
            if char in " \t\r\n":
                self.pos += 1
            elif text.startswith("--", self.pos):
                opening = _LONG_OPEN.match(text, self.pos + 2)
                if opening:
                    close = "]" + opening.group(1) + "]"
                    end = text.find(close, opening.end())
                    if end < 0:
                        raise self.fail("unterminated comment")
                    self.pos = end + len(close)
                else:
                    end = text.find("\n", self.pos)
                    self.pos = len(text) if end < 0 else end
            else:
                return

    def peek(self) -> str:
        self.skip()
        return self.text[self.pos] if self.pos < len(self.text) else ""

    def expect(self, char: str) -> None:
        if self.peek() != char:
            raise self.fail(f"expected {char!r}")
        self.pos += 1

    def parse_file(self) -> dict:
        result: dict = {}
        while self.peek():
            match = _NAME.match(self.text, self.pos)
            if not match:
                raise self.fail("expected a global name")
            self.pos = match.end()
            self.expect("=")
            value = self.parse_value(0)
            if value is not None:
                result[match.group()] = value
            if self.peek() == ";":
                self.pos += 1
        return result

    def parse_value(self, depth: int):
        if depth > MAX_DEPTH:
            raise self.fail(f"tables nested deeper than {MAX_DEPTH}")
        char = self.peek()
        if char == "{":
            return self.parse_table(depth)
        if char in ('"', "'"):
            return self.parse_quoted(char)
        if char == "[":
            return self.parse_long_string()
        match = _NUMBER.match(self.text, self.pos)
        if match:
            self.pos = match.end()
            literal = match.group()
            if re.fullmatch(r"-?0[xX][0-9a-fA-F]+", literal):
                return int(literal, 16)
            if re.fullmatch(r"-?\d+", literal):
                return int(literal)
            return float(literal)
        match = _NAME.match(self.text, self.pos)
        if match and match.group() in ("true", "false", "nil"):
            self.pos = match.end()
            return {"true": True, "false": False, "nil": None}[match.group()]
        raise self.fail("expected a value")

    def parse_quoted(self, quote: str):
        text = self.text
        self.pos += 1
        out: list[str] = []
        while True:
            if self.pos >= len(text):
                raise self.fail("unterminated string")
            char = text[self.pos]
            if char == quote:
                self.pos += 1
                break
            if char == "\n":
                raise self.fail("newline in string")
            if char != "\\":
                out.append(char)
                self.pos += 1
                continue
            self.pos += 1
            escaped = text[self.pos : self.pos + 1]
            if escaped in _ESCAPES:
                out.append(_ESCAPES[escaped])
                self.pos += 1
            elif escaped.isdigit():
                digits = re.match(r"\d{1,3}", text[self.pos :]).group()
                if int(digits) > 255:
                    raise self.fail("escape \\ddd above 255")
                out.append(chr(int(digits)))
                self.pos += len(digits)
            else:
                raise self.fail(f"unknown escape \\{escaped}")
        return self.decode("".join(out))

    def parse_long_string(self):
        opening = _LONG_OPEN.match(self.text, self.pos)
        if not opening:
            raise self.fail("expected a value")
        close = "]" + opening.group(1) + "]"
        end = self.text.find(close, opening.end())
        if end < 0:
            raise self.fail("unterminated long string")
        body = self.text[opening.end() : end]
        self.pos = end + len(close)
        if body.startswith("\n"):
            body = body[1:]
        return self.decode(body)

    @staticmethod
    def decode(raw: str) -> str:
        # The file was read as bytes (one character per byte); the game writes UTF-8.
        return raw.encode("latin-1").decode("utf-8", errors="replace")

    def parse_table(self, depth: int):
        self.expect("{")
        items: list[tuple[object, object]] = []
        position = 0
        while self.peek() != "}":
            char = self.peek()
            key: object = None
            if char == "[" and not _LONG_OPEN.match(self.text, self.pos):
                self.pos += 1
                key = self.parse_value(depth + 1)
                if not isinstance(key, (str, int, float)) or isinstance(key, bool):
                    raise self.fail("table keys must be strings or numbers")
                self.expect("]")
                self.expect("=")
                value = self.parse_value(depth + 1)
            else:
                match = _NAME.match(self.text, self.pos)
                after = match and self.text[match.end() :].lstrip(" \t\r\n")
                if match and after.startswith("=") and not after.startswith("=="):
                    key = match.group()
                    self.pos = match.end()
                    self.expect("=")
                    value = self.parse_value(depth + 1)
                else:
                    position += 1
                    key = position
                    value = self.parse_value(depth + 1)
            if value is not None:
                items.append((key, value))
            if self.peek() in (",", ";"):
                self.pos += 1
            elif self.peek() != "}":
                raise self.fail("expected ',' or '}'")
        self.pos += 1
        return self.build(items)

    def build(self, items):
        if not items:
            return {}
        keys = [key for key, _ in items]
        if all(isinstance(key, int) and not isinstance(key, bool) for key in keys):
            if sorted(keys) == list(range(1, len(keys) + 1)):
                return [value for _, value in sorted(items, key=lambda item: item[0])]
        out: dict[str, object] = {}
        for key, value in items:
            if isinstance(key, float) and key.is_integer():
                key = int(key)
            out[key if isinstance(key, str) else str(key)] = value
        return out


def loads(source: bytes | str) -> dict:
    """Parse SavedVariables text and return ``{global name: value}``."""
    if isinstance(source, str):
        source = source.encode("utf-8")
    return _Parser(source.decode("latin-1")).parse_file()


def load(path) -> dict:
    """Parse the SavedVariables file at `path`."""
    with open(path, "rb") as handle:
        return loads(handle.read())
