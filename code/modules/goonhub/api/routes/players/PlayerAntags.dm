
/// POST /players/antags
/// Add a player antagonist for a given round
/datum/apiRoute/players/antags
	method = RUSTG_HTTP_METHOD_POST
	path = "/players/antags"
	body = /datum/apiBody/PlayerAntags
	correct_response = /datum/apiModel/Tracked/PlayerRes/PlayerAntagResource
