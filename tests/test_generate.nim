import std/[strutils, unittest]
from "."/generate/generate {.all.} import alterHeaders

proc testGenerate =
  suite "generate":
    test "alterHeaders":
      const s = """
        # Header 1

        The quick brown fox jumps over a lazy dog.

        The five boxing wizards jump quickly.

        ## Header 2

        The quick brown fox jumps over a lazy dog.

        The five boxing wizards jump quickly.

        ### Header 3

        The quick brown fox jumps over a lazy dog.

        ```nim
        # This line is not a header
        echo "hi"
        ```

        ## Header 4

        The quick brown fox jumps over a lazy dog.

        The five boxing wizards jump quickly.
      """.unindent()

      const expected = """
        The quick brown fox jumps over a lazy dog.

        The five boxing wizards jump quickly.

        ### Header 2

        The quick brown fox jumps over a lazy dog.

        The five boxing wizards jump quickly.

        #### Header 3

        The quick brown fox jumps over a lazy dog.

        ```nim
        # This line is not a header
        echo "hi"
        ```

        ### Header 4

        The quick brown fox jumps over a lazy dog.

        The five boxing wizards jump quickly.""".unindent() # No final newline

      check alterHeaders(s) == expected

proc main =
  testGenerate()

main()
{.used.}
