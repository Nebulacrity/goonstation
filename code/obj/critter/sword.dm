/* ================================================== */
/* --- Syndicate Weapon: Orion Retribution Device --- */
/* ================================================== */

/obj/critter/sword
	name = "Deep Space Beacon"
	var/transformation_name = "Syndicate Locator Beacon"
	var/true_name = "Syndicate Weapon: Orion Retribution Device"
	desc = "A huge beacon, seemingly constructed for broadcasting long-range signals."
	var/transformation_desc = "A huge beacon, seemingly constructed for baiting Nanotrasen personnel into thinking it's just a beacon."
	var/true_desc = "An automated miniature doomsday device constructed by the Syndicate."
	icon = 'icons/misc/retribution/SWORD/base.dmi'
	icon_state = "beacon"
	dead_state = "anchored"
	death_text = "The Syndicate Weapon stops moving, leaving wreckage in it's wake."
	pet_text = "tries to get the attention of"
	angertext = "focuses on"
	atk_text = "bumps into"
	chase_text = "chases after"
	crit_text = "slams into"
	atk_delay = 50
	crit_chance = 25
	health = 6000
	bound_height = 96
	bound_width = 96
	layer = MOB_LAYER + 5
	atkcarbon = 1
	atksilicon = 1
	flying = 1
	generic = 0
	seekrange = 256						//A perk of being a high-tech prototype - incredibly large detection range.
	var/mode = 0						//0 - Beacon. 1 - Unanchored. 2 - Anchored.
	var/cooldown = 0					//Used to prevent the SWORD from using abilities all the time.
	var/transformation_triggered = false//Used to check if the initial transformation has already been started or not.
	var/changing_modes = false			//Used to prevent some things during transformation sequences.
	var/rotation_locked = false			//Used to lock the SWORD's rotation in place.
	var/current_ability = null			//Used to keep track of what ability the SWORD is currently using.
	var/used_ability = 0				//Used to only allow transforming after at least one ability has been used.
	var/current_heat_level = 0			//Used to keep track of the SWORD's heat for Heat Reallocation.
	var/stuck_location = null			//Used to prevent the SWORD from getting stuck too much.
	var/stuck_timer = null				//Ditto.
	var/image/glow

	New()
		..()
		anchored = 1
		firevuln = 0
		brutevuln = 0
		miscvuln = 0

		SPAWN_DBG(1 MINUTE)
			if(mode == 0 && !changing_modes && !transformation_triggered)	//If in Beacon form and not already transforming...
				transformation_countdown()									//...the countdown starts.
		return
	
	CritterDeath()
		..()
		SPAWN_DBG(5 SECONDS)
			command_announcement("<br><b><span class='alert'>The Syndicate Weapon has been eliminated.</span></b>", "Safety Update", "sound/misc/announcement_1.ogg")
			logTheThing("combat", src, null, "has been defeated.")
			message_admins("The Syndicate Weapon: Orion Retribution Device has been defeated.")

		var/datum/effects/system/harmless_smoke_spread/smoke = new /datum/effects/system/harmless_smoke_spread()
		smoke.set_up(5, 0, get_center())
		smoke.attach(src)
		smoke.start()

		explosion_new(get_center(), get_center(), rand(6, 12))
		fireflash(get_center(), 2)

		for(var/board_count = rand(4, 8), board_count > 0, board_count--)
			new/obj/item/factionrep/ntboard(locate(src.loc.x + rand(-1, 3), src.loc.y + rand(-1, 3), src.loc.z))
			board_count--
		for(var/alloy_count = rand(1, 3), alloy_count > 0, alloy_count--)
			new/obj/item/material_piece/iridiumalloy(locate(src.loc.x + rand(0, 2), src.loc.y + rand(0, 2), src.loc.z))
			alloy_count--
		new/obj/machinery/power/sword_engine(get_center())

		SPAWN_DBG(1 SECOND)
			elecflash(get_center())
			qdel(src)

	process()
		if (!src.alive) return 0

		if(sleeping > 0)
			sleeping--
			return 0

		check_health()

		if(prob(5))
			playsound(src, 'sound/machines/giantdrone_boop1.ogg', 55, 1)

		if(task == "following path" && mode)
			follow_path()
		else if(task == "sleeping" && mode)
			var/waking = 0

			for (var/client/C)
				var/mob/M = C.mob
				if (M && src.z == M.z && get_dist(src,M) <= 64)
					if (isliving(M))
						waking = 1
						break

			for (var/atom in by_cat[TR_CAT_PODS_AND_CRUISERS])
				var/atom/A = atom
				if (A && src.z == A.z && get_dist(src,A) <= 64)
					waking = 1
					break

			if (!waking)
				if (get_area(src) == colosseum_controller.colosseum)
					waking = 1

			if(waking)
				task = "thinking"
			else
				sleeping = 5
				return 0
		else if(sleep_check <= 0 && mode)
			sleep_check = 5

			var/stay_awake = 0

			for (var/client/C)
				var/mob/M = C.mob
				if (M && src.z == M.z && get_dist(src,M) <= 32)
					if (isliving(M))
						stay_awake = 1
						break

			for (var/atom in by_cat[TR_CAT_PODS_AND_CRUISERS])
				var/atom/A = atom
				if (A && src.z == A.z && get_dist(src,A) <= 32)
					stay_awake = 1
					break

			if(!stay_awake)
				sleeping = 5
				task = "sleeping"
				return 0

		else
			sleep_check--

		return ai_think()

	ai_think()
		if(mode)
			switch(task)
				if("thinking")
					src.attack = 0
					src.target = null

					walk_to(src,0)
					seek_target()
					if (!src.target) src.task = "wandering"
				if("chasing")
					if (src.frustration >= rand(32,64))
						src.target = null
						src.last_found = world.time
						src.frustration = 0
						src.task = "thinking"
						walk_to(src,0)
					if (target)
						if (get_dist(get_center(), src.target) <= 3)
							var/mob/living/carbon/M = src.target
							if (M)
								if(!src.attacking) ChaseAttack(M)
								src.task = "attacking"
								src.target_lastloc = M.loc

						else
							if(!stuck_timer)
								stuck_timer = 12 SECONDS + world.time
								stuck_location = get_center()
							
							if(stuck_timer <= world.time && stuck_location == get_center())
								cooldown = 4 SECONDS + world.time
								anchored = 1
								stuck_timer = null
								SPAWN_DBG(4 SECONDS)
									anchored = 0
								for(var/stuck_increment = 1, stuck_increment <= 3, stuck_increment++)
									SPAWN_DBG(stuck_increment SECONDS)
										for (var/turf/simulated/OV in oview(get_center(),stuck_increment))
											tile_purge(OV.loc.x,OV.loc.y,3)

							var/turf/olddist = get_dist(get_center(), src.target)

							for (var/turf/simulated/wall/WT in range(2,get_center()))
								leavescan(WT, 1)
								new /obj/item/raw_material/scrap_metal(WT)
								if(prob(50))
									WT.ReplaceWithLattice()
								else
									WT.ReplaceWithSpace()

								walk_to(src, src.target,1,5)

							if ((get_dist(get_center(), src.target)) >= (olddist))
								src.frustration++
							else
								src.frustration = 0
							
							ability_selection()

					else src.task = "thinking"
				if("attacking")
					if ((get_dist(get_center(), src.target) > 3) || ((src.target:loc != src.target_lastloc)))
						src.task = "chasing"
					else
						if (get_dist(get_center(), src.target) <= 3)
							var/mob/living/carbon/M = src.target
							if (!src.attacking) CritterAttack(src.target)
							if(M != null)
								if (M.health <= 0)
									src.task = "thinking"
									src.target = null
									src.last_found = world.time
									src.frustration = 0
									src.attacking = 0
								else
									ability_selection()
						else
							src.attacking = 0
							src.task = "chasing"
				if("wandering")
					patrol_step()
		return 1


