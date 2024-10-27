#define REAGENT_AMOUNT_PER_ITEM 20 //The amount of reagents medical items contain, for both application and grinding purposes.

/obj/item/stack/medical
	name = "medical pack"
	singular_name = "medical pack"
	icon = 'icons/obj/stacks/miscellaneous.dmi'
	amount = 12
	max_amount = 12
	w_class = WEIGHT_CLASS_TINY
	full_w_class = WEIGHT_CLASS_TINY
	throw_speed = 3
	resistance_flags = FLAMMABLE
	max_integrity = 40
	novariants = FALSE
	item_flags = NOBLUDGEON
	cost = 250
	source = /datum/robot_energy_storage/medical
	merge_type = /obj/item/stack/medical
	///What reagent does it apply?
	var/list/reagent
	///Is this for bruises?
	var/heal_creatures = FALSE
	///Is this for bruises?
	var/heal_brute = FALSE
	///Is this for burns?
	var/heal_burn = FALSE
	///For how long does it stop bleeding?
	var/stop_bleeding = 0
	///How long does it take to apply on yourself?
	var/self_delay = 2 SECONDS
	/// Does this apply the self-tend effect
	var/self_tend_debuff = TRUE

CREATION_TEST_IGNORE_SUBTYPES(/obj/item/stack/medical)

/obj/item/stack/medical/Initialize(mapload, new_amount, merge, mob/user)
	. = ..()
	if(reagent)
		create_reagents(REAGENT_AMOUNT_PER_ITEM)
		reagents.add_reagent_list(reagent)

/obj/item/stack/medical/attack(mob/living/M, mob/user)
	if(!M || !user || (isliving(M) && !M.can_inject(user, TRUE))) //If no mob, user and if we can't inject the mob just return
		return

	if(M.stat == DEAD && !stop_bleeding)
		to_chat(user, "<span class='danger'>\The [M] is dead, you cannot help [M.p_them()]!</span>")
		return

	if(!iscarbon(M) && !isanimal(M))
		to_chat(user, "<span class='danger'>You don't know how to apply \the [src] to [M]!</span>")
		return

	if(M in user.do_afters) //One at a time, please.
		return

	if(isanimal(M))
		var/mob/living/simple_animal/critter = M
		if(!(critter.healable))
			to_chat(user, "<span class='notice'>You cannot use [src] on [M]!</span>")
			return
		if(critter.health == critter.maxHealth)
			to_chat(user, "<span class='notice'>[M] is at full health.</span>")
			return
		if(!heal_creatures) //simplemobs can only take brute damage, and can only benefit from items intended to heal it
			to_chat(user, "<span class='notice'>[src] won't help [M] at all.</span>")
			return
		M.heal_bodypart_damage(REAGENT_AMOUNT_PER_ITEM)
		user.visible_message("<span class='green'>[user] applies [src] on [M].</span>", "<span class='green'>You apply [src] on [M].</span>")
		use(1)
		return

	var/datum/task/select_bodyzone_task = user.select_bodyzone(M, FALSE, BODYZONE_STYLE_MEDICAL)
	select_bodyzone_task.continue_with(CALLBACK(src, PROC_REF(do_application), M, user))

