property pTeamCount, pTeamScoreCache, pOwnScoreWindowId, pTeamScoreWindowId, pTimeWindowId, pTimeOutID, pBuffer, pTimerEndTime, pTimerDurationSec, pCountdownObjId

on construct(me)
  pTeamScoreCache = []
  pOwnScoreWindowId = "game_win_own_score"
  pTeamScoreWindowId = "game_win_team_score"
  pTimeWindowId = "game_win_time"
  pTimeOutID = "game_score_updateGameTimeout"
  return(1)
  exit
end

on deconstruct(me)
  me.removeGameScoreWindows()
  return(1)
  exit
end

on Refresh(me, tTopic, tdata)
  if tTopic = #set_number_of_teams then
    return(me.setTeamNumber(tdata))
  else
    if tTopic = #team_score_updated then
      return(me.updateTeamScores(tdata))
    else
      if tTopic = #personal_score_updated then
        return(me.renderPersonalScores(tdata))
      else
        if tTopic = #update_game_visuals then
          me.cacheTeamScores()
          me.renderPersonalScores(me.getOwnScore())
          return(1)
        else
          if tTopic = #gamestart then
            me.startGameTimer(tdata.getAt(#time_until_game_end), tdata.getAt(#time_until_game_end), tdata.getAt(#time_until_game_end))
            return(me.showGameScoreWindows())
          else
            if tTopic = #gameend then
              return(me.removeGameScoreWindows())
            end if
          end if
        end if
      end if
    end if
  end if
  return(1)
  exit
end

on setTeamNumber(me, tTeamNum)
  pTeamCount = tTeamNum
  pTeamScoreCache = []
  pTeamScoreCache.setAt(pTeamCount, 0)
  return(1)
  exit
end

on getOwnScore(me)
  if not getObject(#session).exists("user_game_index") then
    return(0)
  end if
  tObjectID = getObject(#session).GET("user_game_index")
  tScore = me.getGameSystem().getGameObjectProperty(tObjectID, #score)
  return(tScore)
  exit
end

on startGameTimer(me, tTimeUntilNextState, tStateDuration, tTimeUntilGameEnd)
  if tTimeUntilNextState <= 0 then
    return(0)
  end if
  pTimerEndTime = the milliSeconds + tTimeUntilNextState * 1000
  pTimerDurationSec = tStateDuration
  if timeoutExists(pTimeOutID) then
    removeTimeout(pTimeOutID)
  end if
  createTimeout(pTimeOutID, 1000, #renderGameTimer, me.getID(), pTimerEndTime, tTimeUntilGameEnd)
  return(me.renderGameTimer(pTimerEndTime))
  exit
end

on convertToMinSec(me, tTime)
  --the gameObjectMoveDone = tTime.snowwar_event_4
  --tMin = ERROR
  --the gameObjectAction = tTime.snowwar_event_4
  --tSec = ERROR / 1000
  tMin = tTime / 60000
  tSec = (tTime mod 60000) / 1000
  if tSec < 10 then
    tSec = "0" & tSec
  end if
  return([tMin, tSec])
  exit
end

on renderGameTimer(me, tEndTime)
  tWndObj = getWindow(pTimeWindowId)
  if tWndObj = 0 then
    return(0)
  end if
  tElem = tWndObj.getElement("snowwar_sd_timeleft")
  if tElem = 0 then
    return(0)
  end if
  if tEndTime < the milliSeconds then
    return(0)
  end if
  tTime = me.convertToMinSec(tEndTime - the milliSeconds)
  tTimeStr = tTime.getAt(1) & ":" & tTime.getAt(2)
  tElem.setText(tTimeStr)
  tElem = tWndObj.getElement("snowwar_timeleft")
  if tElem = 0 then
    return(0)
  end if
  tElem.setText(tTimeStr)
  return(1)
  exit
end

on renderPersonalScores(me, tdata)
  tWndObj = getWindow(pOwnScoreWindowId)
  if tWndObj = 0 then
    return(0)
  end if
  if not integerp(tdata) then
    return(0)
  end if
  tElem = tWndObj.getElement("snowwar_score_sd_self")
  if tElem = 0 then
    return(0)
  end if
  tElem.setText(tdata)
  tElem = tWndObj.getElement("snowwar_score_self")
  if tElem = 0 then
    return(0)
  end if
  tElem.setText(tdata)
  return(1)
  exit
end

on cacheTeamScores(me)
  if pTeamCount < 1 then
    return(error(me, "Team count has not been set!", #cacheTeamScores))
  end if
  pTeamScoreCache = []
  pTeamScoreCache.setAt(pTeamCount, 0)
  tGameSystem = me.getGameSystem()
  tIDList = tGameSystem.getGameObjectIdsOfType("avatar")
  repeat with i = 1 to count(tIDList)
    tID = getAt(tIDList, i)
    tObject = tGameSystem.getGameObject(tID)
    if tObject <> 0 then
      tTeamId = tObject.getGameObjectProperty("team_id") + 1
      tScore = tObject.getGameObjectProperty("score")
      pTeamScoreCache.setAt(tTeamId, pTeamScoreCache.getAt(tTeamId) + tScore)
    end if
  end repeat
  return(me.renderTeamScores())
  exit
end

on updateTeamScores(me, tdata)
  if not listp(tdata) then
    return(0)
  end if
  repeat with i = 1 to count(tdata)
    tTeam = getAt(tdata, i)
    tTeamId = tTeam.getAt(#team_id) + 1
    if pTeamScoreCache.count < tTeamId then
      pTeamScoreCache.setAt(tTeamId, 0)
    end if
    pTeamScoreCache.setAt(tTeamId, pTeamScoreCache.getAt(tTeamId) + tTeam.getAt(#score_add))
  end repeat
  return(me.renderTeamScores())
  exit
end

on renderTeamScores(me)
  tWndObj = getWindow(pTeamScoreWindowId)
  if tWndObj = 0 then
    return(0)
  end if
  if not listp(pTeamScoreCache) then
    return(0)
  end if
  tTeamId = 1
  repeat while tTeamId <= pTeamScoreCache.count
    tTeamScore = string(pTeamScoreCache.getAt(tTeamId))
    tElem = tWndObj.getElement("snowwar_score_sd_team" & tTeamId)
    if tElem <> 0 then
      if tTeamScore <> tElem.getText() then
        tElem.setText(tTeamScore)
        tWndObj.getElement("snowwar_score_team" & tTeamId).setText(tTeamScore)
      end if
    end if
    tTeamId = 1 + tTeamId
  end repeat
  return(1)
  exit
end

on showGameScoreWindows(me)
  if not windowExists(pTeamScoreWindowId) then
    if createWindow(pTeamScoreWindowId, "team_stats.window") then
      tWndObj = getWindow(pTeamScoreWindowId)
      tLocH = _movie.stage.rect.width - 54
      if me.getGameSystem().getSpectatorModeFlag() then
        tWndObj.moveTo(tLocH - 30, 40)
      else
        tWndObj.moveTo(tLocH, 70)
      end if
      tWndObj.lock()
      tTeamId = 1
      repeat while tTeamId <= 4
        me.setTeamScoreVisible(tTeamId, tTeamId <= pTeamCount and pTeamCount > 1)
        tTeamId = 1 + tTeamId
      end repeat
      me.renderTeamScores()
    else
      return(error(me, "Cannot open team score window.", #showGameScoreWindows))
    end if
  end if
  if not windowExists(pOwnScoreWindowId) and not me.getGameSystem().getSpectatorModeFlag() then
    if createWindow(pOwnScoreWindowId, "personal_stats.window") then
      tWndObj = getWindow(pOwnScoreWindowId)
      tLocH = _movie.stage.rect.width - 54
      tWndObj.moveTo(tLocH, 10)
      tWndObj.lock()
      me.renderPersonalScores(me.getOwnScore())
    else
      return(error(me, "Cannot open personal score window.", #showGameScoreWindows))
    end if
  end if
  if not windowExists(pTimeWindowId) then
    if createWindow(pTimeWindowId, "habbo_simple.window") then
      tWndObj = getWindow(pTimeWindowId)
      tWndObj.merge("sw_timeleft.window")
      if me.getGameSystem().getSpectatorModeFlag() then
        tWndObj.moveTo(26, 36)
      else
        tWndObj.moveTo(10, 15)
      end if
      tWndObj.lock()
    else
      return(error(me, "Cannot open timeleft window.", #showGameScoreWindows))
    end if
  end if
  return(1)
  exit
end

on setTeamScoreVisible(me, tTeamId, tstate)
  tWndObj = getWindow(pTeamScoreWindowId)
  if tWndObj = 0 then
    return(0)
  end if
  tElement = tWndObj.getElement("snowwar_scorebg_team" & tTeamId)
  if tElement <> 0 then
    tElement.setProperty(#visible, tstate)
  end if
  tElement = tWndObj.getElement("snowwar_score_sd_team" & tTeamId)
  if tElement <> 0 then
    tElement.setProperty(#visible, tstate)
  end if
  tElement = tWndObj.getElement("snowwar_score_team" & tTeamId)
  if tElement <> 0 then
    tElement.setProperty(#visible, tstate)
  end if
  return(1)
  exit
end

on removeGameScoreWindows(me)
  if windowExists(pTeamScoreWindowId) then
    removeWindow(pTeamScoreWindowId)
  end if
  if windowExists(pOwnScoreWindowId) then
    removeWindow(pOwnScoreWindowId)
  end if
  if windowExists(pTimeWindowId) then
    removeWindow(pTimeWindowId)
  end if
  if timeoutExists(pTimeOutID) then
    removeTimeout(pTimeOutID)
  end if
  return(1)
  exit
end
