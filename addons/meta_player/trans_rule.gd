extends Resource

class_name transition_rule

@export var target_player : NodePath = "" ## The meta_player to transition to.
@export_enum("At End", "On Beat", "On Bar") var transition_type : String = "On Beat" ## When to transition. `On_Beat` will transition the beat after being triggered, and `On_Bar` will transition at the end of the current bar upon being triggered. `At_End` will transition at the end of the song.
@export var signal_node : NodePath = "" ## The node containing the signal to be used to trigger the transition.
@export var signal_name : String = "transition" ## The name of the signal that will trigger the transition.
