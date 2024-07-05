/client/proc/dsay(msg as text)
	set category = "Adminbus"
	set name = "Dsay"
	set hidden = 1
	if(!holder)
		to_chat(src, "Only administrators may use this command.")
		return
	if(!mob)
		return
	if(prefs.muted & MUTE_DEADCHAT)
		to_chat(src, "<span class='danger'>You cannot send DSAY messages (muted).</span>")
		return

	if (handle_spam_prevention(msg,MUTE_DEADCHAT))
		return

	msg = copytext_char(sanitize(msg), 1, MAX_MESSAGE_LEN)
	mob.log_talk(msg, LOG_DSAY)

	if (!msg)
		return
	var/rank_name = holder.rank
	var/admin_name = key
	//json_decode(rustg_file_read("[global.config.directory]/badges.json")
	if(holder.fakekey)
		rank_name = pick(strings(DSAY_NICKNAME_FILE, "ranks", CONFIG_DIRECTORY))
		admin_name = pick(strings(DSAY_NICKNAME_FILE, "names", CONFIG_DIRECTORY))
	var/rendered = "<span class='game deadsay'><span class='prefix'>DEAD:</span> <span class='name'>[rank_name]([admin_name])</span> says, <span class='message'>\"[emoji_parse(msg)]\"</span></span>"
	send_chat_to_discord(CHAT_TYPE_DEADCHAT, "[rank_name]([admin_name])", msg)

	for (var/mob/M in GLOB.player_list)
		if(isnewplayer(M))
			continue
		var/area/mob_area = get_area(M)
		if (M.stat == DEAD || (mob_area.area_flags & AREA_DEADCHAT_ALLOWED) || (M.client && M.client.holder && M.client.prefs.read_player_preference(/datum/preference/toggle/chat_dead))) //admins can toggle deadchat on and off. This is a proc in admin.dm and is only give to Administrators and above
			to_chat(M, rendered)

	SSblackbox.record_feedback("tally", "admin_verb", 1, "Dsay") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!

/client/proc/get_dead_say()
	var/msg = tgui_input_text(src, null, "dsay \"text\"", encode = FALSE) // we don't encode/sanitize here because dsay does it anyways.
	dsay(msg)
