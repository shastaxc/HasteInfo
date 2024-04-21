-- Copyright © 2023-2024, Shasta
-- All rights reserved.

-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:

--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--     * Neither the name of HasteInfo nor the
--       names of its contributors may be used to endorse or promote products
--       derived from this software without specific prior written permission.

-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL Shasta BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

_addon.name = 'HasteInfo'
_addon.author = 'Shasta'
_addon.version = '1.4.1'
_addon.commands = {'hi','hasteinfo'}

-------------------------------------------------------------------------------
-- Includes/imports
-------------------------------------------------------------------------------
require('logger')
require('tables')
require('lists')
require('sets')
require('strings')
require('functions')

res = require('resources')
packets = require('packets')
config = require('config')
texts = require('texts')
files = require('files')
inspect = require('inspect')

require('statics')
require('job_determination')
require('interface')
require('reporting')

-- Modify the packets field mapping for incoming packet 0x0DD
-- includes more fields than Windower does by default
do -- Update fields internally.
  packets.raw_fields.incoming[0x0DD] = L{
        {ctype='unsigned int',      label='ID',                 fn=id},             -- 04
        {ctype='unsigned int',      label='HP'},                                    -- 08
        {ctype='unsigned int',      label='MP'},                                    -- 0C
        {ctype='unsigned int',      label='TP',                 fn=percent},        -- 10
        {ctype='bit[2]',            label='Party Number'},                          -- 14:0
        {ctype='bit[1]',            label='Party Leader',       fn=bool},           -- 14:2
        {ctype='bit[1]',            label='Alliance Leader',    fn=bool},           -- 14:3
        {ctype='bit[4]',            label='Is Self',            fn=bool},           -- 14:4
        {ctype='unsigned char',     label='_unknown1'},                             -- 15
        {ctype='unsigned short',    label='_unknown2'},                             -- 16
        {ctype='unsigned short',    label='Index',              fn=index},          -- 18
        {ctype='unsigned char',     label='Party Index'},                           -- 1A
        {ctype='unsigned char',     label='_unknown3'},                             -- 1B
        {ctype='unsigned char',     label='_unknown4'},                             -- 1C
        {ctype='unsigned char',     label='HP%',                fn=percent},        -- 1D
        {ctype='unsigned char',     label='MP%',                fn=percent},        -- 1E
        {ctype='unsigned char',     label='_unknown5'},                             -- 1F
        {ctype='unsigned short',    label='Zone',               fn=zone},           -- 20
        {ctype='unsigned char',     label='Main Job',           fn=job},            -- 22
        {ctype='unsigned char',     label='Main Job Level'},                        -- 23
        {ctype='unsigned char',     label='Sub Job',            fn=job},            -- 24
        {ctype='unsigned char',     label='Sub Job Level'},                         -- 25
        {ctype='unsigned char',     label='Master Level'},                          -- 26
        {ctype='boolbit',           label='Master Breaker'},                        -- 27
        {ctype='bit[7]',            label='_junk2'},                                -- 27
        {ctype='char*',             label='Name'},                                  -- 28
    }
end


-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function init()
  files.create_path('data')
  files.create_path('logs')

  update_player_info()

  settings, ui_settings = load_settings(default_settings, default_ui_settings)
  whitelist = load_whitelist()
  ui = load_ui(ui_settings)

  -- Set UI visibility based on saved setting
  ui:visible(settings.show_ui)

  -- Add primary user
  local me = add_member(player.id, player.name)
  -- Add job info
  me.main = player.main_job
  me.sub = player.sub_job
  me.main_lv = player.main_job_level
  me.sub_lv = player.sub_job_level

  -- Add initial party data
  local party = windower.ffxi.get_party()
  for i = 0, 5 do
    local actor = party['p'..i]
    if actor and actor.name then
      local actor_id
      if actor.mob and actor.mob.id > 0 then
        actor_id = actor.mob.id
      end

      -- Create user if doesn't already exist
      local member = get_member(actor_id, actor.name)
      
      member.zone = actor.zone -- Set zone info
    end
  end
  
  -- Reset self buffs
  reset_self_buffs()
  
  read_dw_traits() -- Also reports
end

-------------------------------------------------------------------------------
-- Party/Haste Functions
-------------------------------------------------------------------------------

function add_member(id, name, is_trust)
  if not id then
    -- IDs must still remain unique. Iterate backwards from 0 until an unused index is found
    for i=-1,-5,-1 do
      if not players[i] then
        id = i
        break
      end
    end
    if not id then
      print('HasteInfo: Something unexpected happened')
    end
  end
  if not name then
    name = ''
  end
  local new_member = {
    id=id,
    name=name,
    is_anon=true, -- Assume new members are anonymous until proven otherwise
    main='',
    main_lv=0,
    sub='',
    sub_lv=0,
    is_trust = is_trust,
    player_potencies=nil, -- When set, is a table of {geomancy=number, march=number}
    samba={},
    songs=T{},
    haste_effects=T{},
    buffs=L{}
  }

  -- Update potencies from whitelisted settings
  name = name:lower()
  if settings.whitelist_enabled then
    if whitelist[id] then -- Find by ID
      new_member.player_potencies = whitelist[id]
    elseif name and not is_trust and whitelist[name] then -- Find by name
      new_member.player_potencies = whitelist[name]
      -- Update settings table to store as ID if it's not a placeholder ID and not a trust
      if not is_trust and id >= 0 then
        new_member.player_potencies.id = id
        whitelist[id] = new_member.player_potencies
        whitelist[name] = nil
      end
    end
  end

  if not new_member.player_potencies then -- Assume defaults.
    new_member.player_potencies = {
      name = name,
      geomancy = settings.default_geomancy,
      march = settings.default_march
    }
    if not is_trust and id >= 0 then
      new_member.player_potencies.id = id
    end
  end

  players[id] = new_member
  
  if settings.show_party then
    update_ui_text() -- Update UI
  end
  return players[id]
end

function get_member(id, name, dontCreate)
  if not id and not name then return end

  local npc_member = get_npc_member(id, name, dontCreate)
  if npc_member then return npc_member end

  -- Update member if necessary. Possible scenarios:
  -- ID given, name given
    -- ID match found, name match found. Return.
    -- ID match found, no name match found. Update name and ID for currently-tracked entry. Return.
    -- ID match not found, name match found. Update name and ID for currently-tracked entry. Return.
    -- ID match not found, name match not found. Add member. Return.
  -- ID given, no name given
    -- ID match found. Return.
    -- ID match not found. Add member. Return.
  -- no ID given, name given
    -- Name match found. Return.
    -- Name match not found. Add member. Return.
  if id and name then
    local foundById = players[id]
    local foundByName = players:with('name', function(n)
      return n:lower() == name:lower()
    end)
    if foundById and foundByName then
      return foundById
    elseif (foundById and not foundByName)
        or (not foundById and foundByName) then
      -- Copy current entry data but update name and ID
      local found_entry
      if foundById then
        found_entry = table.copy(foundById)
        -- Nullify previous entry
        players[foundById.id] = nil
      elseif foundByName then
        found_entry = table.copy(foundByName)
        -- Nullify previous entry
        players[foundByName.id] = nil
      end
      -- Determine which if current or incoming entry has correct id
      if id > found_entry.id then
        -- New entry has correct namd/id
        found_entry.id = id
      end
      -- Make sure name is populated on new entry
      if not found_entry.name or found_entry.name == '' then
        found_entry.name = name
      end
      players[found_entry.id] = found_entry
      return players[found_entry.id]
    elseif not foundById and not foundByName and not dontCreate then
      return add_member(id, name, false)
    end
  elseif id and not name then
    local foundById = players[id]
    if foundById then
      return foundById
    elseif not dontCreate then
      return add_member(id, name, false)
    end
  elseif not id and name then
    local foundByName = players:with('name', function(n)
      return n:lower() == name:lower()
    end)
    if foundByName then
      return foundByName
    elseif not dontCreate then
      return add_member(id, name, false)
    end
  else
    return
  end
end

function remove_member(member_id)
  players[member_id] = nil
  remove_indi_effect(member_id)
  remove_geo_effect(member_id)
  
  if settings.show_party then
    update_ui_text() -- Update UI
  end
end

-- Detects if member is in the same zone as the main player
function is_in_zone(member)
  if member.id == player.id then return true end
  local me = get_member(player.id, player.name, true)
  return member.zone == me.zone
end

-- Packet should already be parsed
function update_job(member, main_job, sub_job, main_job_lv, sub_job_lv)
  if not member then return end
  local is_self = member.id == player.id

  if not main_job then return end -- This can happen when changing jobs
  main_job = res.jobs[main_job].ens
  sub_job = sub_job and res.jobs[sub_job] and res.jobs[sub_job].ens or sub_job

  if main_job == 'NON' and not is_self then
    -- Player is out of zone, assume their job has not changed
    if is_in_zone(member) then
      -- If player is anonymous, mark them as anonymous so the job
      -- deduction algorithm can try to determine their job
      member.is_anon = true
    end
  else
    member.is_anon = false
  end

  local updated_job
  if main_job and main_job ~= 'NON' then
    if main_job ~= member.main then
      member.main = main_job
      updated_job = true
    end
    if main_job_lv ~= member.main_lv then
      member.main_lv = main_job_lv or 0
      updated_job = true
    end
  end
  if sub_job and sub_job ~= 'NON' then
    if sub_job ~= member.sub then
      member.sub = sub_job
      updated_job = true
    end
    if sub_job_lv ~= member.sub_lv then
      member.sub_lv = sub_job_lv or 0
      updated_job = true
    end
  end

  -- If job was updated and this is primary player, update relevant attributes
  if updated_job then
    if is_self then
      player.main_job = main_job
      player.main_job_level = main_job_lv
      player.sub_job = sub_job
      player.sub_job_level = sub_job_lv

      read_dw_traits()
    else
      update_ui_text()
    end
  end
