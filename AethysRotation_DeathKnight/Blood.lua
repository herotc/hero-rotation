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
  local DeathKnight = AR.Commons.DeathKnight;
  -- Spells
  if not Spell.DeathKnight then Spell.DeathKnight = {}; end
  Spell.DeathKnight.Blood = {
  -- Racials
  ArcaneTorrent					= Spell(50613),
  -- Abilities
  BloodDrinker					= Spell(206931),
  BloodPlague					  = Spell(55078),
  DancingRuneWeaponBuff	= Spell(81256),
  DancingRuneWeapon 		= Spell(49028),
  DeathStrike					  = Spell(49998),
  Marrowrend					  = Spell(195182),
  BoneShield					  = Spell(195181),
  VampiricBlood					= Spell(55233),
  BloodMirror					  = Spell(206977),
  BoneStorm						  = Spell(194844),
  Consumption					  = Spell(205223),
  DeathandDecay					= Spell(43265),
  CrimsonScourge				= Spell(81141),
  RapidDecomposition		= Spell(194662),
  Ossuary						    = Spell(219786),
  HeartStrike					  = Spell(206930),
  BloodBoil						  = Spell(50842),
  HeartBreaker          = Spell(221536),
  DeathsCaress          = Spell(195292),
  MindFreeze            = Spell(47528),
  BloodShield           = Spell(77535),
  --Legendary Buff
  HaemostasisBuff       = Spell(235558),

};
  local S = Spell.DeathKnight.Blood;
  if not Item.DeathKnight then Item.DeathKnight = {}; end
  Item.DeathKnight.Blood = {
  --Legendaries
  --Potion
  ProlongedPower        = Item(142117)
    
  };
  local I = Item.DeathKnight.Blood;
  -- GUI Settings
  local Settings = {
  General = AR.GUISettings.General,
  Commons = AR.GUISettings.APL.DeathKnight.Commons,
  Blood = AR.GUISettings.APL.DeathKnight.Blood
 };


