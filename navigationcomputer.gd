## NavigationComputer.gd
## Physics and navigation engine for retro space simulation
##
## ARCHITECTURE OVERVIEW:
## This is the MATH ENGINE. It handles:
##   1. Ship orientation (pitch/yaw angles in radians)
##   2. 3D motion physics (position, velocity, acceleration)
##   3. Vector derivation (forward/right/up vectors from angles)
##   4. Coordinate conversions (Cartesian ↔ Spherical)
##   5. Display formatting (converting radians → degrees → 0-360° strings)
##
## DATA FLOW:
##   Main.gd provides: thrust percentage (0.0-1.0), rotation rates (rad/s)
##   This script calculates: acceleration, velocity, position, orientation
##   Main.gd polls: get_terminal_readout() for formatted display string
##
## COORDINATE SYSTEM (Godot right-handed):
##   +X = right, +Y = up, +Z = backward (so -Z = forward)
##
## REFACTOR NOTES:
##   - Pitch and yaw are DECOUPLED (independent accumulators)
##   - Forward vector derived directly from angles (no compound rotations)
##   - Display uses 0-360° azimuth format (to_360_angle conversion)
##   - Roll removed entirely (deprecated)
##   - Spherical coords are read-only (derived from Cartesian, never stored)
extends Control

# ============================================================================
# SHIP PHYSICAL STATE (CARTESIAN SPACE)
# ============================================================================

## Ship's current position in 3D space (meters)
## Relative to reference origin at (0, 0, 0)
## Updated every physics frame: position += velocity * delta
var ship_position: Vector3 = Vector3.ZERO

## Ship's current velocity vector (meters/second)
## Direction and magnitude of motion
## Updated every physics frame: velocity += acceleration * delta
var ship_velocity: Vector3 = Vector3.ZERO

## Ship's current acceleration vector (meters/second²)
## Resets to zero every frame (thrust must be reapplied continuously)
## Set by apply_thrust() each frame, then applied to velocity
var ship_acceleration: Vector3 = Vector3.ZERO

## Displayed thrust acceleration magnitude (meters/second²)
## Used for UI display only - tracks the "throttle setting"
## Decays when no thrust applied to show "coasting" state
var current_thrust_acceleration: float = 0.0

# ============================================================================
# SHIP ORIENTATION STATE (CANONICAL ANGLES)
# ============================================================================
# CRITICAL: These are the ONLY authoritative orientation values
# All direction vectors (forward, right, up) are DERIVED from these angles
# These accumulators are INDEPENDENT - no coupling between pitch and yaw

## Pitch angle in radians (rotation around local X axis)
## Controls vertical orientation (nose up/down)
## Range: unrestricted (wraps naturally through trig functions)
## Convention: +pitch = nose up, -pitch = nose down
## Display: Converted to 0-360° format using to_360_angle()
var pitch_angle: float = 0.0

## Yaw angle in radians (rotation around global Y axis)
## Controls horizontal heading (compass direction)
## Range: unrestricted (wraps naturally through trig functions)
## Convention: 
##   yaw = 0 → facing -Z (forward in Godot)
##   yaw = +π/2 → facing -X (turned left)
##   yaw = -π/2 → facing +X (turned right)
## Display: Converted to 0-360° format using to_360_angle()
var yaw_angle: float = 0.0

## Reference origin point (black hole or station)
## All spherical coordinates measured relative to this point
const REFERENCE_ORIGIN: Vector3 = Vector3.ZERO

# ============================================================================
# SHIP CONSTANTS
# ============================================================================

## Maximum thrust acceleration (meters/second²)
## This is what 100% throttle produces
const MAX_THRUST_ACCELERATION: float = 10.0

## Maximum rotation rate (radians/second)
## Limits how fast the ship can pitch or yaw
const MAX_ROTATION_RATE: float = 0.5

# ============================================================================
# PHYSICS UPDATE (RUNS EVERY FRAME)
# ============================================================================

