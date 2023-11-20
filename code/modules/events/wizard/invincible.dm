/datum/round_event_control/wizard/invincible //Boolet Proof
	name = "Invincibility"
	weight = 3
	typepath = /datum/round_event/wizard/invincible
	max_occurrences = 5
	earliest_start = 0 MINUTES

/datum/round_event/wizard/invincible/start()

	for(var/mob/living/carbon/human/H in GLOB.alive_mob_list)
		var/datum/reagents/mob_reagent_holder = H.get_reagent_holder()
		mob_reagent_holder.add_reagent(/datum/reagent/medicine/adminordrazine, 40) //100 ticks of absolute invinciblity (barring gibs)
		to_chat(H, "<span class='notice'>You feel invincible, nothing can hurt you!</span>")