end

function parse_action(act, type)
  local me = get_member(player.id, player.name)

  if type == ACTION_TYPE.SELF_MELEE then
    -- Check for haste samba animation
    local is_samba_active = act.targets[1].actions[1].add_effect_animation == 23
    update_samba(me, is_samba_active)
  elseif type == ACTION_TYPE.SELF_HASTE_JA then
    if not haste_triggers['Job Ability'][act.param] then return end
    local haste_effect = table.copy(haste_triggers['Job Ability'][act.param])

    -- Set potency
    haste_effect.potency = haste_effect.potency_base
    if haste_effect.potency_per_merit and haste_effect.merit_job == player.main_job then
      haste_effect.potency = haste_effect.potency + (haste_effect.potency_per_merit * player.merits[haste_effect.merit_name])
    end
    add_haste_effect(me, haste_effect)
  elseif type == ACTION_TYPE.BARD_SONG then
    if not haste_triggers['Magic'][act.param] then return end
    local haste_effect = table.copy(haste_triggers['Magic'][act.param])
    -- Record this action. The next player update packet will tell us what the effect really was.
    local caster = get_member(act.actor_id, nil, true)

    if not caster then
      -- Check if this is a debuff spell and handle accordingly
      if haste_effect.haste_category == 'debuff' then
        for i,target in ipairs(act.targets) do
          if target.id == me.id and target.actions then
            local target_member = get_member(target.id)
            for i,a in ipairs(target.actions) do
              local buff_id = a.param
              -- Ensure spell was not resisted
              if SLOW_DEBUFF_IDS:contains(buff_id)
                  and not IMMUNITY_MESSAGE_IDS:contains(a.message)
                  and not RESIST_MESSAGE_IDS:contains(a.message)
                  and not NO_EFFECT_MESSAGE_IDS:contains(a.message) then
                -- Add to target haste effects
                haste_effect.potency = haste_effect.potency_base
                add_haste_effect(target_member, haste_effect)
              end
            end
          end
        end
      end
      return -- End processing of this action
    end

    for i,target in ipairs(act.targets) do
      -- Only care about songs on main player
      if target.id == me.id then
        local target_member = get_member(target.id)
        if target_member then
          -- Add song gear bonuses
          local song_bonus = 0

          -- Check for trusts
          if caster.is_trust or caster.sub == 'BRD' then
            song_bonus = 0
          else
            song_bonus = math.min(caster.player_potencies.march, haste_effect.song_cap)
          end
    
          -- Determine potency (each song bonus point adds 10% of base potency)
          haste_effect.potency = math.floor(haste_effect.potency_base * (1 + (0.1 * song_bonus)))

          -- Determine JA multipliers to potency
          haste_effect.multipliers = T{}
          haste_effect.multipliers[STR.SOUL_VOICE] = caster.buffs:with('id', SOUL_VOICE_BUFF_ID) and SOUL_VOICE_MULTIPLIER or 1
          haste_effect.multipliers[STR.MARCATO] = caster.buffs:with('id', MARCATO_BUFF_ID) and MARCATO_MULTIPLIER or 1

          haste_effect.received_at = now()
          target_member.songs[act.param] = haste_effect
        end
      end
    end
  elseif type == ACTION_TYPE.GEOMANCY then
    local table_entry = haste_triggers['Magic'][act.param] or nil
    local haste_effect = table_entry and table.copy(haste_triggers['Magic'][act.param])
    
    local caster = get_member(act.actor_id, nil, true)
    if not caster then
      -- Geo spells casted by non-party member should not be processed
      return
    end

    -- geo spells only ever have a single target
    local action_target = act.targets[1]
    if not action_target then return end

    local target_member = get_member(action_target.id)
    local spell = res.spells[act.param]
    local is_indi = spell and spell.en:startswith('I')

    -- See if this is one of the haste spells
    if haste_effect then
      -- Determine potency
      haste_effect.potency = haste_effect.potency_base
  
      -- Add geomancy gear bonus
      local geomancy = 0
      -- Check for trusts
      if caster.is_trust then
        geomancy = 0
        -- Check caster and target to see if this is an Entrusted spell
      elseif target_member and caster.id ~= target_member.id then
        geomancy = 0
      else -- not a trust, not entrusted
        geomancy = caster.player_potencies.geomancy
      end
  
      -- Apply geomancy bonus
      haste_effect.potency = haste_effect.potency + (haste_effect.potency_per_geomancy * geomancy)
      
      -- Determine JA boosts to potency
      -- Bolster and Blaze of Glory both apply to the bubble, but its multiplier maxes at 2x
      local bolster_multiplier = caster.buffs:with('id', BOLSTER_BUFF_ID) and BOLSTER_MULTIPLIER or 1
      local bog_multiplier = caster.buffs:with('id', BOG_BUFF_ID) and BOG_MULTIPLIER or 1
  
      -- Also, add to the indi- or geo- table
      if is_indi then
        haste_effect.caster_id = caster.id
        haste_effect.target_id = target_member.id
        haste_effect.multipliers = T{}
        if caster.id == target_member.id then -- Only apply bolster bonus if indi is on the GEO, not entrusted
          haste_effect.multipliers[STR.BOLSTER] = bolster_multiplier
        end
        add_indi_effect(haste_effect)
      else -- Assume Geo- spell
        haste_effect.caster_id = caster.id
        haste_effect.multipliers = T{}
        haste_effect.multipliers[STR.BOLSTER] = bolster_multiplier
        haste_effect.multipliers[STR.BOG] = bog_multiplier
        add_geo_effect(haste_effect)
      end
    else -- If not a haste spell, still see if this is replacing an existing effect
      -- Even if not a haste geo spell, we should track if it's ending a current one
      if is_indi then
        remove_indi_effect(target_member.id)
      else -- Assume Geo- spell
        remove_geo_effect(caster.id)
      end
    end
  elseif type == ACTION_TYPE.SPELL then
    if not haste_triggers['Magic'][act.param] then return end
    local haste_effect = table.copy(haste_triggers['Magic'][act.param])
    
    for i,target in ipairs(act.targets) do
      local target_member = get_member(target.id, nil, true)
      if target_member then
        for i,a in ipairs(target.actions) do
          local buff_id = a.param
          -- If buff doesn't match a buff that we're interested in, ignore.
          -- 'no effect' buffs have buff_id == 0, so this check filters those too
          -- 'no effect', 'resisted', or 'immune' debuffs are different and must be checked separately
          if HASTE_BUFF_IDS:contains(buff_id) then
            -- Determine potency
            haste_effect.potency = haste_effect.potency_base
            add_haste_effect(target_member, haste_effect)
          elseif SLOW_DEBUFF_IDS:contains(buff_id)
              and not IMMUNITY_MESSAGE_IDS:contains(a.message)
              and not RESIST_MESSAGE_IDS:contains(a.message)
              and not NO_EFFECT_MESSAGE_IDS:contains(a.message) then
            -- Determine potency
            haste_effect.potency = haste_effect.potency_base
            add_haste_effect(target_member, haste_effect)
          end
        end
      end
    end
  elseif type == ACTION_TYPE.SELF_CATASTROPHE then
    -- If player has proper weapon equipped, grant 10% JA haste effect
    if is_wearing_final_apoc() then
      local haste_effect = table.copy(haste_triggers['Weapon Skill'][105])
      haste_effect.potency = haste_effect.potency_base
      add_haste_effect(me, haste_effect)
    end
  elseif type == ACTION_TYPE.PET then
    if not haste_triggers['Job Ability'][act.param] then return end
    local haste_effect = table.copy(haste_triggers['Job Ability'][act.param])
    
    for i,target in ipairs(act.targets) do
      local target_member = get_member(target.id, nil, true)
      if target_member then
        for i,a in ipairs(target.actions) do
          local buff_id = a.param
          -- If buff doesn't match a buff that we're interested in, ignore.
          -- Also, 'no effect' spells have buff_id == 0, so this check filters those too
          if HASTE_BUFF_IDS:contains(buff_id) then
            -- Determine potency
            haste_effect.potency = haste_effect.potency_base
            add_haste_effect(target_member, haste_effect)
          end
        end
      end
    end
  end
end

function parse_buffs(data)
  for k = 0, 4 do
    local actor_id = data:unpack('I', k*48+5)
    
    if actor_id ~= 0 then
      local member = get_member(actor_id)
      new_buffs = L{}
      for i = 1, 32 do
        local buff_id = data:byte(k*48+5+16+i-1) + 256*( math.floor( data:byte(k*48+5+8+ math.floor((i-1)/4)) / 4^((i-1)%4) )%4) -- Credit: Byrth, GearSwap

        new_buffs:append({id=buff_id})
      end
      
      -- Filter new buffs for only ones relevant to us
      new_buffs = new_buffs:filter(function(buff)
        return HASTE_BUFF_IDS:contains(buff.id) or SLOW_DEBUFF_IDS:contains(buff.id) or OTHER_RELEVANT_BUFFS:contains(buff.id)
      end)
        
      reconcile_buff_update(member, new_buffs)
    end
  end
end

function is_samba_expired(member)
  local is_expired = true

  if member.samba and member.samba.expiration then
    is_expired = member.samba.expiration <= now()
    if is_expired then
      member.samba = {}
    end
  end
  
  return is_expired
end