//-ABILITY SELECTION-//

	proc/ability_selection()
		if(cooldown <= world.time && mode && !current_ability && !changing_modes)
			cooldown = 2 SECONDS + world.time
			if(prob(36) && used_ability)
				used_ability = 0
				configuration_swap()
			else
				switch(task)
					if("chasing")
						used_ability = 1
						current_heat_level = current_heat_level + 20
						if(mode == 1)						//Unanchored.
							destructive_flight()
						else								//Anchored.
							if (prob(32) && get_dist(get_center(), src.target) <= 9)
								linear_purge()
							else
								destructive_leap()

					if("attacking")
						used_ability = 1
						current_heat_level = current_heat_level + 20
						if(prob(20))
							stifling_vacuum()
						else if(mode == 1)					//Unanchored.
							if(current_heat_level > 100)
								current_heat_level = 100
							if(prob(current_heat_level))
								heat_reallocation()
							else
								energy_absorption()
						else								//Anchored.
							if(prob(48))
								linear_purge()
							else
								gyrating_edge()


//-TRANSFORMATIONS-//
	
	proc/transformation(var/transformation_id)				//0 - Beacon. 1 - Unanchored. 2 - Anchored.		
		anchored = 1
		firevuln = 1.25
		brutevuln = 1.25
		miscvuln = 0.25
		current_ability = "transformation"

		switch(transformation_id)
			if(0)
				rotation_locked = true
				changing_modes = true
				icon = 'icons/misc/retribution/SWORD/transformations.dmi'
				icon_state = "beacon"
				glow = image('icons/misc/retribution/SWORD/transformations_o.dmi', "beacon")
				glow.plane = PLANE_SELFILLUM
				src.UpdateOverlays(glow, "glow")
				SPAWN_DBG(18)
					icon = 'icons/misc/retribution/SWORD/base.dmi'
					icon_state = "unanchored"
					glow = image('icons/misc/retribution/SWORD/base_o.dmi', "unanchored")
					glow.plane = PLANE_SELFILLUM
					src.UpdateOverlays(glow, "glow")
					changing_modes = false
					rotation_locked = false
					name = true_name
					desc = true_desc
					aggressive = 1							//Only after exiting the beacon form will the SWORD become aggressive.
					health = 6000
					mode = 1

			if(1)
				rotation_locked = true
				changing_modes = true
				icon = 'icons/misc/retribution/SWORD/transformations.dmi'
				icon_state = "anchored"
				glow = image('icons/misc/retribution/SWORD/transformations_o.dmi', "anchored")
				glow.plane = PLANE_SELFILLUM
				src.UpdateOverlays(glow, "glow")
				SPAWN_DBG(11)
					icon = 'icons/misc/retribution/SWORD/base.dmi'
					icon_state = "unanchored"
					glow = image('icons/misc/retribution/SWORD/base_o.dmi', "unanchored")
					glow.plane = PLANE_SELFILLUM
					src.UpdateOverlays(glow, "glow")
					changing_modes = false
					rotation_locked = false
					mode = 1

			else
				rotation_locked = true
				changing_modes = true
				icon = 'icons/misc/retribution/SWORD/transformations.dmi'
				icon_state = "unanchored"
				glow = image('icons/misc/retribution/SWORD/transformations_o.dmi', "unanchored")
				glow.plane = PLANE_SELFILLUM
				src.UpdateOverlays(glow, "glow")
				SPAWN_DBG(11)
					icon = 'icons/misc/retribution/SWORD/base.dmi'
					icon_state = "anchored"
					glow = image('icons/misc/retribution/SWORD/base_o.dmi', "anchored")
					glow.plane = PLANE_SELFILLUM
					src.UpdateOverlays(glow, "glow")
					changing_modes = false
					rotation_locked = false
					mode = 2

		SPAWN_DBG(10)
			anchored = 0
			firevuln = 1
			brutevuln = 1
			miscvuln = 0.2
			current_ability = null
		return


