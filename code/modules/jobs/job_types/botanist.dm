/datum/job/botanist
	jkey = JOB_KEY_BOTANIST
	jtitle = JOB_NAME_BOTANIST
	job_bitflags = JOB_BITFLAG_SELECTABLE
	department_head = list(JOB_NAME_HEADOFPERSONNEL)
	faction = "station"
	total_positions = 3
	spawn_positions = 2
	selection_color = "#bbe291"

	outfit = /datum/outfit/job/botanist

	access = list(ACCESS_HYDROPONICS, ACCESS_BAR, ACCESS_KITCHEN, ACCESS_MORGUE, ACCESS_MINERAL_STOREROOM)
	minimal_access = list(ACCESS_HYDROPONICS, ACCESS_MORGUE, ACCESS_MINERAL_STOREROOM)

	departments = DEPT_BITFLAG_SRV
	bank_account_department = ACCOUNT_SRV_BITFLAG
	payment_per_department = list(ACCOUNT_SRV_ID = PAYCHECK_EASY)

	display_order = JOB_DISPLAY_ORDER_BOTANIST
	rpg_title = "Gardener"

	species_outfits = list(
		SPECIES_PLASMAMAN = /datum/outfit/plasmaman/botany
	)

/datum/outfit/job/botanist
	name = JOB_KEY_BOTANIST
	jobtype = /datum/job/botanist

	id = /obj/item/card/id/job/botanist
	belt = /obj/item/modular_computer/tablet/pda/service
	ears = /obj/item/radio/headset/headset_srv
	uniform = /obj/item/clothing/under/rank/civilian/hydroponics
	suit = /obj/item/clothing/suit/apron
	gloves = /obj/item/clothing/gloves/botanic_leather
	suit_store = /obj/item/plant_analyzer

	backpack = /obj/item/storage/backpack/botany
	satchel = /obj/item/storage/backpack/satchel/hyd


