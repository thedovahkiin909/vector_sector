Godot Space Navigation Simulator - Technical Documentation
Architecture Overview
This is a retro terminal-style space navigation simulator built in Godot. The architecture follows a strict separation of concerns:

main.gd: UI controller layer (no physics/math)
navigationcomputer.gd: Physics/math engine (no UI code)
main.tscn: Scene definition and UI layout

Data Flow Diagram
┌─────────────────────────────────────────────────────────────────┐
│                         USER INPUT                               │
│  (Buttons, Keyboard) → Main.gd Input Handlers                   │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                    MAIN.GD (_physics_process)                    │
│  - Reads: current_thrust, pitch_rate, yaw_rate                  │
│  - Calls: nav_computer.apply_thrust()                           │
│  - Calls: nav_computer.rotate_ship()                            │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────────────────────────────┐
│            NAVIGATIONCOMPUTER.GD (_physics_process)              │
│  - Updates: ship_acceleration from thrust                       │
│  - Updates: ship_velocity from acceleration                     │
│  - Updates: ship_position from velocity                         │
│  - Updates: pitch_angle, yaw_angle from rotation rates          │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                    MAIN.GD (Timer: 10 Hz)                        │
│  - Calls: nav_computer.get_terminal_readout()                   │
│  - Updates: terminal_label.text                                 │
└─────────────────────────────────────────────────────────────────┘
File: main.gd (198 lines)
Critical Line References
LineContentDescription1## Main.gdFile header10##   5. Updates UI labels with formatted textArchitecture documentation25var nav_computer: Control = preload("res://navigationcomputer.gd").new()Navigation computer instantiation35@onready var terminal_label: Label = $TerminalDisplay/ScrollContainer/TerminalLabelTerminal display reference38@onready var thrust_label: Label = $ControlPanel/ThrustControls/ThrustLabelThrust label reference47var current_thrust: float = 0.0Current thrust percentage storage50var thrust_increment: float = 0.1Thrust increment per button click54var pitch_rate: float = 0.0Current pitch rotation rate59var yaw_rate: float = 0.0Current yaw rotation rate68func _ready() -> void:Initialization function71add_child(nav_computer)Adds nav computer to scene tree75_connect_buttons()Wire up button signals78update_thrust_display()Initialize thrust display82var timer = Timer.new()Create display update timer83timer.wait_time = 0.1Set to 10 Hz update rate84timer.timeout.connect(_update_terminal)Connect timer to update function90_update_terminal()Initial terminal update105func _connect_buttons() -> void:Button signal connection setup109$ControlPanel/ThrustControls/ThrustButtons/ThrustPlusButton.pressed.connect(_on_thrust_increase)Connect thrust + button110$ControlPanel/ThrustControls/ThrustButtons/ThrustMinusButton.pressed.connect(_on_thrust_decrease)Connect thrust - button116$ControlPanel/RotationControls/PitchControls/PitchUpButton.button_down.connect(func(): pitch_rate = 1.0)Pitch up button down117$ControlPanel/RotationControls/PitchControls/PitchUpButton.button_up.connect(func(): pitch_rate = 0.0)Pitch up button release120$ControlPanel/RotationControls/PitchControls/PitchDownButton.button_down.connect(func(): pitch_rate = -1.0)Pitch down button down121$ControlPanel/RotationControls/PitchControls/PitchDownButton.button_up.connect(func(): pitch_rate = 0.0)Pitch down button release126$ControlPanel/RotationControls/YawControls/YawLeftButton.button_down.connect(func(): yaw_rate = 1.0)Yaw left button down127$ControlPanel/RotationControls/YawControls/YawLeftButton.button_up.connect(func(): yaw_rate = 0.0)Yaw left button release130$ControlPanel/RotationControls/YawControls/YawRightButton.button_down.connect(func(): yaw_rate = -1.0)Yaw right button down131$ControlPanel/RotationControls/YawControls/YawRightButton.button_up.connect(func(): yaw_rate = 0.0)Yaw right button release135$ControlPanel/UtilityButtons/ResetButton.pressed.connect(_on_reset_pressed)Connect reset button136$ControlPanel/UtilityButtons/KillVelocityButton.pressed.connect(_on_kill_velocity)Connect kill velocity button152func _physics_process(delta: float) -> void:Physics frame update (60 Hz)156nav_computer.apply_thrust(current_thrust)Send thrust to nav computer161nav_computer.rotate_ship(pitch_rate, yaw_rate, delta)Send rotation to nav computer176func _update_terminal() -> void:Terminal display update (10 Hz)181terminal_label.text = nav_computer.get_terminal_readout()Get formatted data from nav computer189func _on_thrust_increase() -> void:Thrust increase handler190current_thrust = min(current_thrust + thrust_increment, 1.0)Increase thrust, clamped to 1.0191update_thrust_display()Update UI immediately197func _on_thrust_decrease() -> void:Thrust decrease handler198current_thrust = max(current_thrust - thrust_increment, 0.0)Decrease thrust, clamped to 0.0199update_thrust_display()Update UI immediately205func update_thrust_display() -> void:Thrust label update208thrust_label.text = "THRUST: %d%%" % (current_thrust * 100)Convert 0.0-1.0 to percentage219func _on_reset_pressed() -> void:Reset button handler222nav_computer.reset_ship()Reset physics state225current_thrust = 0.0Reset local thrust226pitch_rate = 0.0Reset local pitch rate227yaw_rate = 0.0Reset local yaw rate230update_thrust_display()Update UI to show 0%238func _on_kill_velocity() -> void:Kill velocity handler240nav_computer.ship_velocity = Vector3.ZEROEmergency stop258func _input(event: InputEvent) -> void:Keyboard input handler260if event is InputEventKey:Filter for keyboard events262if event.keycode == KEY_W and event.pressed:W key: increase thrust264elif event.keycode == KEY_S and event.pressed:S key: decrease thrust268if event.keycode == KEY_UP:UP arrow: pitch up269pitch_rate = 1.0 if event.pressed else 0.0Set pitch rate based on key state270elif event.keycode == KEY_DOWN:DOWN arrow: pitch down271pitch_rate = -1.0 if event.pressed else 0.0Set pitch rate based on key state274elif event.keycode == KEY_LEFT:LEFT arrow: yaw left275yaw_rate = 1.0 if event.pressed else 0.0Set yaw rate based on key state276elif event.keycode == KEY_RIGHT:RIGHT arrow: yaw right277yaw_rate = -1.0 if event.pressed else 0.0Set yaw rate based on key state280if event.keycode == KEY_R and event.pressed:R key: reset282elif event.keycode == KEY_X and event.pressed:X key: kill velocity
Function Call Flow (main.gd)
_ready() [line 68]
  ├─→ add_child(nav_computer) [line 71]
  ├─→ _connect_buttons() [line 75]
  │     ├─→ Connect thrust buttons [lines 109-110]
  │     ├─→ Connect pitch buttons [lines 116-121]
  │     ├─→ Connect yaw buttons [lines 126-131]
  │     └─→ Connect utility buttons [lines 135-136]
  ├─→ update_thrust_display() [line 78]
  ├─→ Timer setup [lines 82-86]
  └─→ _update_terminal() [line 90]