//-GENERAL ABILITIES-//

	proc/configuration_swap()								//Swaps between anchored and unanchored forms, if possible.
		if(mode == 0)
			return

//		var/pathable_turfs = 0
//		for (var/turf/T in range(1, get_center()))
//			if (T && (T.pathable || istype(T, /turf/space)))
//				pathable_turfs++

		if(mode == 1)
			transformation(2)
			return

		else
			if(mode == 2)
				transformation(1)
				return


	proc/stifling_vacuum()									//In a T-shape in front of it, trips and attracts closer all mobs affected.
		current_ability = "stifling_vacuum"
		walk_towards(src, src.target)
		walk(src,0)
		anchored = 1
		glow = image('icons/misc/retribution/SWORD/abilities_o.dmi', "stiflingVacuum")
		glow.plane = PLANE_SELFILLUM
		src.UpdateOverlays(glow, "glow")
		SPAWN_DBG(4)
			var/increment
			switch (src.dir)
				if (1)	//N
					var/turf/T = locate(src.loc.x + 1,src.loc.y + 3,src.loc.z)
					for (var/mob/M in T)
						M.changeStatus("stunned", 2 SECONDS)
						M.changeStatus("weakened", 4 SECONDS)
					for(increment = -1; increment <= 1; increment++)
						for(var/mob/M in locate(src.loc.x + 1 + increment,src.loc.y + 4,src.loc.z))
							M.changeStatus("stunned", 2 SECONDS)
							M.changeStatus("weakened", 4 SECONDS)
							M.throw_at(T, 3, 1)

				if (4)	//E
					var/turf/T = locate(src.loc.x + 3,src.loc.y + 1,src.loc.z)
					for (var/mob/M in T)
						M.changeStatus("stunned", 2 SECONDS)
						M.changeStatus("weakened", 4 SECONDS)
					for(increment = -1; increment <= 1; increment++)
						for(var/mob/M in locate(src.loc.x + 4,src.loc.y + 1 + increment,src.loc.z))
							M.changeStatus("stunned", 2 SECONDS)
							M.changeStatus("weakened", 4 SECONDS)
							M.throw_at(T, 3, 1)

				if (2)	//S
					var/turf/T = locate(src.loc.x + 1,src.loc.y - 1,src.loc.z)
					for (var/mob/M in T)
						M.changeStatus("stunned", 2 SECONDS)
						M.changeStatus("weakened", 4 SECONDS)
					for(increment = -1; increment <= 1; increment++)
						for(var/mob/M in locate(src.loc.x + 1 + increment,src.loc.y - 2,src.loc.z))
							M.changeStatus("stunned", 2 SECONDS)
							M.changeStatus("weakened", 4 SECONDS)
							M.throw_at(T, 3, 1)

				if (8)	//W
					var/turf/T = locate(src.loc.x - 1,src.loc.y + 1,src.loc.z)
					for (var/mob/M in T)
						M.changeStatus("stunned", 2 SECONDS)
						M.changeStatus("weakened", 4 SECONDS)
					for(increment = -1; increment <= 1; increment++)
						for(var/mob/M in locate(src.loc.x - 2,src.loc.y + 1 + increment,src.loc.z))
							M.changeStatus("stunned", 2 SECONDS)
							M.changeStatus("weakened", 4 SECONDS)
							M.throw_at(T, 3, 1)

		SPAWN_DBG(8)
			anchored = 0
			if(mode == 1)
				glow = image('icons/misc/retribution/SWORD/base_o.dmi', "unanchored")
			else
				glow = image('icons/misc/retribution/SWORD/base_o.dmi', "anchored")
			glow.plane = PLANE_SELFILLUM
			src.UpdateOverlays(glow, "glow")
			current_ability = null
		return


