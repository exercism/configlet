import std/[json, sets, strformat, strscans, strutils, tables]
import pkg/jsony
import ".."/[cli, helpers]
import "."/validators

proc hasValidStatus(data: JsonNode; path: Path): bool =
  const k = "status"
  if hasObject(data, k, path):
    let d = data[k]
    let checks = [
      hasBoolean(d, "concept_exercises", path, k),
      hasBoolean(d, "test_runner", path, k),
      hasBoolean(d, "representer", path, k),
      hasBoolean(d, "analyzer", path, k),
    ]
    result = allTrue(checks)

proc hasValidOnlineEditor(data: JsonNode; path: Path): bool =
  const k = "online_editor"
  if hasObject(data, k, path):
    let d = data[k]
    const indentStyles = ["space", "tab"].toHashSet()
    let checks = [
      hasString(d, "indent_style", path, k, allowed = indentStyles),
      hasInteger(d, "indent_size", path, k, allowed = 0..8),
      hasString(d, "highlightjs_language", path, k),
    ]
    result = allTrue(checks)

proc hasValidTestRunner(data: JsonNode; path: Path): bool =
  const s = "status"
  if hasObject(data, s, path):
    const k = "test_runner"
    if hasBoolean(data[s], k, path, s):
      # Only check the `test_runner` object if `status.test_runner` is `true`.
      if data[s][k].getBool():
        if hasObject(data, k, path):
          result = hasFloat(data[k], "average_run_time", path, k,
                            requirePositive = true, decimalPlaces = 1)
      else:
        result = true

const
  statuses = ["wip", "beta", "active", "deprecated"].toHashSet()

proc isValidConceptExercise(data: JsonNode; context: string; path: Path): bool =
  if isObject(data, context, path):
    let checks = [
      hasString(data, "slug", path, context, maxLen = 255, checkIsKebab = true),
      hasString(data, "name", path, context, maxLen = 255),
      hasString(data, "uuid", path, context, checkIsUuid = true),
      hasArrayOfStrings(data, "concepts", path, context,
                        allowedArrayLen = 0..int.high, checkIsKebab = true,
                        uniqueValues = true),
      hasArrayOfStrings(data, "prerequisites", path, context,
                        allowedArrayLen = 0..int.high, checkIsKebab = true,
                        uniqueValues = true),
      hasString(data, "status", path, context, isRequired = false,
                allowed = statuses),
    ]
    result = allTrue(checks)

proc isValidPracticeExercise(data: JsonNode; context: string;
                             path: Path): bool =
  if isObject(data, context, path):
    let checks = [
      hasString(data, "slug", path, context, maxLen = 255, checkIsKebab = true),
      hasString(data, "name", path, context, maxLen = 255),
      hasString(data, "uuid", path, context, checkIsUuid = true),
      hasInteger(data, "difficulty", path, context, allowed = 0..10),
      hasArrayOfStrings(data, "practices", path, context,
                        allowedArrayLen = 0..int.high, checkIsKebab = true,
                        uniqueValues = true),
      hasArrayOfStrings(data, "prerequisites", path, context,
                        allowedArrayLen = 0..int.high, checkIsKebab = true,
                        uniqueValues = true),
      hasString(data, "status", path, context, isRequired = false,
                allowed = statuses),
    ]
    result = allTrue(checks)

proc hasValidExercises(data: JsonNode; path: Path): bool =
  const k = "exercises"
  if hasObject(data, k, path):
    let exercises = data[k]
    let checks = [
      hasArrayOf(exercises, "concept", path, isValidConceptExercise, k,
                 allowedLength = 0..int.high),
      hasArrayOf(exercises, "practice", path, isValidPracticeExercise, k,
                 allowedLength = 0..int.high),
      hasArrayOfStrings(exercises, "foregone", path, k, isRequired = false,
                        checkIsKebab = true, uniqueValues = true),
    ]
    result = allTrue(checks)

proc isValidConcept(data: JsonNode; context: string; path: Path): bool =
  if isObject(data, context, path):
    let checks = [
      hasString(data, "uuid", path, context, checkIsUuid = true),
      hasString(data, "slug", path, context, maxLen = 255, checkIsKebab = true),
      hasString(data, "name", path, context, maxLen = 255),
    ]
    result = allTrue(checks)

