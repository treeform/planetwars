cimport boxy, windy, opengl, vmath, pixie
import sim
import std/sequtils

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

proc createPlanetImage(color: ColorRGBA, size: int): Image =
  result = newImage(size, size)
  result.fill(rgba(0, 0, 0, 0))  # Transparent background
  
  let ctx = newContext(result)
  let center = vec2(size.float / 2, size.float / 2)
  let radius = size.float / 2 - 2
  
  # Draw main planet circle
  ctx.fillStyle = color
  ctx.fillCircle(circle(center, radius))
  
  # Draw border
  ctx.strokeStyle = rgba(255, 255, 255, 128)
  ctx.lineWidth = 1.0
  ctx.strokeCircle(circle(center, radius))

proc createFleetImage(color: ColorRGBA, size: int): Image =
  result = newImage(size, size)
  result.fill(rgba(0, 0, 0, 0))  # Transparent background
  
  let ctx = newContext(result)
  let center = vec2(size.float / 2, size.float / 2)
  let halfSize = size.float / 2 - 1
  
  # Draw diamond shape for fleet
  ctx.fillStyle = color
  ctx.beginPath()
  ctx.moveTo(center.x, center.y - halfSize)  # Top
  ctx.lineTo(center.x + halfSize, center.y)  # Right
  ctx.lineTo(center.x, center.y + halfSize)  # Bottom
  ctx.lineTo(center.x - halfSize, center.y)  # Left
  ctx.closePath()
  ctx.fill()
  
  # Draw border
  ctx.strokeStyle = rgba(255, 255, 255, 128)
  ctx.lineWidth = 1.0
  ctx.stroke()

proc initVisualizer*(windowWidth, windowHeight: int): Visualizer =
  let window = newWindow("PlanetWars", ivec2(windowWidth.int32, windowHeight.int32))
  window.makeContextCurrent()
  loadExtensions()
  
  let bxy = newBoxy()
  
  # Create planet images for each player color
  for i, color in PlanetColors:
    # Large planets (for high population)
    bxy.addImage("planet_large_" & $i, createPlanetImage(color, 60))
    # Medium planets
    bxy.addImage("planet_medium_" & $i, createPlanetImage(color, 40))
    # Small planets (for low population)
    bxy.addImage("planet_small_" & $i, createPlanetImage(color, 20))
    
    # Fleet images
    bxy.addImage("fleet_large_" & $i, createFleetImage(color, 20))
    bxy.addImage("fleet_medium_" & $i, createFleetImage(color, 15))
    bxy.addImage("fleet_small_" & $i, createFleetImage(color, 10))
  
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

proc getPlanetSize*(population: int32): string =
  if population < 30:
    return "small"
  elif population < 70:
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

proc drawPlanet*(viz: Visualizer, planet: Planet) =
  let screenPos = viz.worldToScreen(planet.pos)
  let colorIndex = getPlayerColorIndex(planet.owner)
  let sizeStr = getPlanetSize(planet.population)
  
  let imageKey = "planet_" & sizeStr & "_" & $colorIndex
  let imageSize = case sizeStr:
    of "small": 20.0
    of "medium": 40.0
    else: 60.0
  
  # Draw planet image centered
  viz.bxy.drawImage(
    imageKey,
    rect = rect(
      screenPos.x - imageSize / 2,
      screenPos.y - imageSize / 2,
      imageSize,
      imageSize
    )
  )

proc drawFleet*(viz: Visualizer, fleet: Fleet) =
  let screenPos = viz.worldToScreen(fleet.pos)
  let colorIndex = getPlayerColorIndex(fleet.owner)
  let sizeStr = getFleetSize(fleet.ships)
  
  let imageKey = "fleet_" & sizeStr & "_" & $colorIndex
  let imageSize = case sizeStr:
    of "small": 10.0
    of "medium": 15.0
    else: 20.0
  
  # Draw fleet image centered
  viz.bxy.drawImage(
    imageKey,
    rect = rect(
      screenPos.x - imageSize / 2,
      screenPos.y - imageSize / 2,
      imageSize,
      imageSize
    )
  )
  
  # Draw trajectory line to target using a simple rectangle
  let targetScreenPos = viz.worldToScreen(fleet.targetPos)
  let direction = (targetScreenPos - screenPos).normalize()
  let lineLength = (targetScreenPos - screenPos).length()
  
  if lineLength > 0:
    # Draw a thin rectangle as the trajectory line
    viz.bxy.drawRect(
      rect = rect(
        screenPos.x,
        screenPos.y - 1,
        lineLength * direction.x,
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
    let totalPop = planets.mapIt(state.planets[it].population).foldl(a + b, 0)
    
    # Draw player status rectangle
    let width = 200.0 + totalPop.float * 0.5  # Width based on population
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
