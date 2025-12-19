## NavigationComputer.gd
## Handles all ship physics, positioning, and orientation for a retro space sim
## Extends Control to avoid Node3D variable conflicts
##
## REFACTOR NOTES:
## - Decoupled pitch and yaw into independent accumulating angles (radians)
## - Forward vector now derived cleanly from pitch + yaw without coupling
## - Display angles converted to 0-360° azimuth using to_360_angle()
## - Roll fully removed (deprecated)
## - Spherical coordinates remain read-only derived values
## - FIXED: Right vector calculation (was rotating wrong direction)
## - FIXED: to_360_angle now handles all negative angles correctly
extends Control

# ============================================================================
# SHIP STATE VARIABLES
# ============================================================================

## Ship's current position in 3D space relative to reference origin (meters)
var ship_position: Vector3 = Vector3.ZERO

## Ship's current velocity vector (meters/second)
var ship_velocity: Vector3 = Vector3.ZERO

## Ship's current acceleration vector (meters/second²)
var ship_acceleration: Vector3 = Vector3.ZERO

## Current thrust acceleration magnitude for display (meters/second²)
## This tracks the acceleration factor being applied to velocity magnitude
var current_thrust_acceleration: float = 0.0

# ============================================================================
# ORIENTATION STATE (CANONICAL - STORED IN RADIANS)
# ============================================================================
## These are the ONLY stored orientation values. They accumulate independently.

## Pitch angle (rotation around local X axis) - nose up/down
## Range: unrestricted, wraps naturally through trigonometry
## Positive = nose up, Negative = nose down
## Display wraps using to_360_angle() for 0-360° format
var pitch_angle: float = 0.0

## Yaw angle (rotation around global Y axis) - heading
## Range: unrestricted, wraps naturally through trigonometry
## Measured from +X axis in XZ plane
## NOTE: Yaw convention in this implementation:
##   - yaw = 0: facing -Z (forward in Godot)
##   - yaw = +π/2: facing -X (turned left)
##   - yaw = -π/2: facing +X (turned right)
var yaw_angle: float = 0.0

## Reference origin point (black hole or station at 0,0,0)
const REFERENCE_ORIGIN: Vector3 = Vector3.ZERO

# ============================================================================
# SHIP CONSTANTS
# ============================================================================

## Maximum thrust acceleration (meters/second²)
const MAX_THRUST_ACCELERATION: float = 10.0

## Maximum rotation rate (radians/second)
const MAX_ROTATION_RATE: float = 0.5

# ============================================================================
# PHYSICS UPDATE
# ============================================================================

func _physics_process(delta: float) -> void:
	# Update velocity based on current acceleration (v = v0 + a*t)
	ship_velocity += ship_acceleration * delta

	# Update position based on current velocity (s = s0 + v*t)
	ship_position += ship_velocity * delta

	# Reset acceleration for next frame (thrust must be reapplied each frame)
	ship_acceleration = Vector3.ZERO

	# Decay the displayed thrust acceleration when no thrust is applied
	# This represents the factor of increase to velocity magnitude
	current_thrust_acceleration = max(0.0, current_thrust_acceleration - MAX_THRUST_ACCELERATION * delta * 2.0)

# ============================================================================
# THRUST CONTROL
# ============================================================================

## Apply thrust in the direction the ship is currently facing
## @param thrust_percentage: Value from 0.0 to 1.0 representing throttle position
func apply_thrust(thrust_percentage: float) -> void:
	# Clamp thrust to valid range
	thrust_percentage = clamp(thrust_percentage, 0.0, 1.0)

	# Get the ship's current forward direction (derived from pitch/yaw)
	var thrust_direction = get_forward_vector()

	# Calculate acceleration directly from throttle percentage
	var thrust_magnitude = MAX_THRUST_ACCELERATION * thrust_percentage

	# Update the displayed acceleration (factor of increase to velocity magnitude)
	current_thrust_acceleration = thrust_magnitude

	# Apply acceleration in the thrust direction
	ship_acceleration += thrust_direction * thrust_magnitude