_physics_process(delta) [line 152] ◄── Called 60 times/second by Godot
  ├─→ nav_computer.apply_thrust(current_thrust) [line 156]
  └─→ nav_computer.rotate_ship(pitch_rate, yaw_rate, delta) [line 161]

_update_terminal() [line 176] ◄── Called 10 times/second by Timer
  └─→ nav_computer.get_terminal_readout() [line 181]

Button/Key Events ◄── Called when user interacts
  ├─→ _on_thrust_increase() [line 189]
  │     └─→ update_thrust_display() [line 191]
  ├─→ _on_thrust_decrease() [line 197]
  │     └─→ update_thrust_display() [line 199]
  ├─→ _on_reset_pressed() [line 219]
  │     ├─→ nav_computer.reset_ship() [line 222]
  │     └─→ update_thrust_display() [line 230]
  ├─→ _on_kill_velocity() [line 238]
  └─→ _input(event) [line 258]
File: navigationcomputer.gd (572 lines)
Critical Line References
LineContentDescription1## NavigationComputer.gdFile header10##   5. Display formatting (converting radians → degrees → 0-360° strings)Architecture documentation17##   +X = right, +Y = up, +Z = backward (so -Z = forward)Coordinate system definition35var ship_position: Vector3 = Vector3.ZEROShip position in meters40var ship_velocity: Vector3 = Vector3.ZEROShip velocity in m/s45var ship_acceleration: Vector3 = Vector3.ZEROShip acceleration in m/s²50var current_thrust_acceleration: float = 0.0Display thrust value62var pitch_angle: float = 0.0Pitch angle in radians73var yaw_angle: float = 0.0Yaw angle in radians81const REFERENCE_ORIGIN: Vector3 = Vector3.ZEROReference point for spherical coords89const MAX_THRUST_ACCELERATION: float = 10.0Maximum thrust in m/s²93const MAX_ROTATION_RATE: float = 0.5Maximum rotation rate in rad/s109func _physics_process(delta: float) -> void:Physics update (60 Hz)113ship_velocity += ship_acceleration * deltaApply acceleration to velocity117ship_position += ship_velocity * deltaApply velocity to position121ship_acceleration = Vector3.ZEROReset acceleration126current_thrust_acceleration = max(0.0, current_thrust_acceleration - MAX_THRUST_ACCELERATION * delta * 2.0)Decay display thrust143func apply_thrust(thrust_percentage: float) -> void:Apply main thrust145thrust_percentage = clamp(thrust_percentage, 0.0, 1.0)Clamp thrust to valid range149var thrust_direction = get_forward_vector()Get forward direction from angles153var thrust_magnitude = MAX_THRUST_ACCELERATION * thrust_percentageCalculate thrust magnitude156current_thrust_acceleration = thrust_magnitudeUpdate display value160ship_acceleration += thrust_direction * thrust_magnitudeApply acceleration170func apply_directional_thrust(direction: Vector3, thrust_percentage: float) -> void:Apply thrust in arbitrary direction197func rotate_ship(pitch: float, yaw: float, delta: float) -> void:Update ship orientation199pitch = clamp(pitch, -MAX_ROTATION_RATE, MAX_ROTATION_RATE)Clamp pitch rate200yaw = clamp(yaw, -MAX_ROTATION_RATE, MAX_ROTATION_RATE)Clamp yaw rate204if abs(pitch) > 0.001:Check pitch threshold205pitch_angle += pitch * deltaUpdate pitch angle210if abs(yaw) > 0.001:Check yaw threshold211yaw_angle += yaw * deltaUpdate yaw angle270func get_forward_vector() -> Vector3:Derive forward vector from angles273var forward = Vector3(Begin forward vector calculation274-sin(yaw_angle) * cos(pitch_angle),X component275sin(pitch_angle),Y component276-cos(yaw_angle) * cos(pitch_angle)Z component281return forward.normalized()Return normalized forward303func get_right_vector() -> Vector3:Derive right vector from yaw306return Vector3(Begin right vector calculation307cos(yaw_angle),X component3080.0,Y component (horizontal)309sin(yaw_angle)Z component318func get_up_vector() -> Vector3:Derive up vector from cross product320return get_right_vector().cross(get_forward_vector()).normalized()Cross product for up346func to_360_angle(angle: float) -> float:Convert angle to 0-360° range349return fposmod(angle, 360.0)Modulo operation for wrapping368func get_bearing_angles() -> Dictionary:Get pitch/yaw in degrees371var pitch_deg = rad_to_deg(pitch_angle)Convert pitch to degrees372var yaw_deg = rad_to_deg(yaw_angle)Convert yaw to degrees376"pitch": pitch_deg,Return pitch377"yaw": yaw_deg,Return yaw404func get_spherical_coordinates() -> Dictionary:Convert to spherical coords406var r = ship_position.length()Calculate distance409if r < 0.001:Handle origin case418var azimuth_rad = atan2(ship_position.z, ship_position.x)Calculate azimuth419var azimuth_deg = rad_to_deg(azimuth_rad)Convert to degrees424var elevation_rad = asin(clamp(ship_position.y / r, -1.0, 1.0))Calculate elevation425var elevation_deg = rad_to_deg(elevation_rad)Convert to degrees428"distance": r,Return distance429"azimuth": azimuth_deg,Return azimuth430"elevation": elevation_degReturn elevation453func get_terminal_readout() -> String:Format terminal display455var spherical = get_spherical_coordinates()Get spherical coords456var bearing = get_bearing_angles()Get bearing angles457var forward = get_forward_vector()Get forward vector460var output = ""Initialize output string463output += "╔═══════════════════════════════════╗\n"Header box468output += "POSITION [CARTESIAN] (km):\n"Cartesian position section469output += "  X: %+10.2f\n" % (ship_position.x / 1000.0)X position in km470output += "  Y: %+10.2f\n" % (ship_position.y / 1000.0)Y position in km471output += "  Z: %+10.2f\n\n" % (ship_position.z / 1000.0)Z position in km475output += "POSITION [SPHERICAL]:\n"Spherical position section476output += "  DIST: %10.2f km\n" % (spherical.distance / 1000.0)Distance in km477output += "  AZI:  %10.2f°\n" % to_360_angle(spherical.azimuth)Azimuth 0-360°478output += "  ELEV: %+10.2f°\n\n" % spherical.elevationElevation -90 to +90481output += "VELOCITY (m/s):\n"Velocity section482output += "  MAG:  %10.2f\n" % ship_velocity.length()Velocity magnitude483output += "  X:    %+10.2f\n" % ship_velocity.xX velocity484output += "  Y:    %+10.2f\n" % ship_velocity.yY velocity485output += "  Z:    %+10.2f\n\n" % ship_velocity.zZ velocity488output += "BEARING:\n"Bearing section489output += "  PITCH:  %9.2f°\n" % to_360_angle(bearing.pitch)Pitch 0-360°490output += "  YAW:    %9.2f°\n\n" % to_360_angle(bearing.yaw)Yaw 0-360°493output += "THRUST VECTOR:\n"Thrust section494output += "  FWD: [%.3f, %.3f, %.3f]\n" % [forward.x, forward.y, forward.z]Forward vector495output += "  ACC:  %10.2f m/s²\n" % current_thrust_accelerationAcceleration498output += "\n───────────────────────────────────\n"Footer500return outputReturn formatted string511func get_compact_status() -> String:Compact status string513var dist = ship_position.length() / 1000.0Calculate distance514var vel = ship_velocity.length()Calculate velocity515var bearing = get_bearing_angles()Get bearing518`return "DIST: %.1fkmVEL: %.1fm/s519dist, vel,Distance and velocity520to_360_angle(bearing.pitch),Pitch 0-360°521to_360_angle(bearing.yaw)Yaw 0-360°540func reset_ship() -> void:Reset all state542ship_position = Vector3.ZEROReset position543ship_velocity = Vector3.ZEROReset velocity544ship_acceleration = Vector3.ZEROReset acceleration545current_thrust_acceleration = 0.0Reset thrust display548pitch_angle = 0.0Reset pitch549yaw_angle = 0.0Reset yaw557func get_distance_to_origin() -> float:Get distance helper558return ship_position.length()Return distance570func is_within_radius(radius: float) -> bool:Check proximity571return ship_position.length() <= radiusReturn comparison
Function Call Flow (navigationcomputer.gd)
_physics_process(delta) [line 109] ◄── Called 60 times/second by Godot
  ├─→ ship_velocity += ship_acceleration * delta [line 113]
  ├─→ ship_position += ship_velocity * delta [line 117]
  ├─→ ship_acceleration = Vector3.ZERO [line 121]
  └─→ current_thrust_acceleration decay [line 126]