function add_haste_effect(member, haste_effect)
  if not member or not haste_effect or not member.haste_effects then return end
  if not haste_effect.potency then
    print('Missing potency on haste_effect: '..haste_effect.triggering_action)
    return
  end
  if haste_effect.potency == 0 then return end

  -- Even if buff_id is already present, this could be a different action that provides the same buff_id but
  -- potentially different potency, so track this newer haste_effect instead.
  haste_effect.received_at = now()
  member.haste_effects[haste_effect.buff_id] = haste_effect
  report()
end

function remove_haste_effect(member, buff_id)
  if not member or not buff_id or not member.haste_effects or not member.haste_effects[buff_id] then return end

  member.haste_effects[buff_id] = nil
  report()
end

function add_indi_effect(effect)
  if not effect then return end

  indi_active[effect.target_id] = effect
  report()
end

function remove_indi_effect(target_id)
  if not target_id and type(target_id) ~= 'number' then return end
  
  indi_active[target_id] = nil
  report()
end

function add_geo_effect(effect)
  if not effect then return end
  
  geo_active[effect.caster_id] = effect
  report()
end

function remove_geo_effect(caster_id)
  if not caster_id and type(caster_id) ~= 'number' then return end
  
  geo_active[caster_id] = nil
  report()
end

-- Remove haste effects that don't carry through zoning, and their corresponding buffs
function remove_zoned_effects(member)
  for effect in member.haste_effects:it() do
    if not effect.persists_thru_zoning then
      remove_haste_effect(member, effect.buff_id)
    end
  end

  -- Remove songs that don't persist through zoning
  for song in member.songs:it() do
    if not song.persists_thru_zoning then
      member.songs:remove(song.triggering_id)
    end
  end
  
  -- If player had an Indi spell on them, stop tracking it
  remove_indi_effect(member.id)

  -- If player had casted a Geo spell, stop tracking it
  remove_geo_effect(member.id)
end

function update_samba(member, is_samba_active)
  if not member then return end
  
  if not is_samba_active then
    member.samba = {}
    report()
  else
    local potency = samba_stats.potency_base
    -- Check if primary player is DNC
    if player.main_job == 'DNC' then
      potency = potency + (samba_stats.potency_per_merit * player.merits[samba_stats.merit_name])
    else
      -- Determine potency based on party jobs
      local has_main_dnc
      for p in players:it() do
        if p.main == 'DNC' then
          has_main_dnc = true
          break
        end
      end
  
      if has_main_dnc then
        potency = potency + (samba_stats.potency_per_merit * 5)
      end
    end
  
    member.samba = {
      ['expiration'] = now() + SAMBA_DURATION,
      ['potency'] = potency,
    }
    report()
  end
end

function reset_self_buffs()
  local me = get_member(player.id, player.name, true)

  -- Try to determine current haste effects based on buff icons
  local current_buffs = windower.ffxi.get_player().buffs
  current_buffs = format_buffs(current_buffs)
  -- Filter for only buffs relevant to haste
  current_buffs = current_buffs:filter(function(buff)
    return HASTE_BUFF_IDS:contains(buff.id)
        or SLOW_DEBUFF_IDS:contains(buff.id)
        or OTHER_RELEVANT_BUFFS:contains(buff.id)
  end)
  -- Add received_at param
  for buff in current_buffs:it() do
    buff.received_at = now()
  end
  deduce_haste_effects(me, current_buffs)
  me.buffs = current_buffs
end

function reset_member(member)
  if member then
    remove_indi_effect(member.id)
    remove_geo_effect(member.id)

    member.samba = {}
    member.songs = T{}
    member.haste_effects = T{}
    member.buffs = L{}

    if member.id == player.id then
      reset_self_buffs()
      read_dw_traits(true)
    end
    
    report()
  end
end

-- Check if user is wearing final upgrade of Apocalypse weapon
function is_wearing_final_apoc()
  local all_items = windower.ffxi.get_items()
  local weapon_bag = all_items.equipment.main_bag
  local weapon_index = all_items.equipment.main
  if not weapon_bag or not weapon_index then
    return false
  end

  local weapon = windower.ffxi.get_items(weapon_bag, weapon_index)
  return weapon.id == FINAL_APOC_ID
end

-- Check to see if there's a tracked haste effect for this buff already
-- If there is already a haste effect being tracked for this buff, assume
-- they correspond to each other. If haste effect is not being tracked,
-- make some smart guesses as to what it could be.
function deduce_haste_effects(member, new_buffs)
  -- Make sure new_buffs is in the proper format
  local buffs = format_buffs(new_buffs)

  for buff in buffs:it() do
    if HASTE_BUFF_IDS:contains(buff.id) then
      -- See if there is a corresponding haste effect on player already
      local haste_effect = member.haste_effects[buff.id]
      local skip
      if not haste_effect then
        -- Depending on the buff, we can possibly deduce its source
        if buff.id == 228 then -- Embrava
          haste_effect = table.copy(haste_triggers['Magic'][478])
        elseif buff.id == 604 then -- Mighty Guard
          haste_effect = table.copy(haste_triggers['Magic'][750])
        elseif buff.id == 353 then -- Hasso
          haste_effect = table.copy(haste_triggers['Job Ability'][173])
        elseif buff.id == 64 then -- Last Resort
          haste_effect = table.copy(haste_triggers['Job Ability'][51])
        elseif buff.id == 273 then -- Relic aftermath
          -- Check if current weapon is one that grants haste effect
          -- Can only check equipment for main player
          if member.id == player.id and is_wearing_final_apoc() then
            haste_effect = table.copy(haste_triggers['Weapon Skill'][105])
          else
            skip = true
          end
        elseif buff.id == SONG_HASTE_BUFF_ID then -- March
          -- We only care about songs for main player
          if member.id ~= player.id then
            skip = true
          else
            update_songs(member, new_buffs)
          end
        elseif buff.id == GEO_HASTE_BUFF_ID then -- Geomancy
          local effect
          -- Get haste effect from indi- and geo- tables
          local found_indi = indi_active:with('buff_id', buff.id)
          local found_geo = geo_active:with('buff_id', buff.id)
          if not found_indi and not found_geo then
            -- Unknown source, but we know it's geomancy. Guess at stats and start tracking
            local geo_in_pt
            local entrusted_member
            local all_buffs_empty = true
            -- Search party for a GEO and select them as the caster
            for p in players:it() do
              if all_buffs_empty and p.buffs and not p.buffs:empty() then
                all_buffs_empty = false
              end
              -- If Cornelia in party, assume it's her haste
              if p.name == 'Cornelia' and p.is_trust then
                effect = table.copy(haste_triggers['Magic'][771])
                effect.potency = effect.potency_base
                effect.caster_id = p.id
                effect.target_id = p.id
                add_indi_effect(effect)
              elseif p.main == 'GEO' and not p.is_trust then
                geo_in_pt = p
              elseif p.buffs and p.buffs:contains(COLURE_ACTIVE_ID) and not indi_active[p.id] then
                if not entrusted_member or p.id == player.id then
                  entrusted_member = p
                end
              end
            end

            -- If all other players' buff lists are empty, assume we haven't rec'd a buff update packet yet
            -- or if there's no detected GEO, mark as unknown buff
            if not effect and (all_buffs_empty or not geo_in_pt) then
              effect = table.copy(haste_triggers['Other'][2])
            end

            -- Assume that if anyone is Entrusted but not on indi-active table, that is the Indi-Haste (prefer self)
            if not effect and geo_in_pt and entrusted_member then
              effect = table.copy(haste_triggers['Magic'][771])
              effect.potency = effect.potency_base
              effect.caster_id = geo_in_pt.id
              effect.target_id = entrusted_member.id
              add_indi_effect(effect)
            end

            -- If there's a GEO, but no Entrusted member, and geo has Colure Active, assume it's their Indi-Haste
            if not effect and not entrusted_member and
                (geo_in_pt and geo_in_pt.buffs and geo_in_pt.buffs:contains(COLURE_ACTIVE_ID)) then
              effect = table.copy(haste_triggers['Magic'][771])
              effect.potency = effect.potency_base + (effect.potency_per_geomancy * geo_in_pt.player_potencies.geomancy)
              effect.caster_id = geo_in_pt.id
              effect.target_id = geo_in_pt.id
              add_indi_effect(effect)
            end

            -- If no one has Colure Active, assume it's a Geo-Haste
            if not effect and not entrusted_member and
                (geo_in_pt and geo_in_pt.buffs and not geo_in_pt.buffs:contains(COLURE_ACTIVE_ID)) then
                  effect = table.copy(haste_triggers['Magic'][801])
                  effect.potency = effect.potency_base + (effect.potency_per_geomancy * geo_in_pt.player_potencies.geomancy)
                  effect.caster_id = geo_in_pt.id
              add_geo_effect(effect)
            end
          elseif found_indi and found_geo then -- Found both active indi- or geo-haste
            -- Determine which effect is stronger
            -- Take potency and add its multipliers
            local indi_mult = total_multiplier(found_indi.multipliers, GEOMANCY_JA_MULTIPLIER_MAX)
            local geo_mult = total_multiplier(found_geo.multipliers, GEOMANCY_JA_MULTIPLIER_MAX)
            
            if (found_indi.potency * indi_mult) >= (found_geo.potency * geo_mult) then
              effect = table.copy(found_indi)
            else
              effect = table.copy(found_geo)
            end
          else -- Only one effect found
            effect = (found_indi and table.copy(found_indi)) or (found_geo and table.copy(found_geo))
          end
        elseif not skip then
          -- Unknown source, guess at potency
          haste_effect = table.copy(haste_triggers['Other'][1])
        end

        if haste_effect and not haste_effect.potency then
          -- Enhance potency based on merits
          if haste_effect.potency_per_merit and haste_effect.merit_job == member.main and haste_effect.merit_name then
            -- If we're dealing with primary player, we can pull merit count; otherwise assume max merits (5)
            local merit_count = member.id == player.id and player.merits[haste_effect.merit_name] or 5
            haste_effect.potency = haste_effect.potency_base + (haste_effect.potency_per_merit * merit_count)
          else
            haste_effect.potency = haste_effect.potency_base
          end
        end
      end
      if haste_effect then
        add_haste_effect(member, haste_effect)
      end
    elseif SLOW_DEBUFF_IDS:contains(buff.id) then
      -- See if there is a corresponding haste effect on player already
      local haste_effect = member.haste_effects[buff.id]
      if not haste_effect then
        if buff.id == WEAKNESS_DEBUFF_ID then -- Weakness
          haste_effect = table.copy(haste_triggers['Other'][0])
        elseif buff.id == SLOW_SPELL_DEBUFF_ID then -- Slow
          haste_effect = table.copy(haste_triggers['Other'][3])
        elseif buff.id == SLOW_SONG_DEBUFF_ID then -- Elegy
          haste_effect = table.copy(haste_triggers['Other'][4])
        elseif buff.id == SLOW_GEO_DEBUFF_ID then -- GEO Slow
          haste_effect = table.copy(haste_triggers['Other'][5])
        end
      end
      if haste_effect then
        add_haste_effect(member, haste_effect)
      end
    end
  end
