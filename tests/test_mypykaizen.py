from unittest.mock import patch

import pytest

from mypykaizen import mypykaizen


def test_sanitize_output_lines_happy_path():
    output_lines = [
        '/Users/foobar/baz.pyi:00: note: "this" of "that" defined here',
        "my_lib/deadbeef.py:42: error: Deadbeef wasn't actually dead all along",
        "I'm a teapot hehe!",
    ]
    assert mypykaizen.sanitize_output_lines(output_lines) == output_lines[1:]


@patch("os.sep", new="\\")
@patch("os.altsep", new="/")
def test_sanitize_output_lines_windows_machine_happy_path():
    output_lines = [
        'C:\\Users\\foobar\\baz.pyi:00: note: "this" of "that" defined here',
        "my_lib\\deadbeef.py:42: error: Deadbeef wasn't actually dead all along",
        "I'm a teapot hehe!",
    ]
    assert mypykaizen.sanitize_output_lines(output_lines) == [
        line.replace("\\", "/") for line in output_lines[1:]
    ]