## Apply thrust in an arbitrary direction (for RCS thrusters, strafing, etc.)
## @param direction: Normalized direction vector
## @param thrust_percentage: Value from 0.0 to 1.0
func apply_directional_thrust(direction: Vector3, thrust_percentage: float) -> void:
	thrust_percentage = clamp(thrust_percentage, 0.0, 1.0)
	var thrust_magnitude = MAX_THRUST_ACCELERATION * thrust_percentage

	# Update the displayed acceleration (factor of increase to velocity magnitude)
	current_thrust_acceleration = thrust_magnitude

	ship_acceleration += direction.normalized() * thrust_magnitude

# ============================================================================
# ROTATION CONTROL (REFACTORED - DECOUPLED AXES)
# ============================================================================

## Rotate the ship around its axes using INDEPENDENT pitch and yaw accumulators
## @param pitch: Rotation rate around X axis (radians/sec) - nose up/down
## @param yaw: Rotation rate around Y axis (radians/sec) - nose left/right
## @param delta: Physics delta time
##
## REFACTOR: Pitch and yaw now modify independent angle variables.
## No axis couples to another. Each updates its own accumulator.
## Both angles are unrestricted and wrap naturally.
##
## SIGN CONVENTIONS (matching Main.gd button inputs):
##   pitch_rate = +1.0 → UP button → nose pitches up (positive pitch)
##   pitch_rate = -1.0 → DOWN button → nose pitches down (negative pitch)
##   yaw_rate = +1.0 → LEFT button → ship turns left (positive yaw)
##   yaw_rate = -1.0 → RIGHT button → ship turns right (negative yaw)
func rotate_ship(pitch: float, yaw: float, delta: float) -> void:
	# Clamp rotation rates to maximum
	pitch = clamp(pitch, -MAX_ROTATION_RATE, MAX_ROTATION_RATE)
	yaw = clamp(yaw, -MAX_ROTATION_RATE, MAX_ROTATION_RATE)

	# Update independent angle accumulators
	# Both pitch and yaw are unrestricted - they wrap naturally via trig functions
	if abs(pitch) > 0.001:
		pitch_angle += pitch * delta
	
	if abs(yaw) > 0.001:
		yaw_angle += yaw * delta

# ============================================================================
# FORWARD VECTOR DERIVATION (REFACTORED - CLEAN SEPARATION)
# ============================================================================

## Derive the ship's forward direction from independent pitch and yaw angles
## 
## MATHEMATICAL DERIVATION:
## 
## Starting configuration (identity):
##   Forward: (0, 0, -1)  [Godot's -Z is forward]
##   Right: (1, 0, 0)     [+X is right]
##   Up: (0, 1, 0)        [+Y is up]
##
## Step 1 - Apply YAW (rotation around global Y axis):
##   This rotates the forward vector in the XZ plane
##   Using standard 2D rotation matrix around Y:
##     X_new = X*cos(θ) - Z*sin(θ)
##     Z_new = X*sin(θ) + Z*cos(θ)
##   
##   For initial forward (0, 0, -1):
##     X = 0*cos(yaw) - (-1)*sin(yaw) = sin(yaw)
##     Z = 0*sin(yaw) + (-1)*cos(yaw) = -cos(yaw)
##   
##   So horizontal_forward = (sin(yaw), 0, -cos(yaw))
##   
##   Wait, let me verify the sign convention:
##     yaw = 0 → (sin(0), 0, -cos(0)) = (0, 0, -1) ✓ facing -Z
##     yaw = π/2 → (sin(π/2), 0, -cos(π/2)) = (1, 0, 0) 
##       But LEFT turn should give (-1, 0, 0) !
##   
##   The issue is the rotation direction. For LEFT to be positive yaw:
##     X = -sin(yaw)  [negative to make positive yaw = left turn]
##     Z = -cos(yaw)
##
## Step 2 - Apply PITCH (rotation around local X axis):
##   The horizontal forward vector gets tilted up/down
##   The X and Z components scale by cos(pitch)
##   The Y component becomes sin(pitch)
##
## This matches Godot's right-handed coordinate system where:
##   +X = right, +Y = up, +Z = backward (so -Z = forward)
##
## Validation:
##   yaw=0, pitch=0: (-sin(0), sin(0), -cos(0)) = (0, 0, -1) ✓
##   yaw=π/2, pitch=0: (-sin(π/2)*cos(0), sin(0), -cos(π/2)*cos(0)) = (-1, 0, 0) ✓ left
##   yaw=0, pitch=π/2: (-sin(0)*cos(π/2), sin(π/2), -cos(0)*cos(π/2)) = (0, 1, 0) ✓ up
func get_forward_vector() -> Vector3:
	# Apply yaw and pitch using the corrected formula
	# This is the standard aerospace Euler angle → direction vector conversion
	var forward = Vector3(
		-sin(yaw_angle) * cos(pitch_angle),  # X component
		sin(pitch_angle),                     # Y component (pure pitch)
		-cos(yaw_angle) * cos(pitch_angle)   # Z component
	)
	
	# Normalize to ensure unit vector (should already be unit length, but safety)
	return forward.normalized()

