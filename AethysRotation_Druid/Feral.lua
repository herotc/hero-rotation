--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, addonTable = ...;
  -- AethysCore
  local AC = AethysCore;
  local Cache = AethysCache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- AethysRotation
  local AR = AethysRotation;
  -- Lua
  


--- ============================ CONTENT ============================
  --- ======= APL LOCALS =======
  local Everyone = AR.Commons.Everyone;
  local Druid = AR.Commons.Druid;
  -- Spells
  if not Spell.Druid then Spell.Druid = {}; end
  Spell.Druid.Feral = {
    -- Racials
    Shadowmeld          = Spell(58984),
    -- Abilities
    Berserk             = Spell(106951),
    FerociousBite       = Spell(22568),
    PredatorySwiftness  = Spell(69369),
    Prowl               = Spell(5215),
    Rake                = Spell(1822),
    RakeDebuff          = Spell(155722),
    Rip                 = Spell(1079),
    Shred               = Spell(5221),
    Swipe               = Spell(106785),
    Thrash              = Spell(106830),
    TigersFury          = Spell(5217),
    WildCharge          = Spell(49376),
	Maim				= Spell(22570),
	Moonfire			= Spell(8921),
    -- Talents
	BrutalSlash			= Spell(202028),
    BalanceAffinity     = Spell(197488),
    GuardianAffinity    = Spell(217615),
    JaggedWounds        = Spell(202032),
    Incarnation         = Spell(102543),
    RestorationAffinity = Spell(197492),
	Bloodtalons			= Spell(155672),
	BloodtalonsBuff		= Spell(145152),
	ElunesGuidance		= Spell(202060),
	SavageRoar			= Spell(52610),
	Sabertooth			= Spell(202031),
	LunarInspiration	= Spell(155580),
    -- Artifact
    AshamanesFrenzy     = Spell(210722),
    -- Defensive
    Regrowth            = Spell(8936),
    Renewal             = Spell(108238),
    SurvivalInstincts   = Spell(61336),
    -- Utility
    SkullBash           = Spell(106839),
    -- Shapeshift
    BearForm            = Spell(5487),
    CatForm             = Spell(768),
    MoonkinForm         = Spell(197625),
    TravelForm          = Spell(783),
    -- Legendaries
    FieryRedMaimers		= Spell(236757),
    -- Misc
	Clearcasting		= Spell(135700),
	PoolEnergy          = Spell(9999000010),
    -- Macros
    
  };
  local S = Spell.Druid.Feral;
  
  S.Rip:RegisterPMultiplier({S.BloodtalonsBuff, 1.2}, {S.SavageRoar, 1.15}, {S.TigersFury, 1.15});
  --S.Thrash:RegisterPMultiplier({S.BloodtalonsBuff, 1.2}, {S.SavageRoar, 1.15}, {S.TigersFury, 1.15}); Don't need it but add moment of clarity scaling if we add it
  S.Rake:RegisterPMultiplier(
        {function ()
          --return (Player:Buff(S.Prowl) or S.Prowl:TimeSinceLastRemovedOnPlayer() < 0.1 or Player:Buff(S.Shadowmeld) or S.Shadowmeld:TimeSinceLastRemovedOnPlayer() < 0.1) and 2 or 1;
		  return Player:IsStealthed(true, true) and 2 or 1;
        end},
        {S.BloodtalonsBuff, 1.2}, {S.SavageRoar, 1.15}, {S.TigersFury, 1.15}
      );
	  
  local function currentPMulti(rSpell)
	local pMulti = 1
	if Player:Buff(S.BloodtalonsBuff) or (S.BloodtalonsBuff:TimeSinceLastRemovedOnPlayer() < 0.1) then
		pMulti = pMulti * 1.2
	end
	if Player:Buff(S.SavageRoar) or (S.SavageRoar:TimeSinceLastRemovedOnPlayer() < 0.1) then
		pMulti = pMulti * 1.15
	end
	if Player:Buff(S.TigersFury) or (S.TigersFury:TimeSinceLastRemovedOnPlayer() < 0.1) then
		pMulti = pMulti * 1.15
	end
	if rSpell == S.Rake and Player:IsStealthed(true,true) then
		pMulti = pMulti * 2
	end
	return pMulti
  end
  
  local function IsDebuffRefreshable(dot)
	if dot == S.Thrash then
		return Target:DebuffRefreshable(S.Thrash, 15 * (S.JaggedWounds:IsAvailable() and 0.67 or 1) * 0.3)
	end
	if dot == S.Rip then
		return Target:DebuffRefreshable(S.Rip, 24 * (S.JaggedWounds:IsAvailable() and 0.67 or 1) * 0.3)
	end
	if dot == S.RakeDebuff then
		return Target:DebuffRefreshable(S.RakeDebuff, 15 * (S.JaggedWounds:IsAvailable() and 0.67 or 1) * 0.3)
	end
	if dot == S.Moonfire then
		return Target:DebuffRefreshable(S.Moonfire, 16 * 0.3)
	end
  end
  
  
  -- Items
  if not Item.Druid then Item.Druid = {}; end
  Item.Druid.Feral = {
    -- Legendaries
    LuffaWrappings = Item(137056, {9}),
	AiluroPouncers = Item(137024, {8})
  };
  local I = Item.Druid.Feral;
  -- Rotation Var
    
  -- GUI Settings
  local Settings = {
    General = AR.GUISettings.General,
    Commons = AR.GUISettings.APL.Druid.Commons,
    Feral = AR.GUISettings.APL.Druid.Feral
  };


