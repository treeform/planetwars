import boxy, windy, opengl, vmath, pixie
import sim
import std/math

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
  let window = newWindow(
    "PlanetWars", 
    ivec2(windowWidth.int32, windowHeight.int32),
    style = Decorated
  )
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
    scale: 1f,
    offset: vmath.vec2(100f, 100f)
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

proc getPlanetSize*(growthRate: int32): float =
  # Planet size based on growth rate, with a reasonable range
  let baseSize = 50f
  let sizeMultiplier = 4f
  return baseSize + (growthRate.float * sizeMultiplier)

proc getFleetSize*(): float =
  # All fleets are the same size now, and smaller
  return 8f

proc getFleetVisualPosition*(state: GameState, fleet: Fleet): sim.Vec2 =
  # Calculate the visual position of a fleet based on its travel progress
  let startPos = state.planets[fleet.startPlanet].pos
  let targetPos = state.planets[fleet.targetPlanet].pos
  
  if fleet.travelDuration <= 0:
    return startPos  # Shouldn't happen, but safety check
  
  # Calculate progress ratio (0.0 to 1.0)
  let progressRatio = fleet.travelProgress.float / fleet.travelDuration.float
  
  # Interpolate between start and target positions
  let deltaX = targetPos.x - startPos.x
  let deltaY = targetPos.y - startPos.y
  
  result.x = startPos.x + (deltaX.float * progressRatio).int32
  result.y = startPos.y + (deltaY.float * progressRatio).int32

proc drawNumber*(viz: Visualizer, number: int32, pos: vmath.Vec2, digitSize: float = 20f) =
  if number < 0:
    return
    
  let numStr = $number
  let spacing = digitSize * 0.8  # More spacing between digits
  let totalWidth = numStr.len.float * spacing
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
    xPos += spacing  # Move to next digit position with more spacing

proc drawPlanet*(viz: Visualizer, planet: Planet) =
  let screenPos = viz.worldToScreen(planet.pos)
  let colorIndex = getPlayerColorIndex(planet.owner)
  let imageSize = getPlanetSize(planet.growthRate)  # Size based on growth rate now
  
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
  
  # Draw ship count in the center of the planet (bigger numbers)
  if planet.ships > 0:
    viz.drawNumber(planet.ships, screenPos)

proc drawFleet*(viz: Visualizer, state: GameState, fleet: Fleet) =
  # Calculate current visual position based on travel progress
  let fleetPos = getFleetVisualPosition(state, fleet)
  let screenPos = viz.worldToScreen(fleetPos)
  let colorIndex = getPlayerColorIndex(fleet.owner)
  let imageSize = getFleetSize()  # All fleets same size now
  
  # Calculate direction to target for rotation
  let targetPos = state.planets[fleet.targetPlanet].pos
  let targetScreenPos = viz.worldToScreen(targetPos)
  let direction = targetScreenPos - screenPos
  let angle = -arctan2(direction.y, direction.x) - PI/2
  
  # Get player color for tinting
  let tintColor = PlanetColors[colorIndex].color
  
  # Draw fleet image centered with tinting, scaling, and rotation
  viz.bxy.drawImage(
    "fleet",
    center = vmath.vec2(screenPos.x, screenPos.y),
    angle = angle,
    tint = tintColor,
    scale = imageSize / 32f  # Assuming base fleet image is ~32px
  )
  
  # Draw ship count in the center of the fleet (bigger numbers)
  if fleet.ships > 0:
    viz.drawNumber(fleet.ships, screenPos)
  

proc drawUI*(viz: Visualizer, state: GameState) =
  # Calculate ship counts for all players
  var playerShips: seq[int32] = @[]
  var maxShips = 0'i32
  
  for playerId in state.players:
    let planets = state.getPlanetsOwnedBy(playerId)
    var totalShips = 0'i32
    for planetId in planets:
      totalShips += state.planets[planetId].ships
    playerShips.add(totalShips)
    if totalShips > maxShips:
      maxShips = totalShips
  
  # Draw player status bars (scaled to 500px max)
  var yPos = 5f
  let barHeight = 15f
  let maxBarWidth = 500f
  
  for i, playerId in state.players:
    let colorIndex = getPlayerColorIndex(playerId)
    let ships = playerShips[i]
    
    # Scale bar width based on ship count (max 500px)
    let width = if maxShips > 0: (ships.float / maxShips.float) * maxBarWidth else: 0f
    
    # Draw player status bar
    if width > 0:
      viz.bxy.drawRect(
        rect = rect(10, yPos, width, barHeight),
        color = rgba(
          (PlanetColors[colorIndex].r.float * 0.7).uint8,
          (PlanetColors[colorIndex].g.float * 0.7).uint8,
          (PlanetColors[colorIndex].b.float * 0.7).uint8,
          178
        ).color
      )
    
    # Draw ship count number on the bar itself
    if ships > 0:
      viz.drawNumber(ships, vmath.vec2(25f, yPos + barHeight / 2))
    
    yPos += 20f  # Normal spacing between bars

proc render*(viz: Visualizer, state: GameState) =
  
  viz.bxy.beginFrame(ivec2(viz.windowSize.x.int32, viz.windowSize.y.int32))
  
  # Draw all planets
  for planet in state.planets:
    viz.drawPlanet(planet)
  
  # Draw all fleets
  for fleet in state.fleets:
    viz.drawFleet(state, fleet)
  
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