/obj/item/stack/medical/proc/do_application(mob/living/M, mob/user, zone_selected)
	if (!zone_selected)
		return
	if (!user.can_interact_with(M, TRUE))
		to_chat(user, "<span class='danger'>You cannot reach [M]!</span>")
		M.balloon_alert(user, "You cannot reach that.")
		return
	if (!user.can_interact_with(src, TRUE))
		to_chat(user, "<span class='danger'>You cannot reach [src]!</span>")
		M.balloon_alert(user, "You cannot reach that.")
		return
	if(M.stat == DEAD && !stop_bleeding)
		to_chat(user, "<span class='danger'>\The [M] is dead, you cannot help [M.p_them()]!</span>")
		M.balloon_alert(user, "[M] is dead.")
		return
	if(!iscarbon(M))
		to_chat(user, "<span class='danger'>You don't know how to apply \the [src] to [M]!</span>")
		M.balloon_alert(user, "You cannot use that.")
		return
	var/obj/item/bodypart/affecting
	var/mob/living/carbon/C = M
	affecting = C.get_bodypart(check_zone(zone_selected))

	if(M in user.do_afters) //One at a time, please.
		return

	if(!affecting) //Missing limb?
		to_chat(user, "<span class='warning'>[C] doesn't have \a [parse_zone(zone_selected)]!</span>")
		C.balloon_alert(user, "[C] has no [parse_zone(zone_selected)]!")
		return

	var/valid = FALSE
	var/message = null

	if(stop_bleeding)
		if (C.is_bleeding())
			valid = TRUE
		else if (C.is_bandaged())
			message = "[C]'s bleeding is already bandaged!"
		else
			message = "[C] isn't bleeding!"

	if(!IS_ORGANIC_LIMB(affecting))
		to_chat(user, "<span class='warning'>Medicine won't work on a robotic limb!</span>")
		C.balloon_alert(user, "Cannot use on robotic limb!")
		return

	if(!affecting.brute_dam && !affecting.burn_dam)
		message = "[M]'s [parse_zone(zone_selected)] isn't hurt!</span>"
	else if((affecting.brute_dam && !affecting.burn_dam && !heal_brute) || (affecting.burn_dam && !affecting.brute_dam && !heal_burn)) //suffer
		message = "This type of medicine isn't appropriate for this type of wound."
	else
		valid = TRUE

	if (!valid)
		to_chat(user, "<span class='warning'>[message]</span>")
		C.balloon_alert(user, message)
		return

	if(C == user)
		user.visible_message("<span class='notice'>[user] starts to apply [src] on [user.p_them()]self...</span>", "<span class='notice'>You begin applying [src] on yourself...</span>")
		if(!do_after(user, self_delay, M))
			return
		if (self_tend_debuff)
			C.apply_status_effect(/datum/status_effect/self_tend)

	if(stop_bleeding)
		C.suppress_bloodloss(stop_bleeding)
		if (C.is_bleeding())
			C.balloon_alert(user, "You reduce [M == user ? "your" : M.p_their()] bleeding to [C.get_bleed_rate_string()]")
		else
			C.balloon_alert(user, "You stop [M == user ? "your" : M.p_their()] bleeding!")
	else
		C.balloon_alert(user, "You apply [src] to [M == user ? "yourself" : M].")

	user.visible_message("<span class='green'>[user] applies [src] to [M].</span>", "<span class='green'>You apply [src] to [M].</span>")
	if(reagent)
		reagents.reaction(M, PATCH, affecting = affecting)
		M.reagents.add_reagent_list(reagent) //Stack size is reduced by one instead of actually removing reagents from the stack.
		C.update_damage_overlays()
	use(1)

/obj/item/stack/medical/on_grind()
	reagents.clear_reagents() //By default grinding returns all contained reagents + grind_results, and for stackable items we only want grind_results
	. = ..()

/obj/item/stack/medical/bruise_pack
	name = "bruise pack"
	singular_name = "bruise pack"
	desc = "A therapeutic gel pack and bandages designed to treat blunt-force trauma."
	icon_state = "brutepack"
	lefthand_file = 'icons/mob/inhands/equipment/medical_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/medical_righthand.dmi'
	heal_brute = TRUE
	heal_creatures = TRUE
	reagent = list(/datum/reagent/medicine/styptic_powder = REAGENT_AMOUNT_PER_ITEM)
	grind_results = list(/datum/reagent/medicine/styptic_powder = REAGENT_AMOUNT_PER_ITEM)
	merge_type = /obj/item/stack/medical/bruise_pack

/obj/item/stack/medical/bruise_pack/one
	amount = 1

/obj/item/stack/medical/bruise_pack/suicide_act(mob/living/user)
	user.visible_message("<span class='suicide'>[user] is bludgeoning [user.p_them()]self with [src]! It looks like [user.p_theyre()] trying to commit suicide!</span>")
	return BRUTELOSS