proc hasValidConcepts(data: JsonNode; path: Path): bool =
  result = hasArrayOf(data, "concepts", path, isValidConcept,
                      allowedLength = 0..int.high)

const keyFeatureIcons = [
  "community",
  "concurrency",
  "cross-platform",
  "documentation",
  "dynamically-typed",
  "easy",
  "embeddable",
  "evolving",
  "expressive",
  "extensible",
  "fast",
  "fun",
  "functional",
  "garbage-collected",
  "general-purpose",
  "homoiconic",
  "immutable",
  "interactive",
  "interop",
  "multi-paradigm",
  "portable",
  "powerful",
  "productive",
  "safe",
  "scientific",
  "small",
  "stable",
  "statically-typed",
  "tooling",
  "web",
  "widely-used",
].toHashSet()

proc isValidKeyFeature(data: JsonNode; context: string; path: Path): bool =
  if isObject(data, context, path):
    let checks = [
      hasString(data, "icon", path, context, allowed = keyFeatureIcons),
      hasString(data, "title", path, context, maxLen = 25),
      hasString(data, "content", path, context, maxLen = 100),
    ]
    result = allTrue(checks)

proc hasValidKeyFeatures(data: JsonNode; path: Path): bool =
  result = hasArrayOf(data, "key_features", path, isValidKeyFeature,
                      isRequired = false, allowedLength = 6..6)

const tags = [
  "paradigm/declarative",
  "paradigm/functional",
  "paradigm/imperative",
  "paradigm/logic",
  "paradigm/object_oriented",
  "paradigm/procedural",
  "typing/static",
  "typing/dynamic",
  "typing/strong",
  "typing/weak",
  "execution_mode/compiled",
  "execution_mode/interpreted",
  "platform/windows",
  "platform/mac",
  "platform/linux",
  "platform/ios",
  "platform/android",
  "platform/web",
  "runtime/standalone_executable",
  "runtime/language_specific",
  "runtime/clr",
  "runtime/jvm",
  "runtime/beam",
  "runtime/wasmtime",
  "used_for/artificial_intelligence",
  "used_for/backends",
  "used_for/cross_platform_development",
  "used_for/embedded_systems",
  "used_for/financial_systems",
  "used_for/frontends",
  "used_for/games",
  "used_for/guis",
  "used_for/mobile",
  "used_for/robotics",
  "used_for/scientific_calculations",
  "used_for/scripts",
  "used_for/web_development",
].toHashSet()

proc hasValidTags(data: JsonNode; path: Path): bool =
  result = hasArrayOfStrings(data, "tags", path, allowed = tags,
                             uniqueValues = true)

proc satisfiesFirstPass(data: JsonNode; path: Path): bool =
  ## Returns `true` if `data` passes the first round of checks for a track-level
  ## `config.json` file. This includes checking that the types are as expected,
  ## so that we can perform more complex checks after deserializing via `jsony`.
  if isObject(data, jsonRoot, path):
    let checks = [
      hasString(data, "language", path, maxLen = 255),
      hasString(data, "slug", path, maxLen = 255, checkIsKebab = true),
      hasBoolean(data, "active", path),
      hasString(data, "blurb", path, maxLen = 400),
      hasInteger(data, "version", path, allowed = 3..3),
      hasValidStatus(data, path),
      hasValidOnlineEditor(data, path),
      hasValidTestRunner(data, path),
      hasValidExercises(data, path),
      hasValidConcepts(data, path),
      hasValidKeyFeatures(data, path),
      hasValidTags(data, path),
    ]
    result = allTrue(checks)

type
  Status = enum
    sMissing = "missing"
    sWip = "wip"
    sBeta = "beta"
    sActive = "active"
    sDeprecated = "deprecated"

  # We can use a `HashSet` for `concepts`, `prerequisites` and `practices`
  # because the first pass has already checked that each has unique values.
  ConceptExercise = object
    slug: string
    # name: string
    # uuid: string
    concepts: HashSet[string]
    prerequisites: HashSet[string]
    status: Status

  PracticeExercise = object
    slug: string
    # name: string
    # uuid: string
    # difficulty: int
    practices: HashSet[string]
    prerequisites: HashSet[string]
    status: Status

  Exercises = object
    `concept`: seq[ConceptExercise]
    practice: seq[PracticeExercise]
    foregone: HashSet[string]

  Concept = object
    name: string
    slug: string
    uuid: string

  Concepts = seq[Concept]

  TrackConfig = object
    exercises: Exercises
    concepts: Concepts