//-ANCHORED ABILITIES-//

	proc/linear_purge()										//After 1.5 seconds, unleashes a destructive beam.
		firevuln = 1.5
		brutevuln = 1.5
		miscvuln = 0.4
		current_ability = "linear_purge"

		walk_towards(src, src.target)
		walk(src,0)
		playsound(get_center(), "sound/weapons/heavyioncharge.ogg", 75, 1)
		anchored = 1

		var/increment
		var/turf/T

		switch (src.dir)
			if (1)	//N
				for(increment = 2; increment <= 9; increment++)
					T = locate(src.loc.x,src.loc.y + increment,src.loc.z)
					leavepurge(T, increment, src.dir)
					SPAWN_DBG(15)
						playsound(get_center(), 'sound/weapons/laserultra.ogg', 100, 1)
						tile_purge(src.loc.x + 1,src.loc.y + 1 + increment,0)

			if (4)	//E
				for(increment = 2; increment <= 9; increment++)
					T = locate(src.loc.x + increment,src.loc.y,src.loc.z)
					leavepurge(T, increment, src.dir)
					SPAWN_DBG(15)
						playsound(get_center(), 'sound/weapons/laserultra.ogg', 100, 1)
						tile_purge(src.loc.x + 1 + increment,src.loc.y + 1,0)

			if (2)	//S
				for(increment = 2; increment <= 9; increment++)
					T = locate(src.loc.x,src.loc.y - increment,src.loc.z)
					leavepurge(T, increment, src.dir)
					SPAWN_DBG(15)
						playsound(get_center(), 'sound/weapons/laserultra.ogg', 100, 1)
						tile_purge(src.loc.x + 1,src.loc.y + 1 - increment,0)

			if (8)	//W
				for(increment = 2; increment <= 9; increment++)
					T = locate(src.loc.x - increment,src.loc.y,src.loc.z)
					leavepurge(T, increment, src.dir)
					SPAWN_DBG(15)
						playsound(get_center(), 'sound/weapons/laserultra.ogg', 100, 1)
						tile_purge(src.loc.x + 1 - increment,src.loc.y + 1,0)

		SPAWN_DBG(10)
			rotation_locked = true

		SPAWN_DBG(20)
			glow = image('icons/misc/retribution/SWORD/base_o.dmi', "anchored")
			glow.plane = PLANE_SELFILLUM
			src.UpdateOverlays(glow, "glow")
			rotation_locked = false
			anchored = 0
			firevuln = 1
			brutevuln = 1
			miscvuln = 0.2
			current_ability = null


	proc/gyrating_edge()									//Spins, dealing mediocre damage to anyone nearby.
		rotation_locked = true
		anchored = 1
		firevuln = 0.5
		brutevuln = 0.5
		miscvuln = 0.1
		current_ability = "gyrating_edge"

		var/spin_dir = prob(50) ? "L" : "R"
		animate_spin(src, spin_dir, 5, 0)
		playsound(get_center(), "sound/effects/flameswoosh.ogg", 60, 1)
		if(spin_dir == "L")
			glow = image('icons/misc/retribution/SWORD/abilities_o.dmi', "gyratingEdge_L")
		else
			glow = image('icons/misc/retribution/SWORD/abilities_o.dmi', "gyratingEdge_R")
		glow.plane = PLANE_SELFILLUM
		src.UpdateOverlays(glow, "glow")

		SPAWN_DBG(1)
			for (var/mob/M in range(5,get_center()))
				random_brute_damage(M, 32)
				random_burn_damage(M, 16)

		SPAWN_DBG(5)
			animate_spin(src, spin_dir, 5, 0)

		SPAWN_DBG(6)
			for (var/mob/M in range(5,get_center()))
				random_brute_damage(M, 16)
				random_burn_damage(M, 32)

		SPAWN_DBG(10)
			glow = image('icons/misc/retribution/SWORD/base_o.dmi', "anchored")
			glow.plane = PLANE_SELFILLUM
			src.UpdateOverlays(glow, "glow")
			rotation_locked = false
			anchored = 0
			firevuln = 1
			brutevuln = 1
			miscvuln = 0.2
			current_ability = null


	proc/destructive_leap()									//Leaps at the target using it's thrusters, dealing damage at the landing location and probably gibbing anyone at the center of said location.
		walk_towards(src, src.target)
		walk(src,0)
		for (var/mob/B in range(3,get_center()))
			random_burn_damage(B, 30)
			B.changeStatus("burning", 3 SECONDS)
		icon = 'icons/misc/retribution/SWORD/abilities.dmi'
		icon_state = "destructiveLeap"
		glow = image('icons/misc/retribution/SWORD/abilities_o.dmi', "destructive")
		glow.plane = PLANE_SELFILLUM
		src.UpdateOverlays(glow, "glow")
		rotation_locked = true
		firevuln = 0.75
		brutevuln = 0.75
		miscvuln = 0.15
		current_ability = "destructive_leap"