apply_thrust(thrust_percentage) [line 143] ◄── Called from main.gd line 156
  ├─→ clamp(thrust_percentage, 0.0, 1.0) [line 145]
  ├─→ get_forward_vector() [line 149]
  │     ├─→ Calculate forward.x = -sin(yaw) * cos(pitch) [line 274]
  │     ├─→ Calculate forward.y = sin(pitch) [line 275]
  │     ├─→ Calculate forward.z = -cos(yaw) * cos(pitch) [line 276]
  │     └─→ Return forward.normalized() [line 281]
  ├─→ thrust_magnitude = MAX_THRUST * percentage [line 153]
  ├─→ current_thrust_acceleration = thrust_magnitude [line 156]
  └─→ ship_acceleration += direction * magnitude [line 160]

rotate_ship(pitch, yaw, delta) [line 197] ◄── Called from main.gd line 161
  ├─→ clamp(pitch, -MAX_RATE, MAX_RATE) [line 199]
  ├─→ clamp(yaw, -MAX_RATE, MAX_RATE) [line 200]
  ├─→ if abs(pitch) > 0.001: pitch_angle += pitch * delta [lines 204-205]
  └─→ if abs(yaw) > 0.001: yaw_angle += yaw * delta [lines 210-211]

get_terminal_readout() [line 453] ◄── Called from main.gd line 181
  ├─→ get_spherical_coordinates() [line 455]
  │     ├─→ var r = ship_position.length() [line 406]
  │     ├─→ if r < 0.001: return zeros [lines 409-415]
  │     ├─→ azimuth_rad = atan2(z, x) [line 418]
  │     ├─→ azimuth_deg = rad_to_deg(azimuth_rad) [line 419]
  │     ├─→ elevation_rad = asin(y / r) [line 424]
  │     ├─→ elevation_deg = rad_to_deg(elevation_rad) [line 425]
  │     └─→ return {distance, azimuth, elevation} [lines 428-430]
  ├─→ get_bearing_angles() [line 456]
  │     ├─→ pitch_deg = rad_to_deg(pitch_angle) [line 371]
  │     ├─→ yaw_deg = rad_to_deg(yaw_angle) [line 372]
  │     └─→ return {pitch, yaw} [lines 376-377]
  ├─→ get_forward_vector() [line 457]
  ├─→ Build output string [lines 460-498]
  │     ├─→ Cartesian position / 1000 [lines 469-471]
  │     ├─→ Spherical with to_360_angle(azimuth) [line 477]
  │     ├─→ Velocity components [lines 483-485]
  │     ├─→ Bearing with to_360_angle(pitch/yaw) [lines 489-490]
  │     └─→ Thrust vector and acceleration [lines 494-495]
  └─→ return output [line 500]