/obj/item/stack/medical/ointment
	name = "ointment"
	desc = "Used to treat those nasty burn wounds."
	icon_state = "ointment"
	lefthand_file = 'icons/mob/inhands/equipment/medical_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/medical_righthand.dmi'
	heal_burn = TRUE
	reagent = list(/datum/reagent/medicine/silver_sulfadiazine = REAGENT_AMOUNT_PER_ITEM)
	grind_results = list(/datum/reagent/medicine/silver_sulfadiazine = REAGENT_AMOUNT_PER_ITEM)
	merge_type = /obj/item/stack/medical/ointment

/obj/item/stack/medical/ointment/one
	amount = 1

/obj/item/stack/medical/ointment/suicide_act(mob/living/user)
	user.visible_message("<span class='suicide'>[user] is squeezing \the [src] into [user.p_their()] mouth! Don't [user.p_they()] know that stuff is toxic?</span>")
	return TOXLOSS

/obj/item/stack/medical/gauze
	name = "medical gauze"
	desc = "A roll of elastic cloth that is extremely effective at stopping bleeding, heals minor bruising."
	icon_state = "gauze"
	stop_bleeding = BLEED_CRITICAL
	heal_creatures = TRUE //Enables gauze to be used on simplemobs for healing
	max_amount = 12
	merge_type = /obj/item/stack/medical/gauze
	self_tend_debuff = FALSE

/obj/item/stack/medical/gauze/attackby(obj/item/I, mob/user, params)
	if(I.tool_behaviour == TOOL_WIRECUTTER || I.is_sharp())
		if(get_amount() < 2)
			to_chat(user, "<span class='warning'>You need at least two gauzes to do this!</span>")
			return
		new /obj/item/stack/sheet/cotton/cloth(user.drop_location())
		user.visible_message("[user] cuts [src] into pieces of cloth with [I].", \
					"<span class='notice'>You cut [src] into pieces of cloth with [I].</span>", \
					"<span class='italics'>You hear cutting.</span>")
		use(2)
	else
		return ..()

/obj/item/stack/medical/gauze/suicide_act(mob/living/user)
	user.visible_message("<span class='suicide'>[user] begins tightening \the [src] around [user.p_their()] neck! It looks like [user.p_they()] forgot how to use medical supplies!</span>")
	return OXYLOSS

/obj/item/stack/medical/gauze/improvised
	name = "improvised gauze"
	singular_name = "improvised gauze"
	desc = "A roll of cloth roughly cut from something that can stop bleeding, but does not heal wounds."
	stop_bleeding = BLEED_SURFACE
	heal_creatures = FALSE
	merge_type = /obj/item/stack/medical/gauze/improvised
	self_tend_debuff = TRUE

/obj/item/stack/medical/gauze/adv
	name = "sterilized medical gauze"
	desc = "A roll of elastic sterilized cloth that is extremely effective at stopping bleeding, heals minor wounds and cleans them."
	singular_name = "sterilized medical gauze"
	self_delay = 0.5 SECONDS
	merge_type = /obj/item/stack/medical/gauze/adv

/obj/item/stack/medical/gauze/adv/one
	amount = 1

/datum/status_effect/self_tend
	id = "self_tend"
	duration = 60 SECONDS
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_MERGE
	on_remove_on_mob_delete = TRUE
	alert_type = /atom/movable/screen/alert/status_effect/self_tend

/datum/status_effect/self_tend/merge()
	duration += initial(duration)

/datum/status_effect/self_tend/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/self_tend)
	owner.Paralyze(3 SECONDS)
	to_chat(owner, "<span class='danger'>An intense wave of pain washes over you as you try to mend your wounds.</span>")
	owner.emote("scream")
	owner.adjustStaminaLoss(clamp(50 - owner.staminaloss, 0, 50))
	return TRUE

/datum/status_effect/self_tend/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/self_tend)
	owner.cure_nearsighted(FAST_REF(src))

/datum/status_effect/self_tend/tick()
	owner.adjustStaminaLoss(clamp(50 - owner.staminaloss, 0, 5))

/atom/movable/screen/alert/status_effect/self_tend
	name = "Self-Tended"
	desc = "You have recently applied medical equipment to yourself, limiting its effectiveness. Getting someone else to tend your wounds avoids negative effects from self-tending."
	icon_state = "self_tend"

/datum/movespeed_modifier/self_tend
	multiplicative_slowdown = 1.5

#undef REAGENT_AMOUNT_PER_ITEM
