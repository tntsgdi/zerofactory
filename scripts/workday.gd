extends Node
# A job of several working days (ARK-01 "Voyager", design/ships/ARK-01_远航者_设计稿.md
# 6.2: "end the day, save every bit of the physical state, carry on the next day;
# the contract pays its running cost by the day"). A ship file's "workday":
#   {"len": s of play a working day, "fee": what each further day costs, "days": the
#    days the job is planned for}
# The day is worked out from the contract's play time. When one ends the next day's
# running cost is booked on the contract's fee, everything is saved, and a card
# says so; the work goes on where it stood. A saved game knows its day (the fee for
# days already begun is in the saved fee, not charged again).

var game
var cfg := {}
var day := 1
var card_t := -1.0


func setup(g, ship: Dictionary) -> void:
	game = g
	cfg = ship.get("workday", {})


func active() -> bool:
	return not cfg.is_empty()


func save_state() -> Dictionary:
	return {"day": day}


func load_state(d: Dictionary) -> void:
	day = maxi(1, int(d.get("day", _day_now())))
	# the contract's fee comes back from the job as signed: the days begun are added again
	game.fee += float(cfg.get("fee", 0.0)) * (day - 1)


func day_len() -> float:
	return float(cfg.get("len", 2700.0))


func _day_now() -> int:
	return 1 + int(floor(game.playtime / day_len()))


# play time left in today (s)
func left_today() -> float:
	return day * day_len() - game.playtime


func planned() -> int:
	return int(cfg.get("days", 10))


func _process(dt: float) -> void:
	if not active() or game == null:
		return
	if card_t >= 0.0:
		card_t += dt
		if card_t > 4.0:
			card_t = -1.0
	if game.state != "play":
		return
	while _day_now() > day:
		_end_day()


func _end_day() -> void:
	day += 1
	game.fee += float(cfg.get("fee", 0.0))
	game.log_op("workday")
	card_t = 0.0
	if not game.in_berth() and (not game.testing or SaveGame.allow_test):
		SaveGame.save(game)
		game.hud.toast_saved()
	game.say("day_over", game.drone.global_position + Vector2(0, -80), str(day - 1))
	game.sfx.play("stamp")
