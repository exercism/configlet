import std/[strformat, strutils]
import ".."/[cli, helpers]
import "."/[approaches_and_articles, concept_exercises, concepts, docs,
            practice_exercises, track_config, validators]

proc allChecksPass(trackDir: Path): bool =
  ## Returns true if all the linting checks pass for the track at `trackDir`.
  # We avoid some short-circuit evaluation here (e.g. due to `and`) because we
  # want to see errors from later checks even if earlier ones return `false`.
  let checks = [
    isTrackConfigValid(trackDir),
    conceptExerciseDocsExist(trackDir),
    practiceExerciseDocsExist(trackDir),
    conceptDocsExist(trackDir),
    isEveryConceptLinksFileValid(trackDir),
    isEveryConceptConfigValid(trackDir),
    isEveryConceptExerciseConfigValid(trackDir),
    isEveryPracticeExerciseConfigValid(trackDir),
    isEveryApproachAndArticleValid(trackDir),
    sharedExerciseDocsExist(trackDir),
    trackDocsExist(trackDir),
  ]
  result = allTrue(checks)

proc lint*(conf: Conf) =
  echo """
    The lint command is under development.
    To check your track using the latest linting rules,
    please regularly update configlet and re-run this command.
  """.unindent()

  let trackDir = Path(conf.trackDir)

  const url = "https://exercism.org/docs/building/configlet/lint"

  if allChecksPass(trackDir):
    echo """
      Basic linting finished successfully:
      - config.json exists and is valid JSON
      - config.json has these valid fields:
          language, slug, active, blurb, version, status, online_editor, key_features, tags
      - Every concept has the required .md files
      - Every concept has a valid links.json file
      - Every concept has a valid .meta/config.json file
      - Every concept exercise has the required .md files
      - Every concept exercise has a valid .meta/config.json file
      - Every practice exercise has the required .md files
      - Every practice exercise has a valid .meta/config.json file
      - Every approach and article is valid
      - Required track docs are present
      - Required shared exercise docs are present""".dedent()
    if printedWarning:
      echo ""
      const msg = """
        Configlet produced at least one warning.
        These warnings might become errors in a future configlet release.
        For more information, please see the documentation:""".unindent()
      warn(msg, url, doubleFinalNewline = false)
  else:
    echo fmt"""
      Configlet detected at least one problem.
      For more information on resolving the problems, please see the documentation:
      {url}""".unindent()
    quit QuitFailure
