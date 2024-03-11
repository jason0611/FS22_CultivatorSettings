--
-- Register DeepCultivator for LS 22
--
-- Glowins Modschmiede 
--

local specName = g_currentModName..".DeepCultivator"

if g_specializationManager:getSpecializationByName("DeepCultivator") == nil then
  	g_specializationManager:addSpecialization("DeepCultivator", "DeepCultivator", g_currentModDirectory.."deepCultivator.lua", nil)
  	dbgprint("Specialization 'DeepCultivator' added", 2)
end

for typeName, typeEntry in pairs(g_vehicleTypeManager.types) do
    if
    		SpecializationUtil.hasSpecialization(Cultivator, typeEntry.specializations) 
    then
     	g_vehicleTypeManager:addSpecialization(typeName, specName)
		dbgprint(specName.." registered for "..typeName)
    end
end

