local GM = require("src.core.index")

return {
	id = "village",
	label = "Village",
	badge = "Village",
	scale = 0.68,
	color = { 0.55, 0.8, 0.45 },
	outline = { 0, 0, 0, 0 },
	populationThreshold = 10,
	--- @param building table
	--- @param dt number
	--- @return void
	think = function(building, dt)
		local diplomacy = GM.Hud and GM.Hud.Instance and GM.Hud.Instance.powerAllocation.diplomacy or 33
		local multiplier = 0.5 + 2.5 * (diplomacy / 100)
		building.state.population = (building.state.population or 0) + (dt * 0.08 * multiplier)
		if building.state.population >= (building.definition.populationThreshold or 10) then
			building._shouldTransform = true
		end
	end
}
