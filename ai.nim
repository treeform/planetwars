import sim
import std/[random]

type
  AIAction* = object
    fromPlanet*: PlanetId
    toPlanet*: PlanetId
    ships*: int32
    
  AI* = ref object of RootObj
    playerId*: PlayerId

method makeDecision*(ai: AI, state: GameState): seq[AIAction] {.base.} =
  # Base method - should be overridden by specific AI implementations
  @[]

type
  PassiveAI* = ref object of AI

proc newPassiveAI*(playerId: PlayerId): PassiveAI =
  PassiveAI(playerId: playerId)

method makeDecision*(ai: PassiveAI, state: GameState): seq[AIAction] =
  @[]

# Simple Random AI
type
  RandomAI* = ref object of AI

proc newRandomAI*(playerId: PlayerId): RandomAI =
  RandomAI(playerId: playerId)

method makeDecision*(ai: RandomAI, state: GameState): seq[AIAction] =
  result = @[]
  
  let myPlanets = state.getPlanetsOwnedBy(ai.playerId)
  if myPlanets.len == 0:
    return
  
  # Try to make one action per turn - check planets randomly
  var planetIndices = myPlanets
  # Shuffle the planet order for random selection
  for i in countdown(planetIndices.high, 1):
    let j = rand(i)
    swap(planetIndices[i], planetIndices[j])
  
  # For each planet I own, try to send ships (but only do one action)
  for planetId in planetIndices:
    let planet = state.planets[planetId]
    
    # Only send ships if we have enough
    if planet.ships > 20:
      # 50% chance to send ships from this planet
      if rand(100) < 50:
        # Find a target (any planet we don't own)
        var targets: seq[PlanetId] = @[]
        for i, targetPlanet in state.planets:
          if targetPlanet.owner != ai.playerId:
            targets.add(i.int32)
        
        if targets.len > 0:
          let targetIndex = rand(targets.len - 1)
          let target = targets[targetIndex]
          let shipsToSend = max(1'i32, planet.ships div 2)  # Send half our ships
          
          result.add(AIAction(
            fromPlanet: planetId,
            toPlanet: target,
            ships: shipsToSend
          ))
          return  # Only one action per turn

# Aggressive AI - attacks nearest enemy planets
type
  AggressiveAI* = ref object of AI

proc newAggressiveAI*(playerId: PlayerId): AggressiveAI =
  AggressiveAI(playerId: playerId)

method makeDecision*(ai: AggressiveAI, state: GameState): seq[AIAction] =
  result = @[]
  
  let myPlanets = state.getPlanetsOwnedBy(ai.playerId)
  if myPlanets.len == 0:
    return
  
  # Find the best attack opportunity among all planets (one action per turn)
  var bestAction: AIAction
  var bestFound = false
  var bestScore = int32.high  # Lower distance = better score
  
  for planetId in myPlanets:
    let planet = state.planets[planetId]
    
    # Only attack if we have enough ships
    if planet.ships > 15:
      # Find nearest enemy or neutral planet
      for i, targetPlanet in state.planets:
        if targetPlanet.owner != ai.playerId:
          let dist = distance(planet.pos, targetPlanet.pos)
          let shipsNeeded = targetPlanet.ships + 5'i32  # Send extra to ensure victory
          
          # Check if we can attack and if it's the best option so far
          if planet.ships > shipsNeeded and dist < bestScore:
            bestScore = dist
            bestAction = AIAction(
              fromPlanet: planetId,
              toPlanet: i.int32,
              ships: shipsNeeded
            )
            bestFound = true
  
  # Execute the best action found
  if bestFound:
    result.add(bestAction)

# Defensive AI - focuses on reinforcing own planets
type
  DefensiveAI* = ref object of AI

proc newDefensiveAI*(playerId: PlayerId): DefensiveAI =
  DefensiveAI(playerId: playerId)

method makeDecision*(ai: DefensiveAI, state: GameState): seq[AIAction] =
  result = @[]
  
  let myPlanets = state.getPlanetsOwnedBy(ai.playerId)
  if myPlanets.len <= 1:
    return
  
  # Find strongest and weakest planets
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
  
  # Send reinforcements from strongest to weakest (one action per turn)
  if strongestPlanet != -1 and weakestPlanet != -1 and strongestPlanet != weakestPlanet:
    let strongPlanet = state.planets[strongestPlanet]
    if strongPlanet.ships > 30:
      let shipsToSend = strongPlanet.ships div 3
      result.add(AIAction(
        fromPlanet: strongestPlanet,
        toPlanet: weakestPlanet,
        ships: shipsToSend
      ))

# Execute AI actions in the game state
proc executeAIActions*(state: var GameState, actions: seq[AIAction]) =
  for action in actions:
    discard state.sendFleet(action.fromPlanet, action.toPlanet, action.ships)

# Factory function to create different AI types
proc createAI*(aiType: string, playerId: PlayerId): AI =
  case aiType:
    of "passive":
      return newPassiveAI(playerId)
    of "random":
      return newRandomAI(playerId)
    of "aggressive":
      return newAggressiveAI(playerId)
    of "defensive":
      return newDefensiveAI(playerId)
    else:
      return newRandomAI(playerId)  # Default to random
