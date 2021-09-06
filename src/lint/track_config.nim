import std/[json, sets, strformat]
import pkg/jsony
import ".."/helpers
import "."/validators

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

type
  Status = enum
    sMissing = "missing"
    sWip = "wip"
    sBeta = "beta"
    sActive = "active"
    sDeprecated = "deprecated"

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

  Concept = object
    name: string
    slug: string
    uuid: string

  Concepts = seq[Concept]

  TrackConfig = object
    exercises: Exercises
    concepts: Concepts

func getConceptSlugs(trackConfig: TrackConfig): HashSet[string] =
  ## Returns a set of every `slug` in the top-level `concepts` array of a track
  ## `config.json` file.
  result = initHashSet[string]()
  for con in trackConfig.concepts:
    result.incl con.slug

iterator visibleConceptExercises(trackConfig: TrackConfig): ConceptExercise =
  ## Yields every Concept Exercise in `trackConfig` that appears on the website.
  ## That is, every Concept Exercise that has a `status` of `beta` or `active`,
  ## or that omits the `status` property entirely (which implies `active`).
  for conceptExercise in trackConfig.exercises.`concept`:
    if conceptExercise.status in [sMissing, sBeta, sActive]:
      yield conceptExercise

proc checkExerciseConcepts(trackConfig: TrackConfig;
                           conceptSlugs: HashSet[string]; b: var bool;
                           path: Path): HashSet[string] =
  ## Checks the `concepts` array of each user-facing Concept Exercise in
  ## `trackConfig`, and sets `b` to `false` if a check fails.
  result = initHashSet[string]()
  for conceptExercise in visibleConceptExercises(trackConfig):
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

proc checkExercisePrerequisites(trackConfig: TrackConfig;
                                conceptSlugs, conceptsTaught: HashSet[string];
                                b: var bool; path: Path) =
  ## Checks the `prerequisites` array of each user-facing Concept Exercise in
  ## `trackConfig`, and sets `b` to `false` if a check fails.
  for conceptExercise in visibleConceptExercises(trackConfig):
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

proc statusMsg(exercise: ConceptExercise | PracticeExercise;
               problem: string): string =
  ## Returns the error text for an `exercise` with the status-related `problem`.
  const exerciseKind =
    when exercise is ConceptExercise:
      "Concept Exercise"
    else:
      "Practice Exercise"
  result = &"The {exerciseKind} {q exercise.slug} has a `status` " &
           &"of {q $exercise.status}, but has {problem}"

proc checkConceptExercises(conceptExercises: seq[ConceptExercise];
                           b: var bool; path: Path) =
  ## Checks the `concepts` and `prerequisites` array of each exercise in
  ## `conceptExercises`, and sets `b` to `false` if a check fails.
  for conceptExercise in conceptExercises:
    let status = conceptExercise.status
    case status
    of sMissing, sBeta, sActive:
      if conceptExercise.concepts.len == 0:
        let msg = statusMsg(conceptExercise, "an empty array of `concepts`")
        b.setFalseAndPrint(msg, path)
    of sDeprecated:
      if conceptExercise.concepts.len > 0:
        let msg = statusMsg(conceptExercise, "a non-empty array of `concepts`")
        b.setFalseAndPrint(msg, path)
      if conceptExercise.prerequisites.len > 0:
        let msg = statusMsg(conceptExercise, "a non-empty array of `prerequisites`")
        b.setFalseAndPrint(msg, path)
    of sWip:
      discard

proc checkPracticeExercises(practiceExercises: seq[PracticeExercise];
                            b: var bool; path: Path) =
  ## Checks the `practices` and `prerequisites` array of each exercise in
  ## `practiceExercises`, and sets `b` to `false` if a check fails.
  for practiceExercise in practiceExercises:
    let status = practiceExercise.status
    case status
    of sMissing, sBeta, sActive:
      if practiceExercise.practices.len == 0:
        let msg = statusMsg(practiceExercise, "an empty array of `practices`")
        b.setFalseAndPrint(msg, path)
      if practiceExercise.prerequisites.len == 0:
        let msg = statusMsg(practiceExercise, "an empty array of `prerequisites`")
        b.setFalseAndPrint(msg, path)
    of sDeprecated:
      if practiceExercise.practices.len > 0:
        let msg = statusMsg(practiceExercise, "a non-empty array of `practices`")
        b.setFalseAndPrint(msg, path)
      if practiceExercise.prerequisites.len > 0:
        let msg = statusMsg(practiceExercise, "a non-empty array of `prerequisites`")
        b.setFalseAndPrint(msg, path)
    of sWip:
      discard

proc satisfiesSecondPass(s: string; path: Path): bool =
  let trackConfig = fromJson(s, TrackConfig)
  result = true

  let conceptSlugs = getConceptSlugs(trackConfig)
  let conceptsTaught = checkExerciseConcepts(trackConfig, conceptSlugs, result,
                                             path)
  checkExercisePrerequisites(trackConfig, conceptSlugs, conceptsTaught, result,
                             path)
  checkConceptExercises(trackConfig.exercises.`concept`, result, path)
  checkPracticeExercises(trackConfig.exercises.practice, result, path)

proc isValidTrackConfig(data: JsonNode; path: Path): bool =
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

proc isTrackConfigValid*(trackDir: Path): bool =
  result = true
  let trackConfigPath = trackDir / "config.json"
  let j = parseJsonFile(trackConfigPath, result)
  if j != nil:
    if not isValidTrackConfig(j, trackConfigPath):
      result = false

  if result:
    let trackConfigContents = readFile(trackConfigPath)
    result = satisfiesSecondPass(trackConfigContents, trackConfigPath)
