## Main.gd
## Main game controller for retro terminal space navigation
extends Control

# References to navigation computer
var nav_computer: Control = preload("res://navigationcomputer.gd").new()

# References to UI elements
@onready var terminal_label: Label = $TerminalDisplay/ScrollContainer/TerminalLabel
@onready var thrust_label: Label = $ControlPanel/ThrustControls/ThrustLabel

# Control state
var current_thrust: float = 0.0
var thrust_increment: float = 0.1

# Rotation rates (radians/second) - controlled by button presses
var pitch_rate: float = 0.0
var yaw_rate: float = 0.0

func _ready() -> void:
	# Add navigation computer as child so it processes
	add_child(nav_computer)
	
	# Connect all button signals
	_connect_buttons()
	
	# Set initial thrust display
	update_thrust_display()
	
	# Create timer for terminal updates (10Hz is enough for display)
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(_update_terminal)
	timer.autostart = true
	add_child(timer)
	
	# Initial terminal update
	_update_terminal()

func _connect_buttons() -> void:
	# Thrust controls - discrete clicks (note the /ThrustButtons/ in path)
	$ControlPanel/ThrustControls/ThrustButtons/ThrustPlusButton.pressed.connect(_on_thrust_increase)
	$ControlPanel/ThrustControls/ThrustButtons/ThrustMinusButton.pressed.connect(_on_thrust_decrease)
	
	# Rotation controls - hold to rotate continuously (note the sub-containers)
	$ControlPanel/RotationControls/PitchControls/PitchUpButton.button_down.connect(func(): pitch_rate = 1.0)
	$ControlPanel/RotationControls/PitchControls/PitchUpButton.button_up.connect(func(): pitch_rate = 0.0)
	
	$ControlPanel/RotationControls/PitchControls/PitchDownButton.button_down.connect(func(): pitch_rate = -1.0)
	$ControlPanel/RotationControls/PitchControls/PitchDownButton.button_up.connect(func(): pitch_rate = 0.0)
	
	$ControlPanel/RotationControls/YawControls/YawLeftButton.button_down.connect(func(): yaw_rate = 1.0)
	$ControlPanel/RotationControls/YawControls/YawLeftButton.button_up.connect(func(): yaw_rate = 0.0)
	
	$ControlPanel/RotationControls/YawControls/YawRightButton.button_down.connect(func(): yaw_rate = -1.0)
	$ControlPanel/RotationControls/YawControls/YawRightButton.button_up.connect(func(): yaw_rate = 0.0)
	
	# Utility buttons
	$ControlPanel/UtilityButtons/ResetButton.pressed.connect(_on_reset_pressed)
	$ControlPanel/UtilityButtons/KillVelocityButton.pressed.connect(_on_kill_velocity)

func _physics_process(delta: float) -> void:
	# Apply thrust every physics frame
	nav_computer.apply_thrust(current_thrust)
	
	# Apply rotation based on button states
	nav_computer.rotate_ship(pitch_rate, yaw_rate, delta)

func _update_terminal() -> void:
	# Update the terminal display with current nav data
	terminal_label.text = nav_computer.get_terminal_readout()

func _on_thrust_increase() -> void:
	current_thrust = min(current_thrust + thrust_increment, 1.0)
	update_thrust_display()

func _on_thrust_decrease() -> void:
	current_thrust = max(current_thrust - thrust_increment, 0.0)
	update_thrust_display()

func update_thrust_display() -> void:
	thrust_label.text = "THRUST: %d%%" % (current_thrust * 100)

func _on_reset_pressed() -> void:
	nav_computer.reset_ship()
	current_thrust = 0.0
	pitch_rate = 0.0
	yaw_rate = 0.0
	update_thrust_display()

func _on_kill_velocity() -> void:
	# Emergency velocity kill
	nav_computer.ship_velocity = Vector3.ZERO

# Optional: Keyboard controls
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		# Thrust
		if event.keycode == KEY_W and event.pressed:
			_on_thrust_increase()
		elif event.keycode == KEY_S and event.pressed:
			_on_thrust_decrease()
		
		# Rotation (hold keys)
		if event.keycode == KEY_UP:
			pitch_rate = 1.0 if event.pressed else 0.0
		elif event.keycode == KEY_DOWN:
			pitch_rate = -1.0 if event.pressed else 0.0
		elif event.keycode == KEY_LEFT:
			yaw_rate = 1.0 if event.pressed else 0.0
		elif event.keycode == KEY_RIGHT:
			yaw_rate = -1.0 if event.pressed else 0.0
		
		# Utility
		if event.keycode == KEY_R and event.pressed:
			_on_reset_pressed()
		elif event.keycode == KEY_X and event.pressed:
			_on_kill_velocity()
