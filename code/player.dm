/// for client variables and stuff that has to persist between connections
/datum/player
	/// the ID of the player as provided by the Goonhub API
	var/id = 0
	/// the key of the client object that this datum is attached to
	var/key
	/// the ckey of the client object that this datum is attached to
	var/ckey
	/// the client object that this datum is attached to
	var/client/client
	/// are they a mentor?
	var/mentor = 0
	/// do we want to see mentor pms?
	var/see_mentor_pms = 1
	/// to make sure that they cant escape being shamecubed by just reconnecting
	var/shamecubed = 0
	/// how many rounds (total) theyve declared ready and joined, null with to differentiate between not set and no participation
	var/rounds_participated = null
	/// how many rounds (rp only) theyve declared ready and joined, null with to differentiate between not set and no participation
	var/rounds_participated_rp = null
	/// how many rounds (total) theyve joined to at least the lobby in, null to differentiate between not set and not seen
	var/rounds_seen = null
	/// how many rounds (rp only) theyve joined to at least the lobby in, null to differentiate between not set and not seen
	var/rounds_seen_rp = null
	/// timestamp of when they were last seen
	var/last_seen = null
	/// a list of cooldowns that has to persist between connections
	var/list/cooldowns = null
	/// position of client in in global.clients
	var/clients_pos = null
	/// the server time that this player joined the game, in 1/10ths of a second
	var/round_join_time = null
	/// the server time that this player left the game, in 1/10ths of a second
	var/round_leave_time = null
	/// the total time that this player has been playing the game this round, in 1/10ths of a second
	var/current_playtime = null
	/// Cache jobbans here to speed things up massively
	var/list/cached_jobbans = null
	/// Manager for cloud data and saves
	var/datum/cloudSaves/cloudSaves = null
	/// buildmode holder of our client so it doesn't need to get rebuilt every time we reconnect
	var/datum/buildmode_holder/buildmode = null
	/// whether this person is a temporary admin (this round only)
	var/tempmin = FALSE
	/// whteher this person is a permanent admin
	var/perm_admin = FALSE
	/// whether this person set DNR (Do not revive)
	var/dnr = FALSE
	/// keep track of whether this player joined round as an observer (blocks them from bank payouts)
	var/joined_observer = FALSE
	/// Last time this person died (used for critter respawns)
	var/last_death_time
	/// real_names this person has joined as
	var/joined_names = list()

	/// sets up vars, caches player stats, adds by_type list entry for this datum
	New(key)
		..()
		START_TRACKING
		src.key = key
		src.ckey = ckey(key)
		src.tag = "player-[src.ckey]"
		src.cloudSaves = new /datum/cloudSaves(src)

		if (ckey(src.key) in mentors)
			src.mentor = 1

		if (src.key) //just a safety check!
			src.cache_round_stats()
		src.last_death_time = world.timeofday

	/// removes by_type list entry for this datum, clears dangling references
	disposing()
		STOP_TRACKING
		if (src.client)
			src.client.player = null
			src.client = null
		..()

	/// Record a player login via the API. Sets player ID field for future API use
	proc/record_login()
		if (!roundId || !src.client || src.id) return
		var/datum/apiModel/Tracked/PlayerResource/playerResponse
		try
			var/datum/apiRoute/players/login/playerLogin = new
			playerLogin.buildBody(
				src.client.ckey,
				src.client.key,
				src.client.address ? src.client.address : "127.0.0.1", // fallback for local dev
				src.client.computer_id,
				src.client.byond_version,
				src.client.byond_build,
				roundId
			)
			playerResponse = apiHandler.queryAPI(playerLogin)
		catch (var/exception/e)
			var/datum/apiModel/Error/error = e.name
			logTheThing(LOG_DEBUG, null, "Failed to record a player login for [src.client.ckey] because: [error.message]")
			logTheThing(LOG_DIARY, null, "Failed to record a player login for [src.client.ckey] because: [error.message]", "admin")
			return

		src.id = playerResponse.id

	/// queries api to cache stats so its only done once per player per round
	proc/cache_round_stats()
		set waitfor = FALSE
		. = cache_round_stats_blocking()

	/// blocking version of cache_round_stats, queries api to cache stats so its only done once per player per round (please update this proc when adding more player stat vars)
	proc/cache_round_stats_blocking()
		var/datum/apiModel/Tracked/PlayerStatsResource/playerStats
		try
			var/datum/apiRoute/players/stats/get/getPlayerStats = new
			getPlayerStats.queryParams = list("ckey" = src.ckey)
			playerStats = apiHandler.queryAPI(getPlayerStats)
		catch
			return FALSE

		src.rounds_participated = text2num(playerStats.played)
		src.rounds_participated_rp = text2num(playerStats.played_rp)
		src.rounds_seen = text2num(playerStats.connected)
		src.rounds_seen_rp = text2num(playerStats.connected_rp)
		src.last_seen = playerStats.latest_connection.created_at
		return TRUE

	/// returns an assoc list of cached player stats (please update this proc when adding more player stat vars)
	proc/get_round_stats(allow_blocking = FALSE)
		if ((isnull(src.rounds_participated) || isnull(src.rounds_seen) || isnull(src.rounds_participated_rp) || isnull(src.rounds_seen_rp) || isnull(src.last_seen))) //if the stats havent been cached yet
			if (allow_blocking) // whether or not we are OK with possibly sleeping the thread
				if (!src.cache_round_stats_blocking())
					return null
			else
				if (!src.cache_round_stats()) //if trying to set them fails
					return null
		return list("participated" = src.rounds_participated, "seen" = src.rounds_seen, "participated_rp" = src.rounds_participated_rp, "seen_rp" = src.rounds_seen_rp, "last_seen" = src.last_seen)

	/// returns the number of rounds that the player has played by joining in at roundstart
	proc/get_rounds_participated()
		if (isnull(src.rounds_participated)) //if the stats havent been cached yet
			if (!src.cache_round_stats()) //if trying to set them fails
				return null
		return src.rounds_participated

	proc/get_rounds_participated_rp()
		if (isnull(src.rounds_participated_rp)) //if the stats havent been cached yet
			if (!src.cache_round_stats()) //if trying to set them fails
				return null
		return src.rounds_participated_rp

	/// returns the number of rounds that the player has at least joined the lobby in
	proc/get_rounds_seen()
		if (isnull(src.rounds_seen)) //if the stats havent been cached yet
			if (!src.cache_round_stats()) //if trying to set them fails
				return null
		return src.rounds_seen

	/// sets the join time to the current server time, in 1/10ths of a second
	proc/log_join_time()
		src.round_join_time = TIME

	/// sets the leave time to the current server time, in 1/10ths of a second
	proc/log_leave_time()
		src.round_leave_time = TIME
		src.calculate_played_time()

	/// adds the calculated playtime (in 1/10ths of a second) to the playtime variable
	proc/calculate_played_time()
		if (isnull(src.round_join_time) || isnull(src.round_leave_time)) //acts as a safety, in case we call log_leave_time without setting a join time (end of round usually)
			return
		src.current_playtime += (src.round_leave_time - round_join_time)
		src.round_leave_time = null //reset this - null value is important
		src.round_join_time = null //reset this - null value is important

	proc/get_buildmode()
		RETURN_TYPE(/datum/buildmode_holder)
		if(src.buildmode)
			return src.buildmode
		var/saved_buildmode = src.cloudSaves.getData("buildmode")
		if(!saved_buildmode)
			src.buildmode = new /datum/buildmode_holder(src.client)
		else
			var/savefile/save = new
			save.ImportText("/", saved_buildmode)
			save.eof = 0
			try
				save["buildmode"] >> src.buildmode
			catch(var/exception/e)
				stack_trace("loading buildmode error\n[e.name]\n[e.desc]")
				boutput(src.client, SPAN_INTERNAL("Loading your buildmode failed. Check runtime log for details."))
				qdel(src.buildmode)
				src.buildmode = new /datum/buildmode_holder(src.client)
			if(isnull(src.buildmode))
				boutput(src.client, SPAN_INTERNAL("Loading your buildmode failed. No clue why."))
				src.buildmode = new /datum/buildmode_holder(src.client)
			if(isnull(src.buildmode.owner))
				src.buildmode.set_client(src.client)
		return src.buildmode

	proc/on_round_end()
		if(src.buildmode)
			var/savefile/S = new
			S["buildmode"] << buildmode
			src.cloudSaves.putData("buildmode", S.ExportText())

	/// Gives this player a medal. Will not sleep, but does not have a return value. Use unlock_medal_sync if you need to know if it worked
	proc/unlock_medal(medal_name, announce=FALSE)
		set waitfor = 0
		src.unlock_medal_sync(medal_name, announce)

	/// Gives this player a medal. Will sleep, make sure the proc calling this is in a spawn etc
	proc/unlock_medal_sync(medal_name, announce=FALSE)
		if (IsGuestKey(src.ckey) || !config || !config.medal_hub || !config.medal_password)
			return FALSE

		var/key = src.key
		var/displayed_key = src.client?.mob?.mind?.displayed_key || src.key
		var/result = world.SetMedal(medal_name, key, config.medal_hub, config.medal_password)
		if(!result)
			return FALSE
		. = TRUE

		var/list/unlocks = list()
		for(var/A in rewardDB)
			var/datum/achievementReward/D = rewardDB[A]
			if (D.required_medal == medal_name)
				unlocks.Add(D)

		if (announce)
			boutput(world, "<span class='medal'>[displayed_key] earned the [medal_name] medal!</span>")
		else if (src.client)
			boutput(src.client, "<span class='medal'>You earned the [medal_name] medal!</span>")

		if (length(unlocks))
			for(var/datum/achievementReward/B in unlocks)
				boutput(src.client, "<span class='medal'><FONT FACE=Arial SIZE=+1>You've unlocked a Reward : [B.title]!</FONT></span>")

	/// Removes a medal from this player. Will sleep, make sure the proc calling this is in a spawn etc
	proc/clear_medal(medal_name)
		if (IsGuestKey(src.ckey) || !config || !config.medal_hub || !config.medal_password)
			return null
		return world.ClearMedal(medal_name, src.key, config.medal_hub, config.medal_password)

	/// Checks if this player has a medal. Will sleep, make sure the proc calling this is in a spawn etc
	proc/has_medal(medal_name)
		if (IsGuestKey(src.ckey) || !config || !config.medal_hub || !config.medal_password)
			return
		return world.GetMedal(medal_name, src.key, config.medal_hub, config.medal_password)

	/// Returns a list of all medals of this player. Will sleep, make sure the proc calling this is in a spawn etc
	proc/get_all_medals()
		RETURN_TYPE(/list)
		if (!config || !config.medal_hub || !config.medal_password)
			return
		. = world.GetMedal("", src.key, config.medal_hub, config.medal_password)
		if(isnull(.))
			return
		. = params2list(.)

/// returns a reference to a player datum based on the ckey you put into it
/proc/find_player(key)
	RETURN_TYPE(/datum/player)
	var/datum/player/player = locate("player-[ckey(key)]")
	return player

/// returns a reference to a player datum, but it tries to make a new one if it cant an already existing one (this is how it persists between connections)
/proc/make_player(key)
	RETURN_TYPE(/datum/player)
	var/datum/player/player = find_player(key) // just double check so that we don't get any dupes
	if (!player)
		player = new(key)
	return player
