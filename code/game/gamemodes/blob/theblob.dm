//I will need to recode parts of this but I am way too tired atm
/obj/structure/blob
	name = "blob"
	icon = 'icons/mob/blob.dmi'
	light_range = 3
	desc = "Some blob creature thingy"
	density = FALSE
	opacity = TRUE
	anchored = TRUE
	pass_flags_self = PASSBLOB
	can_astar_pass = CANASTARPASS_ALWAYS_PROC
	max_integrity = 30
	armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 80, "acid" = 70)
	var/point_return = 0 //How many points the blob gets back when it removes a blob of that type. If less than 0, blob cannot be removed.
	var/health_timestamp = 0
	var/brute_resist = 0.5 //multiplies brute damage by this
	var/fire_resist = 1 //multiplies burn damage by this
	var/atmosblock = FALSE //if the blob blocks atmos and heat spread
	/// If a threshold is reached, resulting in shifting variables
	var/compromised_integrity = FALSE
	var/mob/camera/blob/overmind
	creates_cover = TRUE
	obj_flags = BLOCK_Z_OUT_DOWN | BLOCK_Z_IN_UP // stops blob mobs from falling on multiz.


/obj/structure/blob/Initialize(mapload)
	. = ..()
	GLOB.blobs += src
	setDir(pick(GLOB.cardinal))
	check_integrity()
	if(atmosblock)
		air_update_turf(1)
	ConsumeTile()
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)


/obj/structure/blob/Destroy()
	if(atmosblock)
		atmosblock = FALSE
		air_update_turf(1)
	GLOB.blobs -= src
	if(isturf(loc)) //Necessary because Expand() is screwed up and spawns a blob and then deletes it
		playsound(src.loc, 'sound/effects/splat.ogg', 50, 1)
	return ..()

/obj/structure/blob/has_prints()
	return FALSE

/obj/structure/blob/BlockSuperconductivity()
	return atmosblock

/obj/structure/blob/proc/check_integrity()
	return

/obj/structure/blob/proc/update_state()
	return

/obj/structure/blob/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	return checkpass(mover, PASSBLOB)

/obj/structure/blob/CanAtmosPass(turf/T, vertical)
	return !atmosblock


/obj/structure/blob/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	return pass_info.pass_flags == PASSEVERYTHING || (pass_info.pass_flags & PASSBLOB)


/obj/structure/blob/process()
	Life()
	return

/obj/structure/blob/blob_act(obj/structure/blob/B)
	return

/obj/structure/blob/proc/Life()
	return

/obj/structure/blob/proc/RegenHealth()
	// All blobs heal over time when pulsed, but it has a cool down
	if(health_timestamp > world.time)
		return 0
	if(obj_integrity < max_integrity)
		obj_integrity = min(max_integrity, obj_integrity + 1)
		check_integrity()
		health_timestamp = world.time + 10 // 1 seconds


/obj/structure/blob/proc/Pulse(var/pulse = 0, var/origin_dir = 0, var/a_color)//Todo: Fix spaceblob expand
	RegenHealth()

	if(run_action())//If we can do something here then we dont need to pulse more
		return

	if(pulse > 30)
		return//Inf loop check

	//Looking for another blob to pulse
	var/list/dirs = list(1,2,4,8)
	dirs.Remove(origin_dir)//Dont pulse the guy who pulsed us
	for(var/i = 1 to 4)
		if(!dirs.len)	break
		var/dirn = pick(dirs)
		dirs.Remove(dirn)
		var/turf/T = get_step(src, dirn)
		if(!is_location_within_transition_boundaries(T))
			continue
		var/obj/structure/blob/B = (locate(/obj/structure/blob) in T)
		if(!B)
			expand(T,1,a_color)//No blob here so try and expand
			return
		B.adjustcolors(a_color)

		B.Pulse((pulse+1),get_dir(src.loc,T), a_color)
		return
	return


/obj/structure/blob/proc/run_action()
	return 0

/obj/structure/blob/proc/ConsumeTile()
	for(var/atom/A in loc)
		A.blob_act(src)
	if(iswallturf(loc))
		loc.blob_act(src) //don't ask how a wall got on top of the core, just eat it

/obj/structure/blob/proc/expand(var/turf/T = null, var/prob = 1, var/a_color)
	if(prob && !prob(obj_integrity))
		return
	if(isspaceturf(T) && prob(75)) 	return
	if(!T)
		var/list/dirs = list(1,2,4,8)
		for(var/i = 1 to 4)
			var/dirn = pick(dirs)
			dirs.Remove(dirn)
			T = get_step(src, dirn)
			if(!(locate(/obj/structure/blob) in T))	break
			else	T = null

	if(!T)	return 0
	if(!is_location_within_transition_boundaries(T))
		return
	var/obj/structure/blob/normal/B = new /obj/structure/blob/normal(src.loc, min(obj_integrity, 30))
	B.color = a_color
	B.set_density(TRUE)
	if(T.Enter(B,src))//Attempt to move into the tile
		B.set_density(initial(B.density))
		B.loc = T
	else
		T.blob_act()//If we cant move in hit the turf
		B.loc = null //So we don't play the splat sound, see Destroy()
		qdel(B)

	for(var/atom/A in T)//Hit everything in the turf
		A.blob_act(src)
	return 1


