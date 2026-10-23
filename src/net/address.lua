local Address = {}

function Address.lan()
    local ok, socket = pcall(require, "socket")
    if not ok then return nil end
    local probe = (socket.udp4 or socket.udp)()
    if not probe then return nil end
    local connected = pcall(probe.setpeername, probe, "192.0.2.1", 9)
    local address = connected and probe:getsockname() or nil
    probe:close()
    if not address or address == "0.0.0.0" then return nil end
    return address
end

return Address
