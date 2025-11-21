# Multiplayer Implementation Guide

## Overview
Your game now has full multiplayer support using Godot's high-level multiplayer API with ENet. Players can host servers or join as clients, and all player movements, camera rotations, and object grabbing are synchronized across the network.

## How to Use

### Starting a Server
1. Run the game
2. In the menu, click **"Start Server"**
3. The game will load and you'll be able to play
4. Other players can now connect to your server

### Connecting as a Client
1. Run the game
2. In the menu, enter the server's IP address (default is "localhost" for testing on the same machine)
3. Click **"Connect as Client"**
4. Once connected, the game will load and you'll spawn alongside other players

### Testing Multiplayer Locally
To test multiplayer on the same computer:
1. Open two instances of the game
2. In the first instance, click "Start Server"
3. In the second instance, leave IP as "localhost" and click "Connect as Client"
4. Both players should now see each other!

## What's Synchronized

### Player Movement
- Position (X, Y, Z coordinates)
- Body rotation (looking left/right)
- Camera rotation (looking up/down)

### Object Interaction
- Grabbing objects
- Releasing objects
- Object positions are synchronized through Godot's physics

### Player Spawning
- New players automatically spawn when they join
- Disconnected players are automatically removed
- Multiple spawn points to prevent overlapping

## Network Architecture

### Files Modified/Created

#### `scripts/network_handler.gd`
- Singleton (autoload) that manages network connections
- Handles server creation and client connections
- Manages player spawning/despawning
- Tracks all connected players

#### `entities/player.gd`
- Updated to distinguish between local and remote players
- Only the local player receives input
- Position/rotation is synchronized via RPCs
- Remote players are rendered in a different color (blue tint)

#### `scenes/main.gd` (new)
- Manages the game scene
- Handles player spawning with predefined spawn points
- Connects to NetworkHandler signals

#### `scenes/menu.gd`
- Enhanced with connection status feedback
- IP address input for client connections
- Button state management during connection

#### `scenes/menu.tscn`
- Improved UI with proper layout
- IP address input field
- Status label for connection feedback

#### `scenes/main.tscn`
- Removed hardcoded player (now spawned dynamically)
- Added main.gd script for network management

## Key Features

### Authority System
- Each player has "multiplayer authority" over their own character
- Only the player with authority can control their character
- The server validates all actions

### RPC (Remote Procedure Call) Synchronization
- `sync_transform()` - Sends position/rotation to all other players
- `sync_grab()` - Notifies when an object is grabbed
- `sync_release()` - Notifies when an object is released
- `request_spawn()` - Requests player spawn from server
- `spawn_on_client()` - Tells clients to spawn a new player

### Spawn Management
- Server manages spawn points
- Up to 5 predefined spawn locations
- New players get assigned the next available spawn point

## Network Settings

### Port
Default: `42069`
- Configured in `network_handler.gd`
- Make sure this port is open if hosting over the internet

### IP Address
Default: `localhost`
- Can be changed in the menu UI
- For LAN play, use the server's local IP (e.g., 192.168.1.x)
- For internet play, use the server's public IP (requires port forwarding)

## Controls
- **WASD** - Move
- **Mouse** - Look around
- **Shift** - Sprint
- **Space** - Jump
- **Left Click** - Grab objects
- **ESC** - Release mouse cursor

## Troubleshooting

### "Connection Failed" Error
- Check that the server is running
- Verify the IP address is correct
- Ensure the port (42069) isn't blocked by a firewall
- For internet play, confirm port forwarding is set up

### Players Not Seeing Each Other
- Check the console for error messages
- Verify both players are in the same scene
- Restart both server and client

### Laggy/Jerky Movement
- The interpolation value (0.3) in `sync_transform()` can be adjusted
- Lower values = more responsive but jerkier
- Higher values = smoother but more delayed

## Future Enhancements (Optional)

### Suggestions for expansion:
1. **Server Browser** - List available servers instead of manual IP entry
2. **Player Names** - Add player name input and display
3. **Chat System** - Text communication between players
4. **Server Settings** - Max players, game mode selection
5. **Dedicated Server** - Headless server mode
6. **Interpolation Buffer** - More sophisticated movement prediction
7. **Object Ownership** - Lock objects when grabbed to prevent conflicts
8. **State Synchronization** - Sync all world objects, not just players

## Network Architecture Notes

### Why This Approach?
- **Simple & Robust**: Uses Godot's built-in high-level multiplayer
- **Low Latency**: Direct RPC calls minimize delay
- **Scalable**: Can handle multiple players with minimal changes
- **Easy to Extend**: Adding new synchronized properties is straightforward

### Data Flow
```
Client Input → Local Player Movement → RPC to All Clients → Remote Players Update
```

### Authority Flow
```
Server: Manages game state, spawns players, validates actions
Clients: Send input, render game state, trust server
```

## Technical Details

### RPC Modes Used
- `"any_peer"` - Any connected peer can call this
- `"call_remote"` - Only runs on remote peers (not the caller)
- `"unreliable"` - Position updates don't need guaranteed delivery (faster)
- `"reliable"` - Important events like spawning use reliable delivery

### Network Optimization
- Position updates use unreliable RPCs (sent every frame but okay if dropped)
- Position interpolation smooths out network jitter
- Only changed data is sent (no redundant updates)

---

**Enjoy your multiplayer game!** 🎮

