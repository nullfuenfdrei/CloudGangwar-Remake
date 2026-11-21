-- =======================================================================
--  Client: Admin-Menü (F6 oder /admin) – nur für Spieler mit Admin-Recht.
--  Jede Aktion prüft der Server noch einmal selbst.
-- =======================================================================

AdminUI = { allowed = false, wanted = false }

local function nui(data) SendNUIMessage(data) end

RegisterNetEvent('bspvp:admin:flag', function(on)
    AdminUI.allowed = on == true
    nui({ type = 'adminFlag', allowed = AdminUI.allowed })
end)

-- Der Server prüft das Recht bei jedem Öffnen neu (und sagt Bescheid, wenn es fehlt)
local function toggle()
    if UI.screen == 'admin' then
        UI.close('admin')
    elseif UI.screen == nil then
        AdminUI.wanted = true
        TriggerServerEvent('bspvp:admin:open')
    end
end
RegisterCommand('gwadmin', toggle, false)
RegisterCommand('admin', toggle, false)
RegisterKeyMapping('gwadmin', 'Admin-Menü (nur Admins)', 'keyboard', Config.Keys.admin or 'F6')

RegisterNetEvent('bspvp:admin:data', function(data)
    if type(data) ~= 'table' then return end
    AdminUI.allowed = true
    if UI.screen == 'admin' then
        nui({ type = 'admin', data = data })
    elseif AdminUI.wanted and UI.screen == nil then
        UI.openScreen('admin', { type = 'admin', data = data, open = true })
    end
    AdminUI.wanted = false
end)

RegisterNUICallback('adminAction', function(data, cb)
    if AdminUI.allowed and data and type(data.action) == 'string' then
        TriggerServerEvent('bspvp:admin:action', data.action, type(data.args) == 'table' and data.args or {})
    end
    cb({})
end)

RegisterNUICallback('adminRefresh', function(_, cb)
    if AdminUI.allowed and UI.screen == 'admin' then TriggerServerEvent('bspvp:admin:open') end
    cb({})
end)
