local mod = get_mod("WhosNotReady")


-----------------
-- Temporary locs

local pnr_text_loc = "Players not ready:"


------------
-- Utilities

-- Get player name from account_id
local player_name_from_peer_id = function(peer_id)
    local member = Managers.party_immaterium:member_from_account_id(peer_id)
    local presence = member and member:presence()
    local account_name = presence presence:account_name()
    local character_name = member.name and member:name()
    return character_name or account_name or "[Player name not found]"
end


--------------------------------------------------------
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
-- Create PNR texts for the HUD element & the notif
mod.get_pnr_texts = function()
    local text_1 = pnr_text_loc
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
    -- Adds "spawn", "death" and "hybrid" notification types for our mod
    if message_type ~= "pnr_voting_info" then
        return(func(self, message_type, data))
    else
        local notif_data = func(self, "voting", data)
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
        return notif_data
    end
end)

-------------------------------------------------------------
-- Update list of non-ready players & create/update PNR notif

--[[
mod.update = function(dt)
    -->> No ongoing vote
    if not mod.voting_id then
        return
    end
    -->> Ongoing vote
    --local wrapped_vote_id = string.format("immaterium_party:%s", mod.voting_id)
    --> Update list of members who haven't voted yet
    --local members = Managers.voting:member_list(mod.wrapped_vote_id())
    --[
    local members = Managers.voting:member_list(mod.voting_id)
    local account_ids_not_ready = {}
    for _, member_id in pairs(members) do
        --if not Managers.voting:has_voted(mod.wrapped_vote_id(), member_id) then
        if not Managers.voting:has_voted(mod.voting_id, member_id) then
            table.insert(account_ids_not_ready, member_id)
        end
    end
    mod.players_not_ready = table.clone(account_ids_not_ready)
    --]
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
--]]


--------------------------------------
-- Grab the vote_id when a vote starts

--[[
mod:hook_safe(CLASS.VotingManager, "update", function(self, dt, t)
    local immaterium_party_voting = self._immaterium_party_voting_impl
    local game_mode = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    local in_hub_or_psyk = game_mode == "hub" or game_mode == "training_grounds"
    if not in_hub_or_psyk then
        return
    elseif not immaterium_party_voting then
        mod:echo("Error: self._immaterium_party_voting_impl = nil")
        return
    end
    -- Check for new vote_id
    local vote_id = immaterium_party_voting._current_vote_id
    local vote_status = immaterium_party_voting._current_vote_state
    -- Disable temporarily to try setting mod.voting_id with a "start voting" hook
    if vote_id and vote_status ~= "finished" and not mod.voting_id then
        mod:echo("VotingManager.update - Setting mod.voting_id to: "..tostring(vote_id))
        --mod:echo("VotingManager.update - vote_status = "..tostring(vote_status))
        mod.voting_id = vote_id
    end
    -- We thought there was an ongoing vote, but it has ended
    if vote_status == "finished" and mod.voting_id then
        mod:echo("Vote finished, deleting mod.voting_id")
        Managers.event:trigger("event_remove_notification", mod.notif_id)
        mod.voting_id = nil
        mod.notif_id = nil
        mod.players_not_ready = {}
    end
end)
--]]

mod:hook_require(
    "scripts/settings/voting/voting_templates/mission_vote_matchmaking_immaterium",
    function(returned_template)
        -->> on_vote_casted - Looking for new voting sessions & recording cast votes
        local original_func_on_vote_casted = returned_template.on_vote_casted
        returned_template.on_vote_casted = function(voting_id, template, voter_account_id, vote_option)
            --> New vote started
            if not mod.voting_id then
                -- Set mod.voting_id
                mod:echo("on_vote_casted - Setting mod.vote_id to "..tostring(voting_id))
                mod.voting_id = voting_id
                -- Set mod.players_not_ready
                local members = Managers.voting:member_list(voting_id)
                mod.players_not_ready = table.clone(members)
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
            end
            --> Record player vote
            mod:echo("on_vote_casted - Vote cast by "..player_name_from_peer_id(voter_account_id))
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
            --> Return original result
            return original_func_on_vote_casted(voting_id, template, voter_account_id, vote_option)
        end
        -->> on_completed - Deleting mod.voting_id and notification
        local original_func_on_completed = returned_template.on_completed
        returned_template.on_completed = function(voting_id, template, vote_state, result)
            --> Delete mod.voting_id & notif
            mod:echo("on_completed - Voting over, deleting mod.voting_id")
            if mod.notif_id then
                Managers.event:trigger("event_remove_notification", mod.notif_id)
            end
            mod.voting_id = nil
            mod.notif_id = nil
            mod.players_not_ready = {}
            --> Return original result
            return original_func_on_completed(voting_id, template, vote_state, result)
        end
    end
)