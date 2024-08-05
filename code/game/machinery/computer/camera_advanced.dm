/obj/machinery/computer/camera_advanced
	name = "advanced camera console"
	desc = "Used to access the various cameras on the station."
	icon_screen = "cameras"
	icon_keyboard = "security_key"
	var/list/z_lock = list() // Lock use to these z levels
	var/lock_override = NONE
	var/mob/camera/ai_eye/remote/eyeobj
	var/mob/living/current_user = null
	var/list/networks = list("ss13")
	var/datum/action/innate/camera_off/off_action = new
	var/datum/action/innate/camera_jump/jump_action = new
	///Camera action button to move up a Z level
	var/datum/action/innate/camera_multiz_up/move_up_action = new
	///Camera action button to move down a Z level
	var/datum/action/innate/camera_multiz_down/move_down_action = new
	var/list/actions = list()
	///Should we supress any view changes?
	var/should_supress_view_changes  = TRUE
	light_color = LIGHT_COLOR_RED

	/// if TRUE, this will be visible to ghosts and player user, and automatically transfer ghost orbits to camera eye when used.
	/// if you're going to set this TRUE, check if 'eyeobj.invisibility' takes a correct value
	var/reveal_camera_mob = FALSE
	var/camera_mob_icon = 'icons/mob/cameramob.dmi'
	var/camera_mob_icon_state = "marker"
	/// I hate making this variable separately, but mob/camera/ai_eye is too complex
	/// This takes an image to show camera_eye sprite to clients who are observers
	var/image/camera_sprite_for_observers

	/// list of mobs who are watching camera, not using it directly.
	var/list/camera_observers = list()

/obj/machinery/computer/camera_advanced/Initialize(mapload)
	. = ..()
	for(var/i in networks)
		networks -= i
		networks += lowertext(i)
	if(lock_override)
		if(lock_override & CAMERA_LOCK_STATION)
			z_lock |= SSmapping.levels_by_trait(ZTRAIT_STATION)
		if(lock_override & CAMERA_LOCK_MINING)
			z_lock |= SSmapping.levels_by_trait(ZTRAIT_MINING)
		if(lock_override & CAMERA_LOCK_CENTCOM)
			z_lock |= SSmapping.levels_by_trait(ZTRAIT_CENTCOM)

/obj/machinery/computer/camera_advanced/attack_ghost(mob/dead/observer/ghost)
	. = ..()
	if(.)
		return
	if(current_user && eyeobj)
		ghost.check_orbitable(eyeobj) // ghost QoL

/obj/machinery/computer/camera_advanced/syndie
	icon_keyboard = "syndie_key"
	circuit = /obj/item/circuitboard/computer/advanced_camera
	reveal_camera_mob = TRUE
	camera_mob_icon_state = "syndi"

/obj/machinery/computer/camera_advanced/bounty_hunter
	circuit = /obj/item/circuitboard/computer/advanced_camera/cyan
	reveal_camera_mob = TRUE
	camera_mob_icon_state = "cyan"

/obj/machinery/computer/camera_advanced/wizard
	circuit = /obj/item/circuitboard/computer/advanced_camera/darkblue
	reveal_camera_mob = TRUE
	camera_mob_icon_state = "darkblue"

/obj/machinery/computer/camera_advanced/proc/CreateEye()
	eyeobj = new()
	eyeobj.origin = src
	eyeobj.icon = camera_mob_icon
	eyeobj.icon_state = camera_mob_icon_state
	RevealCameraMob()

/obj/machinery/computer/camera_advanced/proc/RevealCameraMob()
	if(reveal_camera_mob && eyeobj)
		eyeobj.visible_icon = TRUE
		eyeobj.invisibility = INVISIBILITY_OBSERVER
		if(current_user) // indent is correct: do not transfer ghosts unless it's revealed
			current_user.transfer_observers_to(eyeobj, temporary = TRUE)