## Called automatically every physics frame (~60 Hz)
## Updates all motion physics using standard kinematic equations
##
## EXECUTION ORDER:
##   1. Apply acceleration to velocity (v = v0 + a*t)
##   2. Apply velocity to position (s = s0 + v*t)
##   3. Reset acceleration to zero (thrust must be reapplied next frame)
##   4. Decay display thrust (visual effect for UI)
##
## @param delta: Time step since last physics frame (typically ~0.0167s)
func _physics_process(delta: float) -> void:
	# Update velocity from acceleration
	# Formula: v = v0 + a*t
	# This applies the current thrust acceleration to velocity
	ship_velocity += ship_acceleration * delta

	# Update position from velocity
	# Formula: s = s0 + v*t
	# This moves the ship according to current velocity
	ship_position += ship_velocity * delta

	# Reset acceleration for next frame
	# Thrust must be continuously applied each frame (no "set and forget")
	# This simulates realistic engine behavior
	ship_acceleration = Vector3.ZERO

	# Decay the displayed thrust acceleration for UI
	# This creates a visual "throttle down" effect when thrust released
	# Factor of 2.0 means it decays twice as fast as it was applied
	current_thrust_acceleration = max(0.0, current_thrust_acceleration - MAX_THRUST_ACCELERATION * delta * 2.0)

# ============================================================================
# THRUST CONTROL (CALLED BY MAIN.GD)
# ============================================================================

## Applies thrust in the direction the ship is facing
## Called every physics frame from Main.gd with current throttle setting
##
## EXECUTION FLOW:
##   1. Clamp thrust_percentage to valid range [0.0, 1.0]
##   2. Get forward vector from current orientation (pitch/yaw)
##   3. Calculate thrust magnitude from percentage
##   4. Update display thrust value
##   5. Add acceleration in forward direction
##
## @param thrust_percentage: Throttle position from 0.0 (off) to 1.0 (full)
func apply_thrust(thrust_percentage: float) -> void:
	# Clamp to valid range (safety check)
	thrust_percentage = clamp(thrust_percentage, 0.0, 1.0)

	# Get the ship's current forward direction
	# This is DERIVED from pitch_angle and yaw_angle (see line 274)
	# The forward vector changes as the ship rotates
	var thrust_direction = get_forward_vector()

	# Calculate thrust magnitude
	# 0.5 throttle = 5.0 m/s² acceleration
	# 1.0 throttle = 10.0 m/s² acceleration
	var thrust_magnitude = MAX_THRUST_ACCELERATION * thrust_percentage

	# Update display value (for UI only)
	current_thrust_acceleration = thrust_magnitude

	# Apply acceleration in the thrust direction
	# This adds to ship_acceleration, which is applied to velocity in _physics_process
	ship_acceleration += thrust_direction * thrust_magnitude

## Applies thrust in an arbitrary direction (for RCS thrusters, strafing, etc.)
## Not currently used by Main.gd but available for future features
##
## @param direction: Direction vector (will be normalized)
## @param thrust_percentage: Throttle position from 0.0 to 1.0
func apply_directional_thrust(direction: Vector3, thrust_percentage: float) -> void:
	thrust_percentage = clamp(thrust_percentage, 0.0, 1.0)
	var thrust_magnitude = MAX_THRUST_ACCELERATION * thrust_percentage
	current_thrust_acceleration = thrust_magnitude
	ship_acceleration += direction.normalized() * thrust_magnitude

# ============================================================================
# ROTATION CONTROL (CALLED BY MAIN.GD)
# ============================================================================

