## Main.gd
## Main game controller for retro terminal space navigation UI
##
## ARCHITECTURE OVERVIEW:
## This script serves as the UI controller layer. It:
##   1. Instantiates the NavigationComputer (physics/math engine)
##   2. Captures user input from buttons and keyboard
##   3. Converts UI events into physics commands (thrust %, rotation rates)
##   4. Polls the NavigationComputer for display data
##   5. Updates UI labels with formatted text
##
## DATA FLOW:
##   User Input → Main.gd → NavigationComputer.gd → Physics Update
##   Physics State → NavigationComputer.gd → Main.gd → UI Display
##
## NO MATH happens in this file - it's pure UI orchestration.
extends Control

# ============================================================================
# NAVIGATION COMPUTER INSTANCE
# ============================================================================

## The physics and navigation engine instance
## Created by loading navigationcomputer.gd and instantiating it
## Added as a child node in _ready() so it receives _physics_process() calls
var nav_computer: Control = preload("res://navigationcomputer.gd").new()

# ============================================================================
# UI ELEMENT REFERENCES
# ============================================================================

## Reference to the main terminal text display label
## Path: Main/TerminalDisplay/ScrollContainer/TerminalLabel
## Updated every 0.1 seconds with navigation readout
@onready var terminal_label: Label = $TerminalDisplay/ScrollContainer/TerminalLabel

## Reference to the thrust percentage display label
## Path: Main/ControlPanel/ThrustControls/ThrustLabel
## Updated immediately when thrust buttons are pressed
@onready var thrust_label: Label = $ControlPanel/ThrustControls/ThrustLabel

# ============================================================================
# INPUT STATE TRACKING
# ============================================================================

## Current thrust setting as a percentage (0.0 to 1.0)
## This value is passed to nav_computer.apply_thrust() every physics frame
## Modified by +/- buttons in increments of 0.1 (10%)
var current_thrust: float = 0.0

## How much to change thrust per button click (0.1 = 10%)
var thrust_increment: float = 0.1

## Current pitch rotation rate in radians/second
## Set to +1.0 when UP button held, -1.0 when DOWN button held, 0.0 when released
## This is a RATE, not an angle. It's multiplied by delta in nav_computer
var pitch_rate: float = 0.0

## Current yaw rotation rate in radians/second  
## Set to +1.0 when LEFT button held, -1.0 when RIGHT button held, 0.0 when released
## This is a RATE, not an angle. It's multiplied by delta in nav_computer
var yaw_rate: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

## Called when the node enters the scene tree
## Sets up all connections, UI state, and starts the terminal update timer
func _ready() -> void:
	# Add navigation computer as a child node so it receives physics updates
	# This causes nav_computer._physics_process(delta) to be called automatically
	add_child(nav_computer)
	
	# Wire up all button press signals to handler functions
	# Connects UI buttons to thrust and rotation control methods
	_connect_buttons()
	
	# Initialize the thrust display label to show "THRUST: 0%"
	update_thrust_display()
	
	# Create a timer that fires every 0.1 seconds (10 Hz refresh rate)
	# This controls how often the terminal display is updated
	# Physics runs at 60Hz but we don't need to update UI text that fast
	var timer = Timer.new()
	timer.wait_time = 0.1  # 100ms = 10 updates per second
	timer.timeout.connect(_update_terminal)  # Connect to our update function
	timer.autostart = true  # Start immediately
	add_child(timer)  # Add to scene tree so it runs
	
	# Do an immediate first update so terminal isn't blank
	_update_terminal()

# ============================================================================
# BUTTON SIGNAL CONNECTIONS
# ============================================================================