get_forward_vector() [line 270] ◄── Called from multiple locations
  ├─→ forward.x = -sin(yaw_angle) * cos(pitch_angle) [line 274]
  ├─→ forward.y = sin(pitch_angle) [line 275]
  ├─→ forward.z = -cos(yaw_angle) * cos(pitch_angle) [line 276]
  └─→ return forward.normalized() [line 281]

get_right_vector() [line 303] ◄── Used for cross product calculations
  ├─→ right.x = cos(yaw_angle) [line 307]
  ├─→ right.y = 0.0 [line 308]
  ├─→ right.z = sin(yaw_angle) [line 309]
  └─→ return right.normalized() [line 310]

get_up_vector() [line 318] ◄── Derived from right × forward
  └─→ return get_right_vector().cross(get_forward_vector()).normalized() [line 320]

to_360_angle(angle) [line 346] ◄── Display conversion only
  └─→ return fposmod(angle, 360.0) [line 349]

reset_ship() [line 540] ◄── Called from main.gd line 222
  ├─→ ship_position = Vector3.ZERO [line 542]
  ├─→ ship_velocity = Vector3.ZERO [line 543]
  ├─→ ship_acceleration = Vector3.ZERO [line 544]
  ├─→ current_thrust_acceleration = 0.0 [line 545]
  ├─→ pitch_angle = 0.0 [line 548]
  └─→ yaw_angle = 0.0 [line 549]
