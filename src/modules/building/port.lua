return {
    id = "port",
    label = "Port",
    badge = "Port",
    scale = 0.74,
    color = { 0.3, 0.7, 0.95 },
    outline = { 0, 0, 0, 0 },
    think = function(building, dt)
        building.state.trade = (building.state.trade or 0) + (dt * 0.05)
    end
}