# Godot Space Navigation Simulator - Technical Documentation

## Architecture Overview

This retro terminal-style space navigation simulator is built in Godot. The architecture follows a strict separation of concerns:

- **main.gd** — UI controller layer (no physics/math)
- **navigationcomputer.gd** — Physics/math engine (no UI code)
- **main.tscn** — Scene definition and UI layout

## Data Flow Diagram

```
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
```

## File: main.gd (198 lines)

### Critical Line References

| Line | Content | Description |
|------|---------|-------------|
| 1    | `## Main.gd` | File header |
| 10   | `##   5. Updates UI labels with formatted text` | Architecture documentation |
| 25   | `var nav_computer: Control = preload("res://navigationcomputer.gd").new()` | Navigation computer instantiation |
| 35   | `@onready var terminal_label: Label = $TerminalDisplay/ScrollContainer/TerminalLabel` | Terminal display reference |
| 38   | `@onready var thrust_label: Label = $ControlPanel/ThrustControls/ThrustLabel` | Thrust label reference |
| 47   | `var current_thrust: float = 0.0` | Current thrust percentage storage |
| 50   | `var thrust_increment: float = 0.1` | Thrust increment per button click |
| 54   | `var pitch_rate: float = 0.0` | Current pitch rotation rate |
| 59   | `var yaw_rate: float = 0.0` | Current yaw rotation rate |
| 68   | `func _ready() -> void:` | Initialization function |
| 71   | `add_child(nav_computer)` | Adds nav computer to scene tree |
| 75   | `_connect_buttons()` | Wire up button signals |
| 78   | `update_thrust_display()` | Initialize thrust display |
| 82   | `var timer = Timer.new()` | Create display update timer |
| 83   | `timer.wait_time = 0.1` | Set to 10 Hz update rate |
| 84   | `timer.timeout.connect(_update_terminal)` | Connect timer to update function |
| 90   | `_update_terminal()` | Initial terminal update |
| 105  | `func _connect_buttons() -> void:` | Button signal connection setup |
| 109  | `$ControlPanel/ThrustControls/ThrustButtons/ThrustPlusButton.pressed.connect(_on_thrust_increase)` | Connect thrust + button |
| 110  | `$ControlPanel/ThrustControls/ThrustButtons/ThrustMinusButton.pressed.connect(_on_thrust_decrease)` | Connect thrust - button |
| 116  | `$ControlPanel/RotationControls/PitchControls/PitchUpButton.button_down.connect(func(): pitch_rate = 1.0)` | Pitch up button down |
| 117  | `$ControlPanel/RotationControls/PitchControls/PitchUpButton.button_up.connect(func(): pitch_rate = 0.0)` | Pitch up button release |
| 120  | `$ControlPanel/RotationControls/PitchControls/PitchDownButton.button_down.connect(func(): pitch_rate = -1.0)` | Pitch down button down |
| 121  | `$ControlPanel/RotationControls/PitchControls/PitchDownButton.button_up.connect(func(): pitch_rate = 0.0)` | Pitch down button release |
| 126  | `$ControlPanel/RotationControls/YawControls/YawLeftButton.button_down.connect(func(): yaw_rate = 1.0)` | Yaw left button down |
| 127  | `$ControlPanel/RotationControls/YawControls/YawLeftButton.button_up.connect(func(): yaw_rate = 0.0)` | Yaw left button release |
| 130  | `$ControlPanel/RotationControls/YawControls/YawRightButton.button_down.connect(func(): yaw_rate = -1.0)` | Yaw right button down |
| 131  | `$ControlPanel/RotationControls/YawControls/YawRightButton.button_up.connect(func(): yaw_rate = 0.0)` | Yaw right button release |
| 135  | `$ControlPanel/UtilityButtons/ResetButton.pressed.connect(_on_reset_pressed)` | Connect reset button |
| 136  | `$ControlPanel/UtilityButtons/KillVelocityButton.pressed.connect(_on_kill_velocity)` | Connect kill velocity button |
| 152  | `func _physics_process(delta: float) -> void:` | Physics frame update (60 Hz) |
| 156  | `nav_computer.apply_thrust(current_thrust)` | Send thrust to nav computer |
| 161  | `nav_computer.rotate_ship(pitch_rate, yaw_rate, delta)` | Send rotation to nav computer |
| 176  | `func _update_terminal() -> void:` | Terminal display update (10 Hz) |
| 181  | `terminal_label.text = nav_computer.get_terminal_readout()` | Get formatted data from nav computer |
| 189  | `func _on_thrust_increase() -> void:` | Thrust increase handler |
| 190  | `current_thrust = min(current_thrust + thrust_increment, 1.0)` | Increase thrust, clamped to 1.0 |
| 191  | `update_thrust_display()` | Update UI immediately |
| 197  | `func _on_thrust_decrease() -> void:` | Thrust decrease handler |
| 198  | `current_thrust = max(current_thrust - thrust_increment, 0.0)` | Decrease thrust, clamped to 0.0 |
| 199  | `update_thrust_display()` | Update UI immediately |
| 205  | `func update_thrust_display() -> void:` | Thrust label update |
| 208  | `thrust_label.text = "THRUST: %d%%" % (current_thrust * 100)` | Convert 0.0-1.0 to percentage |
| 219  | `func _on_reset_pressed() -> void:` | Reset button handler |
| 222  | `nav_computer.reset_ship()` | Reset physics state |
| 225  | `current_thrust = 0.0` | Reset local thrust |
| 226  | `pitch_rate = 0.0` | Reset local pitch rate |
| 227  | `yaw_rate = 0.0` | Reset local yaw rate |
| 230  | `update_thrust_display()` | Update UI to show 0% |
| 238  | `func _on_kill_velocity() -> void:` | Kill velocity handler |
| 240  | `nav_computer.ship_velocity = Vector3.ZERO` | Emergency stop |
| 258  | `func _input(event: InputEvent) -> void:` | Keyboard input handler |
| 260  | `if event is InputEventKey:` | Filter for keyboard events |
| 262  | `if event.keycode == KEY_W and event.pressed:` | W key: increase thrust |
| 264  | `elif event.keycode == KEY_S and event.pressed:` | S key: decrease thrust |
| 268  | `if event.keycode == KEY_UP:` | UP arrow: pitch up |
| 269  | `pitch_rate = 1.0 if event.pressed else 0.0` | Set pitch rate based on key state |
| 270  | `elif event.keycode == KEY_DOWN:` | DOWN arrow: pitch down |
| 271  | `pitch_rate = -1.0 if event.pressed else 0.0` | Set pitch rate based on key state |
| 274  | `elif event.keycode == KEY_LEFT:` | LEFT arrow: yaw left |
| 275  | `yaw_rate = 1.0 if event.pressed else 0.0` | Set yaw rate based on key state |
| 276  | `elif event.keycode == KEY_RIGHT:` | RIGHT arrow: yaw right |
| 277  | `yaw_rate = -1.0 if event.pressed else 0.0` | Set yaw rate based on key state |
| 280  | `if event.keycode == KEY_R and event.pressed:` | R key: reset |
| 282  | `elif event.keycode == KEY_X and event.pressed:` | X key: kill velocity |