--- ======= ACTION LISTS =======
local function SimulationcraftAPL()
  if Target:IsInRange("Melee") then
  --actions+=/mind_freeze
  -- Interrupts
  if Settings.General.InterruptEnabled and Target:IsInterruptible() and S.MindFreeze:IsCastable("Melee") then
    if AR.CastAnnotated(S.MindFreeze, false, "Interrupt") then return ""; end
  end
  --actions+=/arcane_torrent,if=runic_power.deficit>20
  if S.ArcaneTorrent:IsCastable() and Player:RunicPowerDeficit() > 20 then
    if AR.Cast(S.ArcaneTorrent, Settings.Blood.OffGCDasOffGCD.ArcaneTorrent) then return ""; end
  end
  --actions+=/blood_fury
  --actions+=/berserking,if=buff.dancing_rune_weapon.up
  --actions+=/use_items
  --actions+=/potion,if=buff.dancing_rune_weapon.up
  if  Settings.Commons.UsePotions and I.ProlongedPower:IsReady() and Player:Buff(S.DancingRuneWeaponBuff) then
    if AR.CastSuggested(I.ProlongedPower) then return ""; end
  end
  --actions+=/dancing_rune_weapon,if=!cooldown.blooddrinker.ready&!cooldown.death_and_decay.ready
  if S.DancingRuneWeapon:IsCastable() and not S.BloodDrinker:IsReady() and not S.DeathandDecay:IsReady() then
    if AR.Cast(S.DancingRuneWeapon, Settings.Blood.OffGCDasOffGCD.DancingRuneWeapon) then return ""; end
  end
  --actions.standard=death_strike,if=runic_power.deficit<10
  if S.DeathStrike:IsUsable() and Player:RunicPowerDeficit() < 10 then
    if AR.Cast(S.DeathStrike) then return ""; end
  end
  --actions.standard+=/death_and_decay,if=talent.rapid_decomposition.enabled&!buff.dancing_rune_weapon.up
  if S.DeathandDecay:IsUsable() and S.RapidDecomposition:IsLearned() and not Player:Buff(S.DancingRuneWeaponBuff) then
    if AR.Cast(S.DeathandDecay) then return ""; end
  end
  --actions.standard+=/blooddrinker,if=!buff.dancing_rune_weapon.up
  if S.BloodDrinker:IsCastable() and not Player:Buff(S.DancingRuneWeaponBuff) then
    if AR.Cast(S.BloodDrinker,Settings.Blood.GCDasOffGCD.BloodDrinker) then return ""; end
  end
  --actions.standard+=/marrowrend,if=buff.bone_shield.remains<=gcd*2
  if S.Marrowrend:IsCastable() and Player:BuffRemains(S.BoneShield) <= (Player:GCD() * 2) then
    if AR.Cast(S.Marrowrend) then return ""; end
  end
  --actions.standard+=/blood_boil,if=charges_fractional>=1.8&buff.haemostasis.stack<5&(buff.haemostasis.stack<3|!buff.dancing_rune_weapon.up)
  if S.BloodBoil:IsCastable() and S.BloodBoil:ChargesFractional() >= 1.8 and Player:BuffStack(S.HaemostasisBuff) < 5 and (Player:BuffStack(S.HaemostasisBuff) < 3 or not Player:Buff(S.DancingRuneWeaponBuff)) then
    if AR.Cast(S.BloodBoil) then return ""; end
  end
  --actions.standard+=/marrowrend,if=(buff.bone_shield.stack<5&talent.ossuary.enabled)|buff.bone_shield.remains<gcd*3
  if S.Marrowrend:IsCastable() and (Player:BuffStack(S.BoneShield) < 5 and S.Ossuary:IsAvailable()) or Player:BuffRemainsP(S.BoneShield) < (Player:GCD() * 3) then
    if AR.Cast(S.Marrowrend) then return ""; end
  end
  --actions.standard+=/death_strike,if=buff.blood_shield.up|(runic_power.deficit<15&runic_power.deficit<25|!buff.dancing_rune_weapon.up)
  if S.DeathStrike:IsUsable() and (Player:Buff(S.BloodShield) or (Player:RunicPowerDeficit() < 15 and Player:RunicPowerDeficit() < 25 or not Player:Buff(S.DancingRuneWeaponBuff))) then
    if AR.Cast(S.DeathStrike) then return ""; end
  end
  --actions.standard+=/consumption
  if S.Consumption:IsCastable() then
    if AR.Cast(S.Consumption) then return ""; end
  end
  --actions.standard+=/heart_strike,if=buff.dancing_rune_weapon.up
  if S.HeartStrike:IsCastable() and Player:Buff(S.DancingRuneWeaponBuff) then
    if AR.Cast(S.HeartStrike) then return ""; end
  end
  --actions.standard+=/death_and_decay,if=buff.crimson_scourge.up
  if S.DeathandDecay:IsUsable() and Player:Buff(S.CrimsonScourge) then
    if AR.Cast(S.DeathandDecay) then return ""; end
  end
  --actions.standard+=/blood_boil,if=buff.haemostasis.stack<5&(buff.haemostasis.stack<3|!buff.dancing_rune_weapon.up)
  if S.BloodBoil:IsCastable() and Player:BuffStack(S.HaemostasisBuff) < 5 and (Player:BuffStack(S.HaemostasisBuff) < 3 or not Player:Buff (S.DancingRuneWeaponBuff)) then
    if AR.Cast(S.BloodBoil) then return ""; end
  end
  --actions.standard+=/death_and_decay
  if S.DeathandDecay:IsReady() then
    if AR.Cast(S.DeathandDecay) then return ""; end
  end
  --actions.standard+=/heart_strike,if=rune.time_to_3<gcd|buff.bone_shield.stack>6
  if S.HeartStrike:IsCastable() and Player:RuneTimeToX(3) < Player:GCD() or Player:BuffStack(S.BoneShield) > 6 then
    if AR.Cast(S.HeartStrike) then return ""; end
  end
else
  if S.DeathsCaress:IsCastable(30) and Player:Runes() > 3 then
    if AR.Cast(S.DeathsCaress) then return "";end
  end
end
	return false;
