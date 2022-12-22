/datum/brain_trauma/special/obsessed
	name = "Psychotic Schizophrenia"
	desc = "Patient has a subtype of delusional disorder, becoming irrationally attached to someone."
	scan_desc = "psychotic schizophrenic delusions"
	gain_text = "If you see this message, make a github issue report. The trauma initialized wrong."
	lose_text = "<span class='warning'>The voices in your head fall silent.</span>"
	can_gain = TRUE
	random_gain = FALSE
	resilience = TRAUMA_RESILIENCE_SURGERY
	var/mob/living/obsession
	var/datum/objective/spendtime/attachedobsessedobj
	var/datum/antagonist/obsessed/antagonist
	var/viewing = FALSE //it's a lot better to store if the owner is watching the obsession than checking it twice between two procs

	var/total_time_creeping = 0 //just for roundend fun
	var/time_spent_away = 0
	var/obsession_hug_count = 0

/datum/brain_trauma/special/obsessed/on_gain()

	//setup, linking, etc//
	if(!obsession)//admins didn't set one
		obsession = find_obsession()
		if(!obsession)//we didn't find one
			lose_text = ""
			qdel(src)
			return
	RegisterSignal(obsession.mind, COMSIG_MIND_CRYOED, .proc/on_obsession_cryoed)
	gain_text = "<span class='warning'>You hear a sickening, raspy voice in your head. It wants one small task of you...</span>"
	owner.mind.add_antag_datum(/datum/antagonist/obsessed)
	antagonist = owner.mind.has_antag_datum(/datum/antagonist/obsessed)
	antagonist.trauma = src
	..()
	//antag stuff//
	antagonist.forge_objectives(obsession.mind)
	antagonist.greet()

/datum/brain_trauma/special/obsessed/on_life()
	if(!obsession || obsession.stat == DEAD)
		viewing = FALSE//important, makes sure you no longer stutter when happy if you murdered them while viewing
		return
	if(get_dist(get_turf(owner), get_turf(obsession)) > 7)
		viewing = FALSE //they are further than our viewrange they are not viewing us
		out_of_view()
		return//so we're not searching everything in view every tick
	if(owner in oviewers(7, obsession))
		viewing = TRUE
	else
		viewing = FALSE
	if(viewing)
		SEND_SIGNAL(owner, COMSIG_ADD_MOOD_EVENT, "creeping", /datum/mood_event/creeping, obsession.name)
		total_time_creeping += 20
		time_spent_away = 0
		if(attachedobsessedobj)//if an objective needs to tick down, we can do that since traumas coexist with the antagonist datum
			attachedobsessedobj.timer -= 20 //mob subsystem ticks every 2 seconds(?), remove 20 deciseconds from the timer. sure, that makes sense.
	else
		out_of_view()

/datum/brain_trauma/special/obsessed/proc/out_of_view()
	time_spent_away += 20
	if(time_spent_away > 1800) //3 minutes
		SEND_SIGNAL(owner, COMSIG_ADD_MOOD_EVENT, "creeping", /datum/mood_event/notcreepingsevere, obsession.name)
	else
		SEND_SIGNAL(owner, COMSIG_ADD_MOOD_EVENT, "creeping", /datum/mood_event/notcreeping, obsession.name)

/datum/brain_trauma/special/obsessed/on_lose()
	..()

	UnregisterSignal(obsession.mind, COMSIG_MIND_CRYOED)
	antagonist?.trauma = null
	owner.mind.remove_antag_datum(/datum/antagonist/obsessed)

/datum/brain_trauma/special/obsessed/handle_speech(datum/source, list/speech_args)
	if(!viewing)
		return
	var/datum/component/mood/mood = owner.GetComponent(/datum/component/mood)
	if(mood && mood.sanity >= SANITY_GREAT && social_interaction())
		speech_args[SPEECH_MESSAGE] = ""

/datum/brain_trauma/special/obsessed/on_hug(mob/living/hugger, mob/living/hugged)
	if(hugged == obsession)
		obsession_hug_count++

/datum/brain_trauma/special/obsessed/proc/on_obsession_cryoed()
	SIGNAL_HANDLER

	UnregisterSignal(obsession.mind, COMSIG_MIND_CRYOED)
	var/message = "You get the feeling [obsession] is no longer within reach."
	obsession = find_obsession()
	if(!obsession)//we didn't find one
		lose_text = "<span class='warning'>[message] The voices in your head fall silent.</span>"
		qdel(src)
		return
	RegisterSignal(obsession.mind, COMSIG_MIND_CRYOED, .proc/on_obsession_cryoed)
	to_chat(owner, "<span class='warning'>[message] The voices have a new task for you...</span>")
	antagonist.objectives = list()
	antagonist.forge_objectives(obsession.mind)
	to_chat(owner, "<B>You don't know their connection, but The Voices compel you to stalk [obsession], forcing them into a state of constant paranoia.</B>")
	owner.mind.announce_objectives()

/datum/brain_trauma/special/obsessed/proc/social_interaction()
	var/fail = FALSE //whether you can finish a sentence while doing it
	owner.stuttering = max(3, owner.stuttering)
	owner.blur_eyes(10)
	switch(rand(1,4))
		if(1)
			shake_camera(owner, 15, 1)
			owner.vomit()
			fail = TRUE
		if(2)
			INVOKE_ASYNC(owner, /mob.proc/emote, "cough")
			owner.dizziness += 10
			fail = TRUE
		if(3)
			to_chat(owner, "<span class='userdanger'>You feel your heart lurching in your chest...</span>")
			owner.Stun(20)
			shake_camera(owner, 15, 1)
		if(4)
			to_chat(owner, "<span class='warning'>You faint.</span>")
			owner.Unconscious(80)
			fail = TRUE
	return fail


/datum/brain_trauma/special/obsessed/proc/find_obsession()
	var/list/possible_targets = list()
	for(var/mob/living/Player in GLOB.player_list)
		// these conditions are to filter mobs that isn't good for obssession.
		// prevents crewmembers falling in love with nuke ops they never met, or with monkey, silicon, sentient corgi or weird mobs
		// ------
		// putting all conditions into a single if line is difficult to read...
		if(!Player.mind)
			continue
		if(Player.stat == DEAD)
			continue
		if(isbrain(Player))
			continue
		if(!ishuman(Player)) // non-human isn't good for this...
			continue
		if(isnewplayer(Player))
			continue
		if(!Player.client)
			continue
		if(Player == owner) // don't self-obssession
			continue
		if(Player.mind.get_mind_role(JTYPE_JOB_PATH) == JOB_UNASSIGNED) // not original crew, but they can be a victim if their name is in datacore...
			var/datum/data/record/D
			if(Player.get_visible_name() != "Unknown")
				D = find_record("name", Player.get_visible_name(), GLOB.data_core.general) // [1st try] key by "visible name"
			if(!D && (Player.get_visible_name() != Player.real_name))
				D = find_record("name", Player.real_name, GLOB.data_core.general) // [2nd try] key by "real name"
			if(!D)
				D = find_record("name", Player.mind.name, GLOB.data_core.general) // [3rd try] key by "mind name"
			if(!D)
				return
		possible_targets += Player
	return length(possible_targets) ? pick(possible_targets) : FALSE