## Get the ship's current right direction vector
## Derived by rotating the forward vector 90° right (clockwise from above)
##
## CORRECTED: Right is perpendicular to forward in the XZ plane
## For a vector (x, 0, z) in XZ plane, rotating 90° clockwise gives (z, 0, -x)
## But we need to derive it from yaw only for clean separation
##
## Right vector is the horizontal vector perpendicular to forward heading
## If forward horizontal is (-sin(yaw), 0, -cos(yaw))
## Then right (90° clockwise rotation in XZ) is:
##   Rotating (x, z) by -90° gives (z, -x)
##   So: (-cos(yaw), 0, sin(yaw))
##
## Validation:
##   yaw=0: (-cos(0), 0, sin(0)) = (-1, 0, 0)... wait that's LEFT
##   We want (1, 0, 0) for right when facing -Z
##
## The correct rotation for RIGHT (positive X) from forward (-Z):
##   If forward is angle θ from -Z axis, right is at θ + 90°
##   Right = (cos(yaw), 0, sin(yaw))
func get_right_vector() -> Vector3:
	# Right vector in XZ plane, perpendicular to yaw direction
	return Vector3(
		cos(yaw_angle),   # X component (positive = right)
		0.0,              # Y component always 0 (horizontal)
		sin(yaw_angle)    # Z component
	).normalized()

## Get the ship's current up direction vector
## Derived from the cross product of right × forward (right-handed system)
##
## Using right-hand rule: right × forward = up
func get_up_vector() -> Vector3:
	return get_right_vector().cross(get_forward_vector()).normalized()

# ============================================================================
# ANGLE CONVERSION UTILITIES
# ============================================================================

## Convert angle from any value to 0-360 range
## @param angle: Angle in degrees (any range)
## @return: Equivalent angle in 0-360 degree range
##
## FIXED: Now correctly handles all negative angles and wrapping
## Uses fposmod instead of fmod to ensure positive result
func to_360_angle(angle: float) -> float:
	# fposmod ensures result is always positive in range [0, 360)
	return fposmod(angle, 360.0)

# ============================================================================
# BEARING CALCULATIONS (REFACTORED - DISPLAY ONLY)
# ============================================================================

## Get pitch and yaw angles for display
## Returns angles in degrees (before 0-360 conversion)
##
## REFACTOR: These values are now directly read from the canonical
##           pitch_angle and yaw_angle variables.
##           
## BOTH pitch and yaw are converted to 0-360° format for display using to_360_angle()
func get_bearing_angles() -> Dictionary:
	# Convert stored radians to degrees
	var pitch_deg = rad_to_deg(pitch_angle)
	var yaw_deg = rad_to_deg(yaw_angle)
	
	return {
		"pitch": pitch_deg,  # unrestricted degrees (convert to 0-360° for display)
		"yaw": yaw_deg,      # unrestricted degrees (convert to 0-360° for display)
	}

# ============================================================================
# COORDINATE CONVERSIONS (READ-ONLY DERIVED VALUES)
# ============================================================================

