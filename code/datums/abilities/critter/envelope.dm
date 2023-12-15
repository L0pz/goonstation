// basically just a c/p of devour with stuff renamed.  idk.

// -----------------------------------
// Envelope using an action as the timer
// -----------------------------------

/datum/action/bar/icon/envelopAbility
	duration = 4 SECONDS
	interrupt_flags = INTERRUPT_MOVE | INTERRUPT_ACT | INTERRUPT_STUNNED | INTERRUPT_ACTION
	id = "critter_envelop"
	icon = 'icons/mob/critter_ui.dmi'
	icon_state = "devour_over"
	var/mob/living/target
	var/datum/targetable/critter/envelop/ability

	critter
		duration = 6 SECONDS

	New(Target, Envelop)
		target = Target
		ability = Envelop
		..()

	onUpdate()
		..()

		if (BOUNDS_DIST(owner, target) > 0 || target == null || owner == null || ability?.cooldowncheck())
			interrupt(INTERRUPT_ALWAYS)
			return

	onStart()
		..()
		if (BOUNDS_DIST(owner, target) > 0 || target == null || owner == null || ability?.cooldowncheck())
			interrupt(INTERRUPT_ALWAYS)
			return
		owner.visible_message(SPAN_COMBAT("<B>[owner]</B> starts to envelop [target]!"))

	onEnd()
		..()
		var/mob/ownerMob = owner
		if (ownerMob && target && (BOUNDS_DIST(owner, target) == 0) && (!ability || !ability.cooldowncheck()))
			logTheThing(LOG_COMBAT, target, "was enveloped by [constructTarget(ownerMob,"combat")] [ismob(ownerMob) ? "(mob) " : ""]at [log_loc(ownerMob)].")
			owner.visible_message(SPAN_COMBAT("<B>[ownerMob]</B> completely envelops [target]!"))
			playsound(ownerMob, 'sound/impact_sounds/Slimy_Hit_4.ogg', 50, TRUE)
			if(istype(ownerMob))
				ownerMob.health = ownerMob.max_health
				if (target == owner)
					boutput(owner, SPAN_SUCCESS("Good. Job."))
			target.death()
			target.ghostize()
			if (iscarbon(target))
				for (var/obj/item/W in target)
					if (istype(W,/obj/item))
						target.u_equip(W)
						if (W)
							W.set_loc(target.loc)
							W.dropped(target)
							W.layer = initial(W.layer)
			ability?.actionFinishCooldown()
			qdel(target)

/datum/targetable/critter/envelop
	name = "Envelop"
	desc = "After a short delay, instantly envelop a mob. You must stand still for this."
	cooldown = 0
	var/actual_cooldown = 20 SECONDS
	targeted = 1
	target_anything = 1

	proc/actionFinishCooldown()
		cooldown = actual_cooldown
		doCooldown()
		cooldown = initial(cooldown)

	cast(atom/target)
		if (..())
			return 1
		if (isobj(target))
			target = get_turf(target)
		if (isturf(target))
			target = locate(/mob/living) in target
			if (!target)
				boutput(holder.owner, SPAN_ALERT("Nothing to envelop there."))
				return 1
		if (!istype(target, /mob/living))
			boutput(holder.owner, SPAN_ALERT("Invalid target."))
			return 1
		if (BOUNDS_DIST(holder.owner, target) > 0)
			boutput(holder.owner, SPAN_ALERT("That is too far away to envelop."))
			return 1
		actions.start(new/datum/action/bar/icon/envelopAbility(target, src), holder.owner)
		return 0