end

function from_server_time(t)
  return t / 60 + clock_offset
end

function now()
  return os.clock()
end

function format_buffs(buff_list)
  local buffs = L{}
  for i,buff in ipairs(buff_list) do
    if type(buff) == 'table' then
      buffs:append(buff)
    else
      buffs:append({id=buff})
    end
  end
  return buffs
end

-- Sort by expiration if all elements have expiration; otherwise sort by received_at
function sort_song_dur(is_missing_expirations)
  return function(e1, e2)
    if is_missing_expirations then
      return e1.received_at < e2.received_at
    else
      return e1.expiration < e2.expiration
    end
  end
end

-- Update tracked songs
-- Note: song expirations can vary by +/-1 second between packets
function update_songs(member, buffs)
  if member.id ~= player.id then return end
  -- Format and filter to only Marches
  local new_buffs = format_buffs(buffs):filter(function(buff)
    return buff.id == 214
  end)
  
  local new_count = new_buffs.n

  if new_count == 0 then -- Has no songs now, remove all
    member.songs = T{}
    return
  end

  -- Sort by expiration, if possible
  -- Could have no expiration, but received_at if running this from init()
  local is_missing_expirations = new_buffs:with('expiration', nil) ~= nil
  new_buffs:sort(sort_song_dur(is_missing_expirations))

  -- Copy song table to list
  local my_song_copy = L{}
  for buff in member.songs:it() do
    my_song_copy:append(buff)
  end

  local old_count = my_song_copy.n

  is_missing_expirations = my_song_copy:with('expiration', nil) ~= nil
  my_song_copy:sort(sort_song_dur(is_missing_expirations))

  local count_diff = new_count - old_count

  if count_diff == 0 then -- Count accurate; maybe no difference, but maybe refreshed buff duration
    -- Try to determine if a duration was refreshed
    -- Use expiration matching to figure out which songs were refreshed
    for new_song in new_buffs:it() do
      for old_song in my_song_copy:it() do
        if old_song.expiration and math.abs(new_song.expiration - old_song.expiration) < 3 then
          old_song.expiration = new_song.expiration
          old_song.paired = true
          new_song.paired = true
          break
        end
      end
    end
    -- For remaining unpaired songs, match by reverse order
    my_song_copy:reverse()
    for new_song in new_buffs:it() do
      if not new_song.paired then
        for old_song in my_song_copy:it() do
          if not old_song.paired then
            old_song.received_at = now()
            old_song.expiration = new_song.expiration
          end
        end
      end
    end

    -- Update songs
    for song in my_song_copy:it() do
      -- Clean up attributes
      song.paired = nil

      member.songs[song.triggering_id] = song
    end
    for buff in new_buffs:it() do
      buff.paired = nil
    end
  elseif count_diff < 0 then -- Lost song(s); timed out, dispelled, or overwritten
    -- Two ways to find matches:
    -- 1) expirations match within +/-1
    -- 2) matches no known expiration, pick a random nil expiration to pair it with
    local keep_songs = L{}

    -- Try match method 1, use expiration matching to figure out which songs were lost
    for new_song in new_buffs:it() do
      for old_song in my_song_copy:it() do
        if old_song.expiration and math.abs(new_song.expiration - old_song.expiration) < 3 then
          old_song.expiration = new_song.expiration
          old_song.paired = true
          new_song.paired = true
          keep_songs:append(old_song)
          break
        end
      end
    end

    if keep_songs ~= new_count then -- Do second pass with match method 2
      for new_song in new_buffs:it() do
        if not new_song.paired then -- Still needs a match
          for old_song in my_song_copy:it() do
            if not old_song.paired then
              if not old_song.expiration then
                old_song.expiration = new_song.expiration
                old_song.paired = true
                new_song.paired = true
                keep_songs:append(old_song)
                break
              else
                -- Do I need to handle this case?
                -- print('Unhandled case in lost song determination.')
              end
            end
          end
        end
      end
    end

    -- Double check that list is correct
    if keep_songs.n ~= new_count then
      -- TODO: this triggers a lot in DI because you're not expected to be able to get
      -- songs from outside of party, but you can in DI. Also, lots of dropped packets.
      -- print('Logic that determines lost songs is incorrect.')
    end

    -- Update song list
    member.songs = T{} -- Start by clearing out the old

    for song in keep_songs:it() do
      -- Clean up attributes
      song.paired = nil

      member.songs[song.triggering_id] = song
    end
    
    -- Clean up
    for new_song in new_buffs:it() do
      new_song.paired = nil
    end
    for old_song in my_song_copy:it() do
      old_song.paired = nil
    end
  elseif count_diff > 0 then -- Gained song(s) after having missed the action packet
    local gained_songs = L{}

    -- Try to use expiration match
    for new_song in new_buffs:it() do
      for old_song in my_song_copy:it() do
        if old_song.expiration and math.abs(new_song.expiration - old_song.expiration) < 1 then
          old_song.expiration = new_song.expiration
          old_song.paired = true
          new_song.paired = true
          break
        end
      end
    end
    -- If there are remaining unpaired old songs, pair them based on remaining duration (shortest first)
    for new_song in new_buffs:it() do
      if not new_song.paired then
        for old_song in my_song_copy:it() do
          if not old_song.paired then
            old_song.expiration = new_song.expiration
            old_song.paired = true
            new_song.paired = true
            break
          end
        end
      end
      -- If new song still not paired, there is nothing to pair with and this is a new song entirely
      gained_songs:append(new_song)
    end

    -- Update song list with new expiration times
    for old_song in my_song_copy:it() do
      old_song.paired = nil
      member.songs[old_song.triggering_id].expiration = old_song.expiration
    end
    for new_song in new_buffs:it() do
      new_song.paired = nil
    end

    -- If there are gained songs, try to use a smart deduction to figure out its trigger action
    local song_priority = song_assumption_priority:copy()

    -- Gained songs should already be sorted by shortest duration first
    -- These gained songs are ones that did not have a corresponding action packet detected
    -- so some assumptions have to be made about its potency. Check settings to determine what to do.
    for song in gained_songs:it() do
      for assumed_song in song_priority:it() do
        -- If assumed song not already tracked, add it and include instance specific attributes
        if not member.songs[assumed_song.triggering_id] then
          local haste_effect = assumed_song
          haste_effect.received_at = now()
          haste_effect.expiration = song.expiration
          -- Set potency (assume max)
          -- Caster unknown
          local song_bonus = math.min(settings.default_march, haste_effect.song_cap)
          haste_effect.potency = math.floor(haste_effect.potency_base * (1 + (0.1 * song_bonus)))
          member.songs[haste_effect.triggering_id] = haste_effect
          break
        end
      end
    end
  end
end

-- Make updates for both gained and lost buffs
-- Reconcile these buffs with tracked haste effects and actions; resolve discrepancies using assumed values
-- Does not need to deal with bard songs
function reconcile_buff_update(member, new_buffs)
  if not member or not new_buffs then return end
  
  -- Ensure formatting
  new_buffs = format_buffs(new_buffs)

  -- Filter new buffs for only ones relevant to us
  new_buffs = new_buffs:filter(function(buff)
    return HASTE_BUFF_IDS:contains(buff.id) or SLOW_DEBUFF_IDS:contains(buff.id) or OTHER_RELEVANT_BUFFS:contains(buff.id)
  end)

  -- Assume correct format since this is the only place member.buffs is ever modified
  local old_buffs = table.copy(member.buffs, true)

  -- To figure out the impact on haste effects, we need to know which buffs were gained and lost
  local gained_buffs = L{}
  local lost_buffs = L{}

  for new_buff in new_buffs:it() do
    for old_buff in old_buffs:it() do
      -- If expirations significantly changed, potency may have changed too. Might have just lost an action packet.
      -- However, there is no way to deduce what the new action was that refreshed the buff, so just assume
      -- that it stayed the same.
      if new_buff.id == old_buff.id and not old_buff.paired then
        new_buff.paired = true
        old_buff.paired = true
        break
      end
    end
    if not new_buff.paired then
      gained_buffs:append(new_buff)
    end
  end

  -- Remaining unpaired old buffs can be considered lost
  for old_buff in old_buffs:it() do
    if not old_buff.paired then
      lost_buffs:append(old_buff)
    end
  end

  -- Remove pairing markers
  for buff in new_buffs:it() do
    buff.paired = nil
  end
  for old_buff in old_buffs:it() do
    old_buff.paired = nil
  end

  -- Resolve new buffs' haste effects and other special handling
  for buff in gained_buffs:it() do
    -- Clean up
    buff.paired = nil
    if buff.id == BOLSTER_BUFF_ID then -- Resolve Bolster effect on current Indi spell potency
      update_geomancy_effect_multiplier(member.id, STR.BOLSTER, true)
    elseif HASTE_BUFF_IDS:contains(buff.id) or SLOW_DEBUFF_IDS:contains(buff.id) then
      deduce_haste_effects(member, new_buffs)
    end
  end
  
  -- Resolve lost buffs' haste effects and other special handling
  for buff in lost_buffs:it() do
    -- Clean up
    buff.paired = nil
    if buff.id == SONG_HASTE_BUFF_ID then
    elseif buff.id == BOLSTER_BUFF_ID then -- Resolve the effect of losing Bolster
      update_geomancy_effect_multiplier(member.id, STR.BOLSTER, false)
    elseif buff.id == COLURE_ACTIVE_ID then
      -- If lost buff is Colure Active, and this player was tracked as an indi target, remove from indi table
      remove_indi_effect(member.id)
    else
      -- See if there is a corresponding haste effect on player
      local haste_effect = member.haste_effects[buff.id]
      if haste_effect then -- Remove haste effect
        remove_haste_effect(member, buff.id)
      end
    end
  end

  -- Update buff list to new list
  update_songs(member, new_buffs)
  member.buffs = new_buffs
  report()
end

-- multiplier_name comes from STR enum
-- is_gained: true == gained this buff, false == lost this buff
function update_geomancy_effect_multiplier(caster_id, multiplier_name, is_gained)
  local update_indi
  local update_geo
  local new_multiplier
  if multiplier_name == STR.BOLSTER then
    update_indi = true
    update_geo = not is_gained
    new_multiplier = is_gained and BOLSTER_MULTIPLIER or 1
  elseif multiplier_name == STR.EA then
    update_indi = false
    update_geo = true
    new_multiplier = is_gained and ECLIPTIC_ATTRITION_MULTIPLIER or 1
  end

  local found_effect
  if update_indi then
    found_effect = indi_active[caster_id] -- Only applies to the indi spell that caster casted on themselves
    if found_effect then
      found_effect.multipliers[multiplier_name] = new_multiplier
    end
  end
  if update_geo then
    found_effect = geo_active[caster_id] -- Only applies to geo bubbles that caster casted
    if found_effect then
      found_effect.multipliers[multiplier_name] = new_multiplier
    end
  end
end

function total_multiplier(multipliers, max)
  if not multipliers then return 1 end
  local sum = 0
  for m in multipliers:it() do
    if m then
      sum = sum + m - 1
    end
  end
  return math.min(sum + 1, max)
end

-- Takes stringified binary number and converts to decimal number
function binary_to_decimal(binary_str)
  local bin = string.reverse(binary_str)
  local sum = 0

  for i = 1, string.len(bin) do
    local num = string.sub(bin, i,i) == "1" and 1 or 0
    sum = sum + num * 2^(i-1)
  end
  return sum
end

function get_npc_member(id, name, dontCreate)
  if not id then return end
  local is_npc = id > FIRST_NPC_INDEX
  if not is_npc then return end

  local member = players[id]
  if not member and not dontCreate then
    member = add_member(id, name, true)
  end

  -- Update zone
  if member and not member.zone then
    -- NPC IDs are 32 bits.
    -- First 8 bits (32-25) are are always 0000 0001
    -- Next 12 bits (24-13) are zone ID
    -- Last 12 bits (12-1) is position in entity list (plus an offset)
    local binary_id = math.binary(id)
    local zone_binary = binary_id:sub(2,13)
    local zone_id = binary_to_decimal(zone_binary)
    member.zone = zone_id
  end

  -- Update name
  if member and (not member.name or member.name:empty()) then
    if name and not name:empty() then
      member.name = name
    else -- Get name if in same zone
      local me = get_member(player.id, player.name)
      if me and member.zone == me.zone then
        local npc_info = windower.ffxi.get_mob_by_id(member.id)
        if npc_info then
          member.name = npc_info.name
        else
          member.name = ''
        end
      end
    end
  end

  -- Update trust job info
  update_trust_job(member)

  return member
end

function update_trust_job(member)
  if not member or not member.id or not member.name or member.name:empty() then return end

  -- We don't have subjob info for all trusts, so don't include a nil check for subjob
  if not member.main or member.main:empty() then
    local trust_info = trusts:with('name', member.name)
    if trust_info then
      member.main = trust_info.job
      member.sub = trust_info.subJob or '___'
      update_ui_text()
    end
  end
end

function percent(val)
  -- If string, convert to number to do conversion and then back to string
  local is_str = type(val) == 'string'
  val = is_str and tonumber(val) or val
  -- If not string, don't convert to string, return number
  local result = val / 1024 * 100 or 0
  if is_str then
    return string.format('%.1f', result) + '%'
  end
  return result
end

-- Use the indi- and geo- tables to select the strongest haste effect
function get_geomancy_effect(member)
  if not member or not member.buffs then return end

  for buff in member.buffs:it() do
    if buff.id == GEO_HASTE_BUFF_ID then
      -- Find strongest Geomancy Haste buff currently active
      -- Find strongest buff in indi table
      local strongest_effect
      local strongest_potency = 0
      for effect in indi_active:it() do
        local multiplier = total_multiplier(effect.multipliers, GEOMANCY_JA_MULTIPLIER_MAX)
        local potency = math.floor(effect.potency * multiplier)
        if strongest_effect == nil or strongest_potency < potency then
          strongest_effect = effect
          strongest_potency = potency
        end
      end
      for effect in geo_active:it() do
        local multiplier = total_multiplier(effect.multipliers, GEOMANCY_JA_MULTIPLIER_MAX)
        local potency = math.floor(effect.potency * multiplier)
        if strongest_effect == nil or strongest_potency < potency then
          strongest_effect = effect
          strongest_potency = potency
        end
      end
      if strongest_effect then
        -- Update with its potency with multipliers
        local effect = table.copy(strongest_effect)
        effect.potency = strongest_potency
        return effect
      else
        -- Not tracking any indi- or geo- buffs, so just assume an effect
        local effect = table.copy(haste_triggers['Other'][2])
        return effect
      end
      break -- Can only have one active geomancy haste buff; no need to check the rest of the buffs
    end
  end
end

-- Update player info
function update_player_info()
  local player_info = windower.ffxi.get_player()
  if player_info then
    player.id = player_info.id
    player.name = player_info.name
    player.main_job = player_info.main_job
    player.main_job_level = player_info.main_job_level
    player.sub_job = player_info.sub_job
    player.sub_job_level = player_info.sub_job_level
    player.merits = player_info.merits
    player.job_points = player_info.job_points
  end
end

function update_whitelist_index(id, name)
  if not id or not name then return end
  name = name:lower()
  local found_potencies_by_id = whitelist[id]
  if found_potencies_by_id then return end

  local found_potencies_by_name = whitelist[name]
  -- Update player potencies by name to index by ID
  if found_potencies_by_name then
    local temp_potencies = found_potencies_by_name

    -- Update settings table to store as ID
    whitelist[id] = temp_potencies
    whitelist[name] = nil
    
    local member = get_member(id, name, true)
    if member and not member.is_trust then
      players[member.id].player_potencies = temp_potencies
    end
  end
end

function save_settings()
  if not player or not player.name then print('ERROR: Player not loaded yet. Cannot save settings.') end

	local f = io.open(windower.addon_path..'data/'..player.name..'-settings.lua','w+')
  if f then
    f:write('return ' .. settings:tovstring())
    f:close()
  end
  
  -- Also save UI
  ui_settings:save()
end

function load_settings(defaults, ui_defaults)
  if not player or not player.name then print('ERROR: Player not loaded yet. Cannot load settings.') end

  local filepath = 'data/'..player.name..'-settings.lua'
  local f = files.new(filepath,true)

  if not files.exists(filepath) then
    f:create()
  end

  -- Pull metadata from defaults table
  local confdict_mt = getmetatable(defaults) or _meta.T
  local s = setmetatable(table.copy(defaults or {}), {__class = 'Settings', __index = function(t, k)
      return confdict_mt.__index[k]
  end})

  -- Start with 
  local stored_settings = T(assert(loadfile(windower.addon_path..filepath))())
  if stored_settings then
    s = table.update(table.copy(s), stored_settings, true, 5)
  end

  local ui_s = config.load('data\\ui-settings.xml', ui_defaults)
  ui_s:save() -- In case file didn't exist, this creates one with defaults

  return s, ui_s
end

function save_whitelist()
  if not player or not player.name then print('ERROR: Player not loaded yet. Cannot save whitelist.') end

  local filepath = windower.addon_path..'data/'..player.name..'-whitelist.lua'
	local f = io.open(filepath,'w+')
  if f then
    f:write('return ' .. whitelist:tovstring())
    f:close()
  end
end

function load_whitelist()
  if not player or not player.name then print('ERROR: Player not loaded yet. Cannot load whitelist.') end

  local filepath = 'data/'..player.name..'-whitelist.lua'
  local f = files.new(filepath,true)

  if not files.exists(filepath) then
    f:create()
  end

  local stored_whitelist = T(assert(loadfile(windower.addon_path..filepath))())
  local w = stored_whitelist or T{}

	return w
