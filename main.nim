import sim, viz, ai
import std/[times, os, sequtils]

proc main() =
  # Game configuration
  const
    NumPlayers = 3'i32
    NumPlanets = 15'i32
    WindowWidth = 1200
    WindowHeight = 900
    TurnsPerSecond = 2.0
    TurnDuration = 1000 div TurnsPerSecond.int  # milliseconds
  
  # Initialize game state
  var gameState = initGameState(NumPlayers, NumPlanets)
  
  # Initialize visualization
  var visualizer = initVisualizer(WindowWidth, WindowHeight)
  
  # Create AI players
  var ais: seq[AI] = @[]
  ais.add(createAI("aggressive", 0))
  ais.add(createAI("defensive", 1))
  ais.add(createAI("random", 2))
  
  # Game timing
  var lastTurnTime = epochTime() * 1000.0  # Convert to milliseconds
  var gameRunning = true
  var winner = NeutralPlayer
  
  echo "Starting PlanetWars simulation..."
  echo "Players: ", NumPlayers
  echo "Planets: ", NumPlanets
  echo "Map size: ", MapWidth, "x", MapHeight
  echo ""
  
  # Main game loop
  while gameRunning and not visualizer.shouldClose():
    let currentTime = epochTime() * 1000.0
    
    # Handle window events
    visualizer.pollEvents()
    
    # Update game logic at fixed intervals
    if currentTime - lastTurnTime >= TurnDuration.float:
      # Check for winner
      winner = gameState.getGameWinner()
      if winner != NeutralPlayer:
        echo "Game Over! Player ", winner, " wins!"
        gameRunning = false
      
      # Let each AI make decisions
      if gameRunning:
        for ai in ais:
          let actions = ai.makeDecision(gameState)
          gameState.executeAIActions(actions)
        
        # Update game state
        gameState.updateGame()
        
        # Print game stats every 10 turns
        if gameState.turn mod 10 == 0:
          echo "Turn ", gameState.turn, ":"
          for playerId in gameState.players:
            let planets = gameState.getPlanetsOwnedBy(playerId)
            let totalShips = if planets.len > 0: 
                            planets.mapIt(gameState.planets[it].ships).foldl(a + b, 0)
                          else: 0
            echo "  Player ", playerId, ": ", planets.len, " planets, ", totalShips, " total ships"
          echo "  Active fleets: ", gameState.fleets.len
          echo ""
      
      lastTurnTime = currentTime
    
    # Render the game
    visualizer.render(gameState)
    
    # Small sleep to prevent 100% CPU usage
    sleep(10)
  
  # Show final results
  if winner != NeutralPlayer:
    echo "Final Results:"
    echo "Winner: Player ", winner
    echo "Total turns: ", gameState.turn
    echo ""
    echo "Final planet distribution:"
    for playerId in gameState.players:
      let planets = gameState.getPlanetsOwnedBy(playerId)
      echo "  Player ", playerId, ": ", planets.len, " planets"
    
    # Wait a bit before closing
    echo "Press any key or close window to exit..."
    while not visualizer.shouldClose():
      visualizer.pollEvents()
      visualizer.render(gameState)
      sleep(100)
  
  # Cleanup
  visualizer.cleanup()
  echo "Game ended."

when isMainModule:
  main()