--- ======= ACTION LISTS =======

  local function Cooldowns(MeleeRange, AoERadius, RangedRange)
	--berserk,if=energy>=30&(cooldown.tigers_fury.remains>5|buff.tigers_fury.up)
	if S.Berserk:IsCastable() and AR.CDsON() and Target:IsInRange(MeleeRange) and Player:EnergyPredicted() >= 30 and (S.TigersFury:CooldownRemainsP() > 5 or Player:Buff(S.TigersFury)) then
		if AR.Cast(S.Berserk, Settings.Feral.OffGCDasOffGCD.Berserk) then return "Cast"; end
	end
	-- tigers_fury,if=energy.deficit>=60
	if S.TigersFury:IsCastable() and Player:EnergyDeficit() >= 60 then
		if AR.Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "Cast"; end
    end
	-- -- elunes_guidance,if=combo_points=0&energy>=50
	if S.ElunesGuidance:IsCastable() and Player:ComboPoints() == 0 and Player:EnergyPredicted() >= 50 then
		if AR.Cast(S.ElunesGuidance, Settings.Feral.OffGCDasOffGCD.ElunesGuidance) then return "Cast"; end
	end
	-- -- incarnation,if=energy>=30&(cooldown.tigers_fury.remains>15|buff.tigers_fury.up)
	if S.Incarnation:IsCastable() and AR.CDsON() and Target:IsInRange(MeleeRange) and Player:EnergyPredicted() >= 30 and (S.TigersFury:CooldownRemainsP() > 15 or Player:Buff(S.TigersFury)) then
		if AR.Cast(S.Incarnation, Settings.Feral.OffGCDasOffGCD.Berserk) then return "Cast"; end
	end
	-- -- ashamanes_frenzy,if=combo_points>=2&(!talent.bloodtalons.enabled|buff.bloodtalons.up)
	if S.AshamanesFrenzy:IsCastable() and AR.CDsON() and Player:ComboPoints() >= 2 and (not S.Bloodtalons:IsAvailable() or Player:Buff(S.BloodtalonsBuff)) then
		if AR.Cast(S.AshamanesFrenzy) then return "Cast"; end
	end
	--shadowmeld,if=combo_points<5&energy>=action.rake.cost&dot.rake.pmultiplier<2.1&buff.tigers_fury.up&(buff.bloodtalons.up|!talent.bloodtalons.enabled)&(!talent.incarnation.enabled|cooldown.incarnation.remains>18)&!buff.incarnation.up
	if S.Shadowmeld:IsCastable() and AR.CDsON() and Player:ComboPoints() < 5 and Player:Energy() >= S.Rake:Cost() and Target:PMultiplier(S.Rake) < 2.1 and Player:Buff(S.TigersFury) and (Player:Buff(S.BloodtalonsBuff) or (not S.Bloodtalons:IsAvailable())) and ((not S.Incarnation:IsAvailable()) or (S.Incarnation:CooldownRemainsP() > 18)) and (not Player:Buff(S.Incarnation)) then
		if Settings.Feral.StealthMacro.Shadowmeld then
			if AR.CastQueue(S.Shadowmeld, S.Rake) then return "Shadowmeld to Rake as Macro"; end
		else
			if AR.Cast(S.Shadowmeld, Settings.Commons.OffGCDasOffGCD.Racials) then return "Shadowmeld to Rake"; end
		end
	end
	return false;
  end
  
  local function ST_Finishers (MeleeRange, AoERadius, RangedRange)
	--savage_roar,if=buff.savage_roar.down
	if S.SavageRoar:IsCastable() and not Player:Buff(S.SavageRoar) then
		if AR.Cast(S.SavageRoar) then return "Cast"; end
	end
	--rip,target_if=!ticking|(remains<=duration*0.3)&(target.health.pct>25&!talent.sabertooth.enabled)|(remains<=duration*0.8&persistent_multiplier>dot.rip.pmultiplier)&target.time_to_die>8
	--split in 2 for managements sake
	--if S.Rip:IsCastable() and ((not (Target:DebuffRemainsP(S.Rip) > 1)) or (IsDebuffRefreshable(S.Rip) and ((Target:HealthPercentage() >= 25) and (not S.Sabertooth:IsAvailable()))) or ((((Target:DebuffRemainsP(S.Rip)) <= (24 * (S.JaggedWounds:IsAvailable() and 0.67 or 1) * 0.8)) and (currentPMulti(S.Rip) > Target:PMultiplier(S.Rip))) and (Target:TimeToDie() > 8))) then
	if S.Rip:IsCastable() and ((not (Target:DebuffRemainsP(S.Rip) > 1)) or (IsDebuffRefreshable(S.Rip) and ((Target:HealthPercentage() >= 25) and (not S.Sabertooth:IsAvailable())))) then
		if AR.Cast(S.Rip) then return "Cast"; end
	end
	
	if S.Rip:IsCastable() and ((((Target:DebuffRemainsP(S.Rip)) <= (24 * (S.JaggedWounds:IsAvailable() and 0.67 or 1) * 0.8)) and (currentPMulti(S.Rip) > Target:PMultiplier(S.Rip))) and (Target:TimeToDie() > 8)) then
		if AR.Cast(S.Rip) then return "Cast"; end
	end
	--savage_roar,if=buff.savage_roar.remains<12
	if S.SavageRoar:IsCastable() and (Player:BuffRemainsP(S.SavageRoar) < 12) then
		if AR.Cast(S.SavageRoar) then return "Cast"; end
	end
	--maim,if=buff.fiery_red_maimers.up
	if S.Maim:IsCastable() and Player:Buff(S.FieryRedMaimers) then
		if AR.Cast(S.Maim) then return "Cast"; end
	end
	--ferocious_bite,max_energy=1
	if S.FerociousBite:IsCastable() then
		if (Player:EnergyPredicted() < 50) and ((Target:HealthPercentage() >= 25) or (Player:EnergyTimeToX(50) < Target:DebuffRemains(S.Rip))) then
			if AR.Cast(S.PoolEnergy) then return "Pooling for Ferocious Bite"; end
		else
			if AR.Cast(S.FerociousBite) then return "Cast"; end
		end
	end
	return false;
  end
  
  local function ST_Generators (MeleeRange, AoERadius, RangedRange)
	--regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points>=2&cooldown.ashamanes_frenzy.remains<gcd
	if S.Regrowth:IsCastable() and S.Bloodtalons:IsAvailable() and Player:Buff(S.PredatorySwiftness) and not Player:Buff(S.BloodtalonsBuff) and Player:ComboPoints() >= 2 and (S.AshamanesFrenzy:CooldownRemainsP() < Player:GCD()) then
		if AR.Cast(S.Regrowth) then return "Cast"; end
	end
	--regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points=4&dot.rake.remains<4
	if S.Regrowth:IsCastable() and S.Bloodtalons:IsAvailable() and Player:Buff(S.PredatorySwiftness) and not Player:Buff(S.BloodtalonsBuff) and Player:ComboPoints() == 4 and Target:DebuffRemains(S.RakeDebuff) < 4 then
		if AR.Cast(S.Regrowth) then return "Cast"; end
	end
	--regrowth,if=equipped.ailuro_pouncers&talent.bloodtalons.enabled&(buff.predatory_swiftness.stack>2|(buff.predatory_swiftness.stack>1&dot.rake.remains<3))&buff.bloodtalons.down
	if S.Regrowth:IsCastable() and I.AiluroPouncers:IsEquipped() and S.Bloodtalons:IsAvailable() and (Player:BuffStack(S.PredatorySwiftness) > 2 or (Player:BuffStack(S.PredatorySwiftness) > 1 and Target:DebuffRemains(S.RakeDebuff) < 3)) and not Player:Buff(S.BloodtalonsBuff) then
		if AR.Cast(S.Regrowth) then return "Cast"; end
	end
	--brutal_slash,if=spell_targets.brutal_slash>desired_targets
	if S.BrutalSlash:IsCastable() and AR.AoEON() and (Cache.EnemiesCount[AoERadius] > 1) then
		if AR.Cast(S.BrutalSlash) then return "Cast"; end
	end
	--thrash_cat,if=(not ticking|remains<duration*0.3)&(spell_targets.thrash_cat>2)
	if AR.AoEON() and S.Thrash:IsCastable() and Cache.EnemiesCount[AoERadius] >= 3 and (Target:TimeToDie() - Target:DebuffRemains(S.Thrash)) >= 6 and IsDebuffRefreshable(S.Thrash) then
		if AR.Cast(S.Thrash) then return "Cast"; end
    end
	--rake,target_if=not ticking|(not talent.bloodtalons.enabled&remains<duration*0.3)&target.time_to_die>4
	if S.Rake:IsCastable(MeleeRange) and not S.Bloodtalons:IsAvailable() and Target:TimeToDie() - Target:DebuffRemains(S.RakeDebuff) >= 5 and IsDebuffRefreshable(S.RakeDebuff) then
		if AR.Cast(S.Rake) then return "Cast"; end
	end
	--rake,target_if=talent.bloodtalons.enabled&buff.bloodtalons.up&((remains<=7)&persistent_multiplier>dot.rake.pmultiplier*0.85)&target.time_to_die>4
	if S.Rake:IsCastable(MeleeRange) and S.Bloodtalons:IsAvailable() and Player:Buff(S.BloodtalonsBuff) and Target:TimeToDie() > 4 and (Target:DebuffRemainsP(S.RakeDebuff) <= 7 and currentPMulti(S.Rake) > Target:PMultiplier(S.Rake) * 0.85) then
		if AR.Cast(S.Rake) then return "Cast"; end
	end
	--brutal_slash,if=(buff.tigers_fury.up&(raid_event.adds.in>(1+max_charges-charges_fractional)*recharge_time))
	if S.BrutalSlash:IsCastable() and Player:Buff(S.TigersFury) then
		if AR.Cast(S.BrutalSlash) then return "Cast"; end
	end
	--moonfire_cat,target_if=remains<=duration*0.3
	if S.LunarInspiration:IsAvailable() and S.Moonfire:IsCastable() and IsDebuffRefreshable(S.Moonfire) then
		if AR.Cast(S.Moonfire) then return "Cast"; end
	end
	--thrash_cat,if=(not ticking|remains<duration*0.3)&(variable.use_thrash=2|spell_targets.thrash_cat>1) When is use_thrash=2 true???
	--thrash_cat,if=(not ticking|remains<duration*0.3)&variable.use_thrash=1&buff.clearcasting.react
	if S.Thrash:IsCastable() and Target:TimeToDie() - Target:DebuffRemains(S.Thrash) >= 6 and IsDebuffRefreshable(S.Thrash) and I.LuffaWrappings:IsEquipped() and Player:Buff(S.Clearcasting) then
		if AR.Cast(S.Thrash) then return "Cast"; end
    end
	--swipe_cat,if=spell_targets.swipe_cat>1
	if S.Swipe:IsCastable() and AR.AoEON() and Cache.EnemiesCount[AoERadius] > 1 then
		if AR.Cast(S.Swipe) then return "Cast"; end
	end
	--shred
	if S.Shred:IsCastable(MeleeRange) then
	  if AR.Cast(S.Shred) then return "Cast"; end
	end
	return false;
  end
  
  --actions.single_target
  local function Single_Target (MeleeRange, AoERadius, RangedRange)
	--cat_form,if=not buff.cat_form.up
	if S.CatForm:IsCastable(MeleeRange) and not Player:Buff(S.CatForm) then
		if AR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return "Cast"; end
	end
	--rake,if=buff.prowl.up|buff.shadowmeld.up
	if S.Rake:IsCastable() and (Player:Buff(S.Prowl) or Player:Buff(S.Shadowmeld)) then
		if AR.Cast(S.Rake) then return "Cast"; end
	end
	--call_action_list,name=cooldowns
	ShouldReturn = Cooldowns(MeleeRange, AoERadius, RangedRange);
    if ShouldReturn then return ShouldReturn; end
	--regrowth,if=combo_points=5&talent.bloodtalons.enabled&buff.bloodtalons.down&(not buff.incarnation.up|dot.rip.remains<8|dot.rake.remains<5)
	if S.Regrowth:IsCastable() and (Player:ComboPoints() == 5) and S.Bloodtalons:IsAvailable() and (not Player:Buff(S.BloodtalonsBuff)) and ((not Player:Buff(S.Incarnation)) or (Target:DebuffRemainsP(S.Rip) < 8) or (Target:DebuffRemainsP(S.RakeDebuff) < 5)) then
		if AR.Cast(S.Regrowth) then return "Cast"; end
	end
	--run_action_list,name=st_finishers,if=combo_points>4
	if (Player:ComboPoints() > 4) then
		ShouldReturn = ST_Finishers(MeleeRange, AoERadius, RangedRange);
		if ShouldReturn then return ShouldReturn; end
	end
	--run_action_list,name=st_generators
	ShouldReturn = ST_Generators(MeleeRange, AoERadius, RangedRange);
    if ShouldReturn then return ShouldReturn; end
	
	return false;
  end

