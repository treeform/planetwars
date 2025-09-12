import genny, ../sim

exportRefObject Environment:
  constructor:
    newEnvironment
  procs:
    reset(Environment)
    step(Environment, seq[float32]): seq[float32]

writeFiles("bindings/generated", "planetwars")
include generated/internal
