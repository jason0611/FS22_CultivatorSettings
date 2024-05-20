--
-- CultivatorSettings for LS 22
--
-- Glowins Modschmiede
 
CultivatorSettings = {}

if CultivatorSettings.MOD_NAME == nil then CultivatorSettings.MOD_NAME = g_currentModName end
CultivatorSettings.MODSETTINGSDIR = g_currentModSettingsDirectory

source(g_currentModDirectory.."tools/gmsDebug.lua")
GMSDebug:init(CultivatorSettings.MOD_NAME, false)
GMSDebug:enableConsoleCommands("csDebug")

CultivatorSettings.showKeys = true

-- Standards / Basics
function CultivatorSettings.prerequisitesPresent(specializations)
	return true
end

-- set configuration 

function CultivatorSettings.getConfigurationsFromXML(xmlFile, superfunc, baseXMLName, baseDir, customEnvironment, isMod, storeItem)
    local configurations, defaultConfigurationIds = superfunc(xmlFile, baseXMLName, baseDir, customEnvironment, isMod, storeItem)
	dbgprint("addHLMconfig : Kat: "..storeItem.categoryName.." / ".."Name: "..storeItem.xmlFilename, 2)

	local category = storeItem.categoryName
	local vehicleType = string.lower(xmlFile:getValue("vehicle#type") or "")
	-- register only for cultivators and leave mods alone: Modders should know which kind of device they create... ;-)
	if not isMod and configurations ~= nil and category == "CULTIVATORS" then
		configurations["CultivatorSettings"] = {
        	{name = g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("text_DC_normal"), index = 1, isDefault = true,  isSelectable = true, price = 0, dailyUpkeep = 0, desc = g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("text_DC_normal")},
        	{name = g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("text_DC_shallow"), index = 2, isDefault = false, isSelectable = true, price = 0, dailyUpkeep = 0, desc = g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("text_DC_shallow")},
        	{name = g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("text_DC_deep"), index = 3, isDefault = false, isSelectable = true, price = 0, dailyUpkeep = 0, desc = g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("text_DC_deep")},
        	{name = g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("text_DC_ISOBUS"), index = 4, isDefault = false, isSelectable = true, price = 2500, dailyUpkeep = 0, desc = g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("text_DC_ISOBUS")}
    	}
    	dbgprint("addCconfig : Configuration CultivatorSettings added", 2)
    	dbgprint_r(configurations["CultivatorSettings"], 4)
	end
	
    return configurations, defaultConfigurationIds
end

function CultivatorSettings.initSpecialization()
	dbgprint("initSpecialization : start", 2)
	
    local schemaSavegame = Vehicle.xmlSchemaSavegame
	local key = CultivatorSettings.MOD_NAME..".CultivatorSettings"
	schemaSavegame:register(XMLValueType.INT, "vehicles.vehicle(?)."..key.."#config", "Cultivator configuration", 1)
	schemaSavegame:register(XMLValueType.INT, "vehicles.vehicle(?)."..key.."#mode", "Cultivator setting", 1)
	dbgprint("initSpecialization: finished xmlSchemaSavegame registration process", 2)
	
	if g_configurationManager.configurations["CultivatorSettings"] == nil then
		g_configurationManager:addConfigurationType("CultivatorSettings", g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("text_DC_configuration"), nil, nil, nil, nil, ConfigurationUtil.SELECTOR_MULTIOPTION)
	end
	
	StoreItemUtil.getConfigurationsFromXML = Utils.overwrittenFunction(StoreItemUtil.getConfigurationsFromXML, CultivatorSettings.getConfigurationsFromXML)
	dbgprint("initSpecialization : Configuration initialized", 1)
end

function CultivatorSettings.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CultivatorSettings)
	SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", CultivatorSettings)
	SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", CultivatorSettings)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CultivatorSettings)
	SpecializationUtil.registerEventListener(vehicleType, "registerOverwrittenFunctions", CultivatorSettings)
 	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", CultivatorSettings)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", CultivatorSettings)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", CultivatorSettings)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", CultivatorSettings)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", CultivatorSettings)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", CultivatorSettings)
end

function CultivatorSettings.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getPowerMultiplier", CultivatorSettings.getPowerMultiplier)
end

function CultivatorSettings:onLoad(savegame)
	dbgprint("onLoad", 2)

	CultivatorSettings.isDedi = g_server ~= nil and g_currentMission.connectedToDedicatedServer
	
	-- Make Specialization easier accessible
	self.spec_DeepCultivator = self["spec_"..CultivatorSettings.MOD_NAME..".CultivatorSettings"]
	
	local spec = self.spec_DeepCultivator
	spec.dirtyFlag = self:getNextDirtyFlag()
	
	spec.mode = 1
	spec.lastMode = 0
	spec.config = 0	
end

function CultivatorSettings:onPostLoad(savegame)
	dbgprint("onPostLoad: "..self:getFullName(), 2)
	local spec = self.spec_DeepCultivator
	
	-- Get DC configuration
	spec.config = self.configurations["CultivatorSettings"] or 0
	dbgprint("onPostLoad: spec.config = "..tostring(spec.config), 2)
	
	if savegame ~= nil then	
		dbgprint("onPostLoad : loading saved data", 2)
		local xmlFile = savegame.xmlFile
		local key = savegame.key .."."..CultivatorSettings.MOD_NAME..".CultivatorSettings"
		
		spec.config = xmlFile:getValue(key.."#config", spec.config)
		if spec.config == 4 then
			spec.mode = xmlFile:getValue(key.."#mode", spec.mode)
		end
		dbgprint("onPostLoad : Loaded data for "..self:getName(), 1)
	end
	
	-- Set DC configuration if set by savegame
	if spec.config > 0 then 
		self.configurations["CultivatorSettings"] = spec.config
		if spec.config < 4 then
			spec.mode = spec.config
		end
	end 
	
	dbgprint("onPostLoad : Cultivator config: "..tostring(spec.config), 1)
	dbgprint("onPostLoad : Mode setting: "..tostring(spec.mode), 1)
	dbgprint_r(self.configurations, 4, 2)