proc toLineAndCol(s: string; offset: Natural): tuple[line: int; col: int] =
  ## Returns the line and column number corresponding to the `offset` in `s`.
  result = (1, 1)
  for i, c in s:
    if i == offset:
      break
    elif c == '\n':
      inc result.line
      result.col = 0
    inc result.col

proc tidyJsonyErrorMsg(trackConfigContents: string): string =
  let jsonyMsg = getCurrentExceptionMsg()
  var jsonyMsgStart = ""
  var offset = -1
  # See https://github.com/treeform/jsony/blob/33c3daa/src/jsony.nim#L25-L27
  let details =
    if jsonyMsg.scanf("$* At offset: $i$.", jsonyMsgStart, offset):
      let (line, col) = toLineAndCol(trackConfigContents, offset)
      &"({line}, {col}): {jsonyMsgStart}"
    else:
      &": {jsonyMsg}"
  const bugNotice = """
    --------------------------------------------------------------------------------
    THIS IS A CONFIGLET BUG. PLEASE REPORT IT.

    The JSON parsing error above should not occur - it indicates a bug in configlet!

    If you are seeing this, please open an issue in this repo:
    https://github.com/exercism/configlet

    Please include:
    - a copy of the error message above
    - the contents of the track `config.json` file at the time `configlet lint` ran

    Thank you.
    --------------------------------------------------------------------------------
  """.unindent()
  result = &"JSON parsing error:\nconfig.json{details}\n\n{bugNotice}"

proc toTrackConfig(trackConfigContents: string): TrackConfig =
  ## Deserializes `trackConfigContents` using `jsony` to a `TrackConfig` object.
  try:
    result = fromJson(trackConfigContents, TrackConfig)
  except jsony.JsonError:
    let msg = tidyJsonyErrorMsg(trackConfigContents)
    showError(msg)

func getConceptSlugs(concepts: Concepts): HashSet[string] =
  ## Returns a set of every `slug` in the top-level `concepts` array of a track
  ## `config.json` file.
  result = initHashSet[string]()
  for con in concepts:
    result.incl con.slug

func joinWithNewlines[A](s: SomeSet[A]): string =
  result = ""
  for item in s:
    result.add item
    result.add "\n"
  result.setLen(result.len - 1)

proc checkPractices(practiceExercises: seq[PracticeExercise];
                    conceptSlugs: HashSet[string]; b: var bool;
                    path: Path) =
  ## Checks the `practices` of each user-facing Practice Exercise in
  ## `practiceExercises`, and sets `b` to `false` if a check fails.
  var countConceptsPracticed = initCountTable[string]()
  var practicesNotInTopLevelConcepts = initOrderedSet[string]()

  for practiceExercise in practiceExercises:
    for conceptPracticed in practiceExercise.practices:
      countConceptsPracticed.inc conceptPracticed
      if conceptPracticed notin conceptSlugs:
        practicesNotInTopLevelConcepts.incl conceptPracticed
        # TODO: Eventually make this an error, not a warning.
        if false:
          let msg = &"The Practice Exercise {q practiceExercise.slug} has " &
                    &"{q conceptPracticed} in its `practices` array, which " &
                     "is not a `slug` in the top-level `concepts` array"
          b.setFalseAndPrint(msg, path)

  if practicesNotInTopLevelConcepts.len > 0:
    let msg = "The following concepts exist in the `practices` array " &
              &"of a Practice Exercise in {q $path}, but do not exist in the " &
               "top-level `concepts` array"
    let slugs = joinWithNewlines(practicesNotInTopLevelConcepts)
    warn(msg, slugs)

  for conceptPracticed, count in countConceptsPracticed.pairs:
    if count > 10:
      let msg = &"The Concept {q conceptPracticed} appears {count} times in " &
                 "the `practices` arrays of user-facing Practice Exercises, " &
                 "but can only appear at most 10 times"
      # TODO: Eventually make this an error, not a warning.
      if true:
        warn(msg, path)
      else:
        b.setFalseAndPrint(msg, path)

