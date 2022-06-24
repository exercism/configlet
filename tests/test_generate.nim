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

        <!--
        # This line is not a header
        This line is in an HTML comment block -->

        ### Header 3

        The quick brown fox jumps over a lazy dog.

        ```nim
        # This line is not a header
        echo "hi"
        ```

        ## Header 4

        The quick brown fox jumps over a lazy dog.

        ~~~nim
        # This line is not a header
        echo "hi"
        ~~~
      """.unindent()

      const expected = """
        The quick brown fox jumps over a lazy dog.

        The five boxing wizards jump quickly.

        ### Header 2

        The quick brown fox jumps over a lazy dog.

        <!--
        # This line is not a header
        This line is in an HTML comment block -->

        #### Header 3

        The quick brown fox jumps over a lazy dog.

        ```nim
        # This line is not a header
        echo "hi"
        ```

        ### Header 4

        The quick brown fox jumps over a lazy dog.

        ~~~nim
        # This line is not a header
        echo "hi"
        ~~~""".unindent() # No final newline

      check alterHeaders(s, "Maps", 1) == "## Maps\n\n" & expected
      check alterHeaders(s, "Maps", 2) == expected
      check alterHeaders(s, "Maps", 3) == expected.replace("### ", "#### ")
      check alterHeaders(s, "Maps", 4) == expected.replace("### ", "##### ")

proc main =
  testGenerate()

main()
{.used.}
