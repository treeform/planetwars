import sim
import std/[random]

type
  AIAction* = object
    fromPlanet*: PlanetId
    toPlanet*: PlanetId
    ships*: int32
    
  # Configurable AI with strategy parameters
  ConfigurableAI* = ref object
    playerId*: PlayerId
    attackClosest*: float32      # How often to attack closest enemy planet
    equalize*: float32           # How often to send from strongest to weakest own planet  
    opportunity*: float32        # How often to attack very weak enemy planets
    defend*: float32             # How often to reinforce planets near strong enemies
    neutral*: float32            # How often to prioritize capturing neutral planets
    strongestFirst*: float32     # How often strongest planet attacks closest enemy
    attackLeader*: float32       # How often to attack planets of the strongest player

proc newAI*(playerId: PlayerId, attackClosest, equalize, opportunity, defend, neutral, strongestFirst, attackLeader: float32): ConfigurableAI =
  ConfigurableAI(
    playerId: playerId,
    attackClosest: attackClosest,
    equalize: equalize,
    opportunity: opportunity,
    defend: defend,
    neutral: neutral,
    strongestFirst: strongestFirst,
    attackLeader: attackLeader
  )

proc strategyAttackClosest(ai: ConfigurableAI, state: GameState, myPlanets: seq[PlanetId]): AIAction =
  var bestAction: AIAction
  var bestFound = false
  var bestScore = int32.high
  
  for planetId in myPlanets:
    let planet = state.planets[planetId]
    if planet.ships > 10:
      for i, targetPlanet in state.planets:
        if targetPlanet.owner != ai.playerId:
          let dist = distance(planet.pos, targetPlanet.pos)
          if dist < bestScore:
            bestScore = dist
            bestAction = AIAction(
              fromPlanet: planetId,
              toPlanet: i.int32,
              ships: planet.ships div 2
            )
            bestFound = true
  
  if bestFound:
    return bestAction
  else:
    return AIAction(fromPlanet: -1, toPlanet: -1, ships: 0)

proc strategyEqualize(ai: ConfigurableAI, state: GameState, myPlanets: seq[PlanetId]): AIAction =
  if myPlanets.len <= 1:
    return AIAction(fromPlanet: -1, toPlanet: -1, ships: 0)
    
  var strongestPlanet = -1'i32
  var weakestPlanet = -1'i32
  var maxShips = 0'i32
  var minShips = int32.high
  
  for planetId in myPlanets:
    let planet = state.planets[planetId]
    if planet.ships > maxShips:
      maxShips = planet.ships
      strongestPlanet = planetId
    if planet.ships < minShips:
      minShips = planet.ships
      weakestPlanet = planetId
  
  if strongestPlanet != -1 and weakestPlanet != -1 and strongestPlanet != weakestPlanet:
    let strongPlanet = state.planets[strongestPlanet]
    if strongPlanet.ships > 20:
      return AIAction(
        fromPlanet: strongestPlanet,
        toPlanet: weakestPlanet,
        ships: strongPlanet.ships div 2
      )
  
  return AIAction(fromPlanet: -1, toPlanet: -1, ships: 0)

proc strategyOpportunity(ai: ConfigurableAI, state: GameState, myPlanets: seq[PlanetId]): AIAction =
  var bestAction: AIAction
  var bestFound = false
  var bestRatio = 0f  # Higher ratio = better opportunity
  
  for planetId in myPlanets:
    let planet = state.planets[planetId]
    if planet.ships > 10:
      for i, targetPlanet in state.planets:
        if targetPlanet.owner != ai.playerId and targetPlanet.ships > 0:
          let ratio = planet.ships.float / targetPlanet.ships.float
          if ratio > 3f and ratio > bestRatio:  # At least 3:1 advantage
            bestRatio = ratio
            bestAction = AIAction(
              fromPlanet: planetId,
              toPlanet: i.int32,
              ships: planet.ships div 2
            )
            bestFound = true
  
  if bestFound:
    return bestAction
  else:
    return AIAction(fromPlanet: -1, toPlanet: -1, ships: 0)

proc strategyDefend(ai: ConfigurableAI, state: GameState, myPlanets: seq[PlanetId]): AIAction =
  var bestAction: AIAction
  var bestFound = false
  var bestThreat = 0f
  
  for planetId in myPlanets:
    let planet = state.planets[planetId]
    if planet.ships > 10:
      # Find nearby enemy planets that are stronger
      for i, enemyPlanet in state.planets:
        if enemyPlanet.owner != ai.playerId and enemyPlanet.owner != NeutralPlayer:
          let dist = distance(planet.pos, enemyPlanet.pos)
          if dist < 200:  # Close enough to be a threat
            let threat = enemyPlanet.ships.float / max(1f, dist.float)
            if threat > bestThreat:
              bestThreat = threat
              bestAction = AIAction(
                fromPlanet: planetId,
                toPlanet: i.int32,
                ships: planet.ships div 2
              )
              bestFound = true
  
  if bestFound:
    return bestAction
  else:
    return AIAction(fromPlanet: -1, toPlanet: -1, ships: 0)

proc strategyNeutral(ai: ConfigurableAI, state: GameState, myPlanets: seq[PlanetId]): AIAction =
  var bestAction: AIAction
  var bestFound = false
  var bestScore = int32.high  # Lower distance = better
  
  for planetId in myPlanets:
    let planet = state.planets[planetId]
    if planet.ships > 10:
      # Find nearest neutral planet
      for i, targetPlanet in state.planets:
        if targetPlanet.owner == NeutralPlayer:
          let dist = distance(planet.pos, targetPlanet.pos)
          if dist < bestScore:
            bestScore = dist
            bestAction = AIAction(
              fromPlanet: planetId,
              toPlanet: i.int32,
              ships: planet.ships div 2
            )
            bestFound = true
  
  if bestFound:
    return bestAction
  else:
    return AIAction(fromPlanet: -1, toPlanet: -1, ships: 0)

proc strategyStrongestFirst(ai: ConfigurableAI, state: GameState, myPlanets: seq[PlanetId]): AIAction =
  # Find the planet with most ships
  var strongestPlanet = -1'i32
  var maxShips = 0'i32
  
  for planetId in myPlanets:
    let planet = state.planets[planetId]
    if planet.ships > maxShips:
      maxShips = planet.ships
      strongestPlanet = planetId
  
  if strongestPlanet == -1 or state.planets[strongestPlanet].ships <= 10:
    return AIAction(fromPlanet: -1, toPlanet: -1, ships: 0)
  
  # From strongest planet, find closest enemy
  let strongPlanet = state.planets[strongestPlanet]
  var bestTarget = -1'i32
  var bestDistance = int32.high
  
  for i, targetPlanet in state.planets:
    if targetPlanet.owner != ai.playerId:
      let dist = distance(strongPlanet.pos, targetPlanet.pos)
      if dist < bestDistance:
        bestDistance = dist
        bestTarget = i.int32
  
  if bestTarget != -1:
    return AIAction(
      fromPlanet: strongestPlanet,
      toPlanet: bestTarget,
      ships: strongPlanet.ships div 2
    )
  else:
    return AIAction(fromPlanet: -1, toPlanet: -1, ships: 0)

proc strategyAttackLeader(ai: ConfigurableAI, state: GameState, myPlanets: seq[PlanetId]): AIAction =
  # Find the player with the most planets (strongest player)
  var playerPlanetCounts: seq[int32] = @[]
  for i in 0..<state.players.len:
    playerPlanetCounts.add(0)
  
  for planet in state.planets:
    if planet.owner != NeutralPlayer and planet.owner >= 0 and planet.owner < playerPlanetCounts.len.int32:
      playerPlanetCounts[planet.owner] += 1
  
  # Find strongest player (excluding self)
  var strongestPlayer = -1'i32
  var maxPlanets = 0'i32
  for playerId in 0..<playerPlanetCounts.len:
    if playerId.int32 != ai.playerId and playerPlanetCounts[playerId] > maxPlanets:
      maxPlanets = playerPlanetCounts[playerId]
      strongestPlayer = playerId.int32
  
  if strongestPlayer == -1:
    return AIAction(fromPlanet: -1, toPlanet: -1, ships: 0)
  
  # Attack closest planet belonging to the strongest player
  var bestAction: AIAction
  var bestFound = false
  var bestScore = int32.high
  
  for planetId in myPlanets:
    let planet = state.planets[planetId]
    if planet.ships > 10:
      for i, targetPlanet in state.planets:
        if targetPlanet.owner == strongestPlayer:
          let dist = distance(planet.pos, targetPlanet.pos)
          if dist < bestScore:
            bestScore = dist
            bestAction = AIAction(
              fromPlanet: planetId,
              toPlanet: i.int32,
              ships: planet.ships div 2
            )
            bestFound = true
  
  if bestFound:
    return bestAction
  else:
    return AIAction(fromPlanet: -1, toPlanet: -1, ships: 0)

proc makeDecision*(ai: ConfigurableAI, state: GameState): seq[AIAction] =
  result = @[]
  
  let myPlanets = state.getPlanetsOwnedBy(ai.playerId)
  if myPlanets.len == 0:
    return
  
  # Calculate total strategy weight
  let totalWeight = ai.attackClosest + ai.equalize + ai.opportunity + ai.defend + ai.neutral + ai.strongestFirst + ai.attackLeader
  if totalWeight <= 0:
    return  # Completely passive AI
  
  # Random choice based on strategy weights
  let choice = rand(totalWeight)
  var cumulative = 0f
  
  # Try each strategy based on weights
  cumulative += ai.neutral
  if choice <= cumulative:
    let action = ai.strategyNeutral(state, myPlanets)
    if action.fromPlanet != -1:
      result.add(action)
      return

  cumulative += ai.attackClosest
  if choice <= cumulative:
    let action = ai.strategyAttackClosest(state, myPlanets)
    if action.fromPlanet != -1:
      result.add(action)
      return
  
  cumulative += ai.equalize
  if choice <= cumulative:
    let action = ai.strategyEqualize(state, myPlanets)
    if action.fromPlanet != -1:
      result.add(action)
      return
  
  cumulative += ai.opportunity
  if choice <= cumulative:
    let action = ai.strategyOpportunity(state, myPlanets)
    if action.fromPlanet != -1:
      result.add(action)
      return
  
  cumulative += ai.defend
  if choice <= cumulative:
    let action = ai.strategyDefend(state, myPlanets)
    if action.fromPlanet != -1:
      result.add(action)
      return
  
  cumulative += ai.strongestFirst
  if choice <= cumulative:
    let action = ai.strategyStrongestFirst(state, myPlanets)
    if action.fromPlanet != -1:
      result.add(action)
      return
  
  cumulative += ai.attackLeader
  if choice <= cumulative:
    let action = ai.strategyAttackLeader(state, myPlanets)
    if action.fromPlanet != -1:
      result.add(action)
      return

# Execute AI actions in the game state
proc executeAIActions*(state: var GameState, actions: seq[AIAction]) =
  for action in actions:
    discard state.sendFleet(action.fromPlanet, action.toPlanet, action.ships)