--- ======= MAIN =======
  local function APL()
    -- Unit Update
    local MeleeRange, AoERadius, RangedRange;
    if S.BalanceAffinity:IsAvailable() then
      -- Have to use the spell itself since Balance Affinity is a special range increase
      MeleeRange = S.Shred;
      AoERadius = I.LuffaWrappings:IsEquipped() and 16.25 or 13;
      RangedRange = 45;
    else
      MeleeRange = "Melee";
      AoERadius = I.LuffaWrappings:IsEquipped() and 10 or 8;
      RangedRange = 40;
    end
    AC.GetEnemies(AoERadius, true); -- Thrash & Swipe
    Everyone.AoEToggleEnemiesUpdate();
	--Defensives
	if S.Renewal:IsCastable() and Player:HealthPercentage() <= Settings.Feral.RenewalHP then
		if AR.Cast(S.Renewal, Settings.Feral.OffGCDasOffGCD.Renewal) then return "Renewal"; end
	end
	if S.SurvivalInstincts:IsCastable() and (not Player:Buff(S.SurvivalInstincts)) and Player:HealthPercentage() <= Settings.Feral.SurvivalInstinctsHP then
		if AR.Cast(S.SurvivalInstincts, Settings.Feral.OffGCDasOffGCD.SurvivalInstincts) then return "Survival Instincts"; end
	end
	if S.Regrowth:IsCastable() and Player:Buff(S.PredatorySwiftness) and Player:HealthPercentage() <= Settings.Feral.RegrowthHP then
		if AR.Cast(S.Regrowth, Settings.Feral.GCDasOffGCD.RegrowthHeal) then return "Regrowth (Healing)"; end
	end
    -- Out of Combat
    if not Player:AffectingCombat() then
      -- Prowl, IsStealthed() is fixed, hooray!
      if not InCombatLockdown() and S.Prowl:CooldownUp() and (not Player:IsStealthed()) and GetNumLootItems() == 0 and not UnitExists("npc") and AC.OutOfCombatTime() > 1 then
        if AR.Cast(S.Prowl, Settings.Feral.OffGCDasOffGCD.Prowl) then return "Cast"; end
      end
	  -- if Player:IsStealthed() then
		-- if AR.Cast(S.Prowl) then return "Cast"; end
	  -- end
		if S.CatForm:IsCastable() and not Player:Buff(S.CatForm) then
			if AR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return "OOC Cat Form"; end
		end		  
      -- Wild Charge
      if S.WildCharge:IsCastable(S.WildCharge) and not Target:IsInRange(8) and not Target:IsInRange(MeleeRange) then
        if AR.Cast(S.WildCharge, Settings.Feral.OffGCDasOffGCD.WildCharge) then return "Cast"; end
      end
      -- Opener: Rake
      if Target:Exists() and Player:CanAttack(Target) and not Target:IsDeadOrGhost() and Target:IsInRange(MeleeRange) then
        if S.Rake:IsCastable() then
          if AR.Cast(S.Rake) then return "Cast"; end
        end
      end
      return;
    end
    -- In Combat
    AC.GetEnemies(8, true);
    if Everyone.TargetIsValid() then
      -- Cat Rotation
      if Player:Buff(S.CatForm) then
        -- Skull Bash
        if Settings.General.InterruptEnabled and S.SkullBash:IsCastable(S.SkullBash) and Target:IsInterruptible() then
          if AR.Cast(S.SkullBash) then return "Cast Kick"; end
        end
	    if S.WildCharge:IsCastable(S.WildCharge) and not Target:IsInRange(8) and not Target:IsInRange(MeleeRange) then
			if AR.Cast(S.WildCharge, Settings.Feral.OffGCDasOffGCD.WildCharge) then return "Cast"; end
		end
		--run_action_list,name=single_target,if=dot.rip.ticking|time>15
        if (Target:DebuffRemainsP(S.Rip) > 0) or AC.CombatTime() > 15 then
			ShouldReturn = Single_Target(MeleeRange, AoERadius, RangedRange);
			if ShouldReturn then return ShouldReturn; end
		end
		--rake,if=!ticking|buff.prowl.up
		if S.Rake:IsCastable() and ((not (Target:DebuffRemainsP(S.RakeDebuff) > 1)) or Player:Buff(S.Prowl)) then
			if AR.Cast(S.Rake) then return "Cast"; end
		end
		--moonfire_cat,if=talent.lunar_inspiration.enabled&!ticking
		if S.LunarInspiration:IsAvailable() and S.Moonfire:IsCastable() and not Target:DebuffRemainsP(S.Moonfire) > 1 then
			if AR.Cast(S.Moonfire) then return "Cast"; end
		end
		--savage_roar,if=!buff.savage_roar.up
		if S.SavageRoar:IsCastable() and not Player:Buff(S.SavageRoar) then
			if AR.Cast(S.SavageRoar) then return "Cast"; end
		end
		--berserk
		if S.Berserk:IsCastable() and AR.CDsON() then
			if AR.Cast(S.Berserk, Settings.Feral.OffGCDasOffGCD.Berserk) then return "Cast"; end
		end
		--incarnation
		if S.Incarnation:IsCastable() and AR.CDsON() then
			if AR.Cast(S.Incarnation, Settings.Feral.OffGCDasOffGCD.Berserk) then return "Cast"; end
		end
		--tigers_fury
		if S.TigersFury:IsCastable() then
			if AR.Cast(S.TigersFury, Settings.Feral.OffGCDasOffGCD.TigersFury) then return "Cast"; end
		end
		--regrowth,if=(talent.sabertooth.enabled|buff.predatory_swiftness.up)&talent.bloodtalons.enabled&buff.bloodtalons.down&combo_points=5
		if S.Regrowth:IsCastable() and (Player:ComboPoints() == 5) and (not Player:Buff(S.BloodtalonsBuff)) and S.Bloodtalons:IsAvailable() and (S.Sabertooth:IsAvailable() or Player:Buff(S.PredatorySwiftness)) then
			if AR.Cast(S.Regrowth) then return "Cast"; end
		end
		--rip,if=combo_points=5 // Putting this above ashamanes like in the APL to accomodate entering a fight with 5 Combopoints at this stage
		if S.Rip:IsCastable() and Player:ComboPoints() == 5 then
			if AR.Cast(S.Rip) then return "Cast"; end
		end
		--ashamanes_frenzy
		if S.AshamanesFrenzy:IsCastable() and AR.CDsON() then
			if AR.Cast(S.AshamanesFrenzy) then return "Cast"; end
		end
		--thrash_cat,if=!ticking&variable.use_thrash>0
		if S.Thrash:IsCastable() and I.LuffaWrappings:IsEquipped() and (not (Target:DebuffRemainsP(S.Thrash) > 1)) then
			if AR.Cast(S.Thrash) then return "Cast"; end
		end
		--shred
		if S.Shred:IsCastable(MeleeRange) then
		  if AR.Cast(S.Shred) then return "Cast"; end
		end
      else
		if S.CatForm:IsCastable() then
			if AR.Cast(S.CatForm, Settings.Feral.GCDasOffGCD.CatForm) then return "Cast"; end
		end
      end
	  return;
    end
  end
  AR.SetAPL(103, APL);


