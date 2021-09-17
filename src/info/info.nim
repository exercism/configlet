import std/[algorithm, json, os, sets, terminal]
import ".."/[cli, helpers, lint/validators]

proc getConcepts(j: JsonNode): HashSet[string] =
  ## Returns the slug of every concept.
  for item in j["concepts"]:
    result.incl item["slug"].getStr()

proc getPrereqs(j: JsonNode): HashSet[string] =
  ## Returns the deduplicated values of every practice exercise `prerequisites` key.
  for item in j["exercises"]["practice"]:
    for prereq in item["prerequisites"]:
      result.incl prereq.getStr()

proc getPractices(j: JsonNode): HashSet[string] =
  ## Returns the deduplicated values of every practice exercise `practices` key.
  for item in j["exercises"]["practice"]:
    if item.hasKey("practices"):
      for prac in item["practices"]:
        result.incl prac.getStr()

proc echoHeader(s: string) =
  stdout.styledWriteLine(fgBlue, s)

proc show(s: HashSet[string], header: string) =
  ## Prints `header` and then the elements of `s` in alphabetical order
  echoHeader(header)
  if s.len > 0:
    var elements = newSeq[string](s.len)
    var i = 0
    for item in s:
      elements[i] = item
      inc i
    sort elements
    for item in elements:
      echo item
  else:
    echo "none"
  echo ""

proc concepts(j: JsonNode) =
  let concepts = getConcepts(j)

  let prereqs = getPrereqs(j)
  let conceptsThatArentAPrereq = concepts - prereqs
  show(conceptsThatArentAPrereq,
       "Concepts that aren't a prerequisite for any practice exercise:")

  let practices = getPractices(j)
  let conceptsThatArentPracticed = concepts - practices
  show(conceptsThatArentPracticed,
       "Concepts that aren't practiced by any practice exercise:")

  let conceptsThatAreAPrereqButArentPracticed = prereqs - practices
  show(conceptsThatAreAPrereqButArentPracticed,
       "Concepts that are a prerequisite, but aren't practiced by any practice exercise:")

proc info*(conf: Conf) =
  let trackConfigPath = Path(conf.trackDir / "config.json")
  var b = true # Temporary workaround
  let j = parseJsonFile(trackConfigPath, b)
  concepts(j)
