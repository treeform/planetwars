import sim, viz, ai
import std/times
import windy

proc main() =

  # Create AI players
  var ais: seq[AI] = @[]
  ais.add(createAI("aggressive", 0))
  ais.add(createAI("passive", 1))
  ais.add(createAI("random", 2))
  ais.add(createAI("aggressive", 3))
  ais.add(createAI("aggressive", 4))
  
  # Game configuration
  let
    NumPlayers = ais.len.int32
    NumPlanets = 25'i32
    WindowWidth = 1200
    WindowHeight = 1200
  
  # Initialize game state
  var gameState = initGameState(NumPlayers, NumPlanets)
  
  # Initialize visualization
  var visualizer = initVisualizer(WindowWidth, WindowHeight)
  
  # Game timing and speed control
  var lastFrameTime = epochTime()
  var gameRunning = true
  var winner = NeutralPlayer
  var simSpeed = 1f  # Simulation speed multiplier
  var stepFraction = 0f  # Accumulated fractional steps
  
  
  echo "Starting PlanetWars simulation..."
  echo "Players: ", NumPlayers
  echo "Planets: ", NumPlanets
  echo "Map size: ", MapWidth, "x", MapHeight
  echo "Controls:"
  echo "  [ to slow down, ] to speed up"
  echo "  Click planet to select, click another to send fleet"
  echo ""
  
  # Main game loop
  while gameRunning and not visualizer.shouldClose():
    let currentTime = epochTime()
    let deltaTime = currentTime - lastFrameTime
    lastFrameTime = currentTime
    
    # Handle window events and key input
    visualizer.pollEvents()
    
    # Handle mouse clicks
    if visualizer.window.buttonPressed[MouseLeft]:
      let mousePos = vmath.vec2(visualizer.window.mousePos.x.float, visualizer.window.mousePos.y.float)
      visualizer.handleMouseClick(gameState, mousePos)
    
    # Check for speed control keys
    if visualizer.window.buttonPressed[KeyLeftBracket]:
      simSpeed = max(0.1f, simSpeed * 0.8f)  # Slow down
      echo "Speed: ", simSpeed, "x"
    if visualizer.window.buttonPressed[KeyRightBracket]:
      simSpeed = min(1000f, simSpeed * 1.2f)  # Speed up
      echo "Speed: ", simSpeed, "x"
    
    # Accumulate simulation steps
    stepFraction += simSpeed * deltaTime.float32
    
    # Process complete simulation steps
    while stepFraction >= 1f:
      stepFraction -= 1f
      
      # Check for winner
      winner = gameState.getGameWinner()
      if winner != NeutralPlayer:
        echo "Game Over! Player ", winner, " wins!"
        gameRunning = false
        break
      
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
            var totalShips = 0'i32
            for planetId in planets:
              totalShips += gameState.planets[planetId].ships
            echo "  Player ", playerId, ": ", planets.len, " planets, ", totalShips, " total ships"
          echo "  Active fleets: ", gameState.fleets.len
          echo ""
    
    # Render the game
    visualizer.render(gameState)
  
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
    
    # Wait for user to close window
    echo "Close window to exit..."
    while not visualizer.shouldClose():
      visualizer.pollEvents()
      visualizer.render(gameState)
  
  # Cleanup
  visualizer.cleanup()
  echo "Game ended."

when isMainModule:
  main()