end
local function IcyVeinsRotation()
  if Target:IsInRange("Melee") then
    --Interrupt
  if Settings.General.InterruptEnabled and Target:IsInterruptible() and S.MindFreeze:IsCastable("Melee") then
    if AR.CastAnnotated(S.MindFreeze, false, "Interrupt") then return ""; end
  end  
  if AR.CDsON() and S.DancingRuneWeapon:IsCastable() then
		if AR.Cast(S.DancingRuneWeapon, Settings.Blood.OffGCDasOffGCD.DancingRuneWeapon) then return ""; end
	end

	if S.Marrowrend:IsCastable() and Player:BuffRemains(S.BoneShield) <= (Player:GCD() * 2) then
		if AR.Cast(S.Marrowrend) then return ""; end
	end

	if S.BloodBoil:IsCastable() and Cache.EnemiesCount[10] >= 1 and not Target:Debuff(S.BloodPlague) then
		if AR.Cast(S.BloodBoil) then return ""; end
	end

	if AR.CDsON() and S.BoneStorm:IsCastable() and Cache.EnemiesCount[10] >= 1 and Player:RunicPower() >= 100 then
	    if AR.Cast(S.BoneStorm, Settings.Blood.GCDasOffGCD.BoneStorm) then return ""; end
	end
	
	if S.DeathandDecay:IsUsable() and (Cache.EnemiesCount[10] == 1 and Player:Buff(S.CrimsonScourge) and S.RapidDecomposition:IsAvailable()) or (Cache.EnemiesCount[10] > 1 and Player:Buff(S.CrimsonScourge)) then
		if AR.Cast(S.DeathandDecay) then return ""; end
	end

	if S.BloodDrinker:IsCastable() and S.BloodDrinker:IsLearned() and not Player:Buff(S.DancingRuneWeaponBuff) and Player:RunicPowerDeficit() >= 10 then
		if AR.Cast(S.BloodDrinker, Settings.Blood.GCDasOffGCD.BloodDrinker) then return ""; end
	end
	
	if S.DeathStrike:IsUsable() and S.BloodDrinker:IsCastable() and (S.BloodDrinker:IsAvailable() or S.BloodDrinker:CooldownRemains() <= Player:GCD()) and not Player:Buff(S.DancingRuneWeaponBuff) and ((Player:RuneTimeToX(1) <= Player:GCD()) or Player:Runes() >= 1) then
	    if AR.Cast(S.DeathStrike) then return ""; end
    end

	if S.Marrowrend:IsCastable() and Player:BuffStack(S.BoneShield) <= 6 and Player:RunicPowerDeficit() >= 20 then
		if AR.Cast(S.Marrowrend) then return ""; end
	end
	
	if S.DeathStrike:IsUsable() and S.Marrowrend:IsCastable() and Player:BuffStack(S.BoneShield) <= 6 then
	    if AR.Cast(S.DeathStrike) then return ""; end
	end

	if S.DeathandDecay:IsUsable() and ((Cache.EnemiesCount[10] == 1 and Player:Runes() >= 3 and S.RapidDecomposition:IsAvailable() and S.DeathandDecay:CooldownRemains() == 0)  or (Cache.EnemiesCount[10] >= 3 and S.DeathandDecay:CooldownRemains() == 0)) and Player:RunicPowerDeficit() >= 10 then
		if AR.Cast(S.DeathandDecay) then return ""; end
	end

	--[[if S.DeathStrike:IsUsable() and ((Player:RunicPower() > (80 or (90 and S.Ossuary:IsAvailable()))  and S.BoneStorm:IsAvailable() and not Player:Buff(S.BoneStorm) and (S.BoneStorm:CooldownRemains() > 15 or ((Player:Runes() > 3 and Player:RunicPowerDeficit() < 15) and S.BoneStorm:CooldownRemains() > 5))) or not S.BoneStorm:IsAvailable()) 
		and (not S.Ossuary:IsAvailable() or Player:BuffStack(S.BoneShield) > 5 or Player:Runes() >= 3 and Player:RunicPowerDeficit() < 10) then
		if AR.Cast(S.DeathStrike) then return ""; end
	end--]]

  if S.HeartStrike:IsCastable() and ((Player:RuneTimeToX(3) <= Player:GCD()) or Player:Runes() >=3) and (Player:RunicPowerDeficit()>= 15 or (S.HeartBreaker:IsAvailable() and Player:Buff(S.DeathandDecay) and Player:RunicPowerDeficit() >= (15 + math.min(Cache.EnemiesCount["Melee"],5) * 2))) then
		if AR.Cast(S.HeartStrike) then return ""; end
	end

	--- Move this below builders and replace the RunicPowerDeficit conditional with one that says 3+ runes available.
	if S.DeathStrike:IsUsable() and (Player:RuneTimeToX(3) <= Player:GCD() or Player:Runes() >= 3) then
		if AR.Cast(S.DeathStrike) then return ""; end
	end

	if S.DeathandDecay:IsUsable() and Player:Buff(S.CrimsonScourge) and not S.RapidDecomposition:IsAvailable() then
		if AR.Cast(S.DeathandDecay) then return ""; end
	end

	if S.Consumption:IsCastable() then 
		if AR.Cast(S.Consumption) then return ""; end
	end

	if S.BloodBoil:IsCastable() then
		if AR.Cast(S.BloodBoil) then return ""; end
  end
else
  if S.DeathsCaress:IsCastable(30) and Player:Runes() > 3 then
    if AR.Cast(S.DeathsCaress) then return "";end
  end
end
return false;
end

--- ======= MAIN =======
local function APL ()
    -- Unit Update
    AC.GetEnemies("Melee");
    AC.GetEnemies(10,true);
    AC.GetEnemies(20,true);

   -- In Combat
    if Everyone.TargetIsValid() and Target:IsInRange(30) then
    	if Settings.Blood.RotationToFollow == "Icy Veins" then
			ShouldReturn = IcyVeinsRotation();
		else 
			ShouldReturn = SimulationcraftAPL();
      		if ShouldReturn then return ShouldReturn;
      		end
      	end 
  	end

  	return;
end
AR.SetAPL(250,APL);