## Connects all UI button signals to their handler functions
## Called once during _ready()
##
## BUTTON BEHAVIOR TYPES:
##   - Thrust buttons: Use "pressed" signal (discrete clicks)
##   - Rotation buttons: Use "button_down" and "button_up" (hold to rotate)
##   - Utility buttons: Use "pressed" signal (discrete clicks)
func _connect_buttons() -> void:
	# THRUST CONTROLS
	# Path: Main/ControlPanel/ThrustControls/ThrustButtons/[ButtonName]
	# These use .pressed signal because thrust is adjusted in discrete steps
	$ControlPanel/ThrustControls/ThrustButtons/ThrustPlusButton.pressed.connect(_on_thrust_increase)
	$ControlPanel/ThrustControls/ThrustButtons/ThrustMinusButton.pressed.connect(_on_thrust_decrease)
	
	# PITCH ROTATION CONTROLS
	# Path: Main/ControlPanel/RotationControls/PitchControls/[ButtonName]
	# These use .button_down and .button_up for continuous rotation while held
	# UP button: Sets pitch_rate to +1.0 (nose up) while held
	$ControlPanel/RotationControls/PitchControls/PitchUpButton.button_down.connect(func(): pitch_rate = 1.0)
	$ControlPanel/RotationControls/PitchControls/PitchUpButton.button_up.connect(func(): pitch_rate = 0.0)
	
	# DOWN button: Sets pitch_rate to -1.0 (nose down) while held
	$ControlPanel/RotationControls/PitchControls/PitchDownButton.button_down.connect(func(): pitch_rate = -1.0)
	$ControlPanel/RotationControls/PitchControls/PitchDownButton.button_up.connect(func(): pitch_rate = 0.0)
	
	# YAW ROTATION CONTROLS
	# Path: Main/ControlPanel/RotationControls/YawControls/[ButtonName]
	# LEFT button: Sets yaw_rate to +1.0 (turn left) while held
	$ControlPanel/RotationControls/YawControls/YawLeftButton.button_down.connect(func(): yaw_rate = 1.0)
	$ControlPanel/RotationControls/YawControls/YawLeftButton.button_up.connect(func(): yaw_rate = 0.0)
	
	# RIGHT button: Sets yaw_rate to -1.0 (turn right) while held
	$ControlPanel/RotationControls/YawControls/YawRightButton.button_down.connect(func(): yaw_rate = -1.0)
	$ControlPanel/RotationControls/YawControls/YawRightButton.button_up.connect(func(): yaw_rate = 0.0)
	
	# UTILITY BUTTONS
	# Path: Main/ControlPanel/UtilityButtons/[ButtonName]
	$ControlPanel/UtilityButtons/ResetButton.pressed.connect(_on_reset_pressed)
	$ControlPanel/UtilityButtons/KillVelocityButton.pressed.connect(_on_kill_velocity)

# ============================================================================
# PHYSICS FRAME UPDATE
# ============================================================================

## Called every physics frame (typically 60 times per second)
## This is where we send our current control state to the navigation computer
##
## CRITICAL: This function does NOT do any math. It simply passes our
## current thrust and rotation rate values to the nav_computer, which
## handles all the physics calculations.
##
## @param delta: Time elapsed since last physics frame (typically ~0.0167s)
func _physics_process(delta: float) -> void:
	# Apply thrust based on current throttle setting
	# current_thrust is 0.0 to 1.0, representing 0% to 100%
	# nav_computer will convert this to actual acceleration
	nav_computer.apply_thrust(current_thrust)
	
	# Apply rotation based on button hold states
	# pitch_rate and yaw_rate are in radians/second
	# nav_computer will multiply by delta and update angles
	nav_computer.rotate_ship(pitch_rate, yaw_rate, delta)

# ============================================================================
# UI UPDATE (TERMINAL DISPLAY)
# ============================================================================

## Updates the terminal display with current navigation data
## Called by the timer every 0.1 seconds (10 Hz)
##
## DATA FLOW:
##   1. nav_computer.get_terminal_readout() returns a formatted String
##   2. That String contains all navigation data in terminal format
##   3. We assign it directly to terminal_label.text for display
##
## NO CONVERSION happens here - the nav_computer handles all formatting
func _update_terminal() -> void:
	# Get the fully formatted terminal readout string from nav_computer
	# This string already has all angles converted to 0-360° format
	# and all values formatted with proper spacing and units
	terminal_label.text = nav_computer.get_terminal_readout()