iterator visible(conceptExercises: seq[ConceptExercise]): ConceptExercise =
  ## Yields every Concept Exercise in `conceptExercises` that appears on the
  ## website.
  ## That is, every Concept Exercise that has a `status` of `beta` or `active`,
  ## or that omits the `status` property entirely (which implies `active`).
  for conceptExercise in conceptExercises:
    if conceptExercise.status in [sMissing, sBeta, sActive]:
      yield conceptExercise

proc checkExerciseConcepts(conceptExercises: seq[ConceptExercise];
                           conceptSlugs: HashSet[string]; b: var bool;
                           path: Path): HashSet[string] =
  ## Checks the `concepts` array of each user-facing Concept Exercise in
  ## `conceptExercises`, and sets `b` to `false` if a check fails.
  result = initHashSet[string]()
  for conceptExercise in visible(conceptExercises):
    for conceptTaught in conceptExercise.concepts:
      # Build a set of every concept taught by a user-facing Concept Exercise
      if result.containsOrIncl(conceptTaught):
        let msg = &"The Concept Exercise {q conceptExercise.slug} has " &
                  &"{q conceptTaught} in its `concepts`, but that concept " &
                   "appears in the `concepts` of another Concept Exercise"
        b.setFalseAndPrint(msg, path)
      if conceptTaught notin conceptSlugs:
        let msg = &"The Concept Exercise {q conceptExercise.slug} has " &
                  &"{q conceptTaught} in its `concepts`, which is not a " &
                   "`slug` in the top-level `concepts` array"
        b.setFalseAndPrint(msg, path)

proc checkPrerequisites(conceptExercises: seq[ConceptExercise];
                        conceptSlugs, conceptsTaught: HashSet[string];
                        b: var bool; path: Path) =
  ## Checks the `prerequisites` array of each user-facing Concept Exercise in
  ## `conceptExercises`, and sets `b` to `false` if a check fails.
  for conceptExercise in visible(conceptExercises):
    for prereq in conceptExercise.prerequisites:
      if prereq in conceptExercise.concepts:
        let msg = &"The Concept Exercise {q conceptExercise.slug} has " &
                  &"{q preReq} in both its `prerequisites` and its `concepts`"
        b.setFalseAndPrint(msg, path)
      elif prereq notin conceptsTaught:
        let msg = &"The Concept Exercise {q conceptExercise.slug} has " &
                  &"{q preReq} in its `prerequisites`, which is not in the " &
                   "`concepts` array of any other user-facing Concept Exercise"
        b.setFalseAndPrint(msg, path)

      if prereq notin conceptSlugs:
        let msg = &"The Concept Exercise {q conceptExercise.slug} has " &
                  &"{q preReq} in its `prerequisites`, which is not a " &
                   "`slug` in the top-level `concepts` array"
        b.setFalseAndPrint(msg, path)

