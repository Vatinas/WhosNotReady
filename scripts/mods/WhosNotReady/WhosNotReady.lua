local mod = get_mod("WhosNotReady")


------------
-- Utilities

-- Get player name from account_id
local player_name_from_peer_id = function(peer_id)
    local member = Managers.party_immaterium:member_from_account_id(peer_id)
    local presence = member and member:presence()
    local account_name = presence and presence:account_name()
    local character_name = member.name and member:name()
    if mod:get("name_setting") == "character_name" then
        return character_name or mod:localize("name_not_found")
    elseif mod:get("name_setting") == "account_name" then
        return account_name or mod:localize("name_not_found")
    end
    -- The previous filtering should be exhaustive, the following line is here just in case
    return character_name or account_name or mod:localize("name_not_found")
end


------------------------
-- Initialize mod values

-- The id of the notif that shows voting info
mod.notif_id = nil
-- The id of the voting session
mod.voting_id = nil
mod.wrapped_vote_id = function ()
    return string.format("immaterium_party:%s", mod.voting_id)
end
-- The list of players (peer_id's) of players not ready
mod.players_not_ready = {}
-- Create PNR texts for the notif
mod.get_pnr_texts = function()
    local text_1 = mod:localize("players_not_ready_text")
    local text_2 = ""
    for _, peer_id in pairs(mod.players_not_ready) do
        local player_name = player_name_from_peer_id(peer_id)
        text_2 = text_2..player_name.." - "
    end
    -- Small manip to remove the extra " - " at the end of text_2 (which looks like "player1 - player2 - ")
    if string.len(text_2) >= 3 then
        text_2 = string.sub(text_2, 1, string.len(text_2) - 3)
    end
    return text_1, text_2
end


-------------------------------------
-- Add new notif type for voting info

mod:hook("ConstantElementNotificationFeed", "_generate_notification_data", function(func, self, message_type, data)
    -- Adds "pnr_voting_info" notification type for our mod
    if message_type ~= "pnr_voting_info" then
        return(func(self, message_type, data))
    else
        local notif_data = func(self, "voting", data)
        notif_data.texts = {
            {
                -- First line - "Players not ready:"
                font_size = 22,
                display_name = mod:localize("players_not_ready_text"),
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
        return notif_data
    end
end)


---------------------------------
-- Hook function - on_vote_casted

local on_vote_casted_function = function(voting_id, template, voter_account_id, vote_option)
    --> New vote started
    if not mod.voting_id then
        -- Set mod.voting_id
        --mod:echo("on_vote_casted - Setting mod.vote_id to "..tostring(voting_id))
        mod.voting_id = voting_id
        -- Set mod.players_not_ready
        local members = Managers.voting:member_list(voting_id)
        mod.players_not_ready = table.clone(members)
        -- Create notif
        Managers.event:trigger("event_add_notification_message", "pnr_voting_info", {
            texts = {
                "",
                "",
                "",
            },
        }, function (id)
            mod.notif_id = id
        end)
    end

    --> Record player vote
    --mod:echo("on_vote_casted - Vote casted by "..player_name_from_peer_id(voter_account_id))
    local new_players_not_ready = {}
    for _, account_id in pairs(mod.players_not_ready) do
        if account_id ~= voter_account_id then
            table.insert(new_players_not_ready, account_id)
        end
    end
    mod.players_not_ready = table.clone(new_players_not_ready)

    --> Update notif
    local constant_elements = Managers.ui and Managers.ui:ui_constant_elements()
    local notif_element = constant_elements and constant_elements:element("ConstantElementNotificationFeed")
    local notif = notif_element and notif_element:_notification_by_id(mod.notif_id)
    local text_1, text_2 = mod.get_pnr_texts()
    local texts = {
        text_1, text_2
    }
    if notif then
        notif_element:_set_texts(notif, texts)
        notif.time = 0
    end
end


-------------------------------
-- Hook function - on_completed

local on_completed_function = function(voting_id, template, vote_state, result)
    --> Delete mod.voting_id & notif
    --mod:echo("on_completed - Voting over, deleting mod.voting_id & notif")
    if mod.notif_id then
        Managers.event:trigger("event_remove_notification", mod.notif_id)
    end
    mod.voting_id = nil
    mod.notif_id = nil
    mod.players_not_ready = {}
end


---------------
-- Actual hooks

mod:hook_require(
    "scripts/settings/voting/voting_templates/mission_vote_matchmaking_immaterium",
    function(template)
        mod:hook_safe(template, "on_vote_casted", on_vote_casted_function)
        mod:hook_safe(template, "on_completed", on_completed_function)
    end)