end

function log(message)
  local timestamp = os.date("%Y%m%d")
  local filename = 'logs/'
  if player and player.name then
    filename = filename..player.name
  else
    filename = filename..'default'
  end
  filename = filename..'-'..timestamp..'.log'

  flog(filename, message)
end

-------------------------------------------------------------------------------
-- Event hooks
-------------------------------------------------------------------------------

windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)
  if id == 0x076 then -- Party buffs update; does not include self
    -- Triggers whenever someone joins/leaves party or changes zone
    -- Does not include trusts, so do not use this packet to remove members missing from the update

    parse_buffs(data)
  elseif id == 0x0C9 then -- Triggers when examining someone
    -- Has a "Type" field which changes what data is received
    -- An examination event can result in multiple of this packet type being sent in succession
    -- Type 1 includes job and linkshell info
    -- Type 3 includes gear info; can only include 8 pieces at a time, so will send 2 of these if needed
    local packet = packets.parse('incoming', data)
    if packet['Type'] == 1 then -- Contains job info
      local member = get_member(packet['Target ID'], nil, true)
      update_job(member, packet['Main Job'], packet['Sub Job'], packet['Main Job Level'], packet['Sub Job Level'])
    elseif packet['Type'] == 3 then -- Contains gear info
      deduce_job_from_examination(packet)
    end
  elseif id == 0x0C8 then -- Alliance status update
    -- Triggers after party/alliance members join, after leadership changes,
    -- and after someone changes zone (including yourself)
    -- Includes 'ID 1' through 'ID 18' for all alliance members, in no particular order
    -- This update always precedes a bunch of 0x0DD packets, and we can use this list
    -- to determine if those subsequent 0x0DD updates are for current, new, or leaving members.

    local packet = packets.parse('incoming', data)
    
    alliance_update_0x0DD = T{}
    alliance_update_0x0C8 = {}
    -- Update tracked alliance members
    for i=1,18 do
      local player_id = packet['ID '..i]
      if player_id > 0 then -- ID == 0 is empty party slot
        local player_zone = packet['Zone '..i]
        alliance_update_0x0C8[player_id]={id=player_id, zone=player_zone}
      end
    end
  
    -- Remove tracked members if their ID is not found
    for member in players:it() do
      -- If ID is not a placeholder, but not in the party ids list, remove them
      if member.id >= 0 and not alliance_update_0x0C8[member.id] and member.id ~= player.id then
        remove_member(member.id)
      end
    end
  elseif id == 0x0DF then -- char update; importantly contains job info
    -- Contains single person updates for anyone in alliance
    -- Use this to update jobs too because 0x0DD apparently doesn't trigger in dungeons
    local packet = packets.parse('incoming', data)

    local playerId = packet['ID']
    if playerId and playerId > 0 then
      if playerId == player.id then -- If player is me, add and/or update
        local member = get_member(playerId, nil)
        update_job(member, packet['Main job'], packet['Sub job'], packet['Main job level'], packet['Sub job level'])
      elseif playerId > FIRST_NPC_INDEX then -- If player is a trust...
        -- This means we are not in an alliance and they are in your party
        -- because trusts cannot exist in an alliance. Add and/or update member.
        get_member(playerId, nil)
      else
        local member = get_member(playerId, nil, true)
        if member then -- Don't create new users in this packet, only update job
          update_job(member, packet['Main job'], packet['Sub job'], packet['Main job level'], packet['Sub job level'])
        end
      end
    end
  elseif id == 0x0DD then -- party member update; importantly contains job info
    -- Includes alliance members
    -- Triggers when someone joins/leaves party, or changes zone (even if they are out of zone)
    -- Party Number always 0 if not in alliance
    -- Party Number is 1-3 if person joining (or currently in) party/alliance
    -- Party Number is 0 if person is leaving a party/alliance
    -- Due to this discrepancy, we cannot tell if a person is leaving or joining unless we are
    -- in an alliance.

    -- If Party Number == 2 or 3, always remove them.
    -- If Party Number == 1 we will always add/update them because they are in our party in an alliance.
    -- If Party Number == 0 and we are in alliance, remove them.
    -- If Party Number == 0 and not in alliance and not in alliance_update_0x0C8 remove them.
    -- If Party Number == 0 and not in alliance and IS in alliance_update_0x0C8, add/update them.

    local packet = packets.parse('incoming', data)
    local player_id = packet['ID']

    if alliance_update_0x0C8[player_id] then
      alliance_update_0x0DD[player_id] = {
        id=player_id,
        name=packet['Name'],
        party=packet['Party Number'],
        zone=alliance_update_0x0C8[player_id].zone, -- Zone info from 0x0C8 packet is more accurate
        main=packet['Main Job'],
        sub=packet['Sub Job'],
        main_lv=packet['Main Job Level'],
        sub_lv=packet['Sub Job Level']
      }
    end

    -- If this is the last player update, process all
    if alliance_update_0x0DD:length() > 0 and alliance_update_0x0DD:length() == table.length(alliance_update_0x0C8) then
      local me_update = alliance_update_0x0DD[player.id]
      local me = get_member(player.id, player.name)
      local in_alliance = me_update.party ~= 0
      
      for person in alliance_update_0x0DD:it() do
        local member
        if person.party == me_update.party then -- Person is in my party add/update them
          member = get_member(person.id, person.name)
        elseif in_alliance and person.party == 0 then -- Person left alliance/party
          alliance_update_0x0DD[person.id] = nil -- Stop tracking alliance member
          member = get_member(person.id, person.name, true)
          if member then
            remove_member(member.id) -- Stop tracking party member
            member = nil
          end
        end
        
        -- If `member` exists here then they are in party
        if member then
          -- Update whitelist index
          update_whitelist_index(member.id, member.name)

          -- Update job info
          update_job(member, person.main, person.sub, person.main_lv, person.sub_lv)

          -- Update zone info
          local new_zone = person.zone
          local old_zone = member.zone
          if new_zone and new_zone ~= 0 then
            -- If player just left zone that main player is in, reset buffs
            if me_update and me and member.id ~= me_update.id and old_zone == me.zone and new_zone ~= me_update.zone then
              remove_zoned_effects(member)
            end
            players[member.id].zone = new_zone
          end
        end
      end
      update_ui_text()
      alliance_update_0x0DD = T{}
      alliance_update_0x0C8 = {}
    end
  elseif id == 0x063 then -- Set Update packet
    -- Sends buff ID and expiration for all of main player's current buffs
    -- Update buff durations. credit: Akaden, Buffed addon
    local order = data:unpack('H',0x05)
    if order == 5 then
      -- Includes info about amount of JP spent. We want this info for calculating DW.
      -- This fixes the issue of missing this info when first loading into the game.
      if not player or (player and player.job_points[player.main_job:lower()].jp_spent == 0) then
        (function()
          update_player_info()
          read_dw_traits() -- Also reports
        end):schedule(0)
      end
    elseif order == 9 then
      local buffs = T{}

      -- If you have no buffs, the buffs table will be empty (printed like {})
      -- Sometimes, such as when zoning, it will give you a full 32 buff list
      -- where every id == 0. That packet can be ignored, to avoid dumping buffs when
      -- you really shouldn't. Mark it as a dud and don't process.
      local is_dud

      -- read ids
      for i = 1, 32 do
        local index = 0x09 + ((i-1) * 0x02)
        local status_i = data:unpack('H', index)

        if i == 1 and status_i == 0 then
          is_dud = true
          break
        end

        if status_i ~= 255 then
          buffs[i] = { id = status_i }
        end
      end
      -- read times
      for i = 1, 32 do
        if buffs[i] then
          local index = 0x49 + ((i-1) * 0x04)
          local expiration = data:unpack('I', index)

          buffs[i].expiration = from_server_time(expiration)
        end
      end
      
      if not is_dud then
        local me = get_member(player.id, player.name)
  
        -- Reconcile these buffs with tracked haste effects and actions; resolve discrepancies using assumed values
        -- Delayed to allow other functions to finish parsing, which helps avoid race conditions and
        -- accidentally marking a buff/debuff as "unknown" with assumed potency.
        reconcile_buff_update:schedule(0.1, me, buffs)
      end
    end
  elseif id == 0x037 then
    -- update clock offset
    -- credit: Akaden, Buffed addon
    local p = packets.parse('incoming', data)
    if p['Timestamp'] and p['Time offset?'] then
      local vana_time = p['Timestamp'] * 60 - math.floor(p['Time offset?'])
      clock_offset = math.floor(os.time() - vana_time % 0x100000000 / 60)
    end
  elseif id == 0x044 then
    -- Triggers once to tell sub job info, and again with main job info. Triggers on job change and zone change.
    -- Importantly, this packet includes BLU spell info, although it is not decoded by packets library.
    -- This does not include level info so we will rely on either 0xDF for `job change` event to update levels

    if not job_update_status.started_update_at or job_update_status.started_update_at == 0 then
      job_update_status.started_update_at = now()
    elseif (now() - job_update_status.started_update_at) > 10 then -- Check if we've lost a packet
      -- Seems like we might have lost a packet. Reset flags for a fresh start
      job_update_status.main_update_received = false
      job_update_status.sub_update_received = false
      job_update_status.is_changed = false
      job_update_status.started_update_at = now()
    end

    local p = packets.parse('incoming', data)
    local member = get_member(player.id, player.name, true)

    if p['Subjob'] then
      job_update_status.sub_update_received=true

      local job = res.jobs[p['Job']].ens
      if job ~= member.sub then
        player.sub_job = job
        member.sub = job
        job_update_status.is_changed=true -- Flag if this was changed
      end
    else
      job_update_status.main_update_received=true

      local job = res.jobs[p['Job']].ens
      if job ~= member.main then
        player.main_job = job
        member.main = job
        job_update_status.is_changed=true -- Flag if this was changed
      end
    end

    if job_update_status.main_update_received and job_update_status.sub_update_received then
      -- Finished job update. Reset flags
      job_update_status.main_update_received = false
      job_update_status.sub_update_received = false
      job_update_status.started_update_at = 0

      -- If there were changes, make appropriate updates
      if job_update_status.is_changed then
        job_update_status.is_changed=false
        -- Using this 0 delay schedule will cause this update to happen after the packet finishes processing by windower.
        -- This is necessary in order to read equipped BLU spells correctly.
        read_dw_traits:schedule(0)
      end
    end
  elseif id == 0x00D then -- Updates about nearby PCs
    -- Will show player's pet IDs, so we can double check if tracked GEO bubbles still exist or not
    local packet = packets.parse('incoming', data)
    local player_id = packet['Player']
    -- Check if we are tracking a GEO bubble for this player
    -- Packet says player has no geo bubble, let's stop tracking it
    if packet['Pet Index'] == 0 and player_id and geo_active[player_id] then
      remove_geo_effect(player_id)
    end
  elseif id == 0x067 or id == 0x068 then -- Pet Info & Pet Status
    -- Only listening to these packets to tell when DRG pet is dead and remove Spirit Link/Empathy buff
    if player.main_job == 'DRG' then
      local packet = packets.parse('incoming', data)
      local type = packet['Message Type']
      local pethpp = packet['Current HP%']
      if type == 4 and pethpp == 0 then
        local me = get_member(player.id, player.name)
        remove_haste_effect(me, 1000)
      end
    end
  end
