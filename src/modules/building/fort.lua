return {
	id = "fort",
	label = "Fort",
	badge = "Fort",
	scale = 0.8,
	color = { 0.85, 0.45, 0.2 },
	outline = { 0.3, 0.12, 0.05, 0.8 },
	think = function(building, dt)
		building.state.defense = math.min(1, (building.state.defense or 0) + dt * 0.02)
	end
}