## Updates ship orientation based on rotation rates
## Called every physics frame from Main.gd with current pitch/yaw rates
##
## REFACTOR CRITICAL:
## Pitch and yaw are COMPLETELY INDEPENDENT
##   - Each angle has its own accumulator (pitch_angle, yaw_angle)
##   - No axis affects the other's accumulation
##   - No compound rotations or basis transforms
##   - Angles wrap naturally through trigonometry (no explicit wrapping needed)
##
## SIGN CONVENTIONS (matching Main.gd button inputs):
##   pitch_rate = +1.0 → UP button → nose pitches up (pitch_angle increases)
##   pitch_rate = -1.0 → DOWN button → nose pitches down (pitch_angle decreases)
##   yaw_rate = +1.0 → LEFT button → ship turns left (yaw_angle increases)
##   yaw_rate = -1.0 → RIGHT button → ship turns right (yaw_angle decreases)
##
## @param pitch: Rotation rate around X axis in radians/second
## @param yaw: Rotation rate around Y axis in radians/second
## @param delta: Time step since last frame
func rotate_ship(pitch: float, yaw: float, delta: float) -> void:
	# Clamp rotation rates to maximum (prevent spinning too fast)
	pitch = clamp(pitch, -MAX_ROTATION_RATE, MAX_ROTATION_RATE)
	yaw = clamp(yaw, -MAX_ROTATION_RATE, MAX_ROTATION_RATE)

	# Update pitch angle accumulator
	# Example: pitch_rate = 1.0 rad/s, delta = 0.0167s → pitch_angle += 0.0167 rad
	# The 0.001 threshold prevents tiny floating point errors from accumulating
	if abs(pitch) > 0.001:
		pitch_angle += pitch * delta
	
	# Update yaw angle accumulator
	# Both pitch and yaw are unrestricted - they wrap naturally via sin/cos
	# No need for explicit angle wrapping (e.g., fmod) because trig functions handle it
	if abs(yaw) > 0.001:
		yaw_angle += yaw * delta

# ============================================================================
# DIRECTION VECTOR DERIVATION (CORE MATH)
# ============================================================================

## Derives the ship's forward direction vector from pitch and yaw angles
## This is the HEART of the refactor - where decoupling happens
##
## MATHEMATICAL FOUNDATION:
## Standard aerospace Euler angle to direction vector conversion
## 
## Starting point (identity orientation):
##   Forward = (0, 0, -1)  [Godot convention: -Z is forward]
##   Right = (1, 0, 0)     [+X is right]
##   Up = (0, 1, 0)        [+Y is up]
##
## Transformation process:
##   1. Apply yaw (horizontal rotation around global Y axis)
##   2. Apply pitch (vertical tilt)
##   3. Combine into final forward vector
##
## FORMULA DERIVATION:
## Using rotation matrix math for rotation around Y axis (yaw):
##   For point (0, 0, -1) rotated by yaw angle θ:
##     x_new = 0*cos(θ) - (-1)*sin(θ) = sin(θ)
##     z_new = 0*sin(θ) + (-1)*cos(θ) = -cos(θ)
##   
##   But we want LEFT to be positive yaw (standard nautical convention)
##   So we negate: x = -sin(yaw), z = -cos(yaw)
##
## Then apply pitch (rotation around X axis):
##   The horizontal components (x, z) scale by cos(pitch)
##   The vertical component (y) becomes sin(pitch)
##
## Final formula:
##   forward.x = -sin(yaw) * cos(pitch)
##   forward.y = sin(pitch)
##   forward.z = -cos(yaw) * cos(pitch)
##
## VALIDATION:
##   yaw=0°, pitch=0°: (0, 0, -1) ✓ forward
##   yaw=90°, pitch=0°: (-1, 0, 0) ✓ left
##   yaw=-90°, pitch=0°: (1, 0, 0) ✓ right
##   yaw=0°, pitch=90°: (0, 1, 0) ✓ up
##   yaw=0°, pitch=-90°: (0, -1, 0) ✓ down
##
## WHY THE ORIGINAL FAILED:
## The old implementation used ship_basis.rotated(ship_basis.x, pitch)
## This applied pitch using an already-rotated X axis, causing the axes
## to couple. Extracting angles back from the basis with atan2/asin
## created a lossy round-trip that accumulated error over time.
##
## @return: Normalized forward direction vector
func get_forward_vector() -> Vector3:
	# Compute forward vector directly from angles
	# This is a single-step calculation with no intermediate state
	var forward = Vector3(
		-sin(yaw_angle) * cos(pitch_angle),  # X component: horizontal position scaled by pitch
		sin(pitch_angle),                     # Y component: pure vertical (elevation)
		-cos(yaw_angle) * cos(pitch_angle)   # Z component: depth scaled by pitch
	)
	
	# Normalize to ensure unit length (should already be ~1.0, but safety first)
	# Unit length is critical for physics calculations
	return forward.normalized()

