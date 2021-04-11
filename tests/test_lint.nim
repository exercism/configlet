import std/unittest
import "."/lint/validators

proc main =
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

main()
{.used.}
