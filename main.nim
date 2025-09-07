import sim, viz, ai
import std/times
import windy

proc main() =

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
    NumPlayers = ais.len.int32
    NumPlanets = 40'i32
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
  echo "  S to toggle fleet smoothing"
  echo "  Click planet to select, drag to box select multiple"
  echo "  Click target to send fleets from all selected planets"
  echo ""
  
  # Main game loop
  while gameRunning and not visualizer.shouldClose():
    let currentTime = epochTime()
    let deltaTime = currentTime - lastFrameTime
    lastFrameTime = currentTime
    
    # Handle window events and key input
    visualizer.pollEvents()
    
    # Handle mouse input
    let mousePos = vmath.vec2(visualizer.window.mousePos.x.float, visualizer.window.mousePos.y.float)
    
    if visualizer.window.buttonPressed[MouseLeft]:
      visualizer.handleMouseDown(gameState, mousePos)
    
    if visualizer.window.buttonDown[MouseLeft]:
      visualizer.handleMouseDrag(mousePos)
    
    if visualizer.window.buttonReleased[MouseLeft]:
      visualizer.handleMouseUp(gameState, mousePos)
    
    # Check for speed control keys
    if visualizer.window.buttonPressed[KeyLeftBracket]:
      simSpeed = max(0.1f, simSpeed * 0.8f)  # Slow down
      echo "Speed: ", simSpeed, "x"
    if visualizer.window.buttonPressed[KeyRightBracket]:
      simSpeed = min(1000f, simSpeed * 1.2f)  # Speed up
      echo "Speed: ", simSpeed, "x"
    
    # Check for smoothing toggle
    if visualizer.window.buttonPressed[KeyS]:
      visualizer.smoothingEnabled = not visualizer.smoothingEnabled
      echo "Smoothing: ", if visualizer.smoothingEnabled: "ON" else: "OFF"
    
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
    
    # Render the game with smoothing
    visualizer.render(gameState, stepFraction)
  
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
      visualizer.render(gameState, 0f)
  
  # Cleanup
  visualizer.cleanup()
  echo "Game ended."

when isMainModule:
  main()
