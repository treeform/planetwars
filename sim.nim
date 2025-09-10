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
    ships*: int32
    growthRate*: int32
    owner*: PlayerId  # -1 for neutral, 0+ for players

  Fleet* = object
    id*: FleetId
    owner*: PlayerId
    ships*: int32
    startPlanet*: PlanetId
    targetPlanet*: PlanetId
    travelDuration*: int32  # Total turns needed to reach target
    travelProgress*: int32  # Current progress (0 to travelDuration)

  GameState* = object
    seed*: int
    planets*: seq[Planet]
    fleets*: seq[Fleet]
    players*: seq[PlayerId]
    turn*: int32
    mapSize*: Vec2
    nextFleetId*: FleetId

    # Stats
    moves*: int

const
  NeutralPlayer* = -1'i32
  FleetSpeed* = 20'i32  # units per turn (faster movement)
  MapWidth* = 1000'i32
  MapHeight* = 1000'i32
  ScaleFactor* = 1000'i32  # For fixed-point arithmetic
  MinPlanetDistance* = 100'i32  # Minimum distance between planets

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

proc reset*(state: var GameState) =

  # Generate random planets with minimum distance constraint
  for i in 0 ..< state.planets.len:
    var planetPos: Vec2
    var attempts = 0
    const maxAttempts = 100

    # Try to find a valid position that's not too close to existing planets
    while attempts < maxAttempts:
      planetPos = Vec2(
        x: rand(MapWidth.int).int32,
        y: rand(MapHeight.int).int32
      )

      # Check distance to all existing planets
      var validPosition = true
      for existingPlanet in state.planets:
        if distance(planetPos, existingPlanet.pos) < MinPlanetDistance:
          validPosition = false
          break

      if validPosition:
        break

      attempts += 1

    let planet = Planet(
      id: i.int32,
      pos: planetPos,
      ships: rand(100).int32,
      growthRate: rand(5).int32,
      owner: NeutralPlayer
    )
    state.planets[i] = planet

  # Assign homeworlds to players
  for playerId in 0 ..< state.players.len:
    if playerId < state.planets.len:
      state.planets[playerId].owner = playerId.int32
      state.planets[playerId].ships = 100
      state.planets[playerId].growthRate = 5

proc initGameState*(numPlayers: int32, numPlanets: int32, seed = 42): GameState =
  randomize(seed)

  result = GameState(
    seed: seed,
    planets: newSeq[Planet](numPlanets),
    fleets: newSeqOfCap[Fleet](numPlanets*4),
    players: newSeq[PlayerId](numPlayers),
    turn: 0,
    mapSize: Vec2(x: MapWidth, y: MapHeight),
    nextFleetId: 0
  )

  result.reset()

proc sendFleet*(state: var GameState, fromPlanet: PlanetId, toPlanet: PlanetId, ships: int32): bool =
  if fromPlanet < 0 or fromPlanet >= state.planets.len.int32:
    return false
  if toPlanet < 0 or toPlanet >= state.planets.len.int32:
    return false

  let planet = state.planets[fromPlanet]
  if planet.ships < ships:
    return false

  inc state.moves

  # Calculate travel duration using integer distance and speed
  let startPos = state.planets[fromPlanet].pos
  let targetPos = state.planets[toPlanet].pos
  let travelDistance = distance(startPos, targetPos)
  let duration = max(1'i32, travelDistance div FleetSpeed)  # At least 1 turn

  # Create fleet
  let fleet = Fleet(
    id: state.nextFleetId,
    owner: planet.owner,
    ships: ships,
    startPlanet: fromPlanet,
    targetPlanet: toPlanet,
    travelDuration: duration,
    travelProgress: 0  # Just started
  )

  state.fleets.add(fleet)
  state.planets[fromPlanet].ships -= ships
  state.nextFleetId += 1

  return true

proc updateFleets*(state: var GameState) =
  var fleetsToRemove: seq[int] = @[]

  for i, fleet in state.fleets:
    # Increment travel progress
    state.fleets[i].travelProgress += 1

    # Check if fleet has reached its destination
    if state.fleets[i].travelProgress >= fleet.travelDuration:
      # Fleet arrives at planet
      let targetPlanet = addr state.planets[fleet.targetPlanet]

      if targetPlanet.owner == fleet.owner:
        # Reinforcement
        targetPlanet.ships += fleet.ships
      elif targetPlanet.owner == NeutralPlayer:
        # Capture neutral planet
        if fleet.ships > targetPlanet.ships:
          targetPlanet.ships = fleet.ships - targetPlanet.ships
          targetPlanet.owner = fleet.owner
        else:
          targetPlanet.ships -= fleet.ships
      else:
        # Attack enemy planet
        if fleet.ships > targetPlanet.ships:
          targetPlanet.ships = fleet.ships - targetPlanet.ships
          targetPlanet.owner = fleet.owner
        else:
          targetPlanet.ships -= fleet.ships
          if targetPlanet.ships < 0:
            targetPlanet.ships = 0

      fleetsToRemove.add(i)

  # Remove arrived fleets (in reverse order to maintain indices)
  for i in countdown(fleetsToRemove.high, 0):
    state.fleets.delete(fleetsToRemove[i])

proc updatePlanets*(state: var GameState) =
  for planet in state.planets.mitems:
    if planet.owner != NeutralPlayer and planet.ships > 0:
      planet.ships += planet.growthRate

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
