import std/[strutils, unittest]
from "."/generate/generate {.all.} import alterHeadings

proc testGenerate =
  suite "generate":
    test "alterHeadings":
      const s = """
        # Heading 1

        The quick brown fox jumps over a lazy dog.

        The five boxing wizards jump quickly.

        ## Heading 2

        The quick brown fox jumps over a lazy dog.

        <!--
        # This line is not a heading
        This line is in an HTML comment block -->

        ### Heading 3

        The quick brown fox jumps over a lazy dog.

        ```nim
        # This line is not a heading
        echo "hi"
        ```

        ## Heading 4

        The quick brown fox jumps over a lazy dog.

        ~~~nim
        # This line is not a heading
        echo "hi"
        ~~~
      """.unindent()

      const expected = """
        The quick brown fox jumps over a lazy dog.

        The five boxing wizards jump quickly.

        ### Heading 2

        The quick brown fox jumps over a lazy dog.

        <!--
        # This line is not a heading
        This line is in an HTML comment block -->

        #### Heading 3

        The quick brown fox jumps over a lazy dog.

        ```nim
        # This line is not a heading
        echo "hi"
        ```

        ### Heading 4

        The quick brown fox jumps over a lazy dog.

        ~~~nim
        # This line is not a heading
        echo "hi"
        ~~~""".unindent() # No final newline

      var linkDefs = newSeq[string]()
      check alterHeadings(s, "Maps", 1, linkDefs) == "## Maps\n\n" & expected
      check alterHeadings(s, "Maps", 2, linkDefs) == expected
      check alterHeadings(s, "Maps", 3, linkDefs) == expected.replace("### ", "#### ")
      check alterHeadings(s, "Maps", 4, linkDefs) == expected.replace("### ", "##### ")
      check linkDefs.len == 0

proc main =
  testGenerate()

main()
{.used.}
