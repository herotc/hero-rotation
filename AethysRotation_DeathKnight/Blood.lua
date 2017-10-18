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
  BloodPlague					= Spell(55078),
  DancingRuneWeaponBuff			= Spell(81256),
  DancingRuneWeapon 			= Spell(49028),
  DeathStrike					= Spell(49998),
  Marrowrend					= Spell(195182),
  BoneShield					= Spell(195181),
  VampiricBlood					= Spell(55233),
  BloodMirror					= Spell(206977),
  BoneStorm						= Spell(194844),
  Consumption					= Spell(205223),
  DeathandDecay					= Spell(43265),
  CrimsonScourge				= Spell(81141),
  RapidDecomposition			= Spell(194662),
  Ossuary						= Spell(219786),
  HeartStrike					= Spell(206930),
  BloodBoil						= Spell(50842),
  HeartBreaker                  = Spell(221536),

};
  local S = Spell.DeathKnight.Blood;

  -- GUI Settings
  local Settings = {
   General = AR.GUISettings.General,
   DeathKnight = AR.GUISettings.APL.DeathKnight
 };


--- ======= ACTION LISTS =======
local function SingleTarget()
	if S.BloodDrinker:IsCastable() and S.BloodDrinker:IsAvailable() and not Player:Buff(S.DancingRuneWeaponBuff) then
		if AR.Cast(S.BloodDrinker) then return ""; end
	end

	if S.DancingRuneWeapon:IsCastable() then
		if AR.Cast(S.DancingRuneWeapon) then return ""; end
	end

	if S.DeathStrike:IsUsable() and Player:PrevGCD(1, S.DeathStrike) then
		if AR.Cast(S.DeathStrike) then return ""; end
	end

	if S.Marrowrend:IsCastable() and Player:BuffStack(S.BoneShield) == 0 or Player:BuffRemains(S.BoneShield) < (3*Player:GCD()) then
		if AR.Cast(S.Marrowrend) then return ""; end
	end

	if S.VampiricBlood:IsCastable() then
		if AR.Cast(S.VampiricBlood) then return ""; end
	end

	if S.BloodMirror:IsCastable() and S.BloodMirror:IsAvailable() then
		if AR.Cast(S.BloodMirror) then return ""; end
	end

	if S.Consumption:IsCastable() then
		if AR.Cast(S.Consumption) then return ""; end
	end

	if S.DeathandDecay:IsCastable() and Player:Buff(S.CrimsonScourge) or S.RapidDecomposition:IsLearned() then
		if AR.Cast(S.DeathandDecay) then return ""; end
	end

	if S.BoneStorm:IsCastable() and S.BoneStorm:IsAvailable() and Player:RunicPowerDeficit() < 10 then
		if AR.Cast(S.BoneStorm) then return ""; end
	end

	if S.Marrowrend:IsCastable() and Player:BuffStack(S.BoneShield) < 5 and Cache.EnemiesCount[10] < 3 then
		if AR.Cast(S.Marrowrend) then return ""; end
	end

	if S.DeathStrike:IsUsable() and ((Player:RunicPower() > (80 or (90 and S.Ossuary:IsAvailable()))  and S.BoneStorm:IsAvailable() and not Player:Buff(S.BoneStorm) and (S.BoneStorm:CooldownRemains() > 15 or ((Player:Runes() > 3 and Player:RunicPowerDeficit() < 15) and S.BoneStorm:CooldownRemains() > 5))) or not S.BoneStorm:IsAvailable()) 
		and (not S.Ossuary:IsAvailable() or Player:BuffStack(S.BoneShield) > 5 or Player:Runes() >= 3 and Player:RunicPowerDeficit() < 10) then
		if AR.Cast(S.DeathStrike) then return ""; end
	end

	if S.DeathandDecay:IsUsable() and S.DeathandDecay:CooldownRemains() == 0 then
		if AR.Cast(S.DeathandDecay) then return ""; end
	end

	if S.HeartStrike:IsCastable() and Player:RunicPowerDeficit() >= 5 or Player:Runes() > 3 then
		if AR.Cast(S.HeartStrike) then return ""; end
	end

	if S.BloodBoil:IsCastable() then
		if AR.Cast(S.BloodBoil) then return ""; end
	end

	return false;