end)

windower.register_event('action', function(act)
  deduce_job_from_action(act)

  if act.category == 1 and player.id == act.actor_id then -- Melee attack
    parse_action(act, ACTION_TYPE.SELF_MELEE)
  elseif act.category == 6 then -- JA
    if act.actor_id == player.id then -- Self casted JA by self
      if haste_triggers['Job Ability'][act.param] then
        parse_action(act, ACTION_TYPE.SELF_HASTE_JA)
      end
    elseif act.param == FULL_CIRCLE_ACTION_ID then
      remove_geo_effect(act.actor_id)
    elseif act.param == ECLIPTIC_ATTRITION_ACTION_ID then
      update_geomancy_effect_multiplier(act.actor_id, STR.EA, true)
    elseif act.param == LASTING_EMANATION_ACTION_ID then
      update_geomancy_effect_multiplier(act.actor_id, STR.EA, false)
    end
  elseif act.category == 4 then -- Spell finish casting
    if players[act.targets[1].id] then -- Target is party member
      -- Determine if bard song, geomancy, or other
      local spell = res.spells[act.param]
      if spell then
        if spell.type == 'BardSong' and haste_triggers['Magic'][act.param] then
          parse_action(act, ACTION_TYPE.BARD_SONG)
        elseif spell.type == 'Geomancy' then
          parse_action(act, ACTION_TYPE.GEOMANCY)
        elseif haste_triggers['Magic'][act.param] then
          parse_action(act, ACTION_TYPE.SPELL)
        end
      end
    end
  elseif act.category == 3 and player.id == act.actor_id and haste_triggers['Weapon Skill'][act.param] then -- Finish WS, only care about Catastrophe
    parse_action(act, ACTION_TYPE.SELF_CATASTROPHE)
  elseif act.category == 13 and haste_triggers['Job Ability'][act.param] then -- Pet uses ability
    parse_action(act, ACTION_TYPE.PET)
  end
end)

windower.register_event('action message', function(actor_id, target_id, actor_index, target_index, message_id, param_1, param_2, param_3)
  -- Listen for messages that may correspond to losing a buff
  local interesting_ids = S{341, 342, 343, 344, 647, 757, 792, 806}
  if message_id and interesting_ids:contains(message_id) then
    -- Write to file for later analysis
    local message_id = message_id
    local actor_id = actor_id or 'nil'
    local target_id = target_id or 'nil'
    local actor_index = actor_index or 'nil'
    local target_index = target_index or 'nil'
    local param_1 = param_1 or 'nil'
    local param_2 = param_2 or 'nil'
    local param_3 = param_3 or 'nil'
    local action_msg = res.action_messages[message_id]
    local d = ', '
    local str = 'message_id='..message_id..d..'actor_id='..actor_id..d..'target_id='..target_id..d..
                'actor_index='..actor_index..d..'target_index='..target_index..d..'param_1='..param_1..d..
                'param_2='..param_2..d..'param_3='..param_3..d..'action_msg='..action_msg
    log(str)
  end
end)

-- Triggers on player status change. This only triggers for the following statuses:
-- 0: idle
-- 1: engaged
-- 2: dead
-- 3: engaged while dead
-- 4: in menu, cutscene, some forms of zoning
windower.register_event('status change', function(new_status_id, old_status_id)
  -- In any of these status change scenarios, haste samba status should be reset
  -- Other effects will update from the buff update packet
  local member = get_member(player.id, player.name)
  if member and member.samba then
    update_samba(member, false)
  end

  -- Hide UI while dead
  if new_status_id == 2 or new_status_id == 3 or new_status_id == 4 then
    hide_ui()
  elseif old_status_id == 2 or old_status_id == 3 or old_status_id == 4 then
    show_ui()
  end
end)

-- Hook into job/subjob change event (happens BEFORE job starts changing)
windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
  if id == 0x100 then -- Sending job change command to server, but job not yet changed
    local member = get_member(player.id, player.name)
    reset_member(member)
  elseif id == 0x102 then -- Sent when setting blu spells, among other things (non-blu related)
    if player.main_job == 'BLU' then
      -- Update tracked dw traits
      read_dw_traits()
    end
  elseif id == 0x00D then -- Last packet sent when leaving zone
    hide_ui()
    local member = get_member(player.id, player.name)
    remove_zoned_effects(member)
  end
end)

-- Triggers after zoning
windower.register_event('zone change', function(new_zone, old_zone)
  show_ui()
  local me = get_member(player.id, player.name, true)
  me.zone = new_zone

  -- Stop tracking all trusts
  for p in players:it() do
    if p.is_trust then
      remove_member(p.id)
    end
  end
  
  -- Update player info
  update_player_info()
  read_dw_traits() -- Also reports
  update_ui_text()
end)

windower.register_event('load', function()
  if windower.ffxi.get_player() then
    init()
  end
end)

windower.register_event('unload', function()
  hide_ui()
  save_settings()
  save_whitelist()
end)

windower.register_event('logout', function()
  hide_ui()
  save_settings()
  save_whitelist()
end)

windower.register_event('login', function()
  windower.send_command('lua r hasteinfo')
end)

windower.register_event('job change', function(main_job_id, main_job_level, sub_job_id, sub_job_level)
  local member = get_member(player.id, player.name)
  if not member then return end

  -- Update player levels. We rely on packet 0x044 to tell us the rest
  player.main_job_level = main_job_level
  member.main_lv = main_job_level
  
  player.sub_job_level = sub_job_level
  member.sub_lv = sub_job_level
end)