## Gets the ship's right direction vector (perpendicular to forward)
## Used for understanding ship orientation and future strafing controls
##
## DERIVATION:
## Right vector is always horizontal (y = 0) and perpendicular to yaw direction
## If forward horizontal is (-sin(yaw), 0, -cos(yaw))
## Then right (90° rotation clockwise in XZ plane) is:
##   Rotating 2D vector (x, z) by -90° gives (z, -x)
##   But we need the correct handedness...
##
## CORRECT FORMULA:
## For yaw = 0° (facing -Z), we want right = +X direction
## Right is perpendicular to forward in XZ plane
##   right.x = cos(yaw)
##   right.z = sin(yaw)
##
## VALIDATION:
##   yaw=0°: (1, 0, 0) ✓ right when facing forward
##   yaw=90°: (0, 0, 1) ✓ right when facing left (pointing backward)
##
## @return: Normalized right direction vector
func get_right_vector() -> Vector3:
	# Right vector is horizontal, derived from yaw only
	return Vector3(
		cos(yaw_angle),   # X component
		0.0,              # Y component (always horizontal)
		sin(yaw_angle)    # Z component
	).normalized()

## Gets the ship's up direction vector (perpendicular to both forward and right)
## Forms a complete orthonormal basis with forward and right
##
## Uses right-hand rule: right × forward = up
## This ensures we have a consistent right-handed coordinate system
##
## @return: Normalized up direction vector
func get_up_vector() -> Vector3:
	# Cross product of right and forward gives perpendicular up vector
	# Normalized to ensure unit length
	return get_right_vector().cross(get_forward_vector()).normalized()

# ============================================================================
# ANGLE CONVERSION UTILITIES
# ============================================================================

## Converts any angle in degrees to 0-360° range (azimuth format)
## This is the DISPLAY CONVERSION - used only for UI output
##
## CRITICAL: This function is ONLY called for display formatting
## It is NEVER used in physics calculations
## Physics always works in radians with unrestricted range
##
## WHY WE NEED THIS:
## Internally, angles accumulate without bounds (e.g., 370°, -45°, 720°)
## For display, we want consistent 0-360° format for user comprehension
##
## EXAMPLES:
##   Input: -45° → Output: 315°
##   Input: 370° → Output: 10°
##   Input: 180° → Output: 180°
##   Input: -180° → Output: 180°
##
## TECHNICAL NOTE:
## Uses fposmod() instead of fmod() to ensure positive results
## GDScript's fmod() can return negative values, fposmod() cannot
##
## @param angle: Angle in degrees (any range)
## @return: Equivalent angle in 0-360° range
func to_360_angle(angle: float) -> float:
	# fposmod(angle, 360.0) returns angle modulo 360 in range [0, 360)
	# This correctly handles negative angles and values > 360
	return fposmod(angle, 360.0)

# ============================================================================
# BEARING CALCULATIONS (DISPLAY DATA PREPARATION)
# ============================================================================

## Gets pitch and yaw angles converted to degrees for display
## Returns raw degree values BEFORE 0-360° conversion
##
## DATA FLOW:
##   pitch_angle (radians) → pitch_deg (degrees) → to_360_angle() → display
##   yaw_angle (radians) → yaw_deg (degrees) → to_360_angle() → display
##
## REFACTOR NOTE:
## These values are read directly from canonical angle storage (pitch_angle, yaw_angle)
## They are NEVER derived from vectors (no atan2/asin inverse trig)
## This eliminates the lossy round-trip that caused drift in the old code
##
## @return: Dictionary with "pitch" and "yaw" keys (both in degrees, unconverted)
func get_bearing_angles() -> Dictionary:
	# Convert stored radians to degrees
	# rad_to_deg() is Godot's built-in function: degrees = radians * 180 / PI
	var pitch_deg = rad_to_deg(pitch_angle)
	var yaw_deg = rad_to_deg(yaw_angle)
	
	# Return raw degree values
	# Caller will apply to_360_angle() for display
	return {
		"pitch": pitch_deg,  # Unrestricted degrees (convert to 0-360° for display)
		"yaw": yaw_deg,      # Unrestricted degrees (convert to 0-360° for display)
	}

