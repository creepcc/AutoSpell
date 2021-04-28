require("common.log")
module("AutoSpell Utility by creep", package.seeall, log.setup)
clean.module("AutoSpell Utility by creep", clean.seeall, log.setup)

local _SDK = _G.CoreEx
local ObjManager, EventManager, Input, Renderer, Enums, Game = _SDK.ObjectManager, _SDK.EventManager, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates 
local Orbwalker = _G.Libs.Orbwalker

local Spell, HealthPred = _G.Libs.Spell, _G.Libs.HealthPred
local Menu = _G.Libs.NewMenu
local min = math.min

local Ignite;
local Cleanse;
local Heal;
local Barrier;

local AutoSpell = {}
AutoSpell.IgniteRange  = 650
AutoSpell.IgniteDamage = {70, 90, 110, 130, 150, 170, 190, 210, 230, 250, 270, 290, 310, 330, 350, 370, 390, 410}

AutoSpell.HealRange  = 850
AutoSpell.HealDamage = {90, 105, 120, 135, 150, 165, 180, 195, 210, 225, 240, 255, 270, 285, 300, 315, 330, 345}

AutoSpell.BarrierDamage = {115, 135, 155, 175, 195, 215, 235, 255, 275, 295, 315, 335, 350, 375, 395, 415, 435, 455}

function AutoSpell.GetIgniteDamage() return AutoSpell.IgniteDamage[min(18, Player.Level)] end
function AutoSpell.GetHealDamage() return AutoSpell.HealDamage[min(18, Player.Level)] end
function AutoSpell.GetBarrierDamage() return AutoSpell.BarrierDamage[min(18, Player.Level)] end

function AutoSpell.IsEnabled()
    return Menu.Get("TOGGLE")
end

local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