### Function Call Flow (main.gd)

```
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
```

## File: navigationcomputer.gd (572 lines)

### Critical Line References

| Line | Content | Description |
|------|---------|-------------|
| 1    | `## NavigationComputer.gd` | File header |
| 10   | `##   5. Display formatting (converting radians → degrees → 0-360° strings)` | Architecture documentation |
| 17   | `##   +X = right, +Y = up, +Z = backward (so -Z = forward)` | Coordinate system definition |
| 35   | `var ship_position: Vector3 = Vector3.ZERO` | Ship position in meters |
| 40   | `var ship_velocity: Vector3 = Vector3.ZERO` | Ship velocity in m/s |
| 45   | `var ship_acceleration: Vector3 = Vector3.ZERO` | Ship acceleration in m/s² |
| 50   | `var current_thrust_acceleration: float = 0.0` | Display thrust value |
| 62   | `var pitch_angle: float = 0.0` | Pitch angle in radians |
| 73   | `var yaw_angle: float = 0.0` | Yaw angle in radians |
| 81   | `const REFERENCE_ORIGIN: Vector3 = Vector3.ZERO` | Reference point for spherical coords |
| 89   | `const MAX_THRUST_ACCELERATION: float = 10.0` | Maximum thrust in m/s² |
| 93   | `const MAX_ROTATION_RATE: float = 0.5` | Maximum rotation rate in rad/s |
| 109  | `func _physics_process(delta: float) -> void:` | Physics update (60 Hz) |
| 113  | `ship_velocity += ship_acceleration * delta` | Apply acceleration to velocity |
| 117  | `ship_position += ship_velocity * delta` | Apply velocity to position |
| 121  | `ship_acceleration = Vector3.ZERO` | Reset acceleration |
| 126  | `current_thrust_acceleration = max(0.0, current_thrust_acceleration - MAX_THRUST_ACCELERATION * delta * 2.0)` | Decay display thrust |
| 143  | `func apply_thrust(thrust_percentage: float) -> void:` | Apply main thrust |
| 145  | `thrust_percentage = clamp(thrust_percentage, 0.0, 1.0)` | Clamp thrust to valid range |
| 149  | `var thrust_direction = get_forward_vector()` | Get forward direction from angles |
| 153  | `var thrust_magnitude = MAX_THRUST_ACCELERATION * thrust_percentage` | Calculate thrust magnitude |
| 156  | `current_thrust_acceleration = thrust_magnitude` | Update display value |
| 160  | `ship_acceleration += thrust_direction * thrust_magnitude` | Apply acceleration |
| 170  | `func apply_directional_thrust(direction: Vector3, thrust_percentage: float) -> void:` | Apply thrust in arbitrary direction |
| 197  | `func rotate_ship(pitch: float, yaw: float, delta: float) -> void:` | Update ship orientation |
| 199  | `pitch = clamp(pitch, -MAX_ROTATION_RATE, MAX_ROTATION_RATE)` | Clamp pitch rate |
| 200  | `yaw = clamp(yaw, -MAX_ROTATION_RATE, MAX_ROTATION_RATE)` | Clamp yaw rate |
| 204  | `if abs(pitch) > 0.001:` | Check pitch threshold |
| 205  | `pitch_angle += pitch * delta` | Update pitch angle |
| 210  | `if abs(yaw) > 0.001:` | Check yaw threshold |
| 211  | `yaw_angle += yaw * delta` | Update yaw angle |
| 270  | `func get_forward_vector() -> Vector3:` | Derive forward vector from angles |
| 273  | `var forward = Vector3(` | Begin forward vector calculation |
| 274  | `-sin(yaw_angle) * cos(pitch_angle),` | X component |
| 275  | `sin(pitch_angle),` | Y component |
| 276  | `-cos(yaw_angle) * cos(pitch_angle)` | Z component |
| 281  | `return forward.normalized()` | Return normalized forward |
| 303  | `func get_right_vector() -> Vector3:` | Derive right vector from yaw |
| 306  | `return Vector3(` | Begin right vector calculation |
| 307  | `cos(yaw_angle),` | X component |
| 308  | `0.0,` | Y component (horizontal) |
| 309  | `sin(yaw_angle)` | Z component |
| 318  | `func get_up_vector() -> Vector3:` | Derive up vector from cross product |
| 320  | `return get_right_vector().cross(get_forward_vector()).normalized()` | Cross product for up |
| 346  | `func to_360_angle(angle: float) -> float:` | Convert angle to 0-360° range |
| 349  | `return fposmod(angle, 360.0)` | Modulo operation for wrapping |
| 368  | `func get_bearing_angles() -> Dictionary:` | Get pitch/yaw in degrees |
| 371  | `var pitch_deg = rad_to_deg(pitch_angle)` | Convert pitch to degrees |
| 372  | `var yaw_deg = rad_to_deg(yaw_angle)` | Convert yaw to degrees |
| 376  | `"pitch": pitch_deg,` | Return pitch |
| 377  | `"yaw": yaw_deg,` | Return yaw |
| 404  | `func get_spherical_coordinates() -> Dictionary:` | Convert to spherical coords |
| 406  | `var r = ship_position.length()` | Calculate distance |
| 409  | `if r < 0.001:` | Handle origin case |
| 418  | `var azimuth_rad = atan2(ship_position.z, ship_position.x)` | Calculate azimuth |
| 419  | `var azimuth_deg = rad_to_deg(azimuth_rad)` | Convert to degrees |
| 424  | `var elevation_rad = asin(clamp(ship_position.y / r, -1.0, 1.0))` | Calculate elevation |
| 425  | `var elevation_deg = rad_to_deg(elevation_rad)` | Convert to degrees |
| 428  | `"distance": r,` | Return distance |
| 429  | `"azimuth": azimuth_deg,` | Return azimuth |
| 430  | `"elevation": elevation_deg` | Return elevation |
| 453  | `func get_terminal_readout() -> String:` | Format terminal display |
| 455  | `var spherical = get_spherical_coordinates()` | Get spherical coords |
| 456  | `var bearing = get_bearing_angles()` | Get bearing angles |
| 457  | `var forward = get_forward_vector()` | Get forward vector |
| 460  | `var output = ""` | Initialize output string |
| 463  | `output += "╔═══════════════════════════════════╗\n"` | Header box |
| 468  | `output += "POSITION [CARTESIAN] (km):\n"` | Cartesian position section |
| 469  | `output += "  X: %+10.2f\n" % (ship_position.x / 1000.0)` | X position in km |
| 470  | `output += "  Y: %+10.2f\n" % (ship_position.y / 1000.0)` | Y position in km |
| 471  | `output += "  Z: %+10.2f\n\n" % (ship_position.z / 1000.0)` | Z position in km |
| 475  | `output += "POSITION [SPHERICAL]:\n"` | Spherical position section |
| 476  | `output += "  DIST: %10.2f km\n" % (spherical.distance / 1000.0)` | Distance in km |
| 477  | `output += "  AZI:  %10.2f°\n" % to_360_angle(spherical.azimuth)` | Azimuth 0-360° |
| 478  | `output += "  ELEV: %+10.2f°\n\n" % spherical.elevation` | Elevation -90 to +90 |
| 481  | `output += "VELOCITY (m/s):\n"` | Velocity section |
| 482  | `output += "  MAG:  %10.2f\n" % ship_velocity.length()` | Velocity magnitude |
| 483  | `output += "  X:    %+10.2f\n" % ship_velocity.x` | X velocity |
| 484  | `output += "  Y:    %+10.2f\n" % ship_velocity.y` | Y velocity |
| 485  | `output += "  Z:    %+10.2f\n\n" % ship_velocity.z` | Z velocity |
| 488  | `output += "BEARING:\n"` | Bearing section |
| 489  | `output += "  PITCH:  %9.2f°\n" % to_360_angle(bearing.pitch)` | Pitch 0-360° |
| 490  | `output += "  YAW:    %9.2f°\n\n" % to_360_angle(bearing.yaw)` | Yaw 0-360° |
| 493  | `output += "THRUST VECTOR:\n"` | Thrust section |
| 494  | `output += "  FWD: [%.3f, %.3f, %.3f]\n" % [forward.x, forward.y, forward.z]` | Forward vector |
| 495  | `output += "  ACC:  %10.2f m/s²\n" % current_thrust_acceleration` | Acceleration |
| 498  | `output += "\n───────────────────────────────────\n"` | Footer |
| 500  | `return output` | Return formatted string |
| 511  | `func get_compact_status() -> String:` | Compact status string |
| 513  | `var dist = ship_position.length() / 1000.0` | Calculate distance |
| 514  | `var vel = ship_velocity.length()` | Calculate velocity |
| 515  | `var bearing = get_bearing_angles()` | Get bearing |
| 518  | `return "DIST: %.1fkm | VEL: %.1fm/s | P:%.0f° Y:%.0f°" % [` | Format compact string |
| 519  | `dist, vel,` | Distance and velocity |
| 520  | `to_360_angle(bearing.pitch),` | Pitch 0-360° |
| 521  | `to_360_angle(bearing.yaw)` | Yaw 0-360° |
| 540  | `func reset_ship() -> void:` | Reset all state |
| 542  | `ship_position = Vector3.ZERO` | Reset position |
| 543  | `ship_velocity = Vector3.ZERO` | Reset velocity |
| 544  | `ship_acceleration = Vector3.ZERO` | Reset acceleration |
| 545  | `current_thrust_acceleration = 0.0` | Reset thrust display |
| 548  | `pitch_angle = 0.0` | Reset pitch |
| 549  | `yaw_angle = 0.0` | Reset yaw |
| 557  | `func get_distance_to_origin() -> float:` | Get distance helper |
| 558  | `return ship_position.length()` | Return distance |
| 570  | `func is_within_radius(radius: float) -> bool:` | Check proximity |
| 571  | `return ship_position.length() <= radius` | Return comparison |

### Function Call Flow (navigationcomputer.gd)

```
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
```

## Complete System Loop

### Initialization Phase

```
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
```

### Runtime Loop (Every Frame)

#### Physics Update (60 Hz)

```
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
```

This formatted version ensures all ASCII art diagrams, flowcharts, and code snippets render correctly as fenced code blocks in **GitHub Flavored Markdown** (GFM). Tables are properly aligned, backticks in code cells are escaped where needed, and indentation is preserved for monospaced display. You can copy-paste this directly into a `README.md` or documentation file.