# ============================================================================
# COORDINATE CONVERSIONS (READ-ONLY DERIVED VALUES)
# ============================================================================

## Converts ship's Cartesian position to spherical coordinates
## Useful for navigation displays showing distance/bearing to origin
##
## SPHERICAL COORDINATE SYSTEM:
##   - Distance (r): Straight-line distance from origin
##   - Azimuth: Horizontal angle in XZ plane (like compass heading)
##   - Elevation: Vertical angle from XZ plane (like altitude angle)
##
## CRITICAL: These values are READ-ONLY and DERIVED
## They are calculated from ship_position but NEVER stored
## They NEVER affect physics or motion
##
## CALCULATION METHOD:
##   r = sqrt(x² + y² + z²) = vector.length()
##   azimuth = atan2(z, x)  [angle in XZ plane from +X axis]
##   elevation = asin(y / r)  [angle from XZ plane]
##
## @return: Dictionary with "distance" (meters), "azimuth" (degrees), "elevation" (degrees)
func get_spherical_coordinates() -> Dictionary:
	# Calculate distance from origin
	var r = ship_position.length()
	
	# Handle edge case: ship exactly at origin
	# Prevents division by zero in elevation calculation
	if r < 0.001:
		return {
			"distance": 0.0,
			"azimuth": 0.0,
			"elevation": 0.0
		}
	
	# Calculate azimuth (horizontal angle)
	# atan2(z, x) gives angle from +X axis in XZ plane
	# Range: -180° to +180° (converted to 0-360° in display)
	var azimuth_rad = atan2(ship_position.z, ship_position.x)
	var azimuth_deg = rad_to_deg(azimuth_rad)
	
	# Calculate elevation (vertical angle)
	# asin(y / r) gives angle from XZ plane
	# Range: -90° to +90° (up is positive, down is negative)
	# Clamped to prevent asin domain errors from floating point imprecision
	var elevation_rad = asin(clamp(ship_position.y / r, -1.0, 1.0))
	var elevation_deg = rad_to_deg(elevation_rad)
	
	return {
		"distance": r,              # Distance from origin in meters
		"azimuth": azimuth_deg,     # Horizontal angle in degrees (-180 to +180)
		"elevation": elevation_deg  # Vertical angle in degrees (-90 to +90)
	}

# ============================================================================
# DATA FORMATTING FOR TERMINAL DISPLAY
# ============================================================================

