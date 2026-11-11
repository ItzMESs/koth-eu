-- ============================================================
--  End of match: VICTORY / DEFEAT screen, next map, personal bonus
--  Called from server.lua when a team reaches 100 points.
--  UI: koth-plus (end screen).
-- ============================================================

ENDGAME_BONUS = {
    win  = { money = 2000, xp = 600 },
    lose = { money = 1000, xp = 300 },
    perScoreMoney = 0.5,   -- + half of the XP earned this match as money
    perScoreXp    = 0.15,  -- + 15% of the XP earned this match as XP
}

local TEAM_LABEL = { [1] = "OPFOR", [2] = "BLUFOR", [3] = "INDFOR" }

function EndGameScreen(winnerTeam, seconds)
    local nextMap = MapVoteGetWinner and MapVoteGetWinner() or nil
    for _, t in pairs(TeamIDPlayer or {}) do
        local id = t.id
        if GetPlayerName(id) then
            local win = (t.team == winnerTeam)
            local score = 0
            for _, p in pairs(PlayerDataInfo or {}) do
                if p.id == id then score = tonumber(p.score) or 0 end
            end
            local base = win and ENDGAME_BONUS.win or ENDGAME_BONUS.lose
            local money = math.floor(base.money + score * ENDGAME_BONUS.perScoreMoney)
            local xp = math.floor(base.xp + score * ENDGAME_BONUS.perScoreXp)

            if AddMoneyServer then AddMoneyServer(id, money, true) end
            if AddXpServer then AddXpServer(id, xp, true) end
            if CosmeticsOnMatchEnd then CosmeticsOnMatchEnd(id, win) end

            -- camera fly-over + fireworks (client/end.lua)
            TriggerClientEvent("KothEndMatch", id, win, TEAM_LABEL[winnerTeam] or "")
            -- end screen (koth-plus)
            TriggerClientEvent("KOTH-End:Show", id, {
                victory = win,
                winner = TEAM_LABEL[winnerTeam] or "",
                winnerTeam = winnerTeam,
                nextMap = nextMap,
                money = money,
                xp = xp,
                seconds = seconds or 30,
            })
        end
    end
end