--- ======= SIMC =======
-- Imported Current APL on 2017-10-27, 00:53 CEST (Last APL Update 2017-08-31)
-- # Default consumables
-- potion=old_war
-- flask=seventh_demon
-- food=lavish_suramar_feast
-- augmentation=defiled

-- # This default action priority list is automatically created based on your character.
-- # It is a attempt to provide you with a action list that is both simple and practicable,
-- # while resulting in a meaningful and good simulation. It may not result in the absolutely highest possible dps.
-- # Feel free to edit, adapt and improve it to your own needs.
-- # SimulationCraft is always looking for updates and improvements to the default action lists.

-- # Executed before combat begins. Accepts non-harmful actions only.
-- actions.precombat=flask
-- actions.precombat+=/food
-- actions.precombat+=/augmentation
-- actions.precombat+=/regrowth,if=talent.bloodtalons.enabled
-- actions.precombat+=/variable,name=use_thrash,value=0
-- actions.precombat+=/variable,name=use_thrash,value=1,if=equipped.luffa_wrappings
-- actions.precombat+=/cat_form
-- actions.precombat+=/prowl
-- # Snapshot raid buffed stats before combat begins and pre-potting is done.
-- actions.precombat+=/snapshot_stats
-- actions.precombat+=/potion

-- # Executed every time the actor is available.
-- actions=run_action_list,name=single_target,if=dot.rip.ticking|time>15
-- actions+=/rake,if=!ticking|buff.prowl.up
-- actions+=/dash,if=!buff.cat_form.up
-- actions+=/auto_attack
-- actions+=/moonfire_cat,if=talent.lunar_inspiration.enabled&!ticking
-- actions+=/savage_roar,if=!buff.savage_roar.up
-- actions+=/berserk
-- actions+=/incarnation
-- actions+=/tigers_fury
-- actions+=/ashamanes_frenzy
-- actions+=/regrowth,if=(talent.sabertooth.enabled|buff.predatory_swiftness.up)&talent.bloodtalons.enabled&buff.bloodtalons.down&combo_points=5
-- actions+=/rip,if=combo_points=5
-- actions+=/thrash_cat,if=!ticking&variable.use_thrash>0
-- actions+=/shred

