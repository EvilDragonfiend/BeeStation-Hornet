#define DEFAULT_ALERT "alert_sound"

/proc/priority_announce(text, title = "", sound = DEFAULT_ALERT, type, sender_override, has_important_message, auth_id)
	if(!text)
		return

	var/announcement = "<meta charset='UTF-8'>"
	if(sound == DEFAULT_ALERT)
		sound = SSstation.announcer.get_rand_alert_sound()

	if(sound && SSstation.announcer.event_sounds[sound])
		sound = SSstation.announcer.event_sounds[sound]

	if(type == "Priority")
		announcement += "<h1 class='alert'>Priority Announcement</h1>"
		if (title && length(title) > 0)
			announcement += "<br><h2 class='alert'>[html_encode(title)]</h2>"
	else if(type == JOB_KEY_CAPTAIN)
		announcement += "<h1 class='alert'>[JOB_NAME_CAPTAIN] Announces</h1>"
		GLOB.news_network.submit_article(html_encode(text), "[JOB_NAME_CAPTAIN]'s Announcement", "Station Announcements", null)

	else
		if(!sender_override)
			announcement += "<h1 class='alert'>[command_name()] Update</h1>"
		else
			announcement += "<h1 class='alert'>[sender_override]</h1>"
		if (title && length(title) > 0)
			announcement += "<br><h2 class='alert'>[html_encode(title)]</h2>"

		if(!sender_override)
			if(title == "")
				GLOB.news_network.submit_article(text, "Central Command Update", "Station Announcements", null)
			else
				GLOB.news_network.submit_article(title + "<br><br>" + text, "Central Command", "Station Announcements", null)

	///If the announcer overrides alert messages, use that message.
	if(SSstation.announcer.custom_alert_message && !has_important_message)
		announcement +=  SSstation.announcer.custom_alert_message
	else
		announcement += "<br><span class='alert'>[html_encode(text)]</span><br>"
	announcement += "<br>"
	if(auth_id)
		announcement += "<span class='alert'>-[auth_id]</span><br>"

	var/s = sound(sound)
	for(var/mob/M in GLOB.player_list)
		if(!isnewplayer(M) && M.can_hear())
			to_chat(M, announcement)
			if(M.client.prefs.toggles & PREFTOGGLE_SOUND_ANNOUNCEMENTS)
				SEND_SOUND(M, s)

/proc/exploration_announce(text, z_value)
	var/announcement = "<meta charset='UTF-8'>"
	announcement += "<h1 class='alert'>[command_name()] Update</h1>"
	announcement += "<br><span class='alert'>[html_encode(text)]</span><br>"
	announcement += "<br>"

	for(var/mob/M in GLOB.player_list)
		if(isliving(M))
			var/turf/T = get_turf(M)
			if(istype(get_area(M), /area/shuttle/exploration) || T.z == z_value)
				to_chat(M, announcement)
		if(isobserver(M))
			to_chat(M, announcement)

/proc/print_command_report(text = "", title = null, announce=TRUE)
	if(!title)
		title = "Classified [command_name()] Update"

	if(announce)
		priority_announce("A report has been downloaded and printed out at all communications consoles.", "Incoming Classified Message", SSstation.announcer.get_rand_report_sound(), has_important_message = TRUE)
	var/datum/comm_message/M  = new
	M.title = title
	M.content =  text

	SScommunications.send_message(M)

/proc/minor_announce(message, title = "Attention:", alert, from, html_encode = TRUE)
	if(!message)
		return

	if (html_encode)
		title = html_encode(title)
		message = html_encode(message)

	for(var/mob/M in GLOB.player_list)
		if(!isnewplayer(M) && M.can_hear())
			var/complete_msg = "<meta charset='UTF-8'><span class='big bold'><font color = red>[title]</font color><BR>[message]</span><BR>"
			if(from)
				complete_msg += "<span class='alert'>-[from]</span>"
			to_chat(M, complete_msg)
			if(M.client.prefs.toggles & PREFTOGGLE_SOUND_ANNOUNCEMENTS)
				if(alert)
					SEND_SOUND(M, sound('sound/misc/notice1.ogg'))
				else
					SEND_SOUND(M, sound('sound/misc/notice2.ogg'))

#undef DEFAULT_ALERT
