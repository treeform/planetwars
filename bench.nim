import benchy, sim, ai

var
  numRests = 0
  numMoves = 0

timeIt "full sim":
    # Create AI players with strategy parameters: (attackClosest, equalize, opportunity, defend, neutral, strongestFirst, attackLeader)
  var ais: seq[ConfigurableAI] = @[]
  ais.add(newAI(0, 0f, 0f, 0f, 0f, 0f, 0f, 0f))                 # Passive - does nothing

  ais.add(newAI(1, 0.3f, 0.1f, 0.2f, 0.1f, 0.1f, 0.1f, 0.1f))  # Aggressive - mostly attacks closest
  ais.add(newAI(2, 0.15f, 0.15f, 0.15f, 0.15f, 0.15f, 0.1f, 0.15f))  # Balanced - equal strategies
  ais.add(newAI(3, 0.1f, 0.35f, 0.1f, 0.25f, 0.05f, 0.05f, 0.1f)) # Defensive - equalizes and defends
  ais.add(newAI(4, 0.1f, 0.1f, 0.15f, 0.1f, 0.4f, 0.1f, 0.05f))  # Expansionist - prioritizes neutrals
  ais.add(newAI(5, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.4f, 0.1f))   # Power Player - strongest attacks
  ais.add(newAI(6, 0.2f, 0.05f, 0.2f, 0.05f, 0.1f, 0.1f, 0.3f))  # Leader Hunter - attacks strongest player

  # Game configuration
  let
    numPlayers = ais.len.int32
    numPlanets = 40'i32

  # Initialize game state
  var gameState = initGameState(
    numPlayers,
  numPlanets,
    seed=42
  )
  for i in 0 ..< 1_000_000:
    for ai in ais:
      let actions = ai.makeDecision(gameState)
      gameState.executeAIActions(actions)
    gameState.updateGame()

    let winner = gameState.getGameWinner()
    if winner != NeutralPlayer:
      gameState.reset()
      inc numRests
    numMoves += gameState.moves

echo numMoves
echo numRests
