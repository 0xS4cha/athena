return {
	id = "village",
	label = "Village",
	badge = "Village",
	scale = 0.68,
	color = { 0.55, 0.8, 0.45 },
	outline = { 0.12, 0.28, 0.12, 0.8 },
	populationThreshold = 100,
	think = function(building, dt)
		building.state.population = (building.state.population or 0) + (dt * 0.08)
		
		if building.state.population >= (building.definition.populationThreshold or 100) then
			building._shouldTransform = true
		end
	end
}