Complete System Loop
Initialization Phase
Godot Engine Starts
  └─→ main.tscn loads
       └─→ main.gd _ready() [line 68]
             ├─→ Creates nav_computer instance [line 25]
             ├─→ add_child(nav_computer) [line 71]
             │    └─→ nav_computer now receives _physics_process() calls
             ├─→ _connect_buttons() [line 75]
             ├─→ update_thrust_display() [line 78]
             ├─→ Timer setup for 10 Hz updates [lines 82-86]
             └─→ _update_terminal() first call [line 90]
                  └─→ nav_computer.get_terminal_readout() [line 181]
Runtime Loop (Every Frame)
Physics Update (60 Hz)
Godot Physics Frame (every ~16.67ms)
  ├─→ main.gd _physics_process(delta) [line 152]
  │     ├─→ nav_computer.apply_thrust(current_thrust) [line 156]
  │     │     ├─→ get_forward_vector() [line 149 → line 270]
  │     │     │     └─→ Derives direction from pitch_angle & yaw_angle [lines 274-276]
  │     │     └─→ ship_acceleration += direction * magnitude [line 160]
  │     └─→ nav_computer.rotate_ship(pitch_rate, yaw_rate, delta) [line 161]
  │           ├─→ pitch_angle += pitch * delta [line 205]
  │           └─→ yaw_angle += yaw * delta [line 211]
  │
  └─→ navigationcomputer.gd _physics_process(delta) [line 109]
        ├─→ ship_velocity += ship_acceleration * delta [line 113]
        ├─→ ship_position += ship_velocity * delta [line 117]
        ├─→ ship