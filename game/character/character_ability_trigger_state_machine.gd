extends Object
class_name CharacterAbilityTriggerStateMachine

const MINIMUM_TICK_INTERVAL_BETWEEN_TRIGGERS: int = 30
const TRIGGERED := true
const NOT_TRIGGERED := false

static func compute_trigger_result(
	trigger_state: CharacterAbilityTriggerState,
	player_input: InputState) -> CharacterAbilityTriggerResult:
	if player_input.is_slow_walking() and trigger_state.ticks_until_can_trigger() == 0:
		var next_trigger_state := CharacterAbilityTriggerState.new(
			MINIMUM_TICK_INTERVAL_BETWEEN_TRIGGERS)
		return CharacterAbilityTriggerResult.new(TRIGGERED, next_trigger_state)
	else:
		var next_trigger_state := CharacterAbilityTriggerState.new(max(0, trigger_state.ticks_until_can_trigger() - 1))
		return CharacterAbilityTriggerResult.new(NOT_TRIGGERED, next_trigger_state)
