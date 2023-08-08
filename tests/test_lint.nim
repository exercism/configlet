import std/[strutils, unittest]
import lint/validators
import lint/approaches_and_articles {.all.}

proc testIsKebabCase =
  suite "isKebabCase":
    test "invalid kebab-case strings":
      check:
        # Some short, invalid strings
        not isKebabCase("")
        not isKebabCase(" ")
        not isKebabCase("-")
        not isKebabCase("_")
        not isKebabCase("--")
        not isKebabCase("---")
        not isKebabCase("a ")
        not isKebabCase(" a")
        not isKebabCase("a-")
        not isKebabCase("-a")
        not isKebabCase("--a")
        not isKebabCase("a--")
        not isKebabCase("-a-")
        not isKebabCase("a--b")
        # Containing character not in [a-z0-9]
        not isKebabCase("&")
        not isKebabCase("&str")
        not isKebabCase("hello!")
        # Invalid dash usage
        not isKebabCase("hello-world-")
        not isKebabCase("-hello-world")
        not isKebabCase("-hello-world-")
        not isKebabCase("hello--world")
        not isKebabCase("hello---world")
        # Invalid separator: space
        not isKebabCase("hello world")
        not isKebabCase("hello World")
        not isKebabCase("Hello world")
        not isKebabCase("Hello World")
        not isKebabCase("HELLO WORLD")
        # Invalid separator: underscore
        not isKebabCase("hello_world")
        not isKebabCase("hello_World")
        not isKebabCase("Hello_world")
        not isKebabCase("Hello_World")
        not isKebabCase("HELLO_WORLD")
        # Containing uppercase, with dash
        not isKebabCase("hello-World")
        not isKebabCase("Hello-world")
        not isKebabCase("Hello-World")
        not isKebabCase("HELLO-WORLD")
        # Containing uppercase, with no separator
        not isKebabCase("helloWorld")
        not isKebabCase("Helloworld")
        not isKebabCase("HelloWorld")
        not isKebabCase("HELLOWORLD")

    test "valid kebab-case strings":
      check:
        isKebabCase("a")
        isKebabCase("1")
        isKebabCase("123")
        isKebabCase("123-456")
        isKebabCase("hello-123")
        isKebabCase("123-hello")
        isKebabCase("hello")
        isKebabCase("hello-world")
        isKebabCase("hello-world-hello")
        isKebabCase("hello-world-hello-world")