/obj/structure/blob/proc/on_entered(datum/source, atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER

	arrived.blob_act(src)


/obj/structure/blob/tesla_act(power)
	..()
	take_damage(power / 400, BURN, "energy")


/obj/structure/blob/attack_animal(mob/living/simple_animal/M)
	if(ROLE_BLOB in M.faction) //sorry, but you can't kill the blob as a blobbernaut
		return
	..()

/obj/structure/blob/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	switch(damage_type)
		if(BRUTE)
			if(damage_amount)
				playsound(src.loc, 'sound/effects/attackblob.ogg', 50, TRUE)
			else
				playsound(src, 'sound/weapons/tap.ogg', 50, TRUE)
		if(BURN)
			playsound(src.loc, 'sound/items/welder.ogg', 100, TRUE)

/obj/structure/blob/run_obj_armor(damage_amount, damage_type, damage_flag = 0, attack_dir)
	switch(damage_type)
		if(BRUTE)
			damage_amount *= brute_resist
		if(BURN)
			damage_amount *= fire_resist
		if(CLONE)
		else
			return 0
	var/armor_protection = 0
	if(damage_flag)
		armor_protection = armor.getRating(damage_flag)
	damage_amount = round(damage_amount * (100 - armor_protection)*0.01, 0.1)
	if(overmind?.blob_reagent_datum && damage_flag)
		damage_amount = overmind.blob_reagent_datum.damage_reaction(src, damage_amount, damage_type, damage_flag)
	return damage_amount

/obj/structure/blob/take_damage(damage_amount, damage_type = BRUTE, damage_flag = 0, sound_effect = 1, attack_dir)
	if(QDELETED(src))
		return
	. = ..()
	if(. && obj_integrity > 0)
		check_integrity()

/obj/structure/blob/proc/change_to(var/type)
	if(!ispath(type))
		error("[type] is an invalid type for the blob.")
	var/obj/structure/blob/B = new type(src.loc)
	if(!istype(type, /obj/structure/blob/core) || !istype(type, /obj/structure/blob/node))
		B.color = color
	else
		B.adjustcolors(color)
	qdel(src)

/obj/structure/blob/proc/adjustcolors(var/a_color)
	if(a_color)
		color = a_color


/obj/structure/blob/examine(mob/user)
	. = ..()
	. += "<span class='notice'>It looks like it's made of [get_chem_name()].</span>"
	. += "<span class='notice'>It looks like this chemical does: [get_chem_desc()].</span>"

/obj/structure/blob/proc/get_chem_name()
	for(var/mob/camera/blob/B in GLOB.mob_list)
		if(!QDELETED(B) && lowertext(B.blob_reagent_datum.color) == lowertext(src.color)) // Goddamit why we use strings for these
			return B.blob_reagent_datum.name
	return "unknown"

/obj/structure/blob/proc/get_chem_desc()
	for(var/mob/camera/blob/B in GLOB.mob_list)
		if(!QDELETED(B) && lowertext(B.blob_reagent_datum.color) == lowertext(src.color)) // Goddamit why we use strings for these
			return B.blob_reagent_datum.description
	return "something unknown"


/obj/structure/blob/hit_by_thrown_carbon(mob/living/carbon/human/C, datum/thrownthing/throwingdatum, damage, mob_hurt, self_hurt)
	damage *= 0.25 // Lets not have sorium be too much of a blender / rapidly kill itself
	return ..()


/obj/structure/blob/normal
	icon_state = "blob"
	light_range = 0
	obj_integrity = 21 //doesn't start at full health
	max_integrity = 25
	brute_resist = 0.25


/obj/structure/blob/normal/check_integrity()
	var/old_compromised_integrity = compromised_integrity
	if(obj_integrity <= 15)
		compromised_integrity = TRUE
	else
		compromised_integrity = FALSE
	if(old_compromised_integrity != compromised_integrity)
		update_state()
		update_appearance(UPDATE_NAME|UPDATE_DESC|UPDATE_ICON_STATE)


/obj/structure/blob/normal/update_state()
	if(compromised_integrity)
		brute_resist = 0.5
	else
		brute_resist = 0.25


/obj/structure/blob/normal/update_name(updates = ALL)
	. = ..()
	if(compromised_integrity)
		name = "fragile blob"
	else
		name = "[overmind ? "blob" : "dead blob"]"


/obj/structure/blob/normal/update_desc(updates = ALL)
	. = ..()
	if(compromised_integrity)
		desc = "A thin lattice of slightly twitching tendrils."
	else
		desc = "A thick wall of [overmind ? "writhing" : "lifeless"] tendrils."


/obj/structure/blob/normal/update_icon_state()
	if(compromised_integrity)
		icon_state = "blob_damaged"
	else
		icon_state = "blob"


