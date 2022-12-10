-------------------------------------------------------------------------------
-- Reporting functions
-------------------------------------------------------------------------------

-- Report latest stats
function report(skip_recalculate_stats, force_update)
  if reports_paused then return end

  local old_dw_needed = stats.dual_wield.actual_needed
  if not skip_recalculate_stats then
    calculate_stats()
  end

  -- Update UI
  update_ui_text()

  -- Send report to GearSwap
  local dw_needed = stats.dual_wield.actual_needed
  if (old_dw_needed ~= dw_needed) or force_update then
    windower.send_command('gs c hasteinfo '..dw_needed)
  end
end

-- Calculate haste and dual wield stats
function calculate_stats()
  local me = get_member(player.id, player.name, true)
  if not me then return end
  
  -- Reset stats
  old_dw_stats = table.copy(stats['dual_wield'], true)
  stats['haste'] = table.copy(default_stats['haste'], true)
  stats['dual_wield'] = old_dw_stats

  -- Sum potency of all effects by category (ma, ja, debuff) in uncapped summation
  for effect in me.haste_effects:it() do
    -- Add potency to stats
    stats['haste'][effect.haste_category]['uncapped']['fraction'] = stats['haste'][effect.haste_category]['uncapped']['fraction'] + effect.potency
  end
  
  -- Add Geomancy potency to ma category
  local geomancy_effect = get_geomancy_effect(me)
  if geomancy_effect then
    stats['haste']['ma']['uncapped']['fraction'] = stats['haste']['ma']['uncapped']['fraction'] + geomancy_effect.potency
  end

  -- Add songs potency to ma category
  for song in me.songs:it() do
    -- Calculate final potency after multipliers
    local multiplier = total_multiplier(song.multipliers, SONG_JA_MULTIPLIER_MAX)
    local potency = math.floor(song.potency * multiplier)
    -- Add potency to stats
    stats['haste']['ma']['uncapped']['fraction'] = stats['haste']['ma']['uncapped']['fraction'] + potency
  end

  -- Add samba potency to ja category
  if not is_samba_expired(me) then
    -- Add potency to stats
    stats['haste']['ja']['uncapped']['fraction'] = stats['haste']['ja']['uncapped']['fraction'] + me.samba.potency
  end

  -- Even without category caps, there is a hard limit for what the server will calculate (I think)
  for haste_cat, t in pairs(stats['haste']) do
    t['uncapped']['fraction'] = math.min(t['uncapped']['fraction'], 1024)
  end

  -- Calculate percent values
  for haste_cat, t in pairs(stats['haste']) do
    -- Get uncapped fraction
    local uncapped_frac = t['uncapped']['fraction']
    -- Calculate fraction as percentage
    local uncapped_perc = percent(uncapped_frac)
    t['uncapped']['percent'] = uncapped_perc
    
    -- Calculate actual values (include caps)
    local capped_frac = math.min(uncapped_frac, haste_caps[haste_cat]['fraction'])
    t['actual']['fraction'] = capped_frac
    local capped_perc = math.min(uncapped_perc, haste_caps[haste_cat]['percent'])
    t['actual']['percent'] = capped_perc
  end
  
  -- Calculate total haste (must use actual values with category caps)
  local ma_total = math.min(stats.haste.ma.uncapped.fraction
                            - stats.haste.debuff.uncapped.fraction,
                            haste_caps.ma.fraction)
  stats.haste.total.uncapped.fraction = ma_total + stats.haste.ja.actual.fraction + stats.haste.eq.actual.fraction
  stats.haste.total.actual.fraction = math.min(stats.haste.total.uncapped.fraction, haste_caps.total.fraction)
  
  stats.haste.total.uncapped.percent = percent(stats.haste.total.uncapped.fraction)
  stats.haste.total.actual.percent = math.min(stats.haste.total.uncapped.percent, haste_caps.total.percent)

  -- Determine dual wield needed
  if stats.dual_wield.traits == 0 then -- Unable to dual wield weapons at all
    stats.dual_wield.total_needed = -1
    stats.dual_wield.actual_needed = -1
  else -- Never allow to be negative
    stats.dual_wield.total_needed =  math.max(math.ceil((1 - (0.2 / ( (1024 - stats.haste.total.actual.fraction) / 1024))) * 100), 0)
    stats.dual_wield.actual_needed = math.max(stats.dual_wield.total_needed - stats.dual_wield.traits, 0)
  end
end

function read_dw_traits(dontReport)
  local me = get_member(player.id, player.name, true)
  if not me then return end
  local dw_tier = 0
  dw_tier = math.max(dw_tier, get_dw_tier_for_job(me, true))
  dw_tier = math.max(dw_tier, get_dw_tier_for_job(me, false))
  
  stats.dual_wield.traits = dw_tiers[dw_tier]

  -- Publish new stats
  if not dontReport then
    report()
  end
end

function get_dw_tier_for_job(member, is_main)
  if not member or member.id ~= player.id then return 0 end

  local job = is_main and player.main_job or player.sub_job
  local job_lv = is_main and player.main_job_level or player.sub_job_level
  if not job or not job_lv then return 0 end

  -- Determine DW tier
  local dw_tier
  if S{'NIN', 'DNC', 'THF'}:contains(job) then
    -- Determine dual wield based on job, level, and job points
    local dw_table = dw_jobs[job]
    -- Determine if job point gift tier applies
    local jp_spent = is_main and player.job_points[job:lower()].jp_spent or 0
    for k,entry in ipairs(dw_table) do
      if job_lv >= entry.lv and jp_spent >= entry.jp_spent then
        dw_tier = entry.tier
      else
        break
      end
    end
    dw_tier = dw_tier or 0
  elseif is_main and job == 'BLU' then -- Subjob BLU cannot access any spells that would grant DW trait
    -- Determine dual wield based on equipped BLU spells
    local spell_ids = is_main and windower.ffxi.get_mjob_data().spells or windower.ffxi.get_sjob_data().spells or {}
    local trait_points = 0
    for k,spell_id in ipairs(spell_ids) do
      -- Check if equipped spell is a dw spell
      local dw_spell = dw_blu_spells[spell_id]
      if dw_spell then
        trait_points = trait_points + dw_spell.trait_points
      end
    end
    dw_tier = math.floor(trait_points / 8)
  else
    dw_tier = 0
  end
  return dw_tier
end