local function CountHeroes(pos,Range,type)
    local num = 0
    for k, v in pairs(ObjManager.Get(type, "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(pos.Position) < Range then
            num = num + 1
        end
    end
    return num
end

function AutoSpell.GetIgniteSlot()
    for i=SpellSlots.Summoner1, SpellSlots.Summoner2 do
        if Player:GetSpell(i).Name == "SummonerDot" then
            return i
        end
    end
    return SpellSlots.Unknown
end
function AutoSpell.GetHealSlot()
    for i=SpellSlots.Summoner1, SpellSlots.Summoner2 do
        if Player:GetSpell(i).Name == "SummonerHeal" then
            return i
        end
    end
    return SpellSlots.Unknown
end
function AutoSpell.GetBarrierSlot()
    for i=SpellSlots.Summoner1, SpellSlots.Summoner2 do
        if Player:GetSpell(i).Name == "SummonerBarrier" then
            return i
        end
    end
    return SpellSlots.Unknown
end
function AutoSpell.GetCleanseSlot()
    for i=SpellSlots.Summoner1, SpellSlots.Summoner2 do
        if Player:GetSpell(i).Name == "SummonerBoost" then
            return i
        end
    end
    return SpellSlots.Unknown
end

function AutoSpell.OnHeroImmobilized(obj,buffInst)
    if obj.IsMe and Cleanse:IsReady() then
        Input.Cast(AutoSpell.GetCleanseSlot())
    end
end

function AutoSpell.OnNormalPriority()
        if AutoSpell.IsEnabled() and Menu.Get("AUTOIGNITE") and Ignite:IsReady() then
            local damage = AutoSpell.GetIgniteDamage()
            for k, v in pairs(ObjManager.Get("enemy","heroes")) do
                local hero = v.AsHero
                if (hero:Distance(Player.Position) <= Ignite.Range) and hero.IsTargetable and (hero.Health < AutoSpell.GetIgniteDamage()) and Menu.Get("IGNITETARGET" .. hero.CharName) then
                        return Ignite:Cast(v)
                end
            end
        end
    if AutoSpell.IsEnabled() and Menu.Get("HEALSELF") and Heal:IsReady() then
        local hero = Player.AsHero
        local delay =  0.10 + Game.GetLatency()/1000
        local predDmg = HealthPred.GetDamagePrediction(hero, delay, false)
        local predHealth = (hero.Health - predDmg) / hero.MaxHealth
        local minHealth = Menu.Get("MINHEALTHSELF") / 100
        if predHealth < minHealth and (predDmg > 0 or CountHeroes(hero,800,"enemy") > 0) then
            return Heal:Cast(hero)
        end
    end
    if AutoSpell.IsEnabled() and Menu.Get("HEALALLIES") and Heal:IsReady() then
        for k, v in pairs(ObjManager.Get("ally","heroes")) do
            local hero = v.AsHero
            if (hero:Distance(Player.Position) <= Heal.Range) and hero.IsTargetable and Menu.Get("HEALTARGET" .. hero.CharName) then
                local delay =  0.10 + Game.GetLatency()/1000
                local predDmg = HealthPred.GetDamagePrediction(hero, delay, false)
                local predHealth = (hero.Health - predDmg) / hero.MaxHealth
                local minHealth = Menu.Get("MINHEALTHALLIES") / 100
                if predHealth < minHealth and (predDmg > 0 or CountHeroes(hero,1000,"enemy") > 0) then
                    return Heal:Cast(hero)
                end
            end
        end
    end
    if AutoSpell.IsEnabled() and Menu.Get("AUTOBARRIER") and Barrier:IsReady() then
        local hero = Player.AsHero
        local delay =  0.10 + Game.GetLatency()/1000
        local predDmg = HealthPred.GetDamagePrediction(hero, delay, false)
        local predHealth = (hero.Health - predDmg) / hero.MaxHealth
        local minHealth = Menu.Get("MINBARRIERSELF") / 100
        if predHealth < minHealth and (predDmg > 0 or CountHeroes(hero,600,"enemy") > 0) then
            return Input.Cast(AutoSpell.GetBarrierSlot())
        end
    end
    if not GameIsAvailable() then
        return
    end
end



function AutoSpell.LoadMenu()
    Menu.RegisterMenu("Load", "AutoSpell ", function()
        Menu.ColumnLayout("cols", "cols", 3, true, function()
            Menu.Checkbox("TOGGLE",   "Enabled", true)
            Menu.Checkbox("AUTOIGNITE",   "Auto Ignite ", true)
            Menu.Checkbox("AUTOCLEANSE",   "Auto Cleanse on CC'd ", true)
            Menu.Checkbox("AUTOBARRIER",   "Auto Barrier", true)
            Menu.Slider("MINBARRIERSELF", "Min % Barrier for Self", 20, 0, 100, 5)
            Menu.Checkbox("HEALSELF",   "Auto Heal", true)
            Menu.Slider("MINHEALTHSELF", "Min % Health for Self", 20, 0, 100, 5)
            Menu.Checkbox("HEALALLIES",   "Auto Heal Allies", true)
            Menu.Slider("MINHEALTHALLIES", "Min % Health for Allies", 20, 0, 100, 5)
            Menu.NextColumn()
            Menu.NewTree("HealList","Heal Whitelist", function()
                Menu.ColoredText("Heal Whitelist", 0xFFD700FF, true)
                for k, v in pairs(ObjManager.Get("ally", "heroes")) do
                    local Name = v.AsHero.CharName
                    Menu.Checkbox("HEALTARGET" .. Name, "Use on " .. Name, true)
                end
            end)
            Menu.NextColumn()
            Menu.NewTree("IgniteList","Ignite Whitelist", function()
                for k, v in pairs(ObjManager.Get("enemy", "heroes")) do
                    local Name = v.AsHero.CharName
                    Menu.Checkbox("IGNITETARGET" .. Name, "Use on " .. Name, true)
                end
            end)
        end)
    end)     
end

-- LOAD
function OnLoad()
    Heal = Spell.Targeted({Slot = AutoSpell.GetHealSlot(), Range = AutoSpell.HealRange})
    Ignite = Spell.Targeted({Slot = AutoSpell.GetIgniteSlot(), Range = AutoSpell.IgniteRange})
    Barrier = Spell.Active({Slot = AutoSpell.GetBarrierSlot()})
    Cleanse = Spell.Active({Slot = AutoSpell.GetCleanseSlot()})

        AutoSpell.LoadMenu()
        EventManager.RegisterCallback(Enums.Events.OnNormalPriority, AutoSpell.OnNormalPriority)
        EventManager.RegisterCallback(Enums.Events.OnHeroImmobilized, AutoSpell.OnHeroImmobilized)
     

    return true
end
