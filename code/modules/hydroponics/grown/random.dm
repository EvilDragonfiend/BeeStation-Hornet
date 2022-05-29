//Random seeds; stats, traits, and plant type are randomized for each seed.

/obj/item/seeds/random
	name = "pack of strange seeds"
	desc = "Mysterious seeds as strange as their name implies. Spooky."
	icon_state = "seed-x"
	species = "?????"
	plantname = "strange plant"
	product = /obj/item/reagent_containers/food/snacks/grown/random
	icon_grow = "xpod-grow"
	icon_dead = "xpod-dead"
	icon_harvest = "xpod-harvest"
	growthstages = 4
	mutatelist = list(/obj/item/seeds/random) // recursive
	var/previous_identifier
	maturation = 1
	production = 1
	var/greekpattern = list("alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "mu", "nu", "xi", "omicron", "pi", "rho", "sigma", "tau", "upsilon", "phi", "chi", "psi", "omega")

/obj/item/seeds/random/Initialize(mapload, nogenes)
	. = ..()

	if(research_identifier == name)
		research_identifier = rand(1, SHORT_REAL_LIMIT)
		var/pickedpattern = "[pick(greekpattern)] No.[rand(1,999)]"
		name += " [pickedpattern]"
		plantname += " [pickedpattern]"
	//randomize_stats()

	add_random_reagents(research_identifier)
	add_random_reagents(rand_LCM(research_identifier, maximum=SHORT_REAL_LIMIT))

	if(prob(50))
		add_random_traits(1, 2)
	else
		add_random_traits(1, 1)
	add_random_plant_type(35)

	research_identifier = "[research_identifier]"

/obj/item/seeds/random/proc/set_random(taken_identifier)
	// I wanted to put this in New proc or Init proc, but it isn't compatible well.
	// This makes expectable random stuff based on `rand_LCM` proc and `taken_identifier` var.
	previous_identifier = taken_identifier
	if(isnum(previous_identifier))
		for(var/each in genes)
			if(istype(each, /datum/plant_gene/trait) || istype(each, /datum/plant_gene/reagent/sandbox))
				genes -= each
				qdel(each)

		research_identifier = rand_LCM(previous_identifier, maximum=SHORT_REAL_LIMIT)
		previous_identifier = null

		var/pickedpattern = "[greekpattern[rand_LCM(research_identifier, maximum=length(greekpattern))]] No.[rand_LCM(research_identifier, maximum=999)]"
		name = "[initial(name)] [pickedpattern]"
		plantname = "[initial(plantname)] [pickedpattern]"
		add_random_reagents(research_identifier)
		add_random_reagents(rand_LCM(research_identifier, maximum=SHORT_REAL_LIMIT))

		research_identifier = "[research_identifier]"

/proc/rand_LCM(var/my_rand_seed = 0, var/maximum, var/numbers_of_return = 1, var/flat = 1)
	// Pseudo random number generating - "Modified" Linear Congruential Method
	// Since I didn't want to touch `rand_seed()` proc, I had to make this.
	// This isn't real Linear Congruential Method.

	. = numbers_of_return == 1 ? 0 : list()
	var/static/multiplier = rand(1,65535) // This will make each round random

	for(var/i in 1 to numbers_of_return)
		var/seed_result = (my_rand_seed*multiplier) %maximum +flat
		my_rand_seed = seed_result
		. += seed_result

/obj/item/reagent_containers/food/snacks/grown/random
	seed = /obj/item/seeds/random
	name = "strange plant"
	desc = "What could this even be?"
	icon_state = "crunchy"
	bitesize_mod = 2
	discovery_points = 300

/obj/item/reagent_containers/food/snacks/grown/random/Initialize(mapload)
	. = ..()
	wine_power = rand(10,150)
	if(prob(1))
		wine_power = 200