end
local function IcyVeinsRotation()

	if AR.CDsON() and S.DancingRuneWeapon:IsCastable() then
		if AR.Cast(S.DancingRuneWeapon, Settings.Blood.OffGCDasOffGCD.DancingRuneWeapon) then return ""; end
	end

	if S.Marrowrend:IsCastable() and Player:BuffRemains(S.BoneShield) <= (Player:GCD() * 2) then
		if AR.Cast(S.Marrowrend) then return ""; end
	end

	if S.BloodBoil:IsCastable() and Cache.EnemiesCount[10] >= 1 and not Target:Debuff(S.BloodPlague) then
		if AR.Cast(S.BloodBoil) then return ""; end
	end

	if AR.CDsON() and S.BoneStorm:IsUsable() and Cache.EnemiesCount[10] >= 1 and Player:RunicPower() >= 100 then
	    if AR.Cast(S.BoneStorm, Settings.Blood.GCDasOffGCD.BoneStorm) then return ""; end
	
	if S.DeathandDecay:IsUsable() and (Cache.EnemiesCount[10] == 1 and Player:Buff(S.CrimsonScourge) and S.RapidDecomposition:IsAvailable()) or (Cache.EnemiesCount[10] > 1 and Player:Buff(S.CrimsonScourge)) then
		if AR.Cast(S.DeathandDecay) then return ""; end
	end

	if S.BloodDrinker:IsCastable() and S.BloodDrinker:IsAvailable() and not Player:Buff(S.DancingRuneWeaponBuff) and Player:RunicPowerDeficit() >= 10 then
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

	if S.DeathandDecay:IsUsable() and ((Cache.EnemiesCount[10] == 1 and Player:Runes() >= 3 and S.RapidDecomposition:IsAvailable() and S.DeathandDecay:CooldownRemains() == 0)  or (Cache.EnemiesCount[10] >= 3 and S.DeathandDecay:CooldownRemains() == 0)) and Player:RunicPowerDeficit() >= 10 then
		if AR.Cast(S.DeathandDecay) then return ""; end
	end

	--[[if S.DeathStrike:IsUsable() and ((Player:RunicPower() > (80 or (90 and S.Ossuary:IsAvailable()))  and S.BoneStorm:IsAvailable() and not Player:Buff(S.BoneStorm) and (S.BoneStorm:CooldownRemains() > 15 or ((Player:Runes() > 3 and Player:RunicPowerDeficit() < 15) and S.BoneStorm:CooldownRemains() > 5))) or not S.BoneStorm:IsAvailable()) 
		and (not S.Ossuary:IsAvailable() or Player:BuffStack(S.BoneShield) > 5 or Player:Runes() >= 3 and Player:RunicPowerDeficit() < 10) then
		if AR.Cast(S.DeathStrike) then return ""; end
	end--]]

	if S.HeartStrike:IsCastable() and ((Player:RuneTimeToX(3) <= Player:GCD()) or Player:Runes() >=3) and (S.HeartBreaker:IsAvailable() and Player.RunicPowerDeficit() >= 15 or Player.RunicPowerDeficit() >= (15 + 2 * math.min(Cache:EnemiesCount[10], 5))) then
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

	return false;
end

--- ======= MAIN =======
local function APL ()
    -- Unit Update
    AC.GetEnemies(10);
    AC.GetEnemies(20);

   -- In Combat
    if Everyone.TargetIsValid() and Target:IsInRange(20) then
    	if Settings.DeathKnight.Blood.useIcyVeinsRotation then
			ShouldReturn = IcyVeinsRotation();
		else 
			ShouldReturn = SingleTarget();
      		if ShouldReturn then return ShouldReturn;
      		end
      	end 
  	end

  	return;
end
AR.SetAPL(250,APL);
