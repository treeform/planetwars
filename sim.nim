import std/[random, sequtils, tables]

type
  PlayerId* = int32
  PlanetId* = int32
  FleetId* = int32
  
  Vec2* = object
    x*, y*: int32
  
  Planet* = object
    id*: PlanetId
    pos*: Vec2
    population*: int32
    growthRate*: int32
    owner*: PlayerId  # -1 for neutral, 0+ for players
    
  Fleet* = object
    id*: FleetId
    owner*: PlayerId
    ships*: int32
    pos*: Vec2
    target*: PlanetId
    targetPos*: Vec2
    speed*: int32
    
  GameState* = object
    planets*: seq[Planet]
    fleets*: seq[Fleet]
    players*: seq[PlayerId]
    turn*: int32
    mapSize*: Vec2
    nextFleetId*: FleetId

const
  NeutralPlayer* = -1'i32
  FleetSpeed* = 50'i32  # units per turn
  MapWidth* = 1000'i32
  MapHeight* = 1000'i32
  ScaleFactor* = 1000'i32  # For fixed-point arithmetic

# Integer square root using Newton's method
proc isqrt*(n: int32): int32 =
  if n < 0: return 0
  if n < 2: return n
  
  var x = n
  var y = (x + 1) div 2
  while y < x:
    x = y
    y = (x + n div x) div 2
  return x

proc distance*(a, b: Vec2): int32 =
  let dx = a.x - b.x
  let dy = a.y - b.y
  isqrt(dx * dx + dy * dy)

proc normalize*(v: Vec2): Vec2 =
  let len = isqrt(v.x * v.x + v.y * v.y)
  if len == 0:
    return Vec2(x: 0, y: 0)
  Vec2(x: (v.x * ScaleFactor) div len, y: (v.y * ScaleFactor) div len)

proc `+`*(a, b: Vec2): Vec2 = Vec2(x: a.x + b.x, y: a.y + b.y)
proc `-`*(a, b: Vec2): Vec2 = Vec2(x: a.x - b.x, y: a.y - b.y)
proc `*`*(v: Vec2, s: int32): Vec2 = Vec2(x: v.x * s, y: v.y * s)
proc `div`*(v: Vec2, s: int32): Vec2 = Vec2(x: v.x div s, y: v.y div s)

proc initGameState*(numPlayers: int32, numPlanets: int32): GameState =
  randomize()
  
  result = GameState(
    planets: @[],
    fleets: @[],
    players: toSeq(0'i32..<numPlayers),
    turn: 0,
    mapSize: Vec2(x: MapWidth, y: MapHeight),
    nextFleetId: 0
  )
  
  # Generate random planets
  for i in 0'i32..<numPlanets:
    let planet = Planet(
      id: i,
      pos: Vec2(x: rand(MapWidth.int).int32, y: rand(MapHeight.int).int32),
      population: rand(100).int32,
      growthRate: rand(10).int32,
      owner: NeutralPlayer
    )
    result.planets.add(planet)
  
  # Assign homeworlds to players
  for playerId in 0'i32..<numPlayers:
    if playerId < result.planets.len.int32:
      result.planets[playerId].owner = playerId
      result.planets[playerId].population = max(50'i32, result.planets[playerId].population)
      result.planets[playerId].growthRate = max(5'i32, result.planets[playerId].growthRate)

proc sendFleet*(state: var GameState, fromPlanet: PlanetId, toPlanet: PlanetId, ships: int32): bool =
  if fromPlanet < 0 or fromPlanet >= state.planets.len.int32:
    return false
  if toPlanet < 0 or toPlanet >= state.planets.len.int32:
    return false
    
  let planet = state.planets[fromPlanet]
  if planet.population < ships:
    return false
    
  # Create fleet
  let fleet = Fleet(
    id: state.nextFleetId,
    owner: planet.owner,
    ships: ships,
    pos: planet.pos,
    target: toPlanet,
    targetPos: state.planets[toPlanet].pos,
    speed: FleetSpeed
  )
  
  state.fleets.add(fleet)
  state.planets[fromPlanet].population -= ships
  state.nextFleetId += 1
  
  return true

proc updateFleets*(state: var GameState) =
  var fleetsToRemove: seq[int] = @[]
  
  for i, fleet in state.fleets:
    let targetPos = state.planets[fleet.target].pos
    let direction = normalize(targetPos - fleet.pos)
    let newPos = fleet.pos + (direction div ScaleFactor) * fleet.speed
    
    # Check if fleet reached target
    if distance(newPos, targetPos) <= fleet.speed:
      # Fleet arrives at planet
      let targetPlanet = addr state.planets[fleet.target]
      
      if targetPlanet.owner == fleet.owner:
        # Reinforcement
        targetPlanet.population += fleet.ships
      elif targetPlanet.owner == NeutralPlayer:
        # Capture neutral planet
        if fleet.ships > targetPlanet.population:
          targetPlanet.population = fleet.ships - targetPlanet.population
          targetPlanet.owner = fleet.owner
        else:
          targetPlanet.population -= fleet.ships
      else:
        # Attack enemy planet
        if fleet.ships > targetPlanet.population:
          targetPlanet.population = fleet.ships - targetPlanet.population
          targetPlanet.owner = fleet.owner
        else:
          targetPlanet.population -= fleet.ships
          if targetPlanet.population < 0:
            targetPlanet.population = 0
      
      fleetsToRemove.add(i)
    else:
      # Update fleet position
      state.fleets[i].pos = newPos

  # Remove arrived fleets (in reverse order to maintain indices)
  for i in countdown(fleetsToRemove.high, 0):
    state.fleets.delete(fleetsToRemove[i])

proc updatePlanets*(state: var GameState) =
  for planet in state.planets.mitems:
    if planet.owner != NeutralPlayer and planet.population > 0:
      planet.population += planet.growthRate

proc updateGame*(state: var GameState) =
  updateFleets(state)
  updatePlanets(state)
  state.turn += 1

proc getPlanetsOwnedBy*(state: GameState, playerId: PlayerId): seq[PlanetId] =
  result = @[]
  for i, planet in state.planets:
    if planet.owner == playerId:
      result.add(i.int32)

proc getGameWinner*(state: GameState): PlayerId =
  var playerPlanets: Table[PlayerId, int32]
  
  for planet in state.planets:
    if planet.owner != NeutralPlayer:
      playerPlanets.mgetOrPut(planet.owner, 0) += 1
  
  # Check if any player owns all planets
  for playerId, count in playerPlanets:
    if count == state.planets.len.int32:
      return playerId
  
  # Check if only one player has planets
  if playerPlanets.len == 1:
    for playerId, _ in playerPlanets:
      return playerId
      
  return NeutralPlayer  # No winner yet
