extends StaticBody2D
## Bobbing obstacle: oscillates vertically between sitting on the ground and
## floating amplitude px above it.
## - Bottom of cycle: box sits on GROUND_Y → player must jump over it.
## - Top of cycle:    box rises ~75 px → player can slide under the gap.

var _amplitude : float = 70.0   # px above base (must exceed player slide height ~40)
var _freq      : float = 0.70   # Hz — oscillations per second
var _phase     : float = 0.0
var _base_y    : float = 0.0    # set in _ready() from spawn position

## Call before adding to the scene to configure motion.
func init(amp: float, freq: float) -> void:
    _amplitude = amp
    _freq      = freq
    _phase     = randf() * TAU  # random phase so obstacles aren't in sync

func _ready() -> void:
    _base_y = position.y

func _process(delta: float) -> void:
    _phase += _freq * TAU * delta
    # Smooth cosine: t goes 0→1→0; obstacle goes base_y → base_y-amplitude → base_y
    var t : float = (1.0 - cos(_phase)) * 0.5
    position.y = _base_y - t * _amplitude
