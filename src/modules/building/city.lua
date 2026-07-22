return {
    id = "city",
    label = "City",
    badge = "City",
    scale = 0.95,
    color = { 0.95, 0.85, 0.25 },
    outline = { 0.25, 0.2, 0.05, 0.75 },
    influenceThreshold = 100,
	think = function(building, dt)
		building.state.influence = math.min(1, (building.state.influence or 0) + dt * 0.03)
        local threshold = building.definition.influenceThreshold or 100
		if building.state.influence + 1 % threshold >= threshold then
			do end
		end
	end
}