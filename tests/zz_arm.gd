extends SceneTree
const Bot = preload("res://tests/salvage_bot.gd")
var g
var bot
var f := 0
func _initialize():
	var o := Market.offer_for(5, {"rep": 30, "done": 5}, 2)
	o.traps = ["hidden_damage"]
	o.variant = 974343178
	o.kit = {"arm": 1}
	Game.contract = o
	g = load("res://scenes/main.tscn").instantiate()
	g.bot = {"skip_intro": true, "skip_contract": true, "aim": Vector2.ZERO, "lmb": false, "move": Vector2.ZERO}
	root.add_child(g)
	bot = Bot.new(g, {"paced": true})
	bot.timeout = 60000
func _process(_d):
	f += 1
	if f % 600 == 0:
		print("t=", int(g.sys.time), " arm ", g.arm.state, " carried ", g.arm.carried, " bodies ", g.world.bodies.size(), " busy ", snappedf(bot.busy,0.1), " phase ", bot.phase, " order ", bot.order.size())
	if bot.step():
		print(bot.summary())
		return true
	return false