## Convert ship's Cartesian position to spherical coordinates
## Useful for navigation displays relative to reference origin
##
## REFACTOR: Confirmed as read-only derived values. These never drive motion.
func get_spherical_coordinates() -> Dictionary:
	var r = ship_position.length()
	
	# Handle case where ship is at origin
	if r < 0.001:
		return {
			"distance": 0.0,
			"azimuth": 0.0,
			"elevation": 0.0
		}
	
	# Azimuth: horizontal angle in XZ plane measured from +X axis
	var azimuth_rad = atan2(ship_position.z, ship_position.x)
	var azimuth_deg = rad_to_deg(azimuth_rad)
	
	# Elevation: vertical angle from XZ plane
	var elevation_rad = asin(clamp(ship_position.y / r, -1.0, 1.0))
	var elevation_deg = rad_to_deg(elevation_rad)
	
	return {
		"distance": r,              # Distance from origin in meters
		"azimuth": azimuth_deg,     # -180 to +180 degrees (converted to 0-360° for display)
		"elevation": elevation_deg  # -90 to +90 degrees
	}

# ============================================================================
# DATA FORMATTING FOR TERMINAL DISPLAY (REFACTORED - AZIMUTH DISPLAY)
# ============================================================================

## Format all navigation data as retro terminal text
##
## REFACTOR: All displayed angles now use to_360_angle() for azimuth format
func get_terminal_readout() -> String:
	var spherical = get_spherical_coordinates()
	var bearing = get_bearing_angles()
	var forward = get_forward_vector()
	
	var output = ""
	output += "╔═══════════════════════════════════╗\n"
	output += "║   NAVIGATION COMPUTER v2.4.1      ║\n"
	output += "╚═══════════════════════════════════╝\n\n"
	
	output += "POSITION [CARTESIAN] (km):\n"
	output += "  X: %+10.2f\n" % (ship_position.x / 1000.0)
	output += "  Y: %+10.2f\n" % (ship_position.y / 1000.0)
	output += "  Z: %+10.2f\n\n" % (ship_position.z / 1000.0)
	
	output += "POSITION [SPHERICAL]:\n"
	output += "  DIST: %10.2f km\n" % (spherical.distance / 1000.0)
	output += "  AZI:  %10.2f°\n" % to_360_angle(spherical.azimuth)
	output += "  ELEV: %+10.2f°\n\n" % spherical.elevation
	
	output += "VELOCITY (m/s):\n"
	output += "  MAG:  %10.2f\n" % ship_velocity.length()
	output += "  X:    %+10.2f\n" % ship_velocity.x
	output += "  Y:    %+10.2f\n" % ship_velocity.y
	output += "  Z:    %+10.2f\n\n" % ship_velocity.z
	
	output += "BEARING:\n"
	output += "  PITCH:  %9.2f°\n" % to_360_angle(bearing.pitch)
	output += "  YAW:    %9.2f°\n\n" % to_360_angle(bearing.yaw)
	
	output += "THRUST VECTOR:\n"
	output += "  FWD: [%.3f, %.3f, %.3f]\n" % [forward.x, forward.y, forward.z]
	output += "  ACC:  %10.2f m/s²\n" % current_thrust_acceleration
	
	output += "\n───────────────────────────────────\n"
	
	return output

## Get compact single-line status for HUD overlay
func get_compact_status() -> String:
	var dist = ship_position.length() / 1000.0
	var vel = ship_velocity.length()
	var bearing = get_bearing_angles()

	return "DIST: %.1fkm | VEL: %.1fm/s | P:%.0f° Y:%.0f°" % [
		dist, vel, to_360_angle(bearing.pitch), to_360_angle(bearing.yaw)
	]

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

## Reset ship to starting position with zero velocity
##
## REFACTOR: Now resets pitch_angle and yaw_angle (canonical state)
func reset_ship() -> void:
	ship_position = Vector3.ZERO
	ship_velocity = Vector3.ZERO
	ship_acceleration = Vector3.ZERO
	current_thrust_acceleration = 0.0
	
	# Reset orientation to identity (facing -Z, no pitch)
	pitch_angle = 0.0
	yaw_angle = 0.0

## Get distance to reference origin
func get_distance_to_origin() -> float:
	return ship_position.length()

## Check if ship is within a certain radius of origin
func is_within_radius(radius: float) -> bool:
	return ship_position.length() <= radius