end

function CultivatorSettings:saveToXMLFile(xmlFile, key, usedModNames)
	dbgprint("saveToXMLFile", 2)
	local spec = self.spec_DeepCultivator
	spec.config = self.configurations["CultivatorSettings"] or 0
	if spec.config > 0 then
		xmlFile:setValue(key.."#config", spec.config)
		if spec.config == 4 then
			dbgprint("saveToXMLFile : key: "..tostring(key), 2)
			xmlFile:setValue(key.."#mode", spec.mode)
		end
		dbgprint("saveToXMLFile : saving data finished", 2)
	end
end

function CultivatorSettings:onReadStream(streamId, connection)
	dbgprint("onReadStream", 3)
	local spec = self.spec_DeepCultivator
	spec.config = streamReadInt8(streamId, connection)
	spec.mode = streamReadInt8(streamId, connection)
end

function CultivatorSettings:onWriteStream(streamId, connection)
	dbgprint("onWriteStream", 3)
	local spec = self.spec_DeepCultivator
	streamWriteInt8(streamId, spec.config)
	streamWriteInt8(streamId, spec.mode)
end
	
function CultivatorSettings:onReadUpdateStream(streamId, timestamp, connection)
	if not connection:getIsServer() then
		local spec = self.spec_DeepCultivator
		if streamReadBool(streamId) then
			dbgprint("onReadUpdateStream: receiving data...", 4)
			spec.config = streamReadInt8(streamId)
			spec.mode = streamReadInt8(streamId)
		end
	end
end

function CultivatorSettings:onWriteUpdateStream(streamId, connection, dirtyMask)
	if connection:getIsServer() then
		local spec = self.spec_DeepCultivator
		if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
			dbgprint("onWriteUpdateStream: sending data...", 4)
			streamWriteInt8(streamId, spec.config)
			streamWriteInt8(streamId, spec.mode)
		end
	end
end

-- inputBindings / inputActions
	
function CultivatorSettings:onRegisterActionEvents(isActiveForInput)
	dbgprint("onRegisterActionEvents", 4)
	if self.isClient then
		local spec = self.spec_DeepCultivator
		CultivatorSettings.actionEvents = {} 
		if self:getIsActiveForInput(true) and spec ~= nil and spec.config == 4 then 
			local prio = GS_PRIO_LOW
			_, spec.actionEventMainSwitch = self:addActionEvent(CultivatorSettings.actionEvents, 'TOGGLEDM', self, CultivatorSettings.TOGGLE, false, true, false, true, nil)
			g_inputBinding:setActionEventTextPriority(spec.actionEventMainSwitch, prio)
		end		
	end
end

function CultivatorSettings:TOGGLE(actionName, keyStatus, arg3, arg4, arg5)
	dbgprint("TOGGLE", 4)
	local spec = self.spec_DeepCultivator
	dbgprint_r(spec, 4)
	
	spec.mode = spec.mode + 1
	if spec.mode > 3 then spec.mode = 1 end
	
	if spec.mode == 1 then
		g_currentMission:addGameNotification(g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("deepModeHeader"), g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("normalMode"), "", 2500)
		g_inputBinding:setActionEventText(spec.actionEventMainSwitch, g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("action_switchToShallow"))
	elseif spec.mode == 2 then
		g_currentMission:addGameNotification(g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("deepModeHeader"), g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("shallowMode"), "", 2500)
		g_inputBinding:setActionEventText(spec.actionEventMainSwitch, g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("action_switchToDeepMode"))
	elseif spec.mode == 3 then
		g_currentMission:addGameNotification(g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("deepModeHeader"), g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("deepMode"), "", 2500)
		g_inputBinding:setActionEventText(spec.actionEventMainSwitch, g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("action_switchToNormalMode"))
	end
	self:raiseDirtyFlags(spec.dirtyFlag)
	dbgprint("TOGGLE : Cultivator config: "..tostring(spec.config), 1)
	dbgprint("TOGGLE : Mode setting: "..tostring(spec.mode), 1)
end

function CultivatorSettings:getPowerMultiplier(superfunc)
	local spec = self.spec_DeepCultivator
	local multiplier = 1
	if spec.mode == 2 then multiplier = 0.5 end
	if spec.mode == 3 then multiplier = 1.8 end
	return superfunc(self) * multiplier
end

-- change setting

function CultivatorSettings:onUpdate(dt)
	local spec = self.spec_DeepCultivator
	local specCV = self.spec_cultivator
	
	if spec ~= nil and specCV ~= nil and spec.mode ~= spec.lastMode then
		if spec.mode == 1 then
			specCV.useDeepMode = true
			specCV.isSubsoiler = false
		elseif spec.mode == 2 then
			specCV.useDeepMode = false
			specCV.isSubsoiler = false
		elseif spec.mode == 3 then
			specCV.useDeepMode = true
			specCV.isSubsoiler = true
		end
		spec.lastMode = spec.mode
	end
end

function CultivatorSettings:onDraw(dt)
	local spec = self.spec_DeepCultivator
	if spec ~= nil then 
		if spec.mode == 2 then
			g_currentMission:addExtraPrintText(g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("shallowModeShort"))
		elseif spec.mode == 3 then
			g_currentMission:addExtraPrintText(g_i18n.modEnvironments[CultivatorSettings.MOD_NAME]:getText("deepModeShort"))
		end
	end
end