windower.register_event('addon command', function(cmd, ...)
  local cmd = cmd and cmd:lower()
  local args = {...}
  -- Force all args to lowercase
  for k,v in ipairs(args) do
    args[k] = v:lower()
  end

  if cmd then
    if S{'reload', 'r'}:contains(cmd) then
      windower.send_command('lua r hasteinfo')
      windower.add_to_chat(001, chat_d_blue..'HasteInfo: Reloading.')
    elseif S{'visible', 'vis'}:contains(cmd) then
      settings.show_ui = not settings.show_ui
      toggle_ui()
      windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI visibility set to '..chat_white..tostring(settings.show_ui)..chat_d_blue..'.')
    elseif 'show' == cmd then
      settings.show_ui = true
      show_ui()
      windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI visibility set to '..chat_white..tostring(settings.show_ui)..chat_d_blue..'.')
    elseif 'hide' == cmd then
      settings.show_ui = false
      hide_ui()
      windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI visibility set to '..chat_white..tostring(settings.show_ui)..chat_d_blue..'.')
    elseif 'resetpos' == cmd then
      settings.display.pos.x = 0
      settings.display.pos.y = 0
      ui:pos(0, 0)
      windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI position reset to default.')
    elseif S{'detail', 'details'}:contains(cmd) then
      if not args[1] then
        -- If UI is currently hidden, simply make visible and do nothing else
        if not settings.show_ui then
          settings.show_ui = true
          show_ui()
        else
          -- If all details enabled, collapse
          if settings.summary_mode == 2 and settings.show_party and settings.show_breakdown then
            settings.summary_mode = 1
            settings.show_party = false
            settings.show_breakdown = false
            windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI details set to '..chat_white..'minimal'..chat_d_blue..' mode.')
          else
            -- Else, enable all
            settings.summary_mode = 2
            settings.show_party = true
            settings.show_breakdown = true
            windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI details set to '..chat_white..'verbose'..chat_d_blue..' mode.')
          end
        end
      elseif S{'fractions', 'fraction', 'frac', 'percentage', 'percentages', 'percent', 'perc'}:contains(args[1]) then
        settings.show_fractions = not settings.show_fractions
        windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI detail values set to display in '..chat_white..(settings.show_fractions and 'fractions' or 'percentages')..chat_d_blue..'.')
      elseif 'summary' == args[1] then
        settings.summary_mode = (settings.summary_mode + 1) % 3
        local new_mode = summary_mode_options[settings.summary_mode]
        windower.add_to_chat(001, chat_d_blue..'HasteInfo: Summary detail mode set to '..chat_white..new_mode..chat_d_blue..'.')
      elseif 'party' == args[1] then
        settings.show_party = not settings.show_party
        windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI set to '..chat_white..(settings.show_party and 'show' or 'hide')..chat_d_blue..' party details.')
      elseif S{'breakdown', 'effect', 'effects'}:contains(args[1]) then
        settings.show_breakdown = not settings.show_breakdown
        windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI set to '..chat_white..(settings.show_breakdown and 'show' or 'hide')..chat_d_blue..' effect details.')
      elseif S{'expand', 'verbose'}:contains(args[1]) then
        settings.summary_mode = 2
        settings.show_party = true
        settings.show_breakdown = true
        windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI details set to '..chat_white..'verbose'..chat_d_blue..' mode.')
      elseif S{'collapse', 'collapsed', 'min', 'minimal'}:contains(args[1]) then
        settings.summary_mode = 1
        settings.show_party = false
        settings.show_breakdown = false
        windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI details set to '..chat_white..'minimal'..chat_d_blue..' mode.')
      elseif 'reset' == args[1] then
        settings.summary_mode = defaults.summary_mode
        settings.show_party = defaults.show_party
        settings.show_breakdown = defaults.show_breakdown
        windower.add_to_chat(001, chat_d_blue..'HasteInfo: UI detail modes reset to default.')
      end
      save_settings()
      update_ui_text()
    elseif 'report' == cmd then
      local skip_recalculate = true
      if args[1] == 'false' then
        skip_recalculate = false
      end
      report(skip_recalculate, true) -- Force report to send
      windower.add_to_chat(001, chat_d_blue..'HasteInfo: '..(not skip_recalculate and 'Recalculating stats and s' or 'S')..'ending report as requested.')
    elseif S{'pause', 'freeze', 'stop', 'halt', 'off', 'disable'}:contains(cmd) then
      -- Pause updating UI and sending reports, but keep updating tracked buffs and haste effects
      reports_paused = true
      update_ui_text()
      windower.add_to_chat(001, chat_d_blue..'HasteInfo: Pausing reports.')
    elseif S{'unpause', 'play', 'resume', 'continue', 'start', 'on', 'enable'}:contains(cmd) then
      -- Continue updating UI and sending reports
      reports_paused = false
      update_ui_text()
      windower.add_to_chat(001, chat_d_blue..'HasteInfo: Resuming reports.')
    elseif 'defaultpotency' == cmd then
      if not args[1] then
        -- Toggle defaults between max and min potencies
        settings.default_geomancy = settings.default_geomancy == 10 and 0 or 10
        settings.default_march = settings.default_march == 8 and 0 or 8
        save_settings()
        windower.add_to_chat(001, chat_d_blue..'HasteInfo: Set default geomancy to '..settings.default_geomancy
            ..' and march to '..settings.default_march..'.')
      end
      if args[1] and args[2] then
        local category = args[1]
        local value = tonumber(args[2])
        if S{'geo', 'geomancy', 'g', 'indi'}:contains(category) then
          category = 'geomancy'
        elseif S{'march', 'song', 'm', 's', 'brd'}:contains(category) then
          category = 'march'
        end
        settings['default_'..category] = value
        save_settings()
        windower.add_to_chat(001, chat_d_blue..'HasteInfo: Set default '..category..' to '..value..'.')
      end
    elseif S{'whitelist','wl'}:contains(cmd) then
      if not args[1] then
        -- Toggle whitelist enable/disable
        settings.whitelist_enabled = not settings.whitelist_enabled
        save_settings()
        windower.add_to_chat(001, chat_d_blue..'HasteInfo: Whitelist is '
            ..(settings.whitelist_enabled and 'enabled' or 'disabled')
            ..'.')
      elseif args[1] and args[2] and S{'remove', 'rm', 'r', 'delete', 'd'}:contains(args[1]) then
        -- Remove player from whitelist
        -- Remove by name
        whitelist[args[2]] = nil
        -- Remove by ID
        local found_entry = whitelist:with('name', args[2])
        if found_entry then
          whitelist[found_entry.id] = nil
        end
				save_whitelist()
        windower.add_to_chat(001, chat_d_blue..'HasteInfo: Removed '..args[2]..' from whitelist.')
      elseif args[1] and args[2] and args[3] then
        -- Args: 1) name, 2) geo/march, 3) value
        local name = args[1]
        local category = args[2]
        local value = tonumber(args[3])
        if S{'geo', 'geomancy', 'g', 'indi'}:contains(category) then
          category = 'geomancy'
        elseif S{'march', 'song', 'm', 's', 'brd'}:contains(category) then
          category = 'march'
        end
        
        -- Check if we are already tracking a party member with this name
        local member = get_member(nil, name, true)

        -- Perform input validation
        if category == 'geomancy' or category == 'march'
            and type(value) == 'number' then
          -- Find existing entry
          local player_potencies = whitelist[name]
          if not player_potencies then
            -- Iterate through all entries to see if it's been indexed by ID
            player_potencies = whitelist:with('name', name)
          end

          -- Update entry
          if player_potencies then
            if player_potencies.id then
              whitelist[player_potencies.id][category] = value
            else
              whitelist[name][category] = value
            end
          else -- Entry does not yet exist, make one
            if member and member.id >= 0 and not member.is_trust then
              player_potencies = {
                id=member.id,
                name=name,
                geomancy=(category == 'geomancy' and value) or settings.default_geomancy,
                march=(category == 'march' and value) or settings.default_march,
              }
              whitelist[member.id] = player_potencies
            else
              player_potencies = {
                name=name,
                geomancy=(category == 'geomancy' and value) or settings.default_geomancy,
                march=(category == 'march' and value) or settings.default_march,
              }
              whitelist[name] = player_potencies
            end
          end
          
          -- If player with this name is being tracked in party currently, update that too
          if member and player_potencies then
            players[member.id].player_potencies = player_potencies
          end
          
          save_whitelist()
          windower.add_to_chat(001, chat_d_blue..'HasteInfo: Set '..name..' '..category..' to '..value..'.')
        end
      end
    elseif 'test' == cmd then
      table.vprint(players)
    elseif 'debug' == cmd then
      DEBUG_MODE = not DEBUG_MODE
      log('Toggled Debug Mode to: '..tostring(DEBUG_MODE))
    elseif 'help' == cmd then
      windower.add_to_chat(6, ' ')
      windower.add_to_chat(6, chat_d_blue.. 'HasteInfo Commands available:' )
      windower.add_to_chat(6, chat_l_blue..	'//hi r' .. chat_white .. ': Reload HasteInfo addon')
      windower.add_to_chat(6, chat_l_blue..	'//hi vis ' .. chat_white .. ': Toggle UI visibility')
      windower.add_to_chat(6, chat_l_blue..	'//hi show ' .. chat_white .. ': Show UI')
      windower.add_to_chat(6, chat_l_blue..	'//hi hide ' .. chat_white .. ': Hide UI')
      windower.add_to_chat(6, chat_l_blue..	'//hi resetpos ' .. chat_white .. ': Reset position of UI to default')
      windower.add_to_chat(6, chat_l_blue..	'//hi party ' .. chat_white .. ': Toggle party details in UI')
      windower.add_to_chat(6, chat_l_blue..	'//hi detail ' .. chat_white .. ': Toggle UI between verbose/minimal mode')
			windower.add_to_chat(6, chat_l_blue..	'    fraction ' .. chat_white .. ': Toggle haste values in fraction or percent')
			windower.add_to_chat(6, chat_l_blue..	'    party ' .. chat_white .. ': Toggle display of party info')
			windower.add_to_chat(6, chat_l_blue..	'    breakdown ' .. chat_white .. ': Toggle display of haste effect breakdown')
			windower.add_to_chat(6, chat_l_blue..	'    summary ' .. chat_white .. ': Cycles through summary display modes')
			windower.add_to_chat(6, chat_l_blue..	'    reset ' .. chat_white .. ': Reset details to default settings')
      windower.add_to_chat(6, chat_l_blue..	'//hi pause ' .. chat_white .. ': Pause haste reports (but continues processing)')
      windower.add_to_chat(6, chat_l_blue..	'//hi play ' .. chat_white .. ': Unpause haste reports (but continues processing)')
      windower.add_to_chat(6, chat_l_blue..	'//hi defaultpotency ' .. chat_white .. ': Toggle defaults between min/max')
			windower.add_to_chat(6, chat_l_blue..	'    geo [num] ' .. chat_white .. ': Set default potency for Geomancy')
			windower.add_to_chat(6, chat_l_blue..	'    march [num] ' .. chat_white .. ': Set default potency for Marches')
      windower.add_to_chat(6, chat_l_blue..	'//hi whitelist ' .. chat_white .. ': Toggle whitelist enable/disable')
			windower.add_to_chat(6, chat_l_blue..	'    rm [name] ' .. chat_white .. ': Remove name from whitelist')
			windower.add_to_chat(6, chat_l_blue..	'    [name] geo [num] ' .. chat_white .. ': Set Geomancy potency for player')
			windower.add_to_chat(6, chat_l_blue..	'    [name] march [num] ' .. chat_white .. ': Set March potency for player')
      windower.add_to_chat(6, chat_l_blue..	'//hi debug ' .. chat_white .. ': Toggle debug mode')
      windower.add_to_chat(6, chat_l_blue..	'//hi help ' .. chat_white .. ': Display this help menu again')
    else
      windower.send_command('hi help')
    end
  else
    windower.send_command('hi help')
  end
end)
