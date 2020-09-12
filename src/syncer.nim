import exercises, strformat

proc syncTests*: void =
  echo "Exercises:"
  let exercises = findExercises()
  echo exercises[0].slug

  for testCase in exercises[0].testCases:
    echo &"# {testCase.description}"
    echo &"{uuid} = {testCase.status}"
    echo ""