-- actions.cooldowns=dash,if=!buff.cat_form.up
-- actions.cooldowns+=/berserk,if=energy>=30&(cooldown.tigers_fury.remains>5|buff.tigers_fury.up)
-- actions.cooldowns+=/tigers_fury,if=energy.deficit>=60
-- actions.cooldowns+=/elunes_guidance,if=combo_points=0&energy>=50
-- actions.cooldowns+=/incarnation,if=energy>=30&(cooldown.tigers_fury.remains>15|buff.tigers_fury.up)
-- actions.cooldowns+=/potion,name=prolonged_power,if=target.time_to_die<65|(time_to_die<180&(buff.berserk.up|buff.incarnation.up))
-- actions.cooldowns+=/ashamanes_frenzy,if=combo_points>=2&(!talent.bloodtalons.enabled|buff.bloodtalons.up)
-- actions.cooldowns+=/shadowmeld,if=combo_points<5&energy>=action.rake.cost&dot.rake.pmultiplier<2.1&buff.tigers_fury.up&(buff.bloodtalons.up|!talent.bloodtalons.enabled)&(!talent.incarnation.enabled|cooldown.incarnation.remains>18)&!buff.incarnation.up
-- actions.cooldowns+=/use_items

-- actions.single_target=cat_form,if=!buff.cat_form.up
-- actions.single_target+=/auto_attack
-- actions.single_target+=/rake,if=buff.prowl.up|buff.shadowmeld.up
-- actions.single_target+=/call_action_list,name=cooldowns
-- actions.single_target+=/regrowth,if=combo_points=5&talent.bloodtalons.enabled&buff.bloodtalons.down&(!buff.incarnation.up|dot.rip.remains<8|dot.rake.remains<5)
-- actions.single_target+=/run_action_list,name=st_finishers,if=combo_points>4
-- actions.single_target+=/run_action_list,name=st_generators

