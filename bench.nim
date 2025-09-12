import benchy, sim, ai, std/[times, strformat]

const
  NumPlayers = 6
  NumPlanets = 40
  NumTurns = 1_000_000
  GlobalSeed = 42

var
  numRests = 0
  numMoves = 0
  aiActions: seq[seq[AIAction]]

# Initialize game state
var gameState = initGameState(
  NumPlayers,
  NumPlanets,
  GlobalSeed
)

var ais: seq[ConfigurableAI] = @[]
ais.add(newAI(1, 0.3f, 0.1f, 0.2f, 0.1f, 0.1f, 0.1f, 0.1f))  # Aggressive - mostly attacks closest
ais.add(newAI(2, 0.15f, 0.15f, 0.15f, 0.15f, 0.15f, 0.1f, 0.15f))  # Balanced - equal strategies
ais.add(newAI(3, 0.1f, 0.35f, 0.1f, 0.25f, 0.05f, 0.05f, 0.1f)) # Defensive - equalizes and defends
ais.add(newAI(4, 0.1f, 0.1f, 0.15f, 0.1f, 0.4f, 0.1f, 0.05f))  # Expansionist - prioritizes neutrals
ais.add(newAI(5, 0.1f, 0.1f, 0.1f, 0.1f, 0.1f, 0.4f, 0.1f))   # Power Player - strongest attacks
ais.add(newAI(6, 0.2f, 0.05f, 0.2f, 0.05f, 0.1f, 0.1f, 0.3f))  # Leader Hunter - attacks strongest player

# Run this sim once to get all AI actions.
for i in 0 ..< NumTurns:
  var turnActions: seq[AIAction] = @[]
  for ai in ais:
    let actions = ai.makeDecision(gameState)
    turnActions.add(actions)
    echo "Turn ", i, " ai ", ai.playerId, " actions: ", actions
    gameState.executeAIActions(actions)
  gameState.updateGame()
  aiActions.add(turnActions)

  let winner = gameState.getGameWinner()
  if winner != NeutralPlayer:
    break

echo "aiActions.len ", aiActions.len
echo "Done running sim for ", gameState.turn, " turns"

let startTime = epochTime()
var numTurns = 0
timeIt "full sim":
  gameState.reset()
  for i in 0 ..< aiActions.len:
    for ai in ais:
      let actions = aiActions[gameState.turn]
      numMoves += actions.len
      gameState.executeAIActions(actions)
    gameState.updateGame()
    inc numTurns

let endTime = epochTime()
let sps = numTurns.float32 / (endTime - startTime)
echo &"SPS: {sps:0.2f}"

echo "numTurns ", numTurns
echo "numMoves ", numMoves
echo "numRests ", numRests
