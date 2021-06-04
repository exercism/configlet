## We have patched the stdlib modules of `std/json` and `std/parsejson` so that
## parsing the below cases now raises a `JsonParsingError`:
## - a trailing comma                   e.g. "[1, 2,]"
## - a line comment                     e.g. "[1, 2] // here is a line comment"
## - a (potentially) multi-line comment e.g. "[1, 2] /* here is a comment */"
##
## This module tests that our patched JSON parser works as expected.
import std/[json, strutils, unittest]

template checkEachLineIsInvalidJson(s: string) =
  # This must be a template, rather than a proc. With the latter, a failing test
  # would correctly produce a non-zero exit code and an error message, but
  # incorrectly print [OK] rather than [FAILED].
  for line in s.unindent().splitLines():
    expect JsonParsingError:
      discard parseJson(line)

proc testJsonParser =
  suite "parsejson":
    test "valid JSON: empty array":
      check:
        parseJson("[]") == newJArray()

    test "valid JSON: empty object":
      check:
        parseJson("{}") == newJObject()

    test "valid JSON: empty object surrounded by extra whitespace":
      const s = """

           {}

      """
      check:
        parseJson(s) == newJObject()

    test "invalid JSON: empty string":
      checkEachLineIsInvalidJson ""

    test "invalid JSON: fragments of valid JSON":
      checkEachLineIsInvalidJson """
        [][]
        {}{}
        {}[]
        []{}
        [] []
        {} {}
        []\n[]
        {}\n{}"""

    test "invalid JSON: single comma":
      checkEachLineIsInvalidJson ","

    test "invalid JSON: comma after open bracket/curly":
      checkEachLineIsInvalidJson """
        [,
        [ ,
        [ ,\s
        {,
        { ,
        {",}
        {"a,}
        {"a",}
        {"a":,}
        {"a": ,}
        { , """

    test "invalid JSON: comma inside empty array/object":
      checkEachLineIsInvalidJson """
        [,]
        [, ]
        {,}
        {, }"""

    test "invalid JSON: trailing comma inside non-empty array":
      # These lines raise only with the patched std/json
      checkEachLineIsInvalidJson """
        [1,]
        [1, ]
        [1, 2,]
        [1, 2, ]"""

    test "invalid JSON: trailing comma inside non-empty object":
      # These lines raise only with the patched std/json
      checkEachLineIsInvalidJson """
        {"a": 1,}
        {"a": 1, "b": 2,}"""

    test "invalid JSON: trailing comma inside both object and array":
      # These lines raise only with the patched std/json
      checkEachLineIsInvalidJson """
        {"a": [1,],}
        {"a": [1, 2,], "b": 3}
        {"a": [1, 2,], "b": 3,}"""

    test "invalid JSON: a line comment":
      # This raises only with the patched std/json
      const s = """
        {
          "a": 1,
          "b": 2, // here is a line comment
          "c": 3
        }"""
      expect JsonParsingError:
        discard parseJson(s)

    test "invalid JSON: a multi-line comment":
      # This raises only with the patched std/json
      const s = """
        {
          "a": 1,
          /* here is
             a multi-line
             comment */
          "b": 2,
          "c": 3
        }"""
      expect JsonParsingError:
        discard parseJson(s)

proc main =
  testJsonParser()

main()
{.used.}
