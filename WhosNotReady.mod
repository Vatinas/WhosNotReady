return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`WhosNotReady` encountered an error loading the Darktide Mod Framework.")

		new_mod("WhosNotReady", {
			mod_script       = "WhosNotReady/scripts/mods/WhosNotReady/WhosNotReady",
			mod_data         = "WhosNotReady/scripts/mods/WhosNotReady/WhosNotReady_data",
			mod_localization = "WhosNotReady/scripts/mods/WhosNotReady/WhosNotReady_localization",
		})
	end,
	packages = {},
}