# ============================================================================
# THRUST CONTROL HANDLERS
# ============================================================================

## Increases thrust by one increment (10%)
## Called when the + button is pressed or W key is pressed
## Clamped to maximum of 1.0 (100%)
func _on_thrust_increase() -> void:
	current_thrust = min(current_thrust + thrust_increment, 1.0)
	update_thrust_display()  # Update the UI label immediately

## Decreases thrust by one increment (10%)
## Called when the - button is pressed or S key is pressed
## Clamped to minimum of 0.0 (0%)
func _on_thrust_decrease() -> void:
	current_thrust = max(current_thrust - thrust_increment, 0.0)
	update_thrust_display()  # Update the UI label immediately

## Updates the thrust percentage display label
## Converts current_thrust (0.0-1.0) to percentage (0-100) for display
## This is a LOCAL DISPLAY CONVERSION only - does not affect physics
func update_thrust_display() -> void:
	# Convert 0.0-1.0 float to 0-100 integer percentage for display
	# Example: 0.5 * 100 = 50, displayed as "THRUST: 50%"
	thrust_label.text = "THRUST: %d%%" % (current_thrust * 100)

# ============================================================================
# UTILITY BUTTON HANDLERS
# ============================================================================

## Resets the ship to initial state
## Called when RESET button is pressed or R key is pressed
##
## Resets both nav_computer state AND local UI state
func _on_reset_pressed() -> void:
	# Reset all physics state in nav_computer
	# This sets position, velocity, acceleration, and angles to zero
	nav_computer.reset_ship()
	
	# Reset local UI control state
	current_thrust = 0.0
	pitch_rate = 0.0
	yaw_rate = 0.0
	
	# Update the thrust display to show 0%
	update_thrust_display()

## Emergency velocity kill - sets velocity to zero instantly
## Called when KILL VEL button is pressed or X key is pressed
##
## This is a direct write to nav_computer.ship_velocity
## Does NOT reset position or orientation - only stops motion
func _on_kill_velocity() -> void:
	# Emergency stop - zero out velocity vector
	nav_computer.ship_velocity = Vector3.ZERO

# ============================================================================
# KEYBOARD INPUT (OPTIONAL CONTROLS)
# ============================================================================

## Handles keyboard input as alternative to button clicks
## Provides the same functionality as the UI buttons
##
## KEY MAPPINGS:
##   W/S: Increase/Decrease thrust (discrete)
##   UP/DOWN: Pitch up/down (hold for continuous rotation)
##   LEFT/RIGHT: Yaw left/right (hold for continuous rotation)
##   R: Reset ship
##   X: Kill velocity
##
## @param event: Input event (key press/release)
func _input(event: InputEvent) -> void:
	# Only process keyboard events
	if event is InputEventKey:
		# THRUST CONTROLS (discrete - only on key press)
		if event.keycode == KEY_W and event.pressed:
			_on_thrust_increase()
		elif event.keycode == KEY_S and event.pressed:
			_on_thrust_decrease()
		
		# PITCH ROTATION (continuous - while key held)
		# UP key: pitch_rate = +1.0 when pressed, 0.0 when released
		if event.keycode == KEY_UP:
			pitch_rate = 1.0 if event.pressed else 0.0
		elif event.keycode == KEY_DOWN:
			pitch_rate = -1.0 if event.pressed else 0.0
		
		# YAW ROTATION (continuous - while key held)
		# LEFT key: yaw_rate = +1.0 when pressed, 0.0 when released
		elif event.keycode == KEY_LEFT:
			yaw_rate = 1.0 if event.pressed else 0.0
		elif event.keycode == KEY_RIGHT:
			yaw_rate = -1.0 if event.pressed else 0.0
		
		# UTILITY CONTROLS (discrete - only on key press)
		if event.keycode == KEY_R and event.pressed:
			_on_reset_pressed()
		elif event.keycode == KEY_X and event.pressed:
			_on_kill_velocity()
