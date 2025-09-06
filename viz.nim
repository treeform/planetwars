import boxy, windy, opengl, vmath, pixie
import sim
import std/[sequtils, math]

type
  Visualizer* = object
    bxy*: Boxy
    window*: Window
    windowSize*: vmath.Vec2
    scale*: float
    offset*: vmath.Vec2
    
const
  PlanetColors = [
    rgba(204, 204, 204, 255),  # Neutral - gray
    rgba(51, 204, 51, 255),    # Player 0 - green  
    rgba(204, 51, 51, 255),    # Player 1 - red
    rgba(51, 51, 204, 255),    # Player 2 - blue
    rgba(204, 204, 51, 255),   # Player 3 - yellow
    rgba(204, 51, 204, 255),   # Player 4 - magenta
    rgba(51, 204, 204, 255),   # Player 5 - cyan
  ]

# No longer need to create images - we'll use the provided ones with tinting

proc initVisualizer*(windowWidth, windowHeight: int): Visualizer =
  let window = newWindow("PlanetWars", ivec2(windowWidth.int32, windowHeight.int32))
  window.makeContextCurrent()
  loadExtensions()
  
  let bxy = newBoxy()
  
  # Load the base images (only once at startup)
  bxy.addImage("planet", readImage("data/Planet.png"))
  bxy.addImage("fleet", readImage("data/Fleet.png"))
  
  # Load digit images
  for digit in 0..9:
    bxy.addImage("digit_" & $digit, readImage("data/Number" & $digit & ".png"))
  
  result = Visualizer(
    bxy: bxy,
    window: window,
    windowSize: vmath.vec2(windowWidth.float, windowHeight.float),
    scale: min(windowWidth.float / MapWidth.float, windowHeight.float / MapHeight.float),
    offset: vmath.vec2(0.0, 0.0)
  )

proc worldToScreen*(viz: Visualizer, worldPos: sim.Vec2): vmath.Vec2 =
  vmath.vec2(
    (worldPos.x.float * viz.scale) + viz.offset.x,
    (worldPos.y.float * viz.scale) + viz.offset.y
  )

proc getPlayerColorIndex*(playerId: PlayerId): int =
  if playerId == NeutralPlayer:
    return 0
  elif playerId < PlanetColors.len.int32 - 1:
    return (playerId + 1).int
  else:
    return 0

proc getPlanetSize*(ships: int32): string =
  if ships < 30:
    return "small"
  elif ships < 70:
    return "medium"
  else:
    return "large"

proc getFleetSize*(ships: int32): string =
  if ships < 10:
    return "small"
  elif ships < 25:
    return "medium"
  else:
    return "large"

proc drawNumber*(viz: Visualizer, number: int32, pos: vmath.Vec2, digitSize: float = 16.0) =
  if number < 0:
    return
    
  let numStr = $number
  let totalWidth = numStr.len.float * digitSize * 0.6  # Slightly overlapped
  var xPos = pos.x - totalWidth / 2  # Center the number
  
  for digit in numStr:
    let digitKey = "digit_" & $digit
    viz.bxy.drawImage(
      digitKey,
      rect = rect(
        xPos,
        pos.y - digitSize / 2,
        digitSize,
        digitSize
      )
      # No tint needed - digit images are already white
    )
    xPos += digitSize * 0.6  # Move to next digit position

proc drawPlanet*(viz: Visualizer, planet: Planet) =
  let screenPos = viz.worldToScreen(planet.pos)
  let colorIndex = getPlayerColorIndex(planet.owner)
  let sizeStr = getPlanetSize(planet.ships)
  
  let imageSize = case sizeStr:
    of "small": 20.0
    of "medium": 40.0
    else: 60.0
  
  # Get player color for tinting
  let tintColor = PlanetColors[colorIndex].color
  
  # Draw planet image centered with tinting and scaling
  viz.bxy.drawImage(
    "planet",
    rect = rect(
      screenPos.x - imageSize / 2,
      screenPos.y - imageSize / 2,
      imageSize,
      imageSize
    ),
    tint = tintColor
  )
  
  # Draw ship count in the center of the planet
  if planet.ships > 0:
    viz.drawNumber(planet.ships, screenPos, imageSize * 0.25)

