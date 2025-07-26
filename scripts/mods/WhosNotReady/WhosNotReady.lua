local mod = get_mod("WhosNotReady")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")


----------------------------------------------------
-- Get base game definitions for mission voting view

local Definitions = require("scripts/ui/views/mission_voting_view/mission_voting_view_definitions")


-----------------
-- Temporary locs

local pnr_text_loc = "Players not ready:"


------------
-- Utilities

-- Get player name from account_id
local player_name_from_peer_id = function(peer_id)
    -- return Managers.player:player(peer_id, 1):name()
    --[[
    if not Managers.player:players()[peer_id] then
        mod:echo("Error: Manager.player:players()[peer_id] = nil")
    elseif not Managers.players:players()[peer_id]._profile then
        mod:echo("Error: Manager.players:players()[peer_id]._profile = nil")
    else
        return tostring(Managers.players:players()[peer_id]._profile.name)
    end
    --]]
    --return Managers.backend.interfaces.account:get_account_name_by_account_id(peer_id)
    --return tostring(peer_id)
    --[[
    local members = Managers.party_immaterium:all_members()
    for _, member in pairs(members) do
        if member:unique_id() == peer_id then
            
        end
    end
    --]]
    local member = Managers.party_immaterium:member_from_account_id(peer_id)
    local presence = member:presence()
    local account_name = presence:account_name()
    return account_name
end

-- Update the text of the PNR widget (on the mission voting screen)
local update_PNR_text = function(widget, text)
    if not widget then
        mod:echo("Error: widget = nil")
        return
    elseif not widget.content then
        mod:echo("Error: widget.content = nil")
        return
    elseif not widget.content.text then
        mod:echo("Error: widget.content.text = nil")
        return
    end
    if not text then
        mod:echo("Error: text = nil")
        return
    end
    widget.content.text = text
end


--------------------------------------------------------
-- Initialize mod values

-- The id of the notif that shows voting info
mod.notif_id = nil
-- The id of the voting session
mod.voting_id = nil
-- The list of players (peer_id's) of players not ready
mod.players_not_ready = {}
-- Create PNR texts for the HUD element & the notif
mod.get_pnr_texts = function()
    local text_1 = pnr_text_loc
    local text_2 = ""
    for _, peer_id in pairs(mod.players_not_ready) do
        local player_name = player_name_from_peer_id(peer_id)
        --local player_name = tostring(peer_id)
        text_2 = text_2..player_name.." - "
    end
    -- Small manip to remove the extra " - " at the end of text_2 (which looks like "player1 - player2 - ")
    if string.len(text_2) >= 3 then
        text_2 = string.sub(text_2, 1, string.len(text_2) - 3)
    end
    return text_1, text_2
end


----------------------------------
-- Create new widget definition(s)

local font_style = table.clone(UIFontSettings.header_3)

font_style.font_size = 20
font_style.offset = {
	0,
	0,
	13,
}
font_style.text_horizontal_alignment = "center"
font_style.text_color = {
	255,
	169,
	191,
	153,
}

local widget_definitions = {
    players_not_ready = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "players_not_ready",
			value = "[TEST]",
			value_id = "players_not_ready",
			style = font_style,
		},
	}, "timer_bar"),
}


---------------------------------------
-- Add our defs to the base game's defs

for name, def in pairs(widget_definitions) do
    Definitions[name] = def
end


----------------------------------------------------------------
-- Init the MissionVotingView with the combined defs (manually?)

mod:hook_safe(CLASS.MissionVotingView, "init", function(self, settings, context)
    self._definitions = Definitions
end)


-------------------------------------
-- Add new notif type for voting info

mod:hook("ConstantElementNotificationFeed", "_generate_notification_data", function(func, self, message_type, data)
    -- Adds "spawn", "death" and "hybrid" notification types for our mod
    if message_type ~= "pnr_voting_info" then
        return(func(self, message_type, data))
    else
        local notif_data = func(self, "voting", data)
        ---[[
        notif_data.texts = {
            {
                -- First line - "Players not ready:"
                font_size = 22,
                display_name = pnr_text_loc,
                color = {
                    255,
                    232,
                    238,
                    219,
                },
            },
            {
                -- Second line - "Player_1 - [...] - Player_n"
                font_size = 20,
                display_name = data.texts[2],
                color = Color.text_default(255, true),
            },
        }
        --]]
        -- Temporary solution to remove the notif after voting: set its total time to 1s
        notif_data.total_time = 1
        --notif_data.enter_sound_event = notif_data.enter_sound_event or UISoundEvents.notification_default_enter
        --notif_data.exit_sound_event = notif_data.exit_sound_event or UISoundEvents.notification_default_exit
        return notif_data
    end
end)


---------------------------------------------------
-- Update PNR widget (on the mission voting screen)

--[[
mod:hook_safe(CLASS.MissionVotingView, "update", function(self, dt, t, input_service)
    if not self._voting_id then
        mod:echo("Error: self._voting_id not found")
        return
    end
    mod.voting_id = self._voting_id
    -- Members are represented by their peer_id:
    local members = Managers.voting:member_list(self._voting_id)
    -- Get members who haven't voted yet
    local members_not_ready = {}
    for _, member_id in pairs(members) do
        -- if not Managers.voting:has_voted(self._voting_id, member_id) then
        if not Managers.voting:has_voted(member_id) then
            table.insert(members_not_ready, member_id)
        end
    end
    mod.players_not_ready = table.clone(members_not_ready)
    -- Update PNR widget text
    local widget = self._widgets_by_name.players_not_ready
    if not widget then
        mod:echo("Error: players_not_ready widget not found")
    elseif #mod.players_not_ready ~= 0 then
        local text_1, text_2 = mod.get_pnr_texts()
        update_PNR_text(widget, text_1.."\n"..text_2)
    else
        update_PNR_text(widget, "[TEST2]")
    end
end)
--]]