/obj/machinery/computer/camera_advanced/proc/ConcealCameraMob()
	if(reveal_camera_mob && eyeobj)
		eyeobj.visible_icon = FALSE
		eyeobj.invisibility = INVISIBILITY_ABSTRACT
	if(current_user && eyeobj) // indent is correct: transfer ghosts when nobody uses
		eyeobj.return_observers() // send ghosts back to their original orbit
		eyeobj.transfer_observers_to(current_user) // if a ghost started observing an eye at first, the return proc won't work.

/obj/machinery/computer/camera_advanced/proc/GrantActions(mob/living/user)
	if(off_action)
		off_action.target = user
		off_action.Grant(user)
		actions += off_action

	if(jump_action)
		jump_action.target = user
		jump_action.Grant(user)
		actions += jump_action

	if(move_up_action)
		move_up_action.target = user
		move_up_action.Grant(user)
		actions += move_up_action

	if(move_down_action)
		move_down_action.target = user
		move_down_action.Grant(user)
		actions += move_down_action

/obj/machinery/proc/remove_eye_control(mob/living/user)
	SIGNAL_HANDLER // this should be stated at parent
	CRASH("[type] does not implement ai eye handling")

/obj/machinery/computer/camera_advanced/remove_eye_control(mob/living/user)
	if(!user)
		return
	for(var/V in actions)
		var/datum/action/A = V
		A.Remove(user)
	actions.Cut()
	for(var/datum/camerachunk/camerachunk as anything in eyeobj.visibleCameraChunks)
		camerachunk.remove(eyeobj)
	user.reset_perspective()
	if(user.client)
		if(eyeobj.visible_icon && user.client)
			user.client.images -= eyeobj.user_image
		user.client.view_size.unsupress()

	shoo_all_observers()
	UnregisterSignal(user, COMSIG_MOVABLE_MOVED)

	ConcealCameraMob()
	eyeobj.eye_user = null
	user.remote_control = null
	current_user = null
	user.unset_machine()
	playsound(src, 'sound/machines/terminal_off.ogg', 25, FALSE)

/obj/machinery/computer/camera_advanced/check_eye(mob/user)
	if( (machine_stat & (NOPOWER|BROKEN)) || (!Adjacent(user) && !user.has_unlimited_silicon_privilege) || user.is_blind() || user.incapacitated() )
		user.unset_machine()

/obj/machinery/computer/camera_advanced/Destroy()
	if(current_user)
		remove_eye_control(current_user)
		current_user = null
	ConcealCameraMob()
	if(eyeobj)
		QDEL_NULL(eyeobj)
	QDEL_LIST(actions)
	return ..()

/obj/machinery/computer/camera_advanced/on_unset_machine(mob/M)
	if(M == current_user)
		remove_eye_control(M)

/obj/machinery/computer/camera_advanced/proc/can_use(mob/living/user)
	return TRUE

/obj/machinery/computer/camera_advanced/abductor/can_use(mob/user)
	if(!isabductor(user))
		return FALSE
	return ..()

/obj/machinery/computer/camera_advanced/attack_hand(mob/user)
	. = ..()
	if(.)
		return
	if(!is_operational) //you cant use broken machine you chumbis
		return
	if(current_user)
		start_observe(user)
		return
	var/mob/living/L = user

	if(!can_use(user))
		return
	if(!eyeobj)
		CreateEye()

	if(!eyeobj.eye_initialized)
		var/turf/camera_location
		var/turf/myturf = get_turf(src)
		if(eyeobj.use_static) // I don't honestly get what this code means. Feel free to nuke....
			if((!z_lock.len || (myturf.z in z_lock)) && GLOB.cameranet.checkTurfVis(myturf))
				camera_location = myturf
			else
				for(var/obj/machinery/camera/C in GLOB.cameranet.cameras)
					if(!C.can_use() || z_lock.len && !(C.z in z_lock))
						continue
					var/list/network_overlap = networks & C.network
					if(network_overlap.len)
						camera_location = get_turf(C)
						break
		else
			camera_location = myturf
			if(z_lock.len && !(myturf.z in z_lock))
				camera_location = locate(round(world.maxx/2), round(world.maxy/2), z_lock[1])


		if(isturf(camera_location))
			eyeobj.eye_initialized = TRUE
			eyeobj.abstract_move(camera_location)

	if(!eyeobj.eye_initialized)
		user.unset_machine()
		CRASH("Failed to initialize eyeobj.")

	give_eye_control(L)

