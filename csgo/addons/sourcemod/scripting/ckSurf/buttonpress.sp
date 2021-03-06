// Start timer
public void CL_OnStartTimerPress(int client)
{
	if (!IsFakeClient(client))
	{
		if (IsValidClient(client))
		{
			if (!g_bServerDataLoaded)
			{
				if (GetGameTime() - g_fErrorMessage[client] > 1.0)
				{
					PrintToChat(client, "[%cSurf Timer%c] The server hasn't finished loading it's settings, please wait.", MOSSGREEN, WHITE);
					ClientCommand(client, "play buttons\\button10.wav");
					g_fErrorMessage[client] = GetGameTime();
				}
				return;
			}
			else if (g_bLoadingSettings[client])
			{
				if (GetGameTime() - g_fErrorMessage[client] > 1.0)
				{
					PrintToChat(client, "[%cSurf Timer%c] Your settings are currently being loaded, please wait.", MOSSGREEN, WHITE);
					ClientCommand(client, "play buttons\\button10.wav");
					g_fErrorMessage[client] = GetGameTime();
				}
				return;
			}
			else if (!g_bSettingsLoaded[client])
			{
				if (GetGameTime() - g_fErrorMessage[client] > 1.0)
				{
					PrintToChat(client, "[%cSurf Timer%c] The server hasn't finished loading your settings, please wait.", MOSSGREEN, WHITE);
					ClientCommand(client, "play buttons\\button10.wav");
					g_fErrorMessage[client] = GetGameTime();
				}
				return;
			}
		}
		if (g_bNewReplay[client] || g_bNewBonus[client]) // Don't allow starting the timer, if players record is being saved
			return;
	}

	if (!g_bSpectate[client] && !g_bNoClip[client] && ((GetGameTime() - g_fLastTimeNoClipUsed[client]) > 2.0))
	{

		Action result;
		Call_StartForward(g_OnTimerStartedForward);
		Call_PushCell(client);

		if (g_iClientInZone[client][2] > 0)
			Call_PushCell(RT_Bonus);
		else
			Call_PushCell(RT_Map);

		Call_Finish(result);

		if (result == Plugin_Handled)
			return;


		if (g_bActivateCheckpointsOnStart[client])
			g_bCheckpointsEnabled[client] = true;

		// Reser run variables
		tmpDiff[client] = 9999.0;
		g_fPauseTime[client] = 0.0;
		g_fStartPauseTime[client] = 0.0;
		g_bPause[client] = false;
		SetEntityMoveType(client, MOVETYPE_WALK);
		SetEntityRenderMode(client, RENDER_NORMAL);
		g_fStartTime[client] = GetGameTime();
		g_fCurrentRunTime[client] = 0.0;
		g_bPositionRestored[client] = false;
		g_bMissedMapBest[client] = true;
		g_bMissedBonusBest[client] = true;
		g_bTimeractivated[client] = true;
		int zgroup = g_iClientInZone[client][2];

		// Get player velocity
		float vecPlayerVelocity[3], fPlayerVelocity;

		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecPlayerVelocity);
		fPlayerVelocity = GetVectorLength(vecPlayerVelocity);

		// Build Speed difference message
		char speedDiffMsg[128];
		Format(speedDiffMsg, sizeof(speedDiffMsg), "[%cSurf Timer%c] Start: %c%d %cu/s", MOSSGREEN, WHITE, YELLOW, RoundToCeil(fPlayerVelocity), WHITE);


		if (g_fPlayerRectStartSpeed[client][zgroup] != -1)
		{
			float fDiff = fPlayerVelocity - g_fPlayerRectStartSpeed[client][zgroup];
			char srDiff[16];

			if (fDiff < 0)
				Format(srDiff, sizeof(srDiff), "%c%d%c u/s", RED, RoundToCeil(fDiff), WHITE);
			else
				Format(srDiff, sizeof(srDiff), "%c+%d%c u/s", LIMEGREEN, RoundToCeil(fDiff), WHITE);

			Format(speedDiffMsg, sizeof(speedDiffMsg), "%s | PB: %s", speedDiffMsg, srDiff);
		}



		if (g_fRecordStartSpeed[zgroup] != -1)
		{
			// Get difference between server record 
			float fDiff = fPlayerVelocity - g_fRecordStartSpeed[zgroup];
			char srDiff[16];

			if (fDiff < 0)
				Format(srDiff, sizeof(srDiff), "%c%d%c u/s", RED, RoundToCeil(fDiff), WHITE);
			else
				Format(srDiff, sizeof(srDiff), "%c+%d%c u/s", LIMEGREEN, RoundToCeil(fDiff), WHITE);

			Format(speedDiffMsg, sizeof(speedDiffMsg), "%s | SR: %s", speedDiffMsg, srDiff);
		}

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;

			if (GetClientTeam(i) != CS_TEAM_SPECTATOR)
				continue;

			int ObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
			if (ObserverMode != 4 && ObserverMode != 5)
				continue;

			int ObserverTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
			if (ObserverTarget != client)
				continue;

			PrintToChat(i, speedDiffMsg);
		}

		PrintToChat(client, speedDiffMsg);


		g_fPlayerCurrentStartSpeed[client][g_iClientInZone[client][2]] = fPlayerVelocity;

		if (!IsFakeClient(client))
		{
			// Reset checkpoint times
			for (int i = 0; i < CPLIMIT; i++)
				g_fCheckpointTimesNew[g_iClientInZone[client][2]][client][i] = 0.0;

			// Set missed record time variables
			if (g_iClientInZone[client][2] == 0)
			{
				if (g_fPersonalRecord[client] > 0.0)
					g_bMissedMapBest[client] = false;
			}
			else
			{
				if (g_fPersonalRecordBonus[g_iClientInZone[client][2]][client] > 0.0)
					g_bMissedBonusBest[client] = false;

			}

			// If starting the timer for the first time, print average times
			if (g_bFirstTimerStart[client])
			{
				g_bFirstTimerStart[client] = false;
				Client_Avg(client, 0);
			}
		}
	}

	// Play start sound
	PlayButtonSound(client);

	// Start recording if isn't recording already
	if ((!IsFakeClient(client) && GetConVarBool(g_hReplayBot)) && !g_hRecording[client])
	{
		if (!IsPlayerAlive(client) || GetClientTeam(client) == 1)
		{
			if (g_hRecording[client] != null)
				StopRecording(client);
		}
		else
		{
			if (g_hRecording[client] != null)
				StopRecording(client);
			StartRecording(client);
		}
	}
}

// End timer
public void CL_OnEndTimerPress(int client)
{
	if (!IsValidClient(client))
		return;

	// Print bot finishing message to spectators
	if (IsFakeClient(client) && g_bTimeractivated[client])
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && !IsPlayerAlive(i))
			{
				int SpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
				if (SpecMode == 4 || SpecMode == 5)
				{
					int Target = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
					if (Target == client && g_RecordBot == Target)
					{
						if (g_CurrentReplay == 0)
							PrintToChat(i, "%t", "ReplayFinishingMsg", MOSSGREEN, WHITE, LIMEGREEN, g_szReplayName, GRAY, LIMEGREEN, g_szReplayTime, GRAY);
						else if (g_CurrentReplay > 0)
							PrintToChat(i, "%t", "ReplayFinishingMsgBonus", MOSSGREEN, WHITE, LIMEGREEN, g_szBonusName, GRAY, YELLOW, g_szZoneGroupName[g_iClientInZone[Target][2]], GRAY, LIMEGREEN, g_szBonusTime, GRAY);
					}
				}
			}
		}

		PlayButtonSound(client);

		g_bTimeractivated[client] = false;
		return;
	}

	// If timer is not on, play error sound and return
	if (!g_bTimeractivated[client])
	{
		ClientCommand(client, "play buttons\\button10.wav");
		return;
	}
	else
	{
		PlayButtonSound(client);
	}

	// Get client name
	char szName[MAX_NAME_LENGTH];
	GetClientName(client, szName, MAX_NAME_LENGTH);

	// Get runtime and format it to a string
	g_fFinalTime[client] = GetGameTime() - g_fStartTime[client] - g_fPauseTime[client];
	FormatTimeFloat(client, g_fFinalTime[client], 3, g_szFinalTime[client], 32);

	/*============================================
	=            Handle practice mode            =
	============================================*/
	if (g_bPracticeMode[client])
	{
		if (g_iClientInZone[client][2] > 0)
			PrintToChat(client, "[%cSurf Timer%c] %c%s %cfinished the bonus with a time of [%c%s%c] in practice mode!", MOSSGREEN, WHITE, MOSSGREEN, szName, WHITE, LIGHTBLUE, g_szFinalTime[client], WHITE);
		else
			PrintToChat(client, "[%cSurf Timer%c] %c%s %cfinished the map with a time of [%c%s%c] in practice mode!", MOSSGREEN, WHITE, MOSSGREEN, szName, WHITE, LIGHTBLUE, g_szFinalTime[client], WHITE);

		/* Start function call */
		Call_StartForward(g_PracticeFinishForward);

		/* Push parameters one at a time */
		Call_PushCell(client);
		Call_PushFloat(g_fFinalTime[client]);
		Call_PushString(g_szFinalTime[client]);

		/* Finish the call, get the result */
		Call_Finish();

		return;
	}

	// Set "Map Finished" overlay panel
	g_bOverlay[client] = true;
	g_fLastOverlay[client] = GetGameTime();
	PrintHintText(client, "%t", "TimerStopped", g_szFinalTime[client]);

	// Get Zonegroup
	int zGroup = g_iClientInZone[client][2];

	/*==========================================
	=            Handling map times            =
	==========================================*/
	if (zGroup == 0)
	{
		// Make a new record bot?
		if (GetConVarBool(g_hReplaceReplayTime) && (g_fFinalTime[client] < g_fReplayTimes[0] || g_fReplayTimes[0] == 0.0))
		{
			if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client])
			{
				g_fReplayTimes[0] = g_fFinalTime[client];
				g_bNewReplay[client] = true;
				SaveRecording(client, 0);
			}
		}

		char szDiff[54];
		char szSRDiff[32];
		float diff;
		float srdiff;

		// Record bools init
		g_bMapFirstRecord[client] = false;
		g_bMapPBRecord[client] = false;
		g_bMapSRVRecord[client] = false;

		g_OldMapRank[client] = g_MapRank[client];

		diff = g_fPersonalRecord[client] - g_fFinalTime[client];
		FormatTimeFloat(client, diff, 3, szDiff, sizeof(szDiff));

		if (diff > 0.0)
			Format(g_szTimeDifference[client], sizeof(szDiff), "-%s", szDiff);
		else
			Format(g_szTimeDifference[client], sizeof(szDiff), "+%s", szDiff);



		srdiff = g_fRecordMapTime - g_fFinalTime[client];
		FormatTimeFloat(client, srdiff, 3, szSRDiff, sizeof(szSRDiff));

		if (srdiff > 0.0)
			Format(g_szSRTimeDifference[client], sizeof(szSRDiff), "%c-%s", GREEN, szSRDiff);
		else
			Format(g_szSRTimeDifference[client], sizeof(szSRDiff), "%c+%s", RED, szSRDiff);


		// Check for SR
		if (g_MapTimesCount > 0)
		{  // If the server already has a record
			if (g_fFinalTime[client] < g_fRecordMapTime)
			{  // New fastest time in map
				g_bMapSRVRecord[client] = true;

				g_fRecordMapTime = g_fFinalTime[client];
				Format(g_szRecordPlayer, MAX_NAME_LENGTH, "%s", szName);
				FormatTimeFloat(1, g_fRecordMapTime, 3, g_szRecordMapTime, 64);

				// Insert latest record
				db_InsertLatestRecords(g_szSteamID[client], szName, g_fFinalTime[client]);

				// Update Checkpoints
				if (!g_bPositionRestored[client])
				{
					for (int i = 0; i < CPLIMIT; i++)
					{
						g_fCheckpointServerRecord[zGroup][i] = g_fCheckpointTimesNew[zGroup][client][i];
					}
					g_bCheckpointRecordFound[zGroup] = true;
				}

				if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client] && !g_bNewReplay[client])
				{
					g_bNewReplay[client] = true;
					g_fReplayTimes[0] = g_fFinalTime[client];
					SaveRecording(client, 0);
				}
			}
		}
		else
		{  // Has to be the new record, since it is the first completion
			if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client] && !g_bNewReplay[client])
			{
				g_fReplayTimes[0] = g_fFinalTime[client];
				g_bNewReplay[client] = true;
				SaveRecording(client, 0);
			}
			g_bMapSRVRecord[client] = true;
			g_fRecordMapTime = g_fFinalTime[client];
			Format(g_szRecordPlayer, MAX_NAME_LENGTH, "%s", szName);
			FormatTimeFloat(1, g_fRecordMapTime, 3, g_szRecordMapTime, 64);

			// Insert latest record
			db_InsertLatestRecords(g_szSteamID[client], szName, g_fFinalTime[client]);

			// Update Checkpoints
			if (g_bCheckpointsEnabled[client] && !g_bPositionRestored[client])
			{
				for (int i = 0; i < CPLIMIT; i++)
				{
					g_fCheckpointServerRecord[zGroup][i] = g_fCheckpointTimesNew[zGroup][client][i];
				}
				g_bCheckpointRecordFound[zGroup] = true;
			}

			// Remove SR diff since there was no record
			Format(g_szSRTimeDifference[client], sizeof(szSRDiff), "N/A", szSRDiff);
		}


		// Check for personal record
		if (g_fPersonalRecord[client] == 0.0)
		{  // Clients first record
			g_fPersonalRecord[client] = g_fFinalTime[client];
			g_pr_finishedmaps[client]++;
			g_MapTimesCount++;
			FormatTimeFloat(1, g_fPersonalRecord[client], 3, g_szPersonalRecord[client], 64);

			g_bMapFirstRecord[client] = true;
			g_pr_showmsg[client] = true;
			db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);

			db_selectRecord(client);
		}
		else if (diff > 0.0)
		{  // Client's new record
			g_fPersonalRecord[client] = g_fFinalTime[client];
			if (GetConVarInt(g_hExtraPoints) > 0)
				g_pr_multiplier[client] += 1; // Improved time, increase multip
			FormatTimeFloat(1, g_fPersonalRecord[client], 3, g_szPersonalRecord[client], 64);

			g_bMapPBRecord[client] = true;
			g_pr_showmsg[client] = true;
			db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);

			db_selectRecord(client);

		}

		if (!g_bMapSRVRecord[client] && !g_bMapFirstRecord[client] && !g_bMapPBRecord[client])
		{
			// for ck_min_rank_announce
			db_currentRunRank(client);
		}

		//Challenge
		if (g_bChallenge[client])
		{
			char szNameOpponent[MAX_NAME_LENGTH];

			SetEntityRenderColor(client, 255, 255, 255, 255);
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i) && i != client && i != g_RecordBot)
				{
					if (StrEqual(g_szSteamID[i], g_szChallenge_OpponentID[client]))
					{
						g_bChallenge[client] = false;
						g_bChallenge[i] = false;
						SetEntityRenderColor(i, 255, 255, 255, 255);
						db_insertPlayerChallenge(client);
						GetClientName(i, szNameOpponent, MAX_NAME_LENGTH);
						for (int k = 1; k <= MaxClients; k++)
							if (IsValidClient(k))
								PrintToChat(k, "%t", "ChallengeW", RED, WHITE, MOSSGREEN, szName, WHITE, MOSSGREEN, szNameOpponent, WHITE);

						if (g_Challenge_Bet[client] > 0)
						{
							int lostpoints = g_Challenge_Bet[client] * g_pr_PointUnit;
							for (int j = 1; j <= MaxClients; j++)
								if (IsValidClient(j))
									PrintToChat(j, "%t", "ChallengeL", MOSSGREEN, WHITE, PURPLE, szNameOpponent, GRAY, RED, lostpoints, GRAY);
							CreateTimer(0.5, UpdatePlayerProfile, i, TIMER_FLAG_NO_MAPCHANGE);
							g_pr_showmsg[client] = true;
						}

						break;
					}
				}
			}
		}
		CS_SetClientAssists(client, 100);
	}
	else
	/*====================================
	=            Handle bonus            =
	====================================*/
	{
		if (GetConVarBool(g_hReplaceReplayTime) && (g_fFinalTime[client] < g_fReplayTimes[zGroup] || g_fReplayTimes[zGroup] == 0.0))
		{

		}
		char szDiff[54];
		char szSRDiff[54];
		float diff;
		float srdiff;

		// Record bools init
		g_bBonusFirstRecord[client] = false;
		g_bBonusPBRecord[client] = false;
		g_bBonusSRVRecord[client] = false;

		g_OldMapRankBonus[zGroup][client] = g_MapRankBonus[zGroup][client];

		diff = g_fPersonalRecordBonus[zGroup][client] - g_fFinalTime[client];
		FormatTimeFloat(client, diff, 3, szDiff, sizeof(szDiff));
		if (diff > 0.0)
			Format(g_szBonusTimeDifference[client], sizeof(szDiff), "-%s", szDiff);
		else
			Format(g_szBonusTimeDifference[client], sizeof(szDiff), "+%s", szDiff);


		srdiff = g_fBonusFastest[zGroup] - g_fFinalTime[client];
		FormatTimeFloat(client, srdiff, 3, szSRDiff, sizeof(szSRDiff));

		if (srdiff > 0.0)
			Format(g_szBonusSRTimeDifference[client], sizeof(szSRDiff), "%c-%s", GREEN, szSRDiff);
		else
			Format(g_szBonusSRTimeDifference[client], sizeof(szSRDiff), "%c+%s", RED, szSRDiff);

		g_tmpBonusCount[zGroup] = g_iBonusCount[zGroup];

		if (g_iBonusCount[zGroup] > 0)
		{  // If the server already has a record
			if (g_fFinalTime[client] < g_fBonusFastest[zGroup])
			{  // New fastest time in current bonus
				g_fOldBonusRecordTime[zGroup] = g_fBonusFastest[zGroup];
				g_fBonusFastest[zGroup] = g_fFinalTime[client];
				g_fRecordStartSpeed[zGroup] = g_fPlayerCurrentStartSpeed[client][1];
				Format(g_szBonusFastest[zGroup], MAX_NAME_LENGTH, "%s", szName);
				FormatTimeFloat(1, g_fBonusFastest[zGroup], 3, g_szBonusFastestTime[zGroup], 64);

				// Update Checkpoints
				if (g_bCheckpointsEnabled[client] && !g_bPositionRestored[client])
				{
					for (int i = 0; i < CPLIMIT; i++)
					{
						g_fCheckpointServerRecord[zGroup][i] = g_fCheckpointTimesNew[zGroup][client][i];
					}
					g_bCheckpointRecordFound[zGroup] = true;
				}

				g_bBonusSRVRecord[client] = true;
				if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client] && !g_bNewBonus[client])
				{
					g_bNewBonus[client] = true;
					g_fReplayTimes[zGroup] = g_fFinalTime[client];
					SaveRecording(client, zGroup);
				}
			}
		}
		else
		{  // Has to be the new record, since it is the first completion
			if (GetConVarBool(g_hReplayBot) && !g_bPositionRestored[client] && !g_bNewBonus[client])
			{
				g_bNewBonus[client] = true;
				g_fReplayTimes[zGroup] = g_fFinalTime[client];
				SaveRecording(client, zGroup);
			}

			g_fOldBonusRecordTime[zGroup] = g_fBonusFastest[zGroup];
			g_fBonusFastest[zGroup] = g_fFinalTime[client];
			g_fRecordStartSpeed[zGroup] = g_fPlayerCurrentStartSpeed[client][1];
			Format(g_szBonusFastest[zGroup], MAX_NAME_LENGTH, "%s", szName);
			FormatTimeFloat(1, g_fBonusFastest[zGroup], 3, g_szBonusFastestTime[zGroup], 64);

			// Update Checkpoints
			if (g_bCheckpointsEnabled[client] && !g_bPositionRestored[client])
			{
				for (int i = 0; i < CPLIMIT; i++)
				{
					g_fCheckpointServerRecord[zGroup][i] = g_fCheckpointTimesNew[zGroup][client][i];
				}
				g_bCheckpointRecordFound[zGroup] = true;
			}

			g_bBonusSRVRecord[client] = true;

			g_fOldBonusRecordTime[zGroup] = g_fBonusFastest[zGroup];

			// Remove SR diff since the bonus didn't had any record
			Format(g_szBonusSRTimeDifference[client], sizeof(szSRDiff), "N/A", szSRDiff);
		}


		if (g_fPersonalRecordBonus[zGroup][client] == 0.0)
		{  // Clients first record
			g_fPersonalRecordBonus[zGroup][client] = g_fFinalTime[client];
			g_fPlayerRectStartSpeed[client][zGroup] = g_fPlayerCurrentStartSpeed[client][1];
			FormatTimeFloat(1, g_fPersonalRecordBonus[zGroup][client], 3, g_szPersonalRecordBonus[zGroup][client], 64);

			g_bBonusFirstRecord[client] = true;
			g_pr_showmsg[client] = true;
			db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);
			db_insertBonus(client, g_szSteamID[client], szName, g_fFinalTime[client], zGroup);
		}
		else if (diff > 0.0)
		{  // client's new record
			g_fPersonalRecordBonus[zGroup][client] = g_fFinalTime[client];
			FormatTimeFloat(1, g_fPersonalRecordBonus[zGroup][client], 3, g_szPersonalRecordBonus[zGroup][client], 64);

			g_bBonusPBRecord[client] = true;
			g_pr_showmsg[client] = true;
			db_UpdateCheckpoints(client, g_szSteamID[client], zGroup);
			db_updateBonus(client, g_szSteamID[client], szName, g_fFinalTime[client], zGroup);
		}


		if (!g_bBonusSRVRecord[client] && !g_bBonusFirstRecord[client] && !g_bBonusPBRecord[client])
		{
			db_currentBonusRunRank(client, zGroup);
			/*// Not any kind of a record
			if (GetConVarInt(g_hAnnounceRecord) == 0 && (g_MapRankBonus[zGroup][client] <= GetConVarInt(g_hAnnounceRank) || GetConVarInt(g_hAnnounceRank) == 0))
	 			PrintToChatAll("%t", "BonusFinished1", MOSSGREEN, WHITE, LIMEGREEN, szName, GRAY, YELLOW, g_szZoneGroupName[zGroup], GRAY, RED, szTime, GRAY, RED, szDiff, GRAY, LIMEGREEN, g_MapRankBonus[zGroup][client], GRAY, g_iBonusCount[zGroup], LIMEGREEN, g_szBonusFastestTime[zGroup], GRAY);
			else
			{
				if (IsValidClient(client))
		 			PrintToChat(client, "%t", "BonusFinished1", MOSSGREEN, WHITE, LIMEGREEN, szName, GRAY, YELLOW, g_szZoneGroupName[zGroup], GRAY, RED, szTime, GRAY, RED, szDiff, GRAY, LIMEGREEN, g_MapRankBonus[zGroup][client], GRAY, g_iBonusCount[zGroup], LIMEGREEN, g_szBonusFastestTime[zGroup], GRAY);
			}*/
		}
	}

	Client_Stop(client, 1);
	db_deleteTmp(client);

	//set mvp star
	g_MVPStars[client] += 1;
	CS_SetMVPCount(client, g_MVPStars[client]);
}



public void StartStageTimer(int client)
{
	if (IsFakeClient(client) || !g_bhasStages)
		return;

	if (g_bNoclipped[client] || g_bNoClip[client] || (!g_bNoClip[client] && (GetGameTime() - g_fLastTimeNoClipUsed[client]) < 3.0))
	{
		PrintToChat(client, "[%cSurf Timer%c] %cYou are noclipping or have noclipped recently%c, stage timer disabled. Type %c!back %cto enable timer again.", MOSSGREEN, WHITE, LIGHTRED, WHITE, LIMEGREEN, WHITE);
		return;
	}

	if (g_bPracticeMode[client])
		return;

	int stage = g_Stage[0][client];

	float vPlayerVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vPlayerVelocity);

	if (g_fLastSpeed[client] > g_fStageMaxVelocity[stage] && g_fStageMaxVelocity[stage] > 0)
	{
		PrintToChat(client, "[%cSurf Timer%c] %cMax velocity exceeded to start stage %d.", MOSSGREEN, WHITE, LIGHTRED, g_Stage[0][client]);
		return;
	}

	if (g_PlayerJumpsInStage[client] > 1 && !g_bStageIgnorePrehop[stage])
	{
		PrintToChat(client, "[%cSurf Timer%c] %cPrehopping is not allowed on the stage records.", MOSSGREEN, WHITE, LIGHTRED);
		return;
	}

	Action result;
	Call_StartForward(g_OnTimerStartedForward);
	Call_PushCell(client);
	Call_PushCell(RT_Stage);

	Call_Finish(result);

	if (result == Plugin_Handled)
		return;

	g_bStageTimerRunning[client] = true;
	g_fStageStartTime[client] = GetGameTime();

	// Get player velocity
	float vecPlayerVelocity[3], fPlayerVelocity;

	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecPlayerVelocity);
	fPlayerVelocity = GetVectorLength(vecPlayerVelocity);

	g_fPlayerCurrentStartSpeed[client][stage] = fPlayerVelocity;

	// Build Speed difference message
	char speedDiffMsg[128];

	Format(speedDiffMsg, sizeof(speedDiffMsg), "[%cSurf Timer%c] Stage: %c%d %cu/s", MOSSGREEN, WHITE, YELLOW, RoundToCeil(fPlayerVelocity), WHITE);

	if (g_fPlayerStageRecStartSpeed[client][stage] != -1)
	{
		float fDiff = fPlayerVelocity - g_fPlayerStageRecStartSpeed[client][stage];
		char srDiff[16];

		if (fDiff < 0)
			Format(srDiff, sizeof(srDiff), "%c%d%c u/s", RED, RoundToCeil(fDiff), WHITE);
		else
			Format(srDiff, sizeof(srDiff), "%c+%d%c u/s", LIMEGREEN, RoundToCeil(fDiff), WHITE);

		Format(speedDiffMsg, sizeof(speedDiffMsg), "%s | PB: %s", speedDiffMsg, srDiff);
	}

	if (g_StageRecords[stage][srStartSpeed] != -1)
	{
		// Get difference between server record 
		float fDiff = fPlayerVelocity - g_StageRecords[stage][srStartSpeed];
		char srDiff[16];

		if (fDiff < 0)
			Format(srDiff, sizeof(srDiff), "%c%d%c u/s", RED, RoundToCeil(fDiff), WHITE);
		else
			Format(srDiff, sizeof(srDiff), "%c+%d%c u/s", LIMEGREEN, RoundToCeil(fDiff), WHITE);

		Format(speedDiffMsg, sizeof(speedDiffMsg), "%s | SR: %s", speedDiffMsg, srDiff);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		if (GetClientTeam(i) != CS_TEAM_SPECTATOR)
			continue;

		int ObserverMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
		if (ObserverMode != 4 && ObserverMode != 5)
			continue;
			
		int ObserverTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
			if (ObserverTarget != client)
				continue;

		PrintToChat(i, speedDiffMsg);
	}

	PrintToChat(client, speedDiffMsg);
}