proc checkPrerequisites(practiceExercises: seq[PracticeExercise];
                        conceptSlugs, conceptsTaught: HashSet[string];
                        b: var bool; path: Path) =
  ## Checks the `prerequisites` of each user-facing Practice Exercise in
  ## `practiceExercises`, and sets `b` to `false` if a check fails.
  var prereqsNotTaught = initOrderedSet[string]()
  var prereqsNotInTopLevelConcepts = initOrderedSet[string]()

  for practiceExercise in practiceExercises:
    case practiceExercise.status
    of sMissing, sBeta, sActive:
      for prereq in practiceExercise.prerequisites:
        if prereq notin conceptsTaught:
          prereqsNotTaught.incl prereq
          # TODO: Eventually make this an error, not a warning.
          if false:
            let msg = &"The Practice Exercise {q practiceExercise.slug} has " &
                      &"{q preReq} in its `prerequisites`, which is not in " &
                       "the `concepts` array of any user-facing Concept Exercise"
            b.setFalseAndPrint(msg, path)
        if prereq notin conceptSlugs:
          prereqsNotInTopLevelConcepts.incl prereq
          # TODO: Eventually make this an error, not a warning.
          if false:
            let msg = &"The Practice Exercise {q practiceExercise.slug} has " &
                      &"{q preReq} in its `prerequisites`, which is not a " &
                       "`slug` in the top-level `concepts` array"
            b.setFalseAndPrint(msg, path)
    of sWip, sDeprecated:
      discard

  if prereqsNotTaught.len > 0:
    let msg = "The following concepts exist in the `prerequisites` array " &
              &"of a Practice Exercise in {q $path}, but are not in the " &
               "`concepts` array of any user-facing Concept Exercise"
    let slugs = joinWithNewlines(prereqsNotTaught)
    warn(msg, slugs)

  if prereqsNotInTopLevelConcepts.len > 0:
    let msg = "The following concepts exist in the `prerequisites` array " &
              &"of a Practice Exercise in {q $path}, but do not exist in the " &
               "top-level `concepts` array"
    let slugs = joinWithNewlines(prereqsNotInTopLevelConcepts)
    warn(msg, slugs)

proc statusMsg(exercise: ConceptExercise | PracticeExercise;
               problem: string): string =
  ## Returns the error text for an `exercise` with the status-related `problem`.
  const exerciseKind =
    when exercise is ConceptExercise:
      "Concept Exercise"
    else:
      "Practice Exercise"
  let statusStr =
    case exercise.status
    of sMissing:
      "is user-facing (because a missing `status` key implies `active`)"
    of sDeprecated:
      "has a `status` of `deprecated`"
    else:
      &"is user-facing (because its `status` key has the value {q $exercise.status})"

  result = &"The {exerciseKind} {q exercise.slug} {statusStr}" &
           &", but has {problem}"

proc checkExercisesPCP(exercises: seq[ConceptExercise] | seq[PracticeExercise];
                       b: var bool; path: Path) =
  ## Checks the `prerequisites` array and either the `concepts` or `practices`
  ## array (hence "PCP") of every exercise in `exercises`, and sets `b` to
  ## `false` if a check fails.
  const conceptsOrPracticesStr =
    when exercises is seq[ConceptExercise]:
      "concepts"
    else:
      "practices"

  when exercises is seq[ConceptExercise]:
    var conceptExercisesWithEmptyPrereqs = newSeq[string]()

  for exercise in exercises:
    let conceptsOrPractices =
      when exercises is seq[ConceptExercise]:
        exercise.concepts
      else:
        exercise.practices

    let status = exercise.status

    case status
    of sMissing, sBeta, sActive:
      # Check either `concepts` or `practices`
      # TODO: enable the `practices` check when more tracks have populated them.
      when exercise is ConceptExercise:
        if conceptsOrPractices.len == 0:
          let msg = statusMsg(exercise, &"an empty array of `{conceptsOrPracticesStr}`")
          b.setFalseAndPrint(msg, path)

      # Check `prerequisites`
      when exercise is ConceptExercise:
        if exercise.prerequisites.len == 0:
          conceptExercisesWithEmptyPrereqs.add exercise.slug
      else:
        if exercise.slug == "hello-world":
          if exercise.prerequisites.len > 0:
            let msg = "The Practice Exercise `hello-world` must have an " &
                      "empty array of `prerequisites`"
            b.setFalseAndPrint(msg, path)
        else:
          # TODO: enable the Practice Exercise `prerequisites` check when more
          # tracks have populated them.
          if false:
            if exercise.prerequisites.len == 0:
              let msg = statusMsg(exercise, "an empty array of `prerequisites`")
              b.setFalseAndPrint(msg, path)

    of sDeprecated:
      # Check either `concepts` or `practices`
      if conceptsOrPractices.len > 0:
        let msg = statusMsg(exercise, &"a non-empty array of `{conceptsOrPracticesStr}`")
        b.setFalseAndPrint(msg, path)
      # Check `prerequisites`
      if exercise.prerequisites.len > 0:
        let msg = statusMsg(exercise, "a non-empty array of `prerequisites`")
        b.setFalseAndPrint(msg, path)

    of sWip:
      discard

  when exercises is seq[ConceptExercise]:
    if conceptExercisesWithEmptyPrereqs.len >= 2:
      var msg = "The Concept Exercises "
      for slug in conceptExercisesWithEmptyPrereqs:
        msg.add &"{q slug}, "
      msg.setLen(msg.len - 2)
      msg.add " each have an empty array of `prerequisites`, but only one Concept " &
              "Exercise is allowed to have that"
      b.setFalseAndPrint(msg, path)

proc checkExerciseSlugsAndForegone(exercises: Exercises; b: var bool;
                                   path: Path) =
  ## Sets `b` to `false` if the below conditions are not satisfied:
  ## - Each slug of a Concept Exercise or a Practice Exercise in `exercises`
  ##   only exists once on the track.
  ## - There is exactly one Practice Exercise with the slug `hello-world`.
  ## - The `foregone` array does not contain a slug of an implemented exercise.
  var conceptExerciseSlugs = initHashSet[string](exercises.`concept`.len)
  for conceptExercise in exercises.`concept`:
    let slug = conceptExercise.slug
    if conceptExerciseSlugs.containsOrIncl slug:
      let msg = &"There is more than one Concept Exercise with the slug {q slug}"
      b.setFalseAndPrint(msg, path)

  var practiceExerciseSlugs = initHashSet[string](exercises.practice.len)
  for practiceExercise in exercises.practice:
    let slug = practiceExercise.slug
    if practiceExerciseSlugs.containsOrIncl slug:
      let msg = &"There is more than one Practice Exercise with the slug {q slug}"
      b.setFalseAndPrint(msg, path)

  for slug in conceptExerciseSlugs:
    if slug in practiceExerciseSlugs:
      let msg = &"The slug {q slug} is used for both a Concept Exercise and " &
                 "a Practice Exercise, but must only appear once on the track"
      b.setFalseAndPrint(msg, path)

  if "hello-world" notin practiceExerciseSlugs:
    let msg = &"There must be a Practice Exercise with the slug `hello-world`"
    b.setFalseAndPrint(msg, path)

  for slug in exercises.foregone:
    if slug in conceptExerciseSlugs or slug in practiceExerciseSlugs:
      let msg = &"The `exercises.foregone` array contains the slug {q slug}, " &
                 "but there is an implemented exercise with that slug"
      b.setFalseAndPrint(msg, path)

proc satisfiesSecondPass(trackConfigContents: string; path: Path): bool =
  ## Returns `true` if `trackConfigContents` satisfies some checks.
  ##
  ## Each check in this second pass is generally more complex, and typically
  ## involves determining the validity of values in one key, depending on
  ## another key.
  ##
  ## To make these checks easier, this proc uses `jsony` to deserialize to a
  ## strongly typed `TrackConfig` object. Note that `jsony` is non-strict in
  ## several ways, so we do a first pass that verifies the key names and types.
  let trackConfig = toTrackConfig(trackConfigContents)
  result = true

  let exercises = trackConfig.exercises
  let conceptExercises = exercises.`concept`
  let practiceExercises = exercises.practice
  let concepts = trackConfig.concepts

  let conceptSlugs = getConceptSlugs(concepts)
  checkPractices(practiceExercises, conceptSlugs, result, path)
  let conceptsTaught = checkExerciseConcepts(conceptExercises, conceptSlugs,
                                             result, path)
  checkPrerequisites(conceptExercises, conceptSlugs, conceptsTaught, result,
                     path)
  checkPrerequisites(practiceExercises, conceptSlugs, conceptsTaught, result,
                     path)
  checkExercisesPCP(conceptExercises, result, path)
  checkExercisesPCP(practiceExercises, result, path)
  checkExerciseSlugsAndForegone(exercises, result, path)

proc isTrackConfigValid*(trackDir: Path): bool =
  result = true
  let trackConfigPath = trackDir / "config.json"
  let j = parseJsonFile(trackConfigPath, result)
  if j != nil:
    if not satisfiesFirstPass(j, trackConfigPath):
      result = false

  # Perform the second pass only if the track passes every previous check.
  if result:
    let trackConfigContents = readFile(trackConfigPath)
    result = satisfiesSecondPass(trackConfigContents, trackConfigPath)
