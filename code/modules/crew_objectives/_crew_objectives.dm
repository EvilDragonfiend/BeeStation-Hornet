/datum/controller/subsystem/job/proc/give_crew_objective(datum/mind/crewMind, mob/M)
	if(CONFIG_GET(flag/allow_crew_objectives) && ((M?.client?.prefs.toggles2 & PREFTOGGLE_2_CREW_OBJECTIVES) || (crewMind?.current?.client?.prefs.toggles2 & PREFTOGGLE_2_CREW_OBJECTIVES)))
		generate_individual_objectives(crewMind)
	return

/datum/controller/subsystem/job/proc/generate_individual_objectives(datum/mind/crewMind)
	if(!(CONFIG_GET(flag/allow_crew_objectives)))
		return
	if(!crewMind)
		return
	if(!crewMind.current || crewMind.get_mind_role(JTYPE_SPECIAL))
		return
	if(!crewMind.get_mind_role(JTYPE_JOB_PATH, as_basic_job=TRUE))
		return
	var/list/valid_objs = crew_obj_jobs["[crewMind.get_mind_role(JTYPE_JOB_PATH, as_basic_job=TRUE)]"]
	if(!length(valid_objs))
		return
	var/selectedObj = pick(valid_objs)
	crewMind.add_crew_objective(selectedObj)

/// Adds a new crew objective of objective_type and informs the player (should be a subtype of /datum/objective/crew)
/datum/mind/proc/add_crew_objective(objective_type, silent = FALSE)
	var/datum/objective/crew/newObjective = new objective_type
	if(!newObjective)
		return
	newObjective.owner = src
	src.crew_objectives += newObjective
	if(!silent)
		to_chat(src, "<B>As a part of Nanotrasen's anti-tide efforts, you have been assigned an optional objective. It will be checked at the end of the shift. <span class='warning'>Performing traitorous acts in pursuit of your objective may result in termination of your employment.</span></B>")
		to_chat(src, "<B>Your objective:</B> [newObjective.explanation_text]")

/datum/objective/crew
	// Used for showing the roundend report again, instead of checking complete every time it's opened.
	var/declared_complete = FALSE
	// List or string of JOB_NAME defines that this applies to.
	var/jobs
	explanation_text = "Yell at people on github if this ever shows up. Something involving crew objectives is broken."