//		animate_float(src, -1, 5, 1)
		playsound(get_center(), "sound/effects/flame.ogg", 80, 1)

		SPAWN_DBG(2)
			for(var/i=0, i < 6, i++)
				step(src, src.dir)
				if(i < 3)
					src.pixel_y += 4
				else
					src.pixel_y -= 4
				sleep(0.2)
			for (var/mob/M in range(3,get_center()))
				random_brute_damage(M, 60)
			tile_purge(src.loc.x + 1,src.loc.y + 1,1)
			for (var/mob/M in get_center())
				if(prob(69))								//Nice.
					M.gib()
				else
					random_brute_damage(M, 120)

		SPAWN_DBG(10)
			icon = 'icons/misc/retribution/SWORD/base.dmi'
			icon_state = "anchored"
			glow = image('icons/misc/retribution/SWORD/base_o.dmi', "anchored")
			glow.plane = PLANE_SELFILLUM
			src.UpdateOverlays(glow, "glow")
			rotation_locked = false
			firevuln = 1
			brutevuln = 1
			miscvuln = 0.2
			current_ability = null


//-UNANCHORED ABILITIES-//

	proc/heat_reallocation()								//Sets anyone nearby on fire while dealing increasing burning damage.
		rotation_locked = true
		anchored = 1
		firevuln = 1.25
		brutevuln = 1.25
		miscvuln = 0.25
		current_ability = "heat_reallocation"

		playsound(get_center(), "sound/effects/gust.ogg", 60, 1)
		glow = image('icons/misc/retribution/SWORD/abilities_o.dmi', "heatReallocation")
		glow.plane = PLANE_SELFILLUM
		src.UpdateOverlays(glow, "glow")

		SPAWN_DBG(2)
			for (var/mob/M in range(3,get_center()))
				random_burn_damage(M, (current_heat_level / 5))
				M.changeStatus("burning", 4 SECONDS)

		SPAWN_DBG(4)
			for (var/mob/M in range(3,get_center()))
				random_burn_damage(M, (current_heat_level / 4))
				M.changeStatus("burning", 6 SECONDS)

		SPAWN_DBG(6)
			for (var/mob/M in range(3,get_center()))
				random_burn_damage(M, (current_heat_level / 3))
				M.changeStatus("burning", 8 SECONDS)

		SPAWN_DBG(8)
			current_heat_level = 0
			icon = 'icons/misc/retribution/SWORD/base.dmi'
			icon_state = "unanchored"
			glow = image('icons/misc/retribution/SWORD/base_o.dmi', "unanchored")
			glow.plane = PLANE_SELFILLUM
			src.UpdateOverlays(glow, "glow")
			rotation_locked = false
			anchored = 0
			firevuln = 1
			brutevuln = 1
			miscvuln = 0.2
			current_ability = null


	proc/energy_absorption()								//Becomes immune to burn damage for the duration. Creates a snapshot of it's health during activation, returning to it after 1.2 seconds. Increases the heat value by damage taken during the duration.
		rotation_locked = true
		anchored = 1
		firevuln = 0
		brutevuln = 1.25
		miscvuln = 0.25
		current_ability = "energy_absorption"

		var/health_before_absorption = health
		//playsound(get_center(), 'sound/effects/shieldup.ogg', 80, 1)
		glow = image('icons/misc/retribution/SWORD/abilities_o.dmi', "energyAbsorption")
		glow.plane = PLANE_SELFILLUM
		src.UpdateOverlays(glow, "glow")

		SPAWN_DBG(12)
			if(health_before_absorption > health)
				current_heat_level = current_heat_level + health_before_absorption - health
				health = health_before_absorption

			icon = 'icons/misc/retribution/SWORD/base.dmi'
			icon_state = "unanchored"
			glow = image('icons/misc/retribution/SWORD/base_o.dmi', "unanchored")
			glow.plane = PLANE_SELFILLUM
			src.UpdateOverlays(glow, "glow")
			rotation_locked = false
			anchored = 0
			firevuln = 1
			brutevuln = 1
			miscvuln = 0.2
			current_ability = null


	proc/destructive_flight()								//Charges at the target using it's thrusters twice, dealing damage at the locations of each one's end.
		walk_towards(src, src.target)
		walk(src,0)
		for (var/mob/B in range(3,get_center()))
			random_burn_damage(B, 30)
		icon = 'icons/misc/retribution/SWORD/abilities.dmi'
		icon_state = "destructiveFlight"
		glow = image('icons/misc/retribution/SWORD/abilities_o.dmi', "destructive")
		glow.plane = PLANE_SELFILLUM
		src.UpdateOverlays(glow, "glow")
		rotation_locked = true
		firevuln = 0.75
		brutevuln = 0.75
		miscvuln = 0.15
		current_ability = "destructive_flight"