/obj/machinery/computer/camera_advanced/proc/start_observe(mob/user)
	if(!user.client || !eyeobj)
		return

	if(!camera_sprite_for_observers && eyeobj.visible_icon)
		camera_sprite_for_observers = image(eyeobj.icon, eyeobj, eyeobj.icon_state, FLY_LAYER)

	if(user in camera_observers)
		stop_observe(user)
		return

	camera_observers += user
	if(user.client)
		if(eyeobj.visible_icon)
			user.client.images += camera_sprite_for_observers
		user.reset_perspective(eyeobj)
		if(should_supress_view_changes)
			user.client.view_size.supress()
		for(var/datum/camerachunk/camerachunk as anything in eyeobj.visibleCameraChunks)
			camerachunk.single_add(eyeobj, user.client)
		user.transfer_observers_to(eyeobj, temporary = TRUE)
	RegisterSignals(user, list(COMSIG_MOB_LOGOUT, COMSIG_MOVABLE_MOVED), PROC_REF(stop_observe))

/obj/machinery/computer/camera_advanced/proc/stop_observe(mob/user)
	SIGNAL_HANDLER

	camera_observers -= user
	user.reset_perspective()
	if(user.client)
		for(var/datum/camerachunk/camerachunk as anything in eyeobj.visibleCameraChunks)
			camerachunk.single_remove(eyeobj, user.client)
		user.client.view_size.unsupress()
		if(camera_sprite_for_observers)
			user.client.images -= camera_sprite_for_observers
		eyeobj.return_observers(user) // return my ghosts back, leaving others there.
	UnregisterSignal(user, list(COMSIG_MOB_LOGOUT, COMSIG_MOVABLE_MOVED))

/obj/machinery/computer/camera_advanced/proc/shoo_all_observers()
	for(var/each_mob in camera_observers)
		stop_observe(each_mob)

/obj/machinery/computer/camera_advanced/attack_robot(mob/user)
	return attack_hand(user)

/obj/machinery/computer/camera_advanced/attack_ai(mob/user)
	return //AIs would need to disable their own camera procs to use the console safely. Bugs happen otherwise.

/obj/machinery/computer/camera_advanced/proc/give_eye_control(mob/user)
	if(!user.client)
		return
	GrantActions(user)
	current_user = user
	eyeobj.eye_user = user
	eyeobj.name = "Camera Eye ([user.name])"
	RevealCameraMob()
	user.remote_control = eyeobj
	user.reset_perspective(eyeobj)
	if(should_supress_view_changes )
		user.client.view_size.supress()
	eyeobj.setLoc(get_turf(eyeobj)) // This forcefully puts camera noise. I hate this exists here, but necessary.

	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(remove_eye_control))

/mob/camera/ai_eye/remote
	name = "Inactive Camera Eye"
	ai_detector_visible = FALSE
	var/sprint = 10
	var/cooldown = 0
	var/acceleration = 1
	var/mob/living/eye_user = null
	var/obj/machinery/origin
	var/eye_initialized = 0
	var/visible_icon = 0
	var/image/user_image = null

/mob/camera/ai_eye/remote/update_remote_sight(mob/living/user)
	user.see_invisible = SEE_INVISIBLE_LIVING //can't see ghosts through cameras
	user.sight = SEE_TURFS | SEE_BLACKNESS
	user.see_in_dark = 2
	return TRUE

/mob/camera/ai_eye/remote/Destroy()
	if(origin && eye_user)
		origin.remove_eye_control(eye_user,src)
	origin = null
	. = ..()
	eye_user = null

/mob/camera/ai_eye/remote/GetViewerClient()
	if(eye_user)
		return eye_user.client
	return null

