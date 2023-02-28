import ".."/[cli]

proc create*(conf: Conf) =
  if conf.action.kind == actCreate:
    echo conf.action.approachSlug
    echo conf.action.exerciseCreate
  else:
    quit 1
  