-------------------------------------------------------------
-- Update list of non-ready players & create/update PNR notif

mod.update = function(dt)
    -->> No ongoing vote
    if not mod.voting_id then
        return
    end
    local wrapped_vote_id = string.format("immaterium_party:%s", mod.voting_id)
    -->> Ongoing vote
    --> Update list of members who haven't voted yet
    ---[[
    --]]
    local members = Managers.voting:member_list(wrapped_vote_id)
    local members_not_ready = {}
    local account_ids_not_ready = {}
    --mod:echo(tostring(members))
    ---[[
    ---[[
    for _, member_id in pairs(members) do
        --mod:echo("Managers.voting:has_voted(mod.voting_id, "..tostring(member_id)..") = "..tostring(Managers.voting:has_voted(mod.voting_id, member_id)))
        if not Managers.voting:has_voted(wrapped_vote_id, member_id) then
        --if not Managers.voting:has_voted(member_id) then
            --table.insert(members_not_ready, member_id)
            table.insert(account_ids_not_ready, member_id)
            --[[
            for id, player in pairs(Managers.player:players()) do
                --mod:echo(player:account_id())
                if player:account_id() == member_id then
                    mod:echo("Found player")
                    table.insert(player_names_not_ready, player:name())
                end
                
            end
            --]]
        end
    end
    --]]
    --mod.players_not_ready = table.clone(members_not_ready)
    --mod.players_not_ready = table.clone(player_names_not_ready)
    mod.players_not_ready = table.clone(account_ids_not_ready)
    --> Create/update notif
    local constant_elements = Managers.ui and Managers.ui:ui_constant_elements()
    local notif_element = constant_elements and constant_elements:element("ConstantElementNotificationFeed")
    if not notif_element then
        mod:echo("Error: notif_element not found")
        return
    end
    if not mod.notif_id or not notif_element:_notification_by_id(mod.notif_id) then
        -- Create notif
        Managers.event:trigger("event_add_notification_message", "pnr_voting_info", {
            texts = {
                "[TEST3.1]",
                "[TEST3.2]",
                "[TEST3.3]",
            },
        }, function (id)
            mod.notif_id = id
        end)
    else
        -- Update notif
        local notif = notif_element:_notification_by_id(mod.notif_id)
        local text_1, text_2 = mod.get_pnr_texts()
        local texts = {
            text_1, text_2
        }
        notif_element:_set_texts(notif, texts)
        notif.time = 0
    end
end


--------------------------------------------
-- WIP - Grab the vote_id when a vote starts

--[[
mod:hook_safe(CLASS.VotingManagerImmateriumParty, "update", function(self, dt, t)
    mod.voting_id = mod.voting_id or self._current_vote_id
end)
--]]

--[[
mod:hook_safe(CLASS.VotingManagerImmateriumParty, "start_voting", function(self, template_name, params)
    mod:echo("self._current_vote_id = "..tostring(self._current_vote_id))
    mod.voting_id = mod.voting_id or self._current_vote_id
end)
--]]

--[[
mod:hook_safe(CLASS.VotingManager, "start_voting", function(self, template_name, params)
    local vote_id =  self._immaterium_party_voting_impl and self._immaterium_party_voting_impl._current_vote_id
    if not mod.voting_id then
        mod:echo("start_voting - Setting mod.voting_id to: "..tostring(vote_id))
    end
    --mod.voting_id = mod.voting_id or vote_id
    mod.voting_id = vote_id
end)
--]]

---[[
mod:hook_safe(CLASS.VotingManager, "update", function(self, dt, t)
    -- Check for new vote_id
    local vote_id = self._immaterium_party_voting_impl and self._immaterium_party_voting_impl._current_vote_id
    local vote_status = self._immaterium_party_voting_impl and self._immaterium_party_voting_impl._current_vote_state
    if vote_id and vote_status ~= "finished" and not mod.voting_id then
        --mod:echo("VotingManager.update - Setting mod.voting_id to: "..tostring(vote_id))
        mod:echo("VotingManager.update - Setting mod.voting_id to: "..tostring(vote_id))
        --mod:echo("VotingManager.update - vote_id_2 = "..tostring(vote_id_2))
        --mod:echo(tostring(vote_id == vote_id_2))
        mod:echo("VotingManager.update - vote_status = "..tostring(vote_status))
        mod.voting_id = vote_id
    end
    -- We thought there was an ongoing vote, but it has ended
    if vote_status == "finished" and mod.voting_id then
        mod:echo("self._immaterium_party_voting_impl._current_vote_state == \"finished\", deleting mod.voting_id")
        Managers.event:trigger("event_remove_notification", mod.notif_id)
        mod.voting_id = nil
        mod.notif_id = nil
        mod.players_not_ready = {}
    end
end)
--]]

--[[
mod:hook_safe(CLASS.VotingClient, "init", function(self, voting_id, initiator_peer, template, optional_params, member_list, initial_votes_list, time_left)
    local vote_id =  voting_id
    if not mod.voting_id then
        mod:echo("start_voting - Setting mod.voting_id to: "..tostring(vote_id))
    end
    --mod.voting_id = mod.voting_id or vote_id
    mod.voting_id = vote_id
end)
--]]

--[[
mod:hook_safe(CLASS.VotingClient, "update", function(self, dt, t)
    local vote_id =  self._voting_id
    if not mod.voting_id then
        mod:echo("start_voting - Setting mod.voting_id to: "..tostring(vote_id))
    end
    --mod.voting_id = mod.voting_id or vote_id
    mod.voting_id = vote_id
end)
--]]