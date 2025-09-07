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

proc newAI*(playerId: PlayerId, attackClosest, equalize, opportunity, defend: float32): ConfigurableAI =
  ConfigurableAI(
    playerId: playerId,
    attackClosest: attackClosest,
    equalize: equalize,
    opportunity: opportunity,
    defend: defend
  )

proc makeDecision*(ai: ConfigurableAI, state: GameState): seq[AIAction] =
  result = @[]
  
  let myPlanets = state.getPlanetsOwnedBy(ai.playerId)
  if myPlanets.len == 0:
    return
  
  # Calculate total strategy weight
  let totalWeight = ai.attackClosest + ai.equalize + ai.opportunity + ai.defend
  if totalWeight <= 0:
    return  # Completely passive AI
  
  # Random choice based on strategy weights
  let choice = rand(totalWeight)
  var cumulative = 0f
  
  # Strategy 1: Attack closest enemy planet
  cumulative += ai.attackClosest
  if choice <= cumulative:
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
      result.add(bestAction)
      return
  
  # Strategy 2: Equalize ships between own planets
  cumulative += ai.equalize
  if choice <= cumulative and myPlanets.len > 1:
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
        result.add(AIAction(
          fromPlanet: strongestPlanet,
          toPlanet: weakestPlanet,
          ships: strongPlanet.ships div 2
        ))
        return
  
  # Strategy 3: Attack opportunity targets (very weak enemy planets)
  cumulative += ai.opportunity
  if choice <= cumulative:
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
      result.add(bestAction)
      return
  
  # Strategy 4: Defend against nearby strong enemies
  cumulative += ai.defend
  if choice <= cumulative:
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
      result.add(bestAction)
      return

# Execute AI actions in the game state
proc executeAIActions*(state: var GameState, actions: seq[AIAction]) =
  for action in actions:
    discard state.sendFleet(action.fromPlanet, action.toPlanet, action.ships)

