extends fade_rule

class_name range_fade

@export var val_min := 0.0 ## The lowest value to consider in volume calculation. Volume will be muted at this value (or full volume if inverted).
@export var val_max := 100.0 ## The highest value to consider in volume calculation. Volume will be full at this value (or muted if inverted).
@export var invert := false ## Whether to lower the volume as the parameter approaches val_max, rather than val_min.
