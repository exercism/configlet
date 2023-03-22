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
      check alterHeadings(s, linkDefs) == expected
      check alterHeadings(s, linkDefs, "Maps") == "## Maps\n\n" & expected
      check linkDefs.len == 0

    test "alterHeadings: keeps link reference definition inside block":
      const s = """
        # Heading 1

        ~~~~note
        See the [foo docs][foo-docs] for more details.

        [foo-docs]: http://example.com
        ~~~~
      """.unindent()

      const expected = """
        ~~~~note
        See the [foo docs][foo-docs] for more details.

        [foo-docs]: http://example.com
        ~~~~""".unindent()

      var linkDefs = newSeq[string]()
      check alterHeadings(s, linkDefs) == expected
      check linkDefs.len == 0

proc main =
  testGenerate()

main()
{.used.}
