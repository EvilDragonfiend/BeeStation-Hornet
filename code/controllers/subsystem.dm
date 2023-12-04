
/datum/controller/subsystem
	// Metadata; you should define these.
	name = "fire coderbus" //name of the subsystem
	var/ss_id = "fire_coderbus_again"
	var/init_order = INIT_ORDER_DEFAULT		//order of initialization. Higher numbers are initialized first, lower numbers later. Use defines in __DEFINES/subsystems.dm for easy understanding of order.
	var/wait = 20			//time to wait (in deciseconds) between each call to fire(). Must be a positive integer.
	var/priority = FIRE_PRIORITY_DEFAULT	//When mutiple subsystems need to run in the same tick, higher priority subsystems will run first and be given a higher share of the tick before MC_TICK_CHECK triggers a sleep

	var/flags = 0			//see MC.dm in __DEFINES Most flags must be set on world start to take full effect. (You can also restart the mc to force them to process again)

	var/initialized = FALSE	//set to TRUE after it has been initialized, will obviously never be set if the subsystem doesn't initialize

	//set to 0 to prevent fire() calls, mostly for admin use or subsystems that may be resumed later
	//	use the SS_NO_FIRE flag instead for systems that never fire to keep it from even being added to the list
	var/can_fire = TRUE

	// Bookkeeping variables; probably shouldn't mess with these.
	var/last_fire = 0		//last world.time we called fire()
	var/next_fire = 0		//scheduled world.time for next fire()
	var/cost = 0			//average time to execute
	var/tick_usage = 0		//average tick usage
	/// Running average of the amount of tick usage (in percents of a game tick) the subsystem has spent past its allocated time without pausing
	var/tick_overrun = 0

	/// How much of a tick (in percents of a tick) were we allocated last fire.
	var/tick_allocation_last = 0

	/// How much of a tick (in percents of a tick) do we get allocated by the mc on avg.
	var/tick_allocation_avg = 0
	/// Tracks the current execution state of the subsystem. Used to handle subsystems that sleep in fire so the mc doesn't run them again while they are sleeping
	var/state = SS_IDLE
	var/paused_ticks = 0	//ticks this ss is taking to run right now.
	var/paused_tick_usage	//total tick_usage of all of our runs while pausing this run
	var/ticks = 1			//how many ticks does this ss take to run on avg.
	/// Tracks the amount of completed runs for the subsystem
	var/times_fired = 0
	/// How many fires have we been requested to postpone
	var/postponed_fires = 0
	var/queued_time = 0		//time we entered the queue, (for timing and priority reasons)
	var/queued_priority 	//we keep a running total to make the math easier, if priority changes mid-fire that would break our running total, so we store it here
	//linked list stuff for the queue
	var/datum/controller/subsystem/queue_next
	var/datum/controller/subsystem/queue_prev

	var/runlevels = RUNLEVELS_DEFAULT	//points of the game at which the SS can fire

	var/static/list/failure_strikes //How many times we suspect a subsystem type has crashed the MC, 3 strikes and you're out!

//Do not override
///datum/controller/subsystem/New()

// Used to initialize the subsystem BEFORE the map has loaded
// Called AFTER Recover if that is called
// Prefer to use Initialize if possible
/datum/controller/subsystem/proc/PreInit()
	return

//This is used so the mc knows when the subsystem sleeps. do not override.
/datum/controller/subsystem/proc/ignite(resumed = FALSE)
	SHOULD_NOT_OVERRIDE(TRUE)
	set waitfor = FALSE
	. = SS_IDLE

	tick_allocation_last = Master.current_ticklimit-(TICK_USAGE)
	tick_allocation_avg = MC_AVERAGE(tick_allocation_avg, tick_allocation_last)
	
	. = SS_SLEEPING
	fire(resumed)
	. = state
	if (state == SS_SLEEPING)
		state = SS_IDLE
	if (state == SS_PAUSING)
		var/QT = queued_time
		enqueue()
		state = SS_PAUSED
		queued_time = QT

//previously, this would have been named 'process()' but that name is used everywhere for different things!
//fire() seems more suitable. This is the procedure that gets called every 'wait' deciseconds.
//Sleeping in here prevents future fires until returned.
/datum/controller/subsystem/proc/fire(resumed = 0)
	flags |= SS_NO_FIRE
	CRASH("Subsystem [src]([type]) does not fire() but did not set the SS_NO_FIRE flag. Please add the SS_NO_FIRE flag to any subsystem that doesn't fire so it doesn't get added to the processing list and waste cpu.")

/datum/controller/subsystem/Destroy()
	dequeue()
	can_fire = 0
	flags |= SS_NO_FIRE
	if (Master)
		Master.subsystems -= src
	return ..()

/** Update next_fire for the next run.
 *  reset_time (bool) - Ignore things that would normally alter the next fire, like tick_overrun, and last_fire. (also resets postpone)
 */
/datum/controller/subsystem/proc/update_nextfire(reset_time = FALSE)
	var/queue_node_flags = flags

	if (reset_time)
		postponed_fires = 0
		if (queue_node_flags & SS_TICKER)
			next_fire = world.time + (world.tick_lag * wait)
		else
			next_fire = world.time + wait
		return

	if (queue_node_flags & SS_TICKER)
		next_fire = world.time + (world.tick_lag * wait)
	else if (queue_node_flags & SS_POST_FIRE_TIMING)
		next_fire = world.time + wait + (world.tick_lag * (tick_overrun/100))
	else if (queue_node_flags & SS_KEEP_TIMING)
		next_fire += wait
	else
		next_fire = queued_time + wait + (world.tick_lag * (tick_overrun/100))