proc testIsUuidV4 =
  const ValidUuidV4 = "01234567-9012-4567-9012-456789012345"
  doAssert ValidUuidV4.len == 36

  func uuidIndices: (seq[int], seq[int]) =
    for i, c in ValidUuidV4:
      if c == '-':
        result[0].add i
      else:
        result[1].add i

  const (HyphenIndices, HexIndices) = uuidIndices()

  suite "isUuidV4: returns true for valid version 4 UUIDs":
    test "digits only":
      check:
        isUuidV4(ValidUuidV4)

    test "only letters, apart from version number":
      const uuid = "abcdefab-abcd-4bcd-abcd-abcdefabcdef"
      check:
        isUuidV4(uuid)

    test "some valid version 4 UUIDs":
      const goodUuids = [
        "9a572704-80a0-4bf4-9aa6-97e4bf8133b4",
        "e6d19ba9-ba9c-4779-89d7-f6502c2a7e9c",
        "5d6af41f-45f8-4549-9a07-f496e39f1b53",
        "f9640d96-8794-49ab-8b27-9d2126ed8b5e",
        "07900fee-94d0-4c48-9969-ae4926f9842d",
        "aa023537-d021-4ee7-85ab-eae4a367ba62",
        "f21d1b67-3e10-4c29-9552-a881ef4401b8",
        "b6a419c1-0c51-46c2-91d5-707a847a46a9",
        "fe0bcef1-8f56-4a1e-a375-aeda6f8fb3bc",
        "418e92a8-ade5-4417-bc72-8e3709d1499c",
      ]
      for goodUuid in goodUuids:
        check:
          isUuidV4(goodUuid)

  suite "isUuidV4: returns false for invalid version 4 UUIDs":
    test "nil UUID":
      # The nil UUID is a valid UUID, but not a valid version 4 UUID.
      check:
        not isUuidV4("00000000-0000-0000-0000-000000000000")

    test "version 1 UUID":
      check:
        not isUuidV4("2ad51c8c-4a93-11eb-b378-0242ac130002")

    test "non-canonical form: without hyphens":
      check:
        not isUuidV4("01234567901245679012456789012345")

    test "non-canonical form: with uppercase":
      var uuid = ValidUuidV4
      for i in HexIndices:
        uuid[i] = "ABCDEF"[i mod 6]
        check:
          not isUuidV4(uuid)
        uuid[i] = ValidUuidV4[i]

    test "length: too short":
      check:
        not isUuidV4("")
        not isUuidV4(ValidUuidV4[0 .. ^2])

    test "length: too long":
      check:
        not isUuidV4(ValidUuidV4 & '6')
        not isUuidV4(ValidUuidV4 & ValidUuidV4)

    test "separators: each replaced by a hexadecimal digit":
      var uuid = ValidUuidV4
      for i in HyphenIndices:
        uuid[i] = char(i mod 10 + '0'.ord)
      check:
        not isUuidV4(uuid)

    test "separators: one replaced by a hexadecimal digit":
      var uuid = ValidUuidV4
      for i in HyphenIndices:
        uuid[i] = char(i mod 10 + '0'.ord)
        check:
          not isUuidV4(uuid)
        uuid[i] = '-'

    test "separators: one extra":
      var uuid = ValidUuidV4
      for i in HexIndices:
        uuid[i] = '-'
        check:
          not isUuidV4(uuid)
        uuid[i] = ValidUuidV4[i]

    test "separators: one in the wrong place":
      var uuid = ValidUuidV4
      for i in HyphenIndices:
        uuid[i] = char(i mod 10 + '0'.ord)
        for j in HexIndices:
          uuid[j] = '-'
          check:
            not isUuidV4(uuid)
          uuid[j] = ValidUuidV4[j]
        uuid[i] = '-'

    test "invalid character: letter that is not a hexadecimal digit":
      var uuid = ValidUuidV4
      for i in 0 .. uuid.high:
        uuid[i] = char(i mod 10 + 'g'.ord)
        check:
          not isUuidV4(uuid)
        uuid[i] = ValidUuidV4[i]

    const
      Hex = {'0'..'9', 'a'..'f'}

    test "character at the start of the third grouping":
      var uuid = ValidUuidV4
      for c in Hex:
        uuid[14] = c
        if c == '4':
          check isUuidV4(uuid)
        else:
          check not isUuidV4(uuid)

    test "character at the start of the fourth grouping":
      var uuid = ValidUuidV4
      for c in Hex:
        uuid[19] = c
        if c in {'8', '9', 'a', 'b'}:
          check isUuidV4(uuid)
        else:
          check not isUuidV4(uuid)

func extractPlaceholders(s: string): seq[string] =
  result = newSeq[string]()
  for ph in extractPlaceholders(s):
    result.add ph

proc testExtractPlaceholders =
  suite "extractPlaceholder":
    test "no placeholder":
      check:
        # 0 placeholder characters
        extractPlaceholders("").len == 0
        extractPlaceholders("foo").len == 0

        # 1 placeholder character
        extractPlaceholders("foo%").len == 0
        extractPlaceholders("%foo").len == 0
        extractPlaceholders("{foo").len == 0
        extractPlaceholders("foo}").len == 0

        # 2 placeholder characters
        extractPlaceholders("%{foo").len == 0
        extractPlaceholders("%foo}").len == 0
        extractPlaceholders("{foo}").len == 0
        extractPlaceholders("%foo{bar").len == 0

        # 3 placeholder characters, but badly formed
        extractPlaceholders("%foo{bar}").len == 0
        extractPlaceholders("%}foo{").len == 0
        extractPlaceholders("{%foo}").len == 0

    test "one placeholder":
      check:
        extractPlaceholders("%{}") == @[""]
        extractPlaceholders("%{f}") == @["f"]
        extractPlaceholders("%{foo}") == @["foo"]
        extractPlaceholders("prefix%{foo}") == @["foo"]
        extractPlaceholders("%{foo}suffix") == @["foo"]
        extractPlaceholders("prefix%{foo}suffix") == @["foo"]
        extractPlaceholders("prefix%%{foo}suffix") == @["foo"]
        extractPlaceholders("pre%fix%{foo}suffix") == @["foo"]
        extractPlaceholders("pre%}fix%{foo}suffix") == @["foo"]
        extractPlaceholders("prefix%{foo}s}uffix") == @["foo"]

    test "multiple placeholders":
      check:
        extractPlaceholders("prefix%{foo}bar%{foo}suffix") == @["foo", "foo"]
        extractPlaceholders("prefix%{foo}bar%{baz}suffix") == @["foo", "baz"]
        extractPlaceholders("prefix%{foo}%{bar}%{baz}suffix") == @["foo", "bar", "baz"]

