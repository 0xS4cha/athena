return {
    id = "city",
    label = "City",
    badge = "City",
    scale = 0.95,
    color = { 0.95, 0.85, 0.25 },
    outline = { 0, 0, 0, 0 },
    influenceThreshold = 1,
    expansionCountMax = 3,
	think = function(building, dt)
        if not building.state.expansionCount then building.state.expansionCount = 0 end
        if building.state.expansionCount >= building.definition.expansionCountMax then return end

        local threshold = building.definition.influenceThreshold or 1
		building.state.influence = math.min(threshold, (building.state.influence or 0) + dt * 0.03)

		if building.state.influence >= threshold then
			building._shouldExpansion = true
            building.state.influence = 0
		end
	end
}