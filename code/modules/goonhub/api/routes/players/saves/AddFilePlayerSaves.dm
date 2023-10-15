
/// POST /players/saves/file
/// Add player save
/datum/apiRoute/players/saves/file/post
	method = RUSTG_HTTP_METHOD_POST
	path = "/players/saves/file"
	body = /datum/apiBody/PlayerSavesData
	correct_response = /datum/apiModel/Tracked/PlayerRes/PlayerSaveResource

	buildBody(
		player_id,
		key,
		value
	)
		. = ..(args)

