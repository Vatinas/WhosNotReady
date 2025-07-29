local mod = get_mod("WhosNotReady")

---------------------------------
-- Utilities for creating widgets

local name_setting_dropdown = { }
for _, i in pairs({
    "character_name",
    "account_name"
}) do
    table.insert(name_setting_dropdown, {text = i, value = i})
end


-------------------
-- Creating widgets

local name_widget = {
	setting_id = "name_setting",
	tooltip = "tooltip_name_setting",
	type = "dropdown",
	default_value = "character_name",
	options = table.clone(name_setting_dropdown),
}


--------------------------
-- Adding widgets together

local widgets = {}

table.insert(widgets, name_widget)

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets
	}
}