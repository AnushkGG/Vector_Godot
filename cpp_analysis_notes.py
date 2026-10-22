"""
This script reads the C++ source code logic and generates vastly improved 
Godot project assets and scripts that faithfully recreate it.

The C++ code's key design decisions to port:
1. Procedural city: background buildings at BACKGROUND_SPACING=185, foreground platforms at PLATFORM_SPACING=245
2. Rooftop heights from a fixed 16-entry pattern array (no random gaps!)
3. 3 obstacle types: OB_TANK (water tower, h=58), OB_CRATE (h=30), OB_FENCE (h=20, wide)
4. Runner: IK-based stickman skeleton with muscle segments
5. Chaser: SAME physics as player but 350px behind, uses obstacle jumpDist to pre-jump
6. Physics: GRAVITY=0.65, JUMP_POWER=-10.5, RUN_SPEED=4.4px/frame, FOOT_OFFSET=40
7. Camera: cameraX smoothly follows player (player is always at ~220px screen X)
8. Death = chaser catches runner (distance < 50px)

We translate this into Godot 4 scripts that match these exact constants.
"""
