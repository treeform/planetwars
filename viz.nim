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
    selectedPlanet*: PlanetId  # -1 if no selection
    smoothingEnabled*: bool    # Fleet position smoothing toggle
    
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
  bxy.addImage("background", readImage("data/Background.png"))
  bxy.addImage("planet", readImage("data/Planet.png"))
  bxy.addImage("fleet", readImage("data/Fleet.png"))
  bxy.addImage("selection", readImage("data/Selection.png"))
  
  # Load digit images
  for digit in 0..9:
    bxy.addImage("digit_" & $digit, readImage("data/Number" & $digit & ".png"))
  
  result = Visualizer(
    bxy: bxy,
    window: window,
    windowSize: vmath.vec2(windowWidth.float, windowHeight.float),
    scale: 1f,
    offset: vmath.vec2(100f, 100f),
    selectedPlanet: -1,  # No selection initially
    smoothingEnabled: true  # Smoothing on by default
  )

proc worldToScreen*(viz: Visualizer, worldPos: sim.Vec2): vmath.Vec2 =
  vmath.vec2(
    (worldPos.x.float * viz.scale) + viz.offset.x,
    (worldPos.y.float * viz.scale) + viz.offset.y
  )

proc screenToWorld*(viz: Visualizer, screenPos: vmath.Vec2): sim.Vec2 =
  sim.Vec2(
    x: ((screenPos.x - viz.offset.x) / viz.scale).int32,
    y: ((screenPos.y - viz.offset.y) / viz.scale).int32
  )

proc findPlanetAt*(state: GameState, worldPos: sim.Vec2): PlanetId =
  # Find planet within 50px of the given position
  for i, planet in state.planets:
    let dist = distance(planet.pos, worldPos)
    if dist <= 50:  # 50px selection radius
      return i.int32
  return -1  # No planet found

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

proc getFleetVisualPosition*(state: GameState, fleet: Fleet, stepFraction: float = 0f, smoothing: bool = false): sim.Vec2 =
  # Calculate the visual position of a fleet based on its travel progress
  let startPos = state.planets[fleet.startPlanet].pos
  let targetPos = state.planets[fleet.targetPlanet].pos
  
  if fleet.travelDuration <= 0:
    return startPos  # Shouldn't happen, but safety check
  
  # Calculate progress ratio (0.0 to 1.0)
  var progressRatio = fleet.travelProgress.float / fleet.travelDuration.float
  
  # Add smoothing if enabled - interpolate with the current step fraction
  if smoothing and fleet.travelProgress < fleet.travelDuration:
    progressRatio += stepFraction / fleet.travelDuration.float
  
  # Clamp to valid range
  progressRatio = max(0f, min(1f, progressRatio))
  
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
  
  # Draw selection highlight if this planet is selected
  if viz.selectedPlanet == planet.id:
    let selectionSize = imageSize + 10f  # Slightly larger than planet
    viz.bxy.drawImage(
      "selection",
      rect = rect(
        screenPos.x - selectionSize / 2,
        screenPos.y - selectionSize / 2,
        selectionSize,
        selectionSize
      )
    )
  
  # Draw ship count in the center of the planet (bigger numbers)
  if planet.ships > 0:
    viz.drawNumber(planet.ships, screenPos)

proc drawFleet*(viz: Visualizer, state: GameState, fleet: Fleet, stepFraction: float = 0f) =
  # Calculate current visual position based on travel progress
  let fleetPos = getFleetVisualPosition(state, fleet, stepFraction, viz.smoothingEnabled)
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

proc render*(viz: Visualizer, state: GameState, stepFraction: float = 0f) =
  
  viz.bxy.beginFrame(ivec2(viz.windowSize.x.int32, viz.windowSize.y.int32))
  
  # Draw background
  viz.bxy.drawImage(
    "background",
    rect = rect(0f, 0f, viz.windowSize.x, viz.windowSize.y)
  )
  
  # Draw all planets
  for planet in state.planets:
    viz.drawPlanet(planet)
  
  # Draw all fleets with smoothing
  for fleet in state.fleets:
    viz.drawFleet(state, fleet, stepFraction)
  
  # Draw UI
  viz.drawUI(state)
  
  viz.bxy.endFrame()
  viz.window.swapBuffers()

proc shouldClose*(viz: Visualizer): bool =
  viz.window.closeRequested

proc pollEvents*(viz: Visualizer) =
  pollEvents()
  
proc handleMouseClick*(viz: var Visualizer, state: var GameState, mousePos: vmath.Vec2) =
  let worldPos = viz.screenToWorld(mousePos)
  let clickedPlanet = findPlanetAt(state, worldPos)
  
  if clickedPlanet != -1:
    # Clicked on a planet
    if viz.selectedPlanet == -1:
      # No planet selected, select this one if it belongs to a player
      if state.planets[clickedPlanet].owner != NeutralPlayer:
        viz.selectedPlanet = clickedPlanet
    elif viz.selectedPlanet == clickedPlanet:
      # Clicked on the same selected planet, deselect it
      viz.selectedPlanet = -1
    else:
      # Clicked on a different planet, try to send fleet
      let fromPlanet = viz.selectedPlanet
      let toPlanet = clickedPlanet
      
      # Check if we own the source planet and it has ships
      if state.planets[fromPlanet].owner != NeutralPlayer and state.planets[fromPlanet].ships > 1:
        let shipsToSend = state.planets[fromPlanet].ships div 2  # Send half
        if state.sendFleet(fromPlanet, toPlanet, shipsToSend):
          echo "Sent ", shipsToSend, " ships from planet ", fromPlanet, " to planet ", toPlanet
        else:
          echo "Failed to send fleet"
      
      # Deselect after attempting to send
      viz.selectedPlanet = -1
  else:
    # Clicked on empty space, deselect
    viz.selectedPlanet = -1

proc cleanup*(viz: Visualizer) =
  viz.window.close()