proc testIsFilesPattern =
  suite "isFilesPattern":
    test "invalid files patterns":
      check:
        not isFilesPattern("")
        not isFilesPattern(" ")
        not isFilesPattern("%{unknown_slug}suffix")
        not isFilesPattern("prefix%{unknown_slug}suffix")
        not isFilesPattern("prefix%{unknown_slug}")
        not isFilesPattern("%{unknown_slug}")
        not isFilesPattern("%{ssnake_slug}")
        not isFilesPattern("%{snake_slugg}")
        not isFilesPattern("somedir/%{snake_slug}/%{unknown_slug}.suffix")

    test "valid files patterns":
      check:
        isFilesPattern("somefile")
        isFilesPattern("somefile.go")
        isFilesPattern("%{kebab_slug}.js")
        isFilesPattern("foo%{snake_slug}bar")
        isFilesPattern("foobar%{camel_slug}")
        isFilesPattern("%{pascal_slug}")
        isFilesPattern("somedir/%{pascal_slug}")
        isFilesPattern("somedir/%{pascal_slug}.suffix")
        isFilesPattern("somedir/%{pascal_slug}/filename.suffix")
        isFilesPattern("somedir/%{pascal_slug}/%{pascal_slug}.suffix")
        isFilesPattern("somedir/%{pascal_slug}/%{snake_slug}.suffix")
        isFilesPattern("%{pascal_slug}/filename.suffix")

proc testCountLinesWithoutCodeFence =
  suite "countLinesWithoutCodeFence":
    test "without code fence":
      const dk = dkArticles
      check:
        countLinesWithoutCodeFence("", dk) == 0
        countLinesWithoutCodeFence("a", dk) == 1
        countLinesWithoutCodeFence("a\n", dk) == 1
        countLinesWithoutCodeFence("foo\n", dk) == 1
        countLinesWithoutCodeFence("foo\nb", dk) == 2
        countLinesWithoutCodeFence("foo\nbar", dk) == 2
        countLinesWithoutCodeFence("foo\nbar\n", dk) == 2
        countLinesWithoutCodeFence("foo\nbar\nfoo", dk) == 3

    test "with code fence only":
      const s = """
        ```nim
        echo "foo"
        ```""".unindent()
      check:
        countLinesWithoutCodeFence(s, dkArticles) == 1
        countLinesWithoutCodeFence(s, dkApproaches) == 3

    test "with code fence at start":
      const s = """
        ```nim
        echo "foo"
        ```

      Some content.
      """.unindent()
      check:
        countLinesWithoutCodeFence(s, dkArticles) == 3
        countLinesWithoutCodeFence(s, dkApproaches) == 5

    test "with code fence at end":
      const s = """
        # Some header

        Some content.

        ```nim
        echo "foo"
        ```
      """.unindent()
      check:
        countLinesWithoutCodeFence(s, dkArticles) == 5
        countLinesWithoutCodeFence(s, dkApproaches) == 7

    test "with code fence in middle":
      const s = """
        # Some header

        Some content.

        ```nim
        echo "foo"
        ```

        Some content.
      """.unindent()
      check:
        countLinesWithoutCodeFence(s, dkArticles) == 7
        countLinesWithoutCodeFence(s, dkApproaches) == 9

proc main =
  testIsKebabCase()
  testIsUuidV4()
  testExtractPlaceholders()
  testIsFilesPattern()
  testCountLinesWithoutCodeFence()

main()
{.used.}