proc drawFleet*(viz: Visualizer, fleet: Fleet) =
  let screenPos = viz.worldToScreen(fleet.pos)
  let colorIndex = getPlayerColorIndex(fleet.owner)
  let sizeStr = getFleetSize(fleet.ships)
  
  # Calculate direction to target for rotation
  let targetScreenPos = viz.worldToScreen(fleet.targetPos)
  let direction = targetScreenPos - screenPos
  let angle = arctan2(direction.y, direction.x)
  
  let imageSize = case sizeStr:
    of "small": 10.0
    of "medium": 15.0
    else: 20.0
  
  # Get player color for tinting
  let tintColor = PlanetColors[colorIndex].color
  
  # Draw fleet image centered with tinting, scaling, and rotation
  viz.bxy.drawImage(
    "fleet",
    center = vmath.vec2(screenPos.x, screenPos.y),
    angle = angle,
    tint = tintColor,
    scale = imageSize / 32.0  # Assuming base fleet image is ~32px
  )
  
  # Draw ship count in the center of the fleet
  if fleet.ships > 0:
    viz.drawNumber(fleet.ships, screenPos, imageSize * 0.4)
  
  # Draw trajectory line to target using a simple rectangle
  let lineLength = direction.length()
  
  if lineLength > 0:
    # Draw a thin rectangle as the trajectory line
    viz.bxy.drawRect(
      rect = rect(
        screenPos.x,
        screenPos.y - 1,
        lineLength * direction.normalize().x,
        2
      ),
      color = rgba(
        (PlanetColors[colorIndex].r.float * 0.3).uint8,
        (PlanetColors[colorIndex].g.float * 0.3).uint8,
        (PlanetColors[colorIndex].b.float * 0.3).uint8,
        76
      ).color
    )

proc drawUI*(viz: Visualizer, state: GameState) =
  # Draw simple UI using rectangles as backgrounds for text areas
  # For now, skip text rendering since boxy doesn't have built-in text support
  # We'll just show basic info using colored rectangles
  
  # Draw turn indicator as a small colored rectangle
  viz.bxy.drawRect(
    rect = rect(10, 10, 100, 20),
    color = rgba(50, 50, 50, 200).color
  )
  
  # Draw player status indicators
  var yPos = 40.0
  for playerId in state.players:
    let planets = state.getPlanetsOwnedBy(playerId)
    let colorIndex = getPlayerColorIndex(playerId)
    let totalShips = planets.mapIt(state.planets[it].ships).foldl(a + b, 0)
    
    # Draw player status rectangle
    let width = 200.0 + totalShips.float * 0.5  # Width based on ships
    viz.bxy.drawRect(
      rect = rect(10, yPos, width, 15),
      color = rgba(
        (PlanetColors[colorIndex].r.float * 0.7).uint8,
        (PlanetColors[colorIndex].g.float * 0.7).uint8,
        (PlanetColors[colorIndex].b.float * 0.7).uint8,
        178
      ).color
    )
    yPos += 20.0

proc render*(viz: Visualizer, state: GameState) =
  
  viz.bxy.beginFrame(ivec2(viz.windowSize.x.int32, viz.windowSize.y.int32))
  
  # Draw all planets
  for planet in state.planets:
    viz.drawPlanet(planet)
  
  # Draw all fleets
  for fleet in state.fleets:
    viz.drawFleet(fleet)
  
  # Draw UI
  viz.drawUI(state)
  
  viz.bxy.endFrame()
  viz.window.swapBuffers()

proc shouldClose*(viz: Visualizer): bool =
  viz.window.closeRequested

proc pollEvents*(viz: Visualizer) =
  pollEvents()
  
proc cleanup*(viz: Visualizer) =
  viz.window.close()
