import arguments, commands/[check,update]

let args = parseArguments()

case args.command
of Command.check:
  check(args)
of Command.update:
  update(args)
