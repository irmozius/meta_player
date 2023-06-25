# Godot Meta Player
### Adaptive music plugin for Godot 4.0

## Setup

Use the `Playback` properties to determine whether this player will loop, and whether it should play automatically on `_ready`. 

>IMPORTANT - MAKE SURE THE AUDIO FILE LOADED IS IMPORTED WITH THE 'LOOP' FLAG DISABLED. META_PLAYER DUPLICATES AUDIO FILES TO LOOP, SO THIS WILL CAUSE UNWANTED DESYNCHRONISATION.

Set the exact BPM, time signature and length in the `Music` properties, or looping and beat/bar signals will not work correctly. Don't count reverb/decay tails in this, to allow smooth looping.

Enable volume automation in `Automation` to raise/lower volume of the MetaPlayer based on the value of a chosen parameter. Set the target node in `Target`, and the property name to monitor in `Target Param`. `Val Min` and `Val Max` should be set with the minimum and maximum range of values to react to, and `Param Smooth` lerps the input value. The seek up and down weights control the speed of volume modulation upwards and downwards. Toggle `Invert` on if the volume should rise in response to the parameter decreasing, rather than increasing.

Enable randomisation to leave the playing of this player to chance. `Chance` is the probability of playing, as a percentage.

Create a `play_group` by adding other MetaPlayers as children of a single MetaPlayer. This will cause the children to play in sync with their parent. Be sure to only group tracks of the same bar length, though actual file lengths can of course vary to allow decay.
