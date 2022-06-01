/datum/plant_gene/trait/perennial
	name = "Perennial Growth"
	desc = "Your plants will grow again even if it's harvested."
	plusdesc = "WARNING: Not valid to Replica Pod."
	trait_id = "perennial"
	plant_gene_flags = PLANT_GENE_COMMON_REMOVABLE | PLANT_GENE_RANDOM_ALLOWED
	research_needed = 6

/datum/plant_gene/trait/perennial/can_add(obj/item/seeds/S)
	if(!..())
		return FALSE
	if(istype(S, /obj/item/seeds/replicapod))
		return FALSE
	return TRUE


/datum/plant_gene/trait/no_perennial
	name = "Incompatible Perennial Growth"
	desc = "This plant can't take Perennial Growth trait"
	trait_id = "perennial"
	plant_gene_flags = NONE
	research_needed = -1