//Queue it to run.
//	(we loop thru a linked list until we get to the end or find the right point)
//	(this lets us sort our run order correctly without having to re-sort the entire already sorted list)
/datum/controller/subsystem/proc/enqueue()
	var/SS_priority = priority
	var/SS_flags = flags
	var/datum/controller/subsystem/queue_node
	var/queue_node_priority
	var/queue_node_flags

	for (queue_node = Master.queue_head; queue_node; queue_node = queue_node.queue_next)
		queue_node_priority = queue_node.queued_priority
		queue_node_flags = queue_node.flags

		if (queue_node_flags & (SS_TICKER|SS_BACKGROUND) == SS_TICKER)
			if ((SS_flags & (SS_TICKER|SS_BACKGROUND)) != SS_TICKER)
				continue
			if (queue_node_priority < SS_priority)
				break

		else if (queue_node_flags & SS_BACKGROUND)
			if (!(SS_flags & SS_BACKGROUND))
				break
			if (queue_node_priority < SS_priority)
				break

		else
			if (SS_flags & SS_BACKGROUND)
				continue
			if (SS_flags & SS_TICKER)
				break
			if (queue_node_priority < SS_priority)
				break

	queued_time = world.time
	queued_priority = SS_priority
	state = SS_QUEUED
	if (SS_flags & SS_BACKGROUND) //update our running total
		Master.queue_priority_count_bg += SS_priority
	else
		Master.queue_priority_count += SS_priority

	queue_next = queue_node
	if (!queue_node)//we stopped at the end, add to tail
		queue_prev = Master.queue_tail
		if (Master.queue_tail)
			Master.queue_tail.queue_next = src
		else //empty queue, we also need to set the head
			Master.queue_head = src
		Master.queue_tail = src

	else if (queue_node == Master.queue_head)//insert at start of list
		Master.queue_head.queue_prev = src
		Master.queue_head = src
		queue_prev = null
	else
		queue_node.queue_prev.queue_next = src
		queue_prev = queue_node.queue_prev
		queue_node.queue_prev = src


/datum/controller/subsystem/proc/dequeue()
	if (queue_next)
		queue_next.queue_prev = queue_prev
	if (queue_prev)
		queue_prev.queue_next = queue_next
	if (Master && (src == Master.queue_tail))
		Master.queue_tail = queue_prev
	if (Master && (src == Master.queue_head))
		Master.queue_head = queue_next
	queued_time = 0
	if (state == SS_QUEUED)
		state = SS_IDLE


/datum/controller/subsystem/proc/pause()
	. = 1
	switch(state)
		if(SS_RUNNING)
			state = SS_PAUSED
		if(SS_SLEEPING)
			state = SS_PAUSING

/// Called after the config has been loaded or reloaded.
/datum/controller/subsystem/proc/OnConfigLoad()

//used to initialize the subsystem AFTER the map has loaded
/datum/controller/subsystem/Initialize(start_timeofday)
	initialized = TRUE
	SEND_SIGNAL(src, COMSIG_SUBSYSTEM_POST_INITIALIZE, start_timeofday)
	var/time = (REALTIMEOFDAY - start_timeofday) / 10
	var/msg = "Initialized [name] subsystem within [time] second[time == 1 ? "" : "s"]!"
	testing("[msg]")
	log_world(msg)
	return time

//hook for printing stats to the "MC" statuspanel for admins to see performance and related stats etc.
/datum/controller/subsystem/stat_entry(msg)
	var/list/tab_data = list()

	if(can_fire && !(SS_NO_FIRE & flags))
		msg = "[round(cost,1)]ms|[round(tick_usage,1)]%([round(tick_overrun,1)]%)|[round(ticks,0.1)]\t[msg]"
	else
		msg = "OFFLINE\t[msg]"

	var/title = name
	if (can_fire)
		title = "\[[state_letter()]][title]"

	tab_data["[title]"] = list(
		text="[msg]",
		action = "statClickDebug",
		params=list(
			"targetRef" = FAST_REF(src),
			"class"="subsystem",
		),
		type=STAT_BUTTON,
	)
	return tab_data

/datum/controller/subsystem/proc/state_letter()
	switch (state)
		if (SS_RUNNING)
			. = "R"
		if (SS_QUEUED)
			. = "Q"
		if (SS_PAUSED, SS_PAUSING)
			. = "P"
		if (SS_SLEEPING)
			. = "S"
		if (SS_IDLE)
			. = "  "

/// Causes the next "cycle" fires to be missed. Effect is accumulative but can reset by calling update_nextfire(reset_time = TRUE)
/datum/controller/subsystem/proc/postpone(cycles = 1)
	if (can_fire && cycles >= 1)
		postponed_fires += cycles

//usually called via datum/controller/subsystem/New() when replacing a subsystem (i.e. due to a recurring crash)
//should attempt to salvage what it can from the old instance of subsystem
/datum/controller/subsystem/Recover()

/datum/controller/subsystem/vv_edit_var(var_name, var_value)
	switch (var_name)
		if (NAMEOF(src, can_fire))
			//this is so the subsystem doesn't rapid fire to make up missed ticks causing more lag
			if (var_value)
				update_nextfire(reset_time = TRUE)
		if (NAMEOF(src, queued_priority)) //editing this breaks things.
			return FALSE
	. = ..()


/**
  * Returns the metrics for the subsystem.
  *
  * This can be overriden on subtypes for variables that could affect tick usage
  * Example: ATs on SSair
  */
/datum/controller/subsystem/proc/get_metrics()
	SHOULD_CALL_PARENT(TRUE)
	// Please dont ever modify this. Youll break existing metrics and that will upset me.
	var/list/out = list()
	out["cost"] = cost
	out["tick_usage"] = tick_usage
	out["custom"] = list() // Override as needed on child
	return out
