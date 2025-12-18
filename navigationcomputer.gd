## NavigationComputer.gd
## Handles all ship physics, positioning, and orientation for a retro space sim
## Extends Control to avoid Node3D variable conflicts
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

## Ship's orientation in 3D space using Godot's Basis system
## This tracks the ship's rotation without using transform
var ship_basis: Basis = Basis.IDENTITY

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

	# Get the ship's current forward direction from basis
	# In Godot, -Z is forward in local space
	var thrust_direction = -ship_basis.z

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
# ROTATION CONTROL
# ============================================================================

## Rotate the ship around its local axes
## @param pitch: Rotation around X axis (radians/sec) - nose up/down
## @param yaw: Rotation around Y axis (radians/sec) - nose left/right
## @param delta: Physics delta time
func rotate_ship(pitch: float, yaw: float, delta: float) -> void:
	# Clamp rotation rates to maximum
	pitch = clamp(pitch, -MAX_ROTATION_RATE, MAX_ROTATION_RATE)
	yaw = clamp(yaw, -MAX_ROTATION_RATE, MAX_ROTATION_RATE)

	# Apply rotations around local axes using the current basis
	# Order: pitch (X), then yaw (Y)
	if abs(pitch) > 0.001:
		ship_basis = ship_basis.rotated(ship_basis.x, pitch * delta)
	if abs(yaw) > 0.001:
		ship_basis = ship_basis.rotated(ship_basis.y, yaw * delta)

	# Orthonormalize to prevent floating point drift over time
	ship_basis = ship_basis.orthonormalized()

## Get the ship's current forward direction vector
func get_forward_vector() -> Vector3:
	return -ship_basis.z

## Get the ship's current right direction vector
func get_right_vector() -> Vector3:
	return ship_basis.x

## Get the ship's current up direction vector
func get_up_vector() -> Vector3:
	return ship_basis.y

# ============================================================================
# ANGLE CONVERSION UTILITIES
# ============================================================================

## Convert angle from -180/+180 range to 0-360 range
## @param angle: Angle in degrees (-180 to +180)
## @return: Equivalent angle in 0-360 degree range
func to_360_angle(angle: float) -> float:
	return fmod(angle + 360.0, 360.0)

# ============================================================================
# BEARING CALCULATIONS
# ============================================================================

## Get pitch and yaw angles from the ship's forward vector
## Returns angles in degrees for terminal display
func get_bearing_angles() -> Dictionary:
	var forward = get_forward_vector()
	
	# Calculate yaw (rotation around Y axis, horizontal angle)
	# atan2(z, x) gives angle in XZ plane from +X axis
	var yaw_rad = atan2(forward.z, forward.x)
	var yaw_deg = rad_to_deg(yaw_rad)
	
	# Calculate pitch (rotation around X axis, vertical angle)
	# asin(y) gives angle from XZ plane
	var pitch_rad = asin(clamp(forward.y, -1.0, 1.0))
	var pitch_deg = rad_to_deg(pitch_rad)
	
	return {
		"pitch": pitch_deg,  # -90 to +90 degrees (converted to 0-360° for display)
		"yaw": yaw_deg,      # -180 to +180 degrees (converted to 0-360° for display)
	}

# ============================================================================
# COORDINATE CONVERSIONS
# ============================================================================

## Convert ship's Cartesian position to spherical coordinates
## Useful for navigation displays relative to reference origin
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
# DATA FORMATTING FOR TERMINAL DISPLAY
# ============================================================================

## Format all navigation data as retro terminal text
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
func reset_ship() -> void:
	ship_position = Vector3.ZERO
	ship_velocity = Vector3.ZERO
	ship_acceleration = Vector3.ZERO
	current_thrust_acceleration = 0.0
	ship_basis = Basis.IDENTITY

## Get distance to reference origin
func get_distance_to_origin() -> float:
	return ship_position.length()

## Check if ship is within a certain radius of origin
func is_within_radius(radius: float) -> bool:
	return ship_position.length() <= radius
