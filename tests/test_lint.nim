import std/unittest
import "."/[lint/validators]

proc main =
  suite "isKebabCase":
    test "invalid kebab-case strings":
      check:
        # Some short, bad strings
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
        # With symbols
        not isKebabCase("&")
        not isKebabCase("&str")
        not isKebabCase("hello!")
        # Bad dash usage
        not isKebabCase("hello-world-")
        not isKebabCase("-hello-world")
        not isKebabCase("-hello-world-")
        not isKebabCase("hello--world")
        not isKebabCase("hello---world")
        # With space
        not isKebabCase("hello world")
        not isKebabCase("hello World")
        not isKebabCase("Hello world")
        not isKebabCase("Hello World")
        not isKebabCase("HELLO WORLD")
        # With underscore
        not isKebabCase("hello_world")
        not isKebabCase("hello_World")
        not isKebabCase("Hello_world")
        not isKebabCase("Hello_World")
        not isKebabCase("HELLO_WORLD")
        # With dash
        not isKebabCase("hello-World")
        not isKebabCase("Hello-world")
        not isKebabCase("Hello-World")
        not isKebabCase("HELLO-WORLD")
        # No separator, but with capitals
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

main()
{.used.}
