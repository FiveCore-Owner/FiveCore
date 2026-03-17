-- Loading Screen — Client Script
-- Receives step events from core and forwards them to the loadscreen NUI.
-- Shuts down the loading screen when the character list is ready (step 3),
-- so the character creator NUI becomes visible.

RegisterNetEvent("loading:updateStep")
AddEventHandler("loading:updateStep", function(data)
    local step = type(data) == "table" and data.step or tonumber(data) or 1
    SendNUIMessage({ type = "updateStep", step = step })

    if step >= 3 then
        CreateThread(function()
            Wait(600)
            ShutdownLoadingScreen()
        end)
    end
end)

RegisterNetEvent("fivecore:setLanguage")
AddEventHandler("fivecore:setLanguage", function(lang)
    local locale = Locales and (Locales[lang] or Locales['en']) or nil
    SendNUIMessage({ type = "setLang", lang = lang, locale = locale })
end)