-- actions.st_finishers=pool_resource,for_next=1
-- actions.st_finishers+=/savage_roar,if=buff.savage_roar.down
-- actions.st_finishers+=/pool_resource,for_next=1
-- actions.st_finishers+=/rip,target_if=!ticking|(remains<=duration*0.3)&(target.health.pct>25&!talent.sabertooth.enabled)|(remains<=duration*0.8&persistent_multiplier>dot.rip.pmultiplier)&target.time_to_die>8
-- actions.st_finishers+=/pool_resource,for_next=1
-- actions.st_finishers+=/savage_roar,if=buff.savage_roar.remains<12
-- actions.st_finishers+=/maim,if=buff.fiery_red_maimers.up
-- actions.st_finishers+=/ferocious_bite,max_energy=1

-- actions.st_generators=regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points>=2&cooldown.ashamanes_frenzy.remains<gcd
-- actions.st_generators+=/regrowth,if=talent.bloodtalons.enabled&buff.predatory_swiftness.up&buff.bloodtalons.down&combo_points=4&dot.rake.remains<4
-- actions.st_generators+=/regrowth,if=equipped.ailuro_pouncers&talent.bloodtalons.enabled&(buff.predatory_swiftness.stack>2|(buff.predatory_swiftness.stack>1&dot.rake.remains<3))&buff.bloodtalons.down
-- actions.st_generators+=/brutal_slash,if=spell_targets.brutal_slash>desired_targets
-- actions.st_generators+=/pool_resource,for_next=1
-- actions.st_generators+=/thrash_cat,if=(!ticking|remains<duration*0.3)&(spell_targets.thrash_cat>2)
-- actions.st_generators+=/pool_resource,for_next=1
-- actions.st_generators+=/rake,target_if=!ticking|(!talent.bloodtalons.enabled&remains<duration*0.3)&target.time_to_die>4
-- actions.st_generators+=/pool_resource,for_next=1
-- actions.st_generators+=/rake,target_if=talent.bloodtalons.enabled&buff.bloodtalons.up&((remains<=7)&persistent_multiplier>dot.rake.pmultiplier*0.85)&target.time_to_die>4
-- actions.st_generators+=/brutal_slash,if=(buff.tigers_fury.up&(raid_event.adds.in>(1+max_charges-charges_fractional)*recharge_time))
-- actions.st_generators+=/moonfire_cat,target_if=remains<=duration*0.3
-- actions.st_generators+=/pool_resource,for_next=1
-- actions.st_generators+=/thrash_cat,if=(!ticking|remains<duration*0.3)&(variable.use_thrash=2|spell_targets.thrash_cat>1)
-- actions.st_generators+=/thrash_cat,if=(!ticking|remains<duration*0.3)&variable.use_thrash=1&buff.clearcasting.react
-- actions.st_generators+=/pool_resource,for_next=1
-- actions.st_generators+=/swipe_cat,if=spell_targets.swipe_cat>1
-- actions.st_generators+=/shred

