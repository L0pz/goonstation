/datum/targetable/changeling/sting
	name = "Sting"
	desc = "Transfer some toxins into your target."
	var/stealthy = 1
	var/venom_id = "toxin"
	var/inject_amount = 50
	cooldown = 140 SECONDS
	targeted = TRUE
	target_anything = TRUE
	target_in_inventory = TRUE
	sticky = TRUE

	cast(atom/target)
		. = ..()
		if (isobj(target) && (target.is_open_container() || istype(target, /obj/item/reagent_containers/food) || istype(target, /obj/item/reagent_containers/patch)))
			if (BOUNDS_DIST(holder.owner, target) > 0)
				boutput(holder.owner, "<span class='alert'>We cannot reach that target with our stinger.</span>")
				return TRUE
			if (!target.reagents)
				boutput(holder.owner, "<span class='notice'>We cannot seem to sting [target].</span>")
				return 1

			if (target.reagents.total_volume >= target.reagents.maximum_volume)
				boutput(holder.owner, "<span class='alert'>[target] is full.</span>")
				return 1
			if (istype(target,/obj/item/reagent_containers/patch))
				var/obj/item/reagent_containers/patch/P = target
				if (P.medical)
					//break the seal
					boutput(holder.owner, "<span class='alert'>You break [P]'s tamper-proof seal!</span>")
					P.medical = FALSE
			logTheThing(LOG_COMBAT, holder.owner, "stings [target] with [name] as a changeling at [log_loc(holder.owner)].")
			target.reagents.add_reagent(venom_id, inject_amount)
			holder.owner.show_message("<span class='notice'>We stealthily sting [target].</span>")
			return FALSE


		if (isobj(target))
			target = get_turf(target)
		if (isturf(target))
			target = locate(/mob/living) in target
			if (!target)
				boutput(holder.owner, "<span class='alert'>We cannot sting without a target.</span>")
				return TRUE
		if (target == holder.owner) // target_self = FALSE doesn't handle this because of fuckass turf targeting
			return TRUE
		if (BOUNDS_DIST(holder.owner, target) > 0)
			boutput(holder.owner, "<span class='alert'>We cannot reach that target with our stinger.</span>")
			return 1
		var/mob/MT = target
		if (!MT.reagents)
			boutput(holder.owner, "<span class='alert'>That does not hold reagents, apparently.</span>")
			return 1
		if (!stealthy)
			holder.owner.visible_message("<span class='alert'><b>[holder.owner] stings [target]!</b></span>")
		else
			holder.owner.show_message("<span class='notice'>We stealthily sting [target].</span>")
		if(MT.reagents.total_volume + inject_amount > MT.reagents.maximum_volume)
			MT.reagents.remove_any(MT.reagents.total_volume + inject_amount - MT.reagents.maximum_volume)
		MT.reagents?.add_reagent(venom_id, inject_amount)

		if (isliving(MT))
			MT:was_harmed(holder.owner, special = "ling")
		logTheThing(LOG_COMBAT, holder.owner, "stings [constructTarget(MT,"combat")] with [name] as a changeling [log_loc(holder.owner)].")

	neurotoxin
		name = "Neurotoxic Sting"
		desc = "Transfer some neurotoxin into your target."
		icon_state = "stingneuro"
		venom_id = "neurotoxin"

	//neuro replacement for RP
	capulettium
		name = "Capulettium Sting"
		desc = "Transfer some capulettium into your target."
		icon_state = "stingneuro"
		venom_id = "capulettium"
		inject_amount = 20

	lsd
		name = "Hallucinogenic Sting"
		desc = "Transfer some LSD into your target."
		icon_state = "stinglsd"
		venom_id = "LSD"
		inject_amount = 30

	dna
		name = "DNA Sting"
		desc = "Injects stable mutagen and the blood of the selected victim into your target."
		icon_state = "stingdna"
		venom_id = "dna_mutagen"
		inject_amount = 30
		pointCost = 4
		var/datum/targetable/changeling/dna_target_select/targeting = null

		New()
			..()

		onAttach(var/datum/abilityHolder/H)
			targeting = H.addAbility(/datum/targetable/changeling/dna_target_select)
			targeting.sting = src
			if (H.owner)
				object.suffix = "\[[holder.owner.name]\]"

		cast(atom/target)
			if (..())
				return 1
			if (target.is_open_container() == 1 || istype(target,/obj/item/reagent_containers/food) || istype(target,/obj/item/reagent_containers/patch))
				if (target.reagents.total_volume >= target.reagents.maximum_volume)
					return 0
				var/max_amount = min(15,target.reagents.maximum_volume - target.reagents.total_volume)
				target.reagents?.add_reagent("blood", max_amount, targeting.dna_sting_target)
				return 0
			var/mob/MT = target
			MT.reagents?.add_reagent("blood", 15, targeting.dna_sting_target)
			return 0

	fartonium
		name = "Fartonium Sting"
		desc = "Let someone else let 'er rip"
		icon_state = "stingfart"
		venom_id = "fartonium"
		inject_amount = 25
		cooldown = 60 SECONDS

	simethicone
		name = "Anti-farting sting"
		desc = "You fartless bastard"
		icon_state = "stingnofart"
		venom_id = "anti_fart"
		inject_amount = 25
		cooldown = 60 SECONDS


/datum/targetable/changeling/dna_target_select
	name = "Select DNA Sting target"
	desc = "Select target for DNA sting"
	icon_state = "stingdna"
	copiable = FALSE
	lock_holder = FALSE
	ignore_holder_lock = TRUE
	var/datum/bioHolder/dna_sting_target = null
	var/datum/targetable/changeling/sting = null
	sticky = TRUE

	onAttach(var/datum/abilityHolder/G)
		var/datum/abilityHolder/changeling/H = G
		if (istype(H) && length(H.absorbed_dna) > 0)
			dna_sting_target = H.absorbed_dna[H.absorbed_dna[1]]

	cast(atom/target)
		if (..())
			return 1

		var/datum/abilityHolder/changeling/H = holder
		if (!istype(H))
			boutput(holder.owner, "<span class='alert'>That ability is incompatible with our abilities. We should report this to a coder.</span>")
			return 1

		var/target_name = tgui_input_list(holder.owner, "Select new DNA sting target!", "DNA Sting Target", sortList(H.absorbed_dna, /proc/cmp_text_asc))
		if (!target_name)
			boutput(holder.owner, "<span class='notice'>We change our mind.</span>")
			return 1

		dna_sting_target = H.absorbed_dna[target_name]
		if (sting)
			sting.object.suffix = "\[[target_name]\]"

		return 0