public void EndStageTimer(int client)
{
	if (IsFakeClient(client))
		return;

	// Make sure the player is not on the bonus
	if (g_iClientInZone[client][2] != 0)
		return;

	if (!g_bStageTimerRunning[client])
		return;

	// get final timer
	float final_time = GetGameTime();

	g_bStageTimerRunning[client] = false;

	// Calculate run time
	float runtime = final_time - g_fStageStartTime[client];


	int stage = g_Stage[0][client];


	// Get formatted run time
	char runtime_str[32];
	FormatTimeFloat(client, runtime, 5, runtime_str, sizeof(runtime_str));


	// Get record diff
	float srdiff = g_StageRecords[stage][srRunTime] - runtime;
	float pbdiff = g_fStagePlayerRecord[client][stage] - runtime;
	char srdiff_str[32], pbdiff_str[32];

	FormatTimeFloat(client, srdiff, 5, srdiff_str, sizeof(srdiff_str));
	FormatTimeFloat(client, pbdiff, 5, pbdiff_str, sizeof(pbdiff_str));

	if (g_StageRecords[stage][srRunTime] != 9999999.0)
	{
		if (srdiff > 0)	
			Format(srdiff_str, sizeof(srdiff_str), "-%s", srdiff_str);
		else
			Format(srdiff_str, sizeof(srdiff_str), "+%s", srdiff_str);
	}
	else if (!g_StageRecords[stage][srLoaded])
		Format(srdiff_str, sizeof(srdiff_str), "N/A");
	else
	{
		Format(srdiff_str, sizeof(srdiff_str), "Not loaded");
		db_loadStageServerRecords(stage);
	}

	if (g_fStagePlayerRecord[client][stage] != 9999999.0)
	{
		if (pbdiff > 0) Format(pbdiff_str, sizeof(pbdiff_str), "-%s", pbdiff_str);
		else
			Format(pbdiff_str, sizeof(pbdiff_str), "+%s", pbdiff_str);
	}
	else
		Format(pbdiff_str, sizeof(pbdiff_str), "N/A");

	// Check if the player beaten the record
	if (g_StageRecords[stage][srRunTime] > runtime)
	{
		
		// Check if the stage records were loaded before sending the message
		if (!g_bLoadingStages) {
			// Send message to all players
			PrintToChatAll("[%cSurf Timer%c] %c%N %chas beaten the %cstage %d record %cin %c%s %c(PB: %s) (SR: %s) ", MOSSGREEN, WHITE, LIMEGREEN, client, YELLOW, LIMEGREEN, stage, YELLOW, LIMEGREEN, runtime_str, YELLOW, pbdiff_str, srdiff_str);

			// Play sound to everyone
			for (int i = 1; i <= MaxClients; i++)
				if (IsClientConnected(i) && IsValidClient(i) && !IsFakeClient(i))
					ClientCommand(i, "play buttons\\blip2");
		}

		if (g_fStagePlayerRecord[client][stage] != 9999999.0)
			db_updateStageRecord(client, stage, runtime);
		else
			db_insertStageRecord(client, stage, runtime);

		// Get player name
		char name[45];
		GetClientName(client, name, sizeof(name));

		strcopy(g_StageRecords[stage][srPlayerName], sizeof(name), name);
		g_StageRecords[stage][srRunTime] = runtime;
		g_StageRecords[stage][srLoaded] = true;
		g_StageRecords[stage][srStartSpeed] = g_fPlayerCurrentStartSpeed[client][stage];

		g_fStagePlayerRecord[client][stage] = runtime;

		Stage_SaveRecording(client, stage, runtime_str);

		g_fPlayerStageRecStartSpeed[client][stage] = g_fPlayerCurrentStartSpeed[client][stage];

	}
	else if (g_fStagePlayerRecord[client][stage] > runtime)
	{
		// Player beaten his own record

		PrintToChat(client, "[%cSurf Timer%c] %cFinished the %cstage %d %cin %c%s %c(PB: %s) (SR: %s) ", MOSSGREEN, WHITE, YELLOW, LIMEGREEN, stage, YELLOW, LIMEGREEN, runtime_str, YELLOW, pbdiff_str, srdiff_str);

		if (g_fStagePlayerRecord[client][stage] != 9999999.0)
			db_updateStageRecord(client, stage, runtime);
		else
			db_insertStageRecord(client, stage, runtime);

		g_fStagePlayerRecord[client][stage] = runtime;
		g_fPlayerStageRecStartSpeed[client][stage] = g_fPlayerCurrentStartSpeed[client][stage];
	}
	else
	{
		// missed sr and pb
		PrintToChat(client, "[%cSurf Timer%c] %cFinished the %cstage %d %cin %c%s %c(PB: %s) (SR: %s) ", MOSSGREEN, WHITE, YELLOW, LIMEGREEN, stage, YELLOW, LIMEGREEN, runtime_str, YELLOW, pbdiff_str, srdiff_str);
		return;
	}

}
