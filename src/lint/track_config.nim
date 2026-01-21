import std/[json, os, sets, strformat, strutils, tables]
import ".."/[helpers, types_track_config]
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
      hasString(d, "highlightjs_language", path, k, isRequired = false),
    ]
    result = allTrue(checks)

proc hasValidFiles(data: JsonNode; path: Path): bool =
  const f = "files"
  if hasKey(data, f):
    if hasObject(data, f, path, isRequired = false):
      let checks = [
        hasArrayOfStrings(data[f], "solution", path, context = f,
                          uniqueValues = true, isRequired = false,
                          checkIsFilesPattern = true),
        hasArrayOfStrings(data[f], "test", path, context = f,
                          uniqueValues = true, isRequired = false,
                          checkIsFilesPattern = true),
        hasArrayOfStrings(data[f], "example", path, context = f,
                          uniqueValues = true, isRequired = false,
                          checkIsFilesPattern = true),
        hasArrayOfStrings(data[f], "exemplar", path, context = f,
                          uniqueValues = true, isRequired = false,
                          checkIsFilesPattern = true),
        hasArrayOfStrings(data[f], "editor", path, context = f,
                          uniqueValues = true, isRequired = false,
                          checkIsFilesPattern = true),
        hasArrayOfStrings(data[f], "invalidator", path, context = f,
                          uniqueValues = true, isRequired = false,
                          checkIsFilesPattern = true),
      ]
      result = allTrue(checks)
  else:
    result = true

proc hasValidTestRunner(data: JsonNode; path: Path): bool =
  const s = "status"
  if hasObject(data, s, path):
    const k = "test_runner"
    if hasBoolean(data[s], k, path, s):
      # Only check the `test_runner` object if `status.test_runner` is `true`.
      if data[s][k].getBool():
        if hasObject(data, k, path):
          result = hasInteger(data[k], "average_run_time", path, k,
                              allowed = 1..20)
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
      hasInteger(data, "difficulty", path, context, allowed = 1..10),
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

    const k = "status"
    if result and data["slug"].getStr() == "hello-world" and data.hasKey(k):
      let statusVal = data[k].getStr()
      if statusVal != "active":
        let msg = &"The hello-world Practice Exercise has a {q k} of {q statusVal}, " &
                   "but for that exercise, either the value must be `active` or the " &
                   "key/value pair must be omitted (which implies `active`)"
        result.setFalseAndPrint(msg, path)

proc hasValidExercises(data: JsonNode; path: Path): bool =
  const k = "exercises"
  if hasObject(data, k, path):
    let exercises = data[k]
    let checks = [
      hasArrayOf(exercises, "concept", path, isValidConceptExercise, k,
                 isRequired = false, allowedLength = 0..int.high),
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
      hasValidAnalyzerTags(data, path),
    ]
    result = allTrue(checks)

proc hasValidConcepts(data: JsonNode; path: Path): bool =
  result = hasArrayOf(data, "concepts", path, isValidConcept,
                      isRequired = false, allowedLength = 0..int.high)

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
  const iconErrorAnnotation = """
    A key feature's `icon` is shown for the feature when presented on the website.
    The icon must be chosen from our list of supported icons:
    https://exercism.org/docs/building/tracks/icons#h-key-feature-icons
    You can choose any icon that you think fits, regardless of its name.

    For more information on key features see:
    https://exercism.org/docs/building/tracks/config-json#h-key-features""".unindent()

  const titleErrorAnnotation = """
    A key feature's `title` is a concise header for the key feature.
    As little technical jargon as possible should be used.
    Its length must be <= 25 and Markdown is not supported.

    For more information on key features see:
    https://exercism.org/docs/building/tracks/config-json#h-key-features""".unindent()

  const contentErrorAnnotation = """
    A key feature's `content` is a description of the key feature.
    Its length must be <= 100 and Markdown is not supported.

    For more information on key features see:
    https://exercism.org/docs/building/tracks/config-json#h-key-features""".unindent()

  if isObject(data, context, path):
    let checks = [
      hasString(data, "icon", path, context, allowed = keyFeatureIcons,
                errorAnnotation = iconErrorAnnotation),
      hasString(data, "title", path, context, maxLen = 25,
                errorAnnotation = titleErrorAnnotation),
      hasString(data, "content", path, context, maxLen = 100,
                errorAnnotation = contentErrorAnnotation),
    ]
    result = allTrue(checks)

proc hasValidKeyFeatures(data: JsonNode; path: Path): bool =
  const errorAnnotation = """
    The key features succinctly describe the most important features
    of the language to promote the language to potential students.
    Exactly 6 key features must be specified.

    For more information on key features see:
    https://exercism.org/docs/building/tracks/config-json#h-key-features""".unindent()
  result = hasArrayOf(data, "key_features", path, isValidKeyFeature,
                      isRequired = false, allowedLength = 6..6,
                      errorAnnotation = errorAnnotation)

const tags = [
  "paradigm/array",
  "paradigm/declarative",
  "paradigm/functional",
  "paradigm/imperative",
  "paradigm/logic",
  "paradigm/object_oriented",
  "paradigm/procedural",
  "paradigm/stack_oriented",
  "typing/static",
  "typing/dynamic",
  "typing/strong",
  "typing/weak",
  "typing/gradual",
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
  const errorAnnotation = """
    Tracks are annotated with tags to allow searching for tracks with certain tags.
    Tags must be chosen from our list of supported tags.
    Tags should be selected based on the general usage of their language.
    For more information on tags and the list of supported tags see:
    https://exercism.org/docs/building/tracks/config-json#h-tags""".unindent()
  result = hasArrayOfStrings(data, "tags", path, allowed = tags,
                             uniqueValues = true, errorAnnotation = errorAnnotation)

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
      hasValidFiles(data, path),
      hasValidTestRunner(data, path),
      hasValidExercises(data, path),
      hasValidConcepts(data, path),
      hasValidKeyFeatures(data, path),
      hasValidTags(data, path),
    ]
    result = allTrue(checks)

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
          let msg = &"The Practice Exercise {q $practiceExercise.slug} has " &
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
  ##
  ## Returns a `HashSet` of concepts taught by a user-facing Concept Exercise.
  result = initHashSet[string]()
  for conceptExercise in visible(conceptExercises):
    for conceptTaught in conceptExercise.concepts:
      # Build a set of every concept taught by a user-facing Concept Exercise
      if result.containsOrIncl(conceptTaught):
        let msg = &"The Concept Exercise {q $conceptExercise.slug} has " &
                  &"{q conceptTaught} in its `concepts`, but that concept " &
                   "appears in the `concepts` of another Concept Exercise"
        b.setFalseAndPrint(msg, path)
      if conceptTaught notin conceptSlugs:
        let msg = &"The Concept Exercise {q $conceptExercise.slug} has " &
                  &"{q conceptTaught} in its `concepts`, which is not a " &
                   "`slug` in the top-level `concepts` array"
        b.setFalseAndPrint(msg, path)

proc checkForCycle(prerequisitesByConcept: Table[string, seq[string]];
                   currentConcept: string;
                   prereqPath: seq[string];
                   conceptExerciseSlug: string;
                   b, hadCycle: var bool; path: Path) =
  ## Sets `b` to `false` if the given `conceptExerciseSlug` has a cycle due to
  ## its `prerequisites`.
  ##
  ## An example of such a cycle:
  ## - exercise slug A teaches concept A', and requires concept B'
  ## - exercise slug B teaches concept B', and requires concept C'
  ## - exercise slug C teaches concept C', and requires concept A'
  ##
  ## This is important to forbid because any exercise that is involved in such a
  ## cycle would not be unlockable.
  if hadCycle:
    return

  let updatedPrereqPath = prereqPath & currentConcept
  if currentConcept in prereqPath:
    var formattedCycle = &"{q updatedPrereqPath[0]} depends on {q updatedPrereqPath[1]}"
    for i in 1..prereqPath.high:
      formattedCycle.add &", which depends on {q updatedPrereqPath[i + 1]}"
    formattedCycle.add " forming a cycle"
    let msg = &"The Concept Exercise {q conceptExerciseSlug} has a " &
              &"cycle in its `prerequisites`: {formattedCycle}"
    b.setFalseAndPrint(msg, path)
    hadCycle = true
    return

  if prerequisitesByConcept.hasKey(currentConcept):
    for prereq in prerequisitesByConcept[currentConcept]:
      checkForCycle(prerequisitesByConcept, prereq, updatedPrereqPath,
                    conceptExerciseSlug, b, hadCycle, path)

proc checkPrerequisites(conceptExercises: seq[ConceptExercise];
                        conceptSlugs, conceptsTaught: HashSet[string];
                        b: var bool; path: Path) =
  ## Checks the `prerequisites` array of each user-facing Concept Exercise in
  ## `conceptExercises`, and sets `b` to `false` if a check fails.
  var prerequisitesByConcept = initTable[string, seq[string]]()
  for conceptExercise in visible(conceptExercises):
    for c in conceptExercise.concepts:
      if c notin prerequisitesByConcept:
        prerequisitesByConcept[c] = @[]
    for prereq in conceptExercise.prerequisites:
      for c in conceptExercise.concepts:
        prerequisitesByConcept[c].add prereq
      if prereq in conceptExercise.concepts:
        let msg = &"The Concept Exercise {q $conceptExercise.slug} has " &
                  &"{q prereq} in both its `prerequisites` and its `concepts`"
        b.setFalseAndPrint(msg, path)
      elif prereq notin conceptsTaught:
        let msg = &"The Concept Exercise {q $conceptExercise.slug} has " &
                  &"{q prereq} in its `prerequisites`, which is not in the " &
                   "`concepts` array of any other user-facing Concept Exercise"
        b.setFalseAndPrint(msg, path)

      if prereq notin conceptSlugs:
        let msg = &"The Concept Exercise {q $conceptExercise.slug} has " &
                  &"{q prereq} in its `prerequisites`, which is not a " &
                   "`slug` in the top-level `concepts` array"
        b.setFalseAndPrint(msg, path)

  # Check for cycles between `prerequisites` and `concepts`
  for conceptExercise in visible(conceptExercises):
    var hadCycle = false
    for c in conceptExercise.concepts:
      checkForCycle(prerequisitesByConcept, c, @[], $conceptExercise.slug, b,
                    hadCycle, path)

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
            let msg = &"The Practice Exercise {q $practiceExercise.slug} has " &
                      &"{q prereq} in its `prerequisites`, which is not in " &
                       "the `concepts` array of any user-facing Concept Exercise"
            b.setFalseAndPrint(msg, path)
        if prereq notin conceptSlugs:
          prereqsNotInTopLevelConcepts.incl prereq
          # TODO: Eventually make this an error, not a warning.
          if false:
            let msg = &"The Practice Exercise {q $practiceExercise.slug} has " &
                      &"{q prereq} in its `prerequisites`, which is not a " &
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

func statusMsg(exercise: ConceptExercise | PracticeExercise;
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

  result = &"The {exerciseKind} {q $exercise.slug} {statusStr}" &
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
  else:
    var countPracticeExercisesWithEmptyPractices = 0
    var countPracticeExercisesWithEmptyPrereqs = 0

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
      if conceptsOrPractices.len == 0:
        when exercise is ConceptExercise:
          let msg = statusMsg(exercise, &"an empty array of `{conceptsOrPracticesStr}`")
          b.setFalseAndPrint(msg, path)
        else:
          # TODO: Make each empty `practices` an error, not a warning.
          inc countPracticeExercisesWithEmptyPractices

      # Check `prerequisites`
      when exercise is ConceptExercise:
        if exercise.prerequisites.len == 0:
          conceptExercisesWithEmptyPrereqs.add $exercise.slug
      else:
        if $exercise.slug == "hello-world":
          if exercise.prerequisites.len > 0:
            let msg = "The Practice Exercise `hello-world` must have an " &
                      "empty array of `prerequisites`"
            b.setFalseAndPrint(msg, path)
        else:
          # TODO: Make an empty Practice Exercise `prerequisites` array an error,
          # not a warning
          if exercise.prerequisites.len == 0:
            inc countPracticeExercisesWithEmptyPrereqs

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
      msg.add " each have an empty array of `prerequisites`, but only one " &
              "Concept Exercise is allowed to have that"
      b.setFalseAndPrint(msg, path)
  else:
    if countPracticeExercisesWithEmptyPractices > 0:
      let msg = &"{countPracticeExercisesWithEmptyPractices} user-facing " &
                 "Practice Exercises have an empty `practices` array"
      warn(msg, path)
    if countPracticeExercisesWithEmptyPrereqs > 0:
      let msg = &"{countPracticeExercisesWithEmptyPrereqs} user-facing " &
                 "Practice Exercises have an empty `prerequisites` array"
      warn(msg, path)

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
    if conceptExerciseSlugs.containsOrIncl $slug:
      let msg = &"There is more than one Concept Exercise with the slug {q $slug}"
      b.setFalseAndPrint(msg, path)

  var practiceExerciseSlugs = initHashSet[string](exercises.practice.len)
  for practiceExercise in exercises.practice:
    let slug = practiceExercise.slug
    if practiceExerciseSlugs.containsOrIncl $slug:
      let msg = &"There is more than one Practice Exercise with the slug {q $slug}"
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

proc checkFilePatternsOverlap(filePatterns: FilePatterns; trackSlug: string;
                              b: var bool; path: Path) =
  const overlappingSolutionTestTrackSlugs = ["d", "plsql"]
  const uniqueFilePatternCombinations = [
    ("solution", "test"),
    ("solution", "example"),
    ("solution", "exemplar"),
    ("solution", "editor"),
    ("solution", "invalidator"),
    ("test", "example"),
    ("test", "exemplar"),
    ("test", "editor"),
    ("test", "invalidator"),
    ("editor", "example"),
    ("editor", "exemplar"),
    ("editor", "invalidator"),
    ("invalidator", "example"),
    ("invalidator", "exemplar"),
  ]

  var seenFilePatterns = initTable[string, HashSet[string]](250)
  for key, patterns in filePatterns.fieldPairs:
    seenFilePatterns[key] = patterns.toHashSet

  for (key1, key2) in uniqueFilePatternCombinations:
    if key1 == "solution" and key2 == "test" and trackSlug in overlappingSolutionTestTrackSlugs:
      continue

    let duplicatePatterns = seenFilePatterns[key1] * seenFilePatterns[key2]
    for duplicatePattern in duplicatePatterns:
      let msg =
        &"The values in the `files.{key1}` and `files.{key2}` keys must not overlap, " &
        &"but the {q duplicatePattern} value appears in both"
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
  let trackConfig = TrackConfig.init(trackConfigContents)
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
  checkFilePatternsOverlap(trackConfig.files, trackConfig.slug, result, path)

proc getExerciseSlugs(data: JsonNode; k: string): HashSet[string] =
  result = initHashSet[string]()
  if data.kind != JObject or "exercises" notin data:
    return

  let exercises = data["exercises"]

  if exercises.kind != JObject or k notin exercises or exercises[k].kind != JArray:
    return

  for exercise in exercises[k]:
    if exercise.kind == JObject:
      if exercise.hasKey("slug"):
        let slug = exercise["slug"]
        if slug.kind == JString:
          let slugStr = slug.getStr()
          if slugStr.len > 0:
            result.incl slugStr

proc checkExerciseDirsAndTrackConfigAreInSync(trackDir: Path; data: JsonNode;
                                              b: var bool; path: Path) =
  ## Sets `b` to `false` if there is an exercise directory that is
  ## not an exercise `slug` in `data` and vice versa.
  for exerciseKind in ["concept", "practice"]:
    let exerciseSlugs = getExerciseSlugs(data, exerciseKind)
    let exercisesDir = trackDir / "exercises" / exerciseKind
    var exerciseDirSlugs = initHashSet[string]()

    if dirExists(exercisesDir):
      for exerciseDir in getSortedSubdirs(exercisesDir):
        exerciseDirSlugs.incl lastPathPart(exerciseDir.string)

    for exerciseSlug in exerciseDirSlugs - exerciseSlugs:
      let msg = &"{q $exercisesDir} contains a directory named {q exerciseSlug}, " &
                &"which is not a `slug` in the array of {exerciseKind} " &
                  "exercises. Please add the exercise to that array. " &
                  "If the exercise is not ready to be shown on the " &
                  "website, please set its `status` value to \"wip\""
      b.setFalseAndPrint(msg, path)

    for exerciseSlug in exerciseSlugs - exerciseDirSlugs:
      let exerciseDir = exercisesDir / exerciseSlug
      let msg = &"The {q exerciseSlug} {exerciseKind} exercise is missing its " &
                &"required files. Please create the {q $exerciseDir} directory with " &
                "its required files"
      b.setFalseAndPrint(msg, path)

proc getConceptSlugs(data: JsonNode): HashSet[string] =
  result = initHashSet[string]()
  if data.kind != JObject or "concepts" notin data:
    return

  let concepts = data["concepts"]
  if concepts.kind != JArray:
    return

  for conceptNode in concepts:
    if conceptNode.kind == JObject:
      if conceptNode.hasKey("slug"):
        let slug = conceptNode["slug"]
        if slug.kind == JString:
          let slugStr = slug.getStr()
          if slugStr.len > 0:
            result.incl slugStr

proc checkConceptDirsAndTrackConfigAreInSync(trackDir: Path; data: JsonNode;
                                             b: var bool; path: Path) =
  ## Sets `b` to `false` if there is a concept directory that is
  ## not a concept `slug` in `data` or vice versa.
  let conceptSlugs = getConceptSlugs(data)
  let conceptsDir = trackDir / "concepts"
  var conceptDirSlugs = initHashSet[string]()

  if dirExists(conceptsDir):
    for conceptDir in getSortedSubdirs(conceptsDir):
      conceptDirSlugs.incl lastPathPart(conceptDir.string)

  for conceptSlug in conceptDirSlugs - conceptSlugs:
    let msg = &"{q $conceptsDir} contains a directory named {q conceptSlug}, " &
              &"which is not a `slug` in the concepts array. " &
               "Please add the concept to that array"
    b.setFalseAndPrint(msg, path)

  for conceptSlug in conceptSlugs - conceptDirSlugs:
    let conceptDir = conceptsDir / conceptSlug
    let msg = &"The {q conceptSlug} concept is missing its required files. " &
              &"Please create the {q $conceptDir} directory with its required files"
    b.setFalseAndPrint(msg, path)

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

  if j != nil:
    checkExerciseDirsAndTrackConfigAreInSync(trackDir, j, result, trackConfigPath)
    checkConceptDirsAndTrackConfigAreInSync(trackDir, j, result, trackConfigPath)