//		animate_float(src, -1, 5, 1)
		playsound(get_center(), "sound/effects/flame.ogg", 80, 1)

		var/increment
		var/turf/T

		SPAWN_DBG(1)
			for(var/i=0, i < 6, i++)
				switch (src.dir)
					if (1)	//N
						for(increment = -1; increment <= 1; increment++)
							T = locate(src.loc.x + 1 + increment,src.loc.y + 3,src.loc.z)
							if(T && prob(33))
								playsound(get_center(), 'sound/effects/smoke_tile_spread.ogg', 70, 1)
								tile_purge(src.loc.x + 1 + increment,src.loc.y + 3,0)

					if (4)	//E
						for(increment = -1; increment <= 1; increment++)
							T = locate(src.loc.x + 3,src.loc.y + 1 + increment,src.loc.z)
							if(T && prob(33))
								playsound(get_center(), 'sound/effects/smoke_tile_spread.ogg', 70, 1)
								tile_purge(src.loc.x + 3,src.loc.y + 1 + increment,0)

					if (2)	//S
						for(increment = -1; increment <= 1; increment++)
							T = locate(src.loc.x + 1 + increment,src.loc.y - 1,src.loc.z)
							if(T && prob(33))
								playsound(get_center(), 'sound/effects/smoke_tile_spread.ogg', 70, 1)
								tile_purge(src.loc.x + 1 + increment,src.loc.y - 1,0)

					if (8)	//W
						for(increment = -1; increment <= 1; increment++)
							T = locate(src.loc.x - 1,src.loc.y + 1 + increment,src.loc.z)
							if(T && prob(33))
								playsound(get_center(), 'sound/effects/smoke_tile_spread.ogg', 70, 1)
								tile_purge(src.loc.x - 1,src.loc.y + 1 + increment,0)
				step(src, src.dir)
				sleep(0.1)
			for (var/mob/M in range(3,get_center()))
				random_brute_damage(M, 60)

		SPAWN_DBG(8)
			walk_towards(src, src.target)
			walk(src,0)
			for(var/l=0, l < 6, l++)
				switch (src.dir)
					if (1)	//N
						for(increment = -1; increment <= 1; increment++)
							T = locate(src.loc.x + 1,src.loc.y + 3,src.loc.z)
							if(T)
								playsound(get_center(), 'sound/effects/smoke_tile_spread.ogg', 70, 1)
								tile_purge(src.loc.x + 1 + increment,src.loc.y + 3,0)

					if (4)	//E
						for(increment = -1; increment <= 1; increment++)
							T = locate(src.loc.x + 3,src.loc.y + 1,src.loc.z)
							if(T)
								playsound(get_center(), 'sound/effects/smoke_tile_spread.ogg', 70, 1)
								tile_purge(src.loc.x + 3,src.loc.y + 1 + increment,0)

					if (2)	//S
						for(increment = -1; increment <= 1; increment++)
							T = locate(src.loc.x + 1,src.loc.y - 1,src.loc.z)
							if(T)
								playsound(get_center(), 'sound/effects/smoke_tile_spread.ogg', 70, 1)
								tile_purge(src.loc.x + 1 + increment,src.loc.y - 1,0)

					if (8)	//W
						for(increment = -1; increment <= 1; increment++)
							T = locate(src.loc.x - 1,src.loc.y + 1,src.loc.z)
							if(T)
								playsound(get_center(), 'sound/effects/smoke_tile_spread.ogg', 70, 1)
								tile_purge(src.loc.x - 1,src.loc.y + 1 + increment,0)
				step(src, src.dir)
				sleep(0.1)
			for (var/mob/O in range(3,get_center()))
				random_brute_damage(O, 45)

		SPAWN_DBG(15)
			icon = 'icons/misc/retribution/SWORD/base.dmi'
			icon_state = "unanchored"
			glow = image('icons/misc/retribution/SWORD/base_o.dmi', "unanchored")
			glow.plane = PLANE_SELFILLUM
			src.UpdateOverlays(glow, "glow")
			rotation_locked = false
			firevuln = 1
			brutevuln = 1
			miscvuln = 0.2
			current_ability = null