## Formats all navigation data as retro terminal text
## This is the main output function called by Main.gd every 0.1 seconds
##
## STRING FORMATTING:
##   - Uses %+10.2f for signed floats with fixed width and 2 decimals
##   - Uses %10.2f for unsigned floats
##   - Uses %9.2f for angles
##   - All spacing carefully aligned for monospace terminal aesthetic
##
## COORDINATE CONVERSIONS (happens HERE in this function):
##   1. get_spherical_coordinates() returns raw degrees
##   2. to_360_angle() converts azimuth to 0-360° for display
##   3. get_bearing_angles() returns raw pitch/yaw degrees
##   4. to_360_angle() converts both to 0-360° for display
##
## DATA SECTIONS:
##   - Position (Cartesian): X, Y, Z in kilometers
##   - Position (Spherical): Distance, Azimuth (0-360°), Elevation (-90 to +90)
##   - Velocity: Magnitude and X, Y, Z components in m/s
##   - Bearing: Pitch (0-360°), Yaw (0-360°)
##   - Thrust: Forward vector and acceleration magnitude
##
## @return: Fully formatted terminal readout string
func get_terminal_readout() -> String:
	# Fetch all data from calculation functions
	var spherical = get_spherical_coordinates()  # Line 456: Returns distance, azimuth, elevation
	var bearing = get_bearing_angles()           # Line 422: Returns pitch, yaw in degrees
	var forward = get_forward_vector()           # Line 274: Returns forward direction vector
	
	# Build output string section by section
	var output = ""
	
	# Header with box drawing characters
	output += "╔═══════════════════════════════════╗\n"
	output += "║   NAVIGATION COMPUTER v2.4.1      ║\n"
	output += "╚═══════════════════════════════════╝\n\n"
	
	# CARTESIAN POSITION (converted to kilometers for readability)
	output += "POSITION [CARTESIAN] (km):\n"
	output += "  X: %+10.2f\n" % (ship_position.x / 1000.0)
	output += "  Y: %+10.2f\n" % (ship_position.y / 1000.0)
	output += "  Z: %+10.2f\n\n" % (ship_position.z / 1000.0)
	
	# SPHERICAL POSITION
	# Distance in kilometers, azimuth converted to 0-360°, elevation stays -90 to +90
	output += "POSITION [SPHERICAL]:\n"
	output += "  DIST: %10.2f km\n" % (spherical.distance / 1000.0)
	output += "  AZI:  %10.2f°\n" % to_360_angle(spherical.azimuth)  # <-- CONVERSION HERE
	output += "  ELEV: %+10.2f°\n\n" % spherical.elevation
	
	# VELOCITY (magnitude and components)
	output += "VELOCITY (m/s):\n"
	output += "  MAG:  %10.2f\n" % ship_velocity.length()
	output += "  X:    %+10.2f\n" % ship_velocity.x
	output += "  Y:    %+10.2f\n" % ship_velocity.y
	output += "  Z:    %+10.2f\n\n" % ship_velocity.z
	
	# BEARING (ship orientation)
	# Both pitch and yaw converted to 0-360° format
	output += "BEARING:\n"
	output += "  PITCH:  %9.2f°\n" % to_360_angle(bearing.pitch)  # <-- CONVERSION HERE
	output += "  YAW:    %9.2f°\n\n" % to_360_angle(bearing.yaw)  # <-- CONVERSION HERE
	
	# THRUST INFORMATION
	# Forward vector shows direction, acceleration shows current throttle
	output += "THRUST VECTOR:\n"
	output += "  FWD: [%.3f, %.3f, %.3f]\n" % [forward.x, forward.y, forward.z]
	output += "  ACC:  %10.2f m/s²\n" % current_thrust_acceleration
	
	# Footer separator
	output += "\n───────────────────────────────────\n"
	
	return output

## Gets compact single-line status for HUD overlay
## Alternative format for minimalist display
##
## FORMAT: "DIST: X.Xkm | VEL: X.Xm/s | P:X° Y:X°"
##
## @return: Single-line status string
func get_compact_status() -> String:
	# Calculate derived values
	var dist = ship_position.length() / 1000.0
	var vel = ship_velocity.length()
	var bearing = get_bearing_angles()

	# Format with to_360_angle conversions
	return "DIST: %.1fkm | VEL: %.1fm/s | P:%.0f° Y:%.0f°" % [
		dist, vel, 
		to_360_angle(bearing.pitch),  # <-- CONVERSION HERE
		to_360_angle(bearing.yaw)     # <-- CONVERSION HERE
	]

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

## Resets ship to initial state (origin, no motion, no rotation)
## Called by Main.gd when RESET button pressed or R key pressed
##
## Resets ALL state variables to zero/identity:
##   - Position: (0, 0, 0)
##   - Velocity: (0, 0, 0)
##   - Acceleration: (0, 0, 0)
##   - Thrust display: 0.0
##   - Pitch angle: 0.0 (facing horizontally)
##   - Yaw angle: 0.0 (facing -Z direction)
func reset_ship() -> void:
	# Reset motion state
	ship_position = Vector3.ZERO
	ship_velocity = Vector3.ZERO
	ship_acceleration = Vector3.ZERO
	current_thrust_acceleration = 0.0
	
	# Reset orientation to identity (facing -Z, level flight)
	pitch_angle = 0.0
	yaw_angle = 0.0

## Gets distance from ship to origin
## Simple helper function for proximity checks
##
## @return: Distance in meters
func get_distance_to_origin() -> float:
	return ship_position.length()

## Checks if ship is within a certain radius of origin
## Useful for proximity alerts, docking, etc.
##
## @param radius: Radius to check in meters
## @return: True if ship is within radius, false otherwise
func is_within_radius(radius: float) -> bool:
	return ship_position.length() <= radius