/mob/camera/ai_eye/remote/setLoc(destination)
	if(eye_user)
		destination = get_turf(destination)
		if (destination)
			abstract_move(destination)
		else
			moveToNullspace()

		update_ai_detect_hud()

		if(use_static)
			GLOB.cameranet.visibility(src, GetViewerClient(), null, use_static)

		if(visible_icon)
			if(!user_image)
				user_image = image(icon, src, icon_state, FLY_LAYER)
			if(eye_user.client)
				eye_user.client.images |= user_image

/mob/camera/ai_eye/remote/relaymove(mob/living/user, direction)
	if(direction == UP || direction == DOWN)
		zMove(direction, FALSE)
		return
	var/initial = initial(sprint)
	var/max_sprint = 50

	if(cooldown && cooldown < world.timeofday) // 3 seconds
		sprint = initial

	for(var/i = 0; i < max(sprint, initial); i += 20)
		var/turf/step = get_turf(get_step(src, direction))
		if(step)
			setLoc(step)

	cooldown = world.timeofday + 5
	if(acceleration)
		sprint = min(sprint + 0.5, max_sprint)
	else
		sprint = initial

/datum/action/innate/camera_off
	name = "End Camera View"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "camera_off"

/datum/action/innate/camera_off/Activate()
	if(!target || !isliving(target))
		return
	var/mob/living/C = target
	var/mob/camera/ai_eye/remote/remote_eye = C.remote_control
	var/obj/machinery/computer/camera_advanced/console = remote_eye.origin
	console.remove_eye_control(target)

/datum/action/innate/camera_jump
	name = "Jump To Camera"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "camera_jump"

/datum/action/innate/camera_jump/Activate()
	if(!target || !isliving(target))
		return
	var/mob/living/C = target
	var/mob/camera/ai_eye/remote/remote_eye = C.remote_control
	var/obj/machinery/computer/camera_advanced/origin = remote_eye.origin

	var/list/L = list()

	for (var/obj/machinery/camera/cam in GLOB.cameranet.cameras)
		if(origin.z_lock.len && !(cam.z in origin.z_lock))
			continue
		L.Add(cam)

	camera_sort(L)

	var/list/T = list()

	for (var/obj/machinery/camera/netcam in L)
		var/list/tempnetwork = netcam.network & origin.networks
		if (tempnetwork.len)
			T["[netcam.c_tag][netcam.can_use() ? null : " (Deactivated)"]"] = netcam

	playsound(origin, 'sound/machines/terminal_prompt.ogg', 25, 0)
	var/camera = input("Choose which camera you want to view", "Cameras") as null|anything in T
	var/obj/machinery/camera/final = T[camera]
	playsound(src, "terminal_type", 25, 0)
	if(final)
		playsound(origin, 'sound/machines/terminal_prompt_confirm.ogg', 25, 0)
		remote_eye.setLoc(get_turf(final))
		C.overlay_fullscreen("flash", /atom/movable/screen/fullscreen/flash/static)
		C.clear_fullscreen("flash", 3) //Shorter flash than normal since it's an ~~advanced~~ console!
	else
		playsound(origin, 'sound/machines/terminal_prompt_deny.ogg', 25, FALSE)

/datum/action/innate/camera_multiz_up
	name = "Move up a floor"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "move_up"

/datum/action/innate/camera_multiz_up/Activate()
	if(!target || !isliving(target))
		return
	var/mob/living/user_mob = target
	var/mob/camera/ai_eye/remote/remote_eye = user_mob.remote_control
	if(remote_eye.zMove(UP, FALSE))
		to_chat(user_mob, "<span class='notice'>You move upwards.</span>")
	else
		to_chat(user_mob, "<span class='notice'>You couldn't move upwards!</span>")

/datum/action/innate/camera_multiz_down
	name = "Move down a floor"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "move_down"

/datum/action/innate/camera_multiz_down/Activate()
	if(!target || !isliving(target))
		return
	var/mob/living/user_mob = target
	var/mob/camera/ai_eye/remote/remote_eye = user_mob.remote_control
	if(remote_eye.zMove(DOWN, FALSE))
		to_chat(user_mob, "<span class='notice'>You move downwards.</span>")
	else
		to_chat(user_mob, "<span class='notice'>You couldn't move downwards!</span>")
