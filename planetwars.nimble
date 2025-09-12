# Package

version       = "0.1.0"
author        = "Anonymous"
description   = "PlanetWars/Galcon style AI benchmark"
license       = "MIT"
srcDir        = "."
bin           = @["main"]


# Dependencies

requires "nim >= 1.6.0"
requires "boxy"
requires "windy"


task bindings, "Generate bindings":

  proc compile(libName: string, flags = "") =
    exec "nim c -f " & flags & " -d:release --app:lib --gc:arc --tlsEmulation:off --out:" & libName & " --outdir:bindings/generated bindings/bindings.nim"

  when defined(windows):
    compile "planetwars.dll"

  elif defined(macosx):
    compile "libplanetwars.dylib"

  else:
    compile "libplanetwars.so"
