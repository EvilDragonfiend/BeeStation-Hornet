//Wakes the user so they are able to do their thing. Also injects a decent dose of radium.
//Movement impairing would indicate drugs and the like.
/obj/item/clothing/suit/space/space_ninja/proc/ninjaboost()

	if(!ninjacost(0,N_ADRENALINE))
		var/mob/living/carbon/human/H = affecting
		H.SetUnconscious(0)
		H.SetStun(0)
		H.SetKnockdown(0)
		H.SetImmobilized(0)
		H.SetParalyzed(0)
		H.adjustStaminaLoss(-75)
		H.stuttering = 0
		H.update_mobility()
		var/datum/reagents/mob_reagent_holder = H.get_reagent_holder()
		mob_reagent_holder.add_reagent(/datum/reagent/medicine/amphetamine, 5)
		H.say(pick("A CORNERED FOX IS MORE DANGEROUS THAN A JACKAL!","HURT ME MOOORRREEE!","IMPRESSIVE!"), forced = "ninjaboost")
		a_boost--
		to_chat(H, "<span class='notice'>There are <B>[a_boost]</B> adrenaline boosts remaining.</span>")
		s_coold = 6
		addtimer(CALLBACK(src, PROC_REF(ninjaboost_after)), 70)

/obj/item/clothing/suit/space/space_ninja/proc/ninjaboost_after()
	var/mob/living/carbon/human/H = affecting
	var/datum/reagents/mob_reagent_holder = H.get_reagent_holder()
	mob_reagent_holder.add_reagent(/datum/reagent/uranium/radium, a_transfer)
	to_chat(H, "<span class='danger'>You are beginning to feel the after-effect of the injection.</span>")