//-MISCELLANEOUS-//

	proc/tile_purge(var/point_x, var/point_y, var/dam_type)	//A helper proc for Linear Purge, Destructive Leap and Destructive Flight.
		for (var/mob/M in locate(point_x,point_y,src.z))
			if(!dam_type)
				if (isrobot(M))
					M.health = M.health * rand(0.10, 0.20)
				else
					random_burn_damage(M, 80)
				playsound(M.loc, "sound/impact_sounds/burn_sizzle.ogg", 70, 1)
			else
				if (isrobot(M))
					M.health = M.health * rand(0.10 / dam_type, 0.20 / dam_type)
				else
					random_brute_damage(M, 80 / dam_type)
			M.changeStatus("weakened", 4 SECOND)
			M.changeStatus("stunned", 1 SECOND)
			INVOKE_ASYNC(M, /mob.proc/emote, "scream")
		var/turf/simulated/T = locate(point_x,point_y,src.z)
		if(dam_type == 2 && istype(T, /turf/simulated/wall))
			leavescan(T, 1)
			if(prob(64))
				new /obj/item/raw_material/scrap_metal(T)
				if(prob(32))
					new /obj/item/raw_material/scrap_metal(T)
			if(prob(50))
				T.ReplaceWithLattice()
			else
				T.ReplaceWithSpace()
		else
			if(T && prob(90))
				new /obj/item/raw_material/scrap_metal(T)
				if(prob(48))
					new /obj/item/raw_material/scrap_metal(T)
				if(prob(32))
					T.ReplaceWithLattice()
				else
					T.ReplaceWithSpace()
			for (var/obj/S in locate(point_x,point_y,src.z))
				if(dam_type == 3 && !istype(S, /obj/critter))
					leavescan(get_turf(S), 1)
					qdel(S)
				else if(prob(64) && !istype(S, /obj/critter))
					leavescan(get_turf(S), 1)
					S.ex_act(1)
		return


	proc/transformation_countdown()							//Starts the initial transformation's countdown.
		transformation_triggered = true
		name = transformation_name
		desc = transformation_desc
		glow = image('icons/misc/retribution/SWORD/base_o.dmi', "beacon")
		glow.plane = PLANE_SELFILLUM
		src.UpdateOverlays(glow, "glow")
		command_announcement("<br><b><span class='alert'>An unidentified long-range beacon has been detected near the station. Await further instructions.</span></b>", "Alert", "sound/vox/alert.ogg")
		SPAWN_DBG(2 MINUTES)
			command_announcement("<br><b><span class='alert'>The station is under siege by the Syndicate-made object detected earlier. Survive any way possible.</span></b>", "Alert", "sound/vox/alert.ogg")
			transformation(0)


	proc/get_center()										//Returns the central turf.
		var/turf/center_tile = get_step(get_turf(src), NORTHEAST)
		return center_tile