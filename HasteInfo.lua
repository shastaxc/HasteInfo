-- Copyright © 2022, Shasta
-- All rights reserved.

-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:

--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--     * Neither the name of SilverLibs nor the
--       names of its contributors may be used to endorse or promote products
--       derived from this software without specific prior written permission.

-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL <your name> BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


--=============================================================================
--=============================================================================
--====================             DO NOT              ========================
--====================             MODIFY              ========================
--====================            ANYTHING             ========================
--=============================================================================
--=============================================================================

_addon.name = 'HasteInfo'
_addon.author = 'Shasta'
_addon.version = '0.0.2'
_addon.commands = {'hi','hasteinfo'}

-------------------------------------------------------------------------------
-- Includes/imports
-------------------------------------------------------------------------------
require('logger')
require('tables')
require('lists')
require('sets')
require('logger')
require('strings')

res = require('resources')
packets = require('packets')
config = require('config')
texts = require('texts')

require('statics')

-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function init()
  player = windower.ffxi.get_player()

  load_settings()

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
    local member = party['p'..i]
    if member and member.name then
      local actor_id
      if member.mob and member.mob.id > 0 then
        actor_id = member.mob.id
      end
      -- Create user if doesn't already exist
      get_member(actor_id, member.name)
    end
  end
  
  -- Reset self buffs
  reset_self_buffs()
  
  read_dw_traits()
  report()
end

function load_settings()
  settings = config.load('data\\settings.xml',defaults)
  settings:save() -- In case file didn't exist, this creates one with defaults
  ui = texts.new('${value}', settings.display)
  
  ui.value = 'HasteInfo Loading...'

  -- Set UI visibility based on saved setting
  ui:visible(settings.show_ui)
end

-------------------------------------------------------------------------------
-- Party/Haste Functions
-------------------------------------------------------------------------------

function add_member(id, name)
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
  local new_member = {id=id, name=name, main='', main_lv=0, sub='', sub_lv=0, samba={}, songs=T{}, haste_effects=T{}, buffs=L{}}
  players[id] = new_member
  return players[id]
end

function get_member(id, name, dontCreate)
  local foundMember = players[id]
  if foundMember then
    if name and foundMember.name ~= name then
      foundMember.name = name
    end
    return foundMember
  else
    local foundByName = players:with('name', name)
    if foundByName then -- try to match by name if no ID match
      -- This situation may happen when resummoning trusts or if member was out of zone when first detected
      -- If name matches, keep the higher ID
      local found_id = foundByName.id
      if id > found_id then
        players[id] = table.copy(foundByName)
        players[id].id = id
        players[found_id] = nil
        return players[id]
      else
        return foundByName
      end
    elseif not dontCreate then
      return add_member(id, name)
    end
  end
end

-- Packet should already be parsed
function update_job_from_packet(member, packet)
  local main_job = packet['Main job']
  local main_job_lv = packet['Main job level']
  local sub_job =  packet['Sub job']
  local sub_job_lv = packet['Sub job level']

  if main_job and main_job ~= 'NON' then
    member.main = res.jobs[main_job].ens
    member.main_lv = main_job_lv or 0
  end
  if sub_job and sub_job ~= 'NON' then
    member.sub = res.jobs[sub_job].ens
    member.sub_lv = sub_job_lv or 0
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

    local me_target = table.with(act.targets, 'id', me.id)
    if not me_target then return end
    -- Check if it has any effect
    if table.find(me_target.actions, function(a) return a.param ~= 0 end) then
      -- Set potency
      haste_effect.potency = haste_effect.potency_base
      if haste_effect.potency_per_merit then
        haste_effect.potency = haste_effect.potency + (haste_effect.potency_per_merit * player.merits[haste_effect.merit_name])
      end
      add_haste_effect(me, haste_effect)
    end
  elseif type == ACTION_TYPE.ENTRUST_ACTIVATION then
  elseif type == ACTION_TYPE.BARD_SONG then
    if not haste_triggers['Magic'][act.param] then return end
    local haste_effect = table.copy(haste_triggers['Magic'][act.param])

    -- Record this action. The next player update packet will tell us what the effect really was.
    local caster = get_member(act.actor_id, nil, true)
    if not caster or not player[caster.id] then return end

    for i,target in ipairs(act.targets) do
      -- Only care about songs on main player
      if target.id == me.id then
        local target_member = get_member(target.id)
        if target_member then
          -- Add song gear bonuses
          local song_bonus = 0
          if caster then -- caster is in party
            -- Check for trusts
            if trusts:with('name', caster.name) or caster.sub == 'BRD' then
              song_bonus = 0
            else
              song_bonus = haste_effect.song_cap
            end
          else -- caster is not defined, must make assumptions about song potency
            song_bonus = haste_effect.song_cap
          end
    
          -- Determine potency (each song bonus point adds 10% of base potency)
          haste_effect.potency = math.floor(haste_effect.potency_base + (haste_effect.potency_base * 0.1 * song_bonus))
          haste_effect.received_at = now()
          target_member.songs[act.param] = haste_effect
        end
      end
    end
  elseif type == ACTION_TYPE.GEOMANCY then
    if not haste_triggers['Magic'][act.param] then return end
    local haste_effect = table.copy(haste_triggers['Magic'][act.param])
    
    local caster = get_member(act.actor_id, nil, true)
    if not caster or not player[caster.id] then return end

    for i,target in ipairs(act.targets) do
      local target_member = get_member(target.id)

      -- Determine potency
      haste_effect.potency = haste_effect.potency_base

      -- Add geomancy gear bonus
      local geomancy = 0
      -- Check for trusts
      if trusts:with('name', caster.name) then
        geomancy = 0
      else -- not a trust
        geomancy = 10 -- assume idris; TODO: Enhance this with a whitelist/blacklist
      end
      haste_effect.potency = haste_effect.potency + (haste_effect.potency_per_geomancy * geomancy)
      -- Also, add to the indi- or geo- table
      if haste_effect.triggering_action:startswith('Indi-') then
        haste_effect.caster_id = caster.id
        haste_effect.target_id = target_member.id
        add_indi_effect(haste_effect)
      elseif haste_effect.triggering_action:startswith('Geo-') then
        haste_effect.caster_id = caster.id
        add_geo_effect(haste_effect)
      end

      add_haste_effect(target_member, haste_effect)
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
          -- Also, 'no effect' spells have buff_id == 0, so this check filters those too
          if HASTE_BUFF_IDS:contains(buff_id) or SLOW_DEBUFF_IDS:contains(buff_id) then
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
      local member = get_member(actor_id) or add_member(actor_id)
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

  -- Thanks to this packet update, we should have all party members with IDs in the table.
  -- If there were previous entries with placeholder IDs, dump them. They will never reconcile.
  for member in players:it() do
    if member.id < 0 then
      players[member.id] = nil
    end
  end
end

function is_samba_expired(member)
  local is_expired = true

  if member.samba and member.samba.expiration then
    is_expired = member.samba.expiration >= now()
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

  -- Even if buff_id is already present, this could be a different action that provides the same buff_id but
  -- potentially different potency, so track this newer haste_effect instead.
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
  if not target_id and type(target_id) ~= 'number' then return end
  
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
  
  -- If player had an Indi spell on them, stop tracking it
  remove_indi_effect(member.id)

  -- If player had casted a Geo spell, stop tracking it
  remove_geo_effect(member.id)
end

function update_samba(member, is_samba_active)
  if not member then return end
  if member.samba and not is_samba_active then
    member.samba = {}
    report()
  elseif is_samba_active then
    local potency = samba_stats.potency_base
    -- Check if primary player is DNC
    if player.main_job == 'DNC' then
      potency = potency + (samba_stats.potency_per_merit * player.merits[samba_stats.merit_name])
    else
      -- Determine potency based on party jobs
      local has_main_dnc
      for member in players:it() do
        if member.main == 'DNC' then
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
  current_buffs = current_buffs:map(function(buff)
    buff.received_at = now()
    return buff
  end)
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
      read_dw_traits()
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
        elseif buff.id == 214 then -- March
          -- We only care about songs for main player
          if member.id ~= player.id then
            skip = true
          end
          update_songs(member, new_buffs)
        elseif buff.id == 580 then -- Geomancy
          -- Get haste effect from indi- and geo- tables
          local found_indi = indi_active:with('buff_id', buff.id)
          if found_indi then
            haste_effect = found_indi
          else
            local found_geo = geo_active:with('buff_id', buff.id)
            if found_geo then
              haste_effect = found_geo
            end
          end
      
          if not haste_effect then
            -- Unknown source, but we know it's geomancy. Guess at potency
            haste_effect = table.copy(haste_triggers[771])
            haste_effect.potency = haste_effect.potency_base + (haste_effect.potency_per_geomancy * 10)
          end
        elseif not skip then
          -- Unknown source, guess at potency
          haste_effect = table.copy(haste_triggers['Other'][0])
        end

        if haste_effect and not haste_effect.potency then
          -- Enhance potency based on merits
          if haste_effect.potency_per_merit and haste_effect.merit_name then
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
        if old_song.expiration and math.abs(new_song.expiration - old_song.expiration) < 1 then
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
  elseif count_diff < 0 then -- Lost song(s); timed out, dispelled, or overwritten
    -- Two ways to find matches:
    -- 1) expirations match within +/-1
    -- 2) matches no known expiration, pick a random nil expiration to pair it with
    local keep_songs = L{}

    -- Try match method 1, use expiration matching to figure out which songs were lost
    for new_song in new_buffs:it() do
      for old_song in my_song_copy:it() do
        if old_song.expiration and math.abs(new_song.expiration - old_song.expiration) < 1 then
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
                print('Unhandled case in lost song determination.')
              end
            end
          end
        end
      end
    end

    -- Double check that list is correct
    if keep_songs ~= new_count then
      print('Logic that determines lost songs is incorrect.')
    end

    -- Update song list
    member.songs = T{} -- Start by clearing out the old

    for song in keep_songs:it() do
      -- Clean up attributes
      song.paired = nil

      member.songs[song.triggering_id] = song
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
      member.songs[old_song.triggering_id].expiration = old_song.expiration
    end

    -- If there are gained songs, try to use a smart deduction to figure out its trigger action
    local song_assumption_priority = song_assumption_priority:copy()

    -- Gained songs should already be sorted by shortest duration first
    for song in gained_songs:it() do
      for assumed_song in song_assumption_priority:it() do
        -- If assumed song not already tracked, add it and include instance specific attributes
        if not member.songs[assumed_song.triggering_id] then
          assumed_song.received_at = now()
          assumed_song.expiration = song.expiration
          -- Set potency (assume max)
          haste_effect.potency = math.floor(haste_effect.potency_base + (haste_effect.potency_base * 0.1 * haste_effect.song_cap))
          member.songs[assumed_song.triggering_id] = assumed_song
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

  -- Resolve new buffs' haste effects and other special handling
  for buff in gained_buffs:it() do
    if buff.id == BOLSTER_BUFF_ID then -- Resolve Bolster effect on current Indi spell potency
      -- TODO: update indi- table, and haste effects for all party members who have the corresponding buff
    elseif buff.id == ECLIPTIC_ATTRITION_BUFF_ID then -- Resolve EA effect on current Geo spell potency
      -- TODO: update geo- table, and haste effects for all party members who have the corresponding buff
    elseif HASTE_BUFF_IDS:contains(buff.id) then
      deduce_haste_effects(member, new_buffs)
    end
  end
  
  -- Resolve lost buffs' haste effects and other special handling
  for buff in lost_buffs:it() do
    -- See if there is a corresponding haste effect on player
    local haste_effect = member.haste_effects[buff.id]
    if haste_effect then -- Remove haste effect
      remove_haste_effect(member, buff.id)
    end

    -- If lost buff is Colure Active, and this player was tracked as an indi target, remove from indi table
    if buff.id == COLURE_ACTIVE_ID then
      remove_indi_effect(member.id)
    end
  end

  -- Update buff list to new list
  member.buffs = new_buffs
end


-------------------------------------------------------------------------------
-- UI Functions
-------------------------------------------------------------------------------

function toggle_ui()
  local is_vis = ui:visible()
  -- If we're changing it to be visible, we need to update the UI text first
  if not is_vis then
    update_ui_text(true)
  end
  
  -- Toggle visibility
  ui:visible(not is_vis)
end

function show_ui()
  local is_vis = ui:visible()
  -- If we're changing it to be visible, we need to update the UI text first
  if not is_vis then
    update_ui_text(true)
    ui:show()
  end
end

function hide_ui()
  ui:hide()
end

function update_ui_text(force_update)
  -- No point in setting UI text if it's not visible
  if not force_update and not ui:visible() then return end

  -- Get stats to display and report
  local dw_needed = stats.dual_wield.actual_needed
  local total_haste = settings.show_fractions and stats.haste.total.actual.fraction or string.format("%.1f", stats.haste.total.actual.percent)
  local perc = settings.show_fractions and nil or '%'
  local dw_traits = ''
  local ma_haste = ''
  local ja_haste = ''
  local eq_haste = ''

  if settings.show_haste_details then
    dw_traits = stats.dual_wield.traits
    ma_haste = settings.show_fractions and stats.haste.ma.actual.fraction or string.format("%.1f", stats.haste.ma.actual.percent)
    ja_haste = settings.show_fractions and stats.haste.ja.actual.fraction or string.format("%.1f", stats.haste.ja.actual.percent)
    eq_haste = settings.show_fractions and stats.haste.eq.actual.fraction or string.format("%.1f", stats.haste.eq.actual.percent)
  end

  -- Compose new text string
  local str = ''
  str = str..'DW Needed: '..dw_needed
  if settings.show_haste_details then
  str = str..' ('..dw_traits..' from traits)'
  end
  str = str..' | Haste: '..total_haste..perc
  if settings.show_haste_details then
    str = str..' Total ('..ma_haste..perc..' MA, '..ja_haste..perc..' JA, '..eq_haste..perc..' EQ)'
  end

  ui:text(str)
end


-------------------------------------------------------------------------------
-- Reporting functions
-------------------------------------------------------------------------------

-- Report latest stats
function report(skip_recalculate_stats)
  if reports_paused then return end
  if not skip_recalculate_stats then
    calculate_stats()
  end

  -- Update UI
  update_ui_text()

  -- Send report to GearSwap
  local dw_needed = stats.dual_wield.actual_needed
  windower.send_command('gs c hasteinfo '..dw_needed)
end

-- Calculate haste and dual wield stats
function calculate_stats()
  local me = get_member(player.id, player.name, true)
  
  -- Reset stats
  old_dw_stats = table.copy(stats['dual_wield'], true)
  stats['haste'] = table.copy(default_stats['haste'], true)
  stats['dual_wield'] = old_dw_stats

  -- Sum potency of all effects by category (ma, ja, debuff) in uncapped summation
  for effect in me.haste_effects:it() do
    -- Add potency to stats
    stats['haste'][effect.haste_category]['uncapped']['fraction'] = stats['haste'][effect.haste_category]['uncapped']['fraction'] + effect.potency
  end

  -- Add songs potency to ma category
  for song in me.songs:it() do
    -- Add potency to stats
    stats['haste']['ma']['uncapped']['fraction'] = stats['haste']['ma']['uncapped']['fraction'] + song.potency
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

  -- Calculate total haste
  stats['haste']['total']['uncapped']['fraction'] = stats['haste']['ma']['uncapped']['fraction']
                                                  + stats['haste']['ja']['uncapped']['fraction']
                                                  + stats['haste']['eq']['uncapped']['fraction']
                                                  - stats['haste']['debuffs']['uncapped']['fraction']

  -- Calculate percent values
  for haste_cat, t in pairs(stats['haste']) do
    -- Get uncapped fraction
    local uncapped_frac = t['uncapped']['fraction']
    -- Calculate fraction as percentage
    local uncapped_perc = uncapped_frac / 1024 * 100 or 0
    t['uncapped']['percent'] = uncapped_perc
    
    -- Calculate actual values (include caps)
    local capped_frac = math.min(uncapped_frac, haste_caps[haste_cat]['fraction'])
    t['actual']['fraction'] = capped_frac
    local capped_perc = math.min(uncapped_perc, haste_caps[haste_cat]['percent'])
    t['actual']['percent'] = capped_perc
  end

  -- Determine dual wield needed
  stats.dual_wield.total_needed = math.max(math.ceil((1 - (0.2 / ( (1024 - stats.haste.total.actual.fraction) / 1024))) * 100), 0)
  stats.dual_wield.actual_needed = stats.dual_wield.total_needed - stats.dual_wield.traits
end

function read_dw_traits()
  local me = get_member(player.id, player.name, true)
  if not me then return end

  local dw_tier = 0
  dw_tier = math.max(dw_tier, get_dw_tier_for_job(me, true))
  dw_tier = math.max(dw_tier, get_dw_tier_for_job(me, false))
  
  stats.dual_wield.traits = dw_tiers[dw_tier]
end

function get_dw_tier_for_job(member, is_main)
  if not member then return 0 end
  local job = is_main and member.main or member.sub
  local job_lv = is_main and member.main_lv or member.sub_lv
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
  elseif job == 'BLU' then
    -- Determine dual wield based on equipped BLU spells
    local spell_ids = windower.ffxi.get_mjob_data().spells
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


-------------------------------------------------------------------------------
-- Event hooks
-------------------------------------------------------------------------------

windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)
  if id == 0x076 then -- Party buffs update; does not include buffs on self
    parse_buffs(data)
  elseif id == 0xDF then -- char update
    local packet = packets.parse('incoming', data)
    if packet then
      local playerId = packet['ID']
      if playerId and playerId > 0 then
        -- print('PACKET: Char update for player ID: '..playerId)
        local member = get_member(playerId, nil)
        update_job_from_packet(member, packet)
      else
        print('Char update: ID not found.')
      end
    end
  elseif id == 0xDD then -- party member update
    local packet = packets.parse('incoming', data)
    if packet then
      local name = packet['Name']
      local playerId = packet['ID']
      if name and playerId and playerId > 0 then
        -- print('PACKET: Party member update for '..name)
        local member = get_member(playerId, name)
        update_job_from_packet(member, packet)
      else
        print('Party update: name and/or ID not found.')
      end
    end
  elseif id == 0x01B then -- job info, comes in after changing jobs
    local packet = packets.parse('incoming', data)
    local member = get_member(player.id, player.name)
    update_job_from_packet(member, packet)
  elseif id == 0x063 then -- Set Update packet
    -- Update buff durations. credit: Akaden, Buffed addon
    local order = data:unpack('H',0x05)
    if order == 9 then
      local buffs = T{}

      -- read ids
      for i = 1, 32 do
        local index = 0x09 + ((i-1) * 0x02)
        local status_i = data:unpack('H', index)

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

      local me = get_member(player.id, player.name)

      -- Reconcile these buffs with tracked haste effects and actions; resolve discrepancies using assumed values
      reconcile_buff_update(me, buffs)
    end
  elseif id == 0x037 then
    -- update clock offset
    -- credit: Akaden, Buffed addon
    local p = packets.parse('incoming', data)
    if p['Timestamp'] and p['Time offset?'] then
      local vana_time = p['Timestamp'] * 60 - math.floor(p['Time offset?'])
      clock_offset = math.floor(os.time() - vana_time % 0x100000000 / 60)
    end
  end
end)


windower.register_event('action', function(act)
  if act.category == 1 and player.id == act.actor_id then -- Melee attack
    parse_action(act, ACTION_TYPE.SELF_MELEE)
  elseif act.category == 6 then -- JA; Only care about JA on self, except Entrust
    if act.actor_id == player.id and haste_triggers['Job Ability'][act.param] then
      parse_action(act, ACTION_TYPE.SELF_HASTE_JA)
    elseif act.param == 386 then -- Entrust activation
      parse_action(act, ACTION_TYPE.ENTRUST_ACTIVATION)
    end
  elseif act.category == 4 and haste_triggers['Magic'][act.param]
      and players[act.targets[1].id] then -- Spell finish casting on party member target
    -- Determine if bard song, geomancy, or other
    local spell = res.spells[act.param]
    if spell then
      if spell.type == 'BardSong' then
        parse_action(act, ACTION_TYPE.BARD_SONG)
      elseif spell.type == 'Geomancy' then
        parse_action(act, ACTION_TYPE.GEOMANCY)
      else
        parse_action(act, ACTION_TYPE.SPELL)
      end
    end
  elseif act.category == 3 and player.id == act.actor_id and haste_triggers['Weapon Skill'][act.param] then -- Finish WS, only care about Catastrophe
    parse_action(act, ACTION_TYPE.SELF_CATASTROPHE)
  elseif act.category == 13 and haste_triggers['Job Ability'][act.param] then -- Pet uses ability
    parse_action(act, ACTION_TYPE.PET)
  end
end)

-- Triggers on player status change. This only triggers for the following statuses:
-- Idle, Engaged, Resting, Dead, Zoning
windower.register_event('status change', function(new_status_id, old_status_id)
  -- In any of these status change scenarios, haste samba status should be reset
  -- Other effects will update from the buff update packet
  local member = get_member(player.id, player.name)
  if member and member.samba then
    update_samba(member, false)
  end
end)

-- Hook into job/subjob change event (happens BEFORE job starts changing)
windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
  if id == 0x100 then -- Sending job change command to server
    local member = get_member(player.id, player.name)
    reset_member(member)
  end
end)

windower.register_event('zone change', function(new_zone, old_zone)
  -- Update buffs after zoning
  local member = get_member(player.id, player.name)
  remove_zoned_effects(member)
end)

windower.register_event('load', function()
  if windower.ffxi.get_player() then
    init()
  end
end)

windower.register_event('unload', function()
  hide_ui()
  settings:save()
end)

windower.register_event('logout', function()
  hide_ui()
  settings:save()
end)

windower.register_event('login',function ()
  windower.send_command('lua r hasteinfo')
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
    elseif S{'visible', 'vis'}:contains(cmd) then
      settings.show_ui = not settings.show_ui
      settings:save()
      toggle_ui()
    elseif 'show' == cmd then
      settings.show_ui = true
      settings:save()
      show_ui()
    elseif 'hide' == cmd then
      settings.show_ui = false
      settings:save()
      hide_ui()
    elseif 'resetpos' == cmd then
      settings.display.pos.x = 0
      settings.display.pos.y = 0
      settings:save()
      ui:pos(0, 0)
    elseif 'party' == cmd then
      -- TODO: Toggle party details in UI
    elseif 'details' == cmd then
      -- Toggle main player's haste details in UI
      settings.show_haste_details = not settings.show_haste_details
      settings:save()
      update_ui_text()
      if S{'fractions', 'fraction', 'frac', 'f'}:contains(args[1]) then
        settings.show_fractions = true
      elseif S{'percentage', 'percentages', 'percent', 'perc', 'p'}:contains(args[1]) then
        settings.show_fractions = false
      end 
    elseif 'report' == cmd then
      report(true)
    elseif S{'pause', 'freeze', 'stop', 'halt', 'off', 'disable'}:contains(cmd) then
      -- Pause updating UI and sending reports, but keep updating tracked buffs and haste effects
      reports_paused = true
    elseif S{'unpause', 'play', 'resume', 'continue', 'start', 'on', 'enable'}:contains(cmd) then
      -- Continue updating UI and sending reports
      reports_paused = false
    elseif 'test' == cmd then
    elseif 'debug' == cmd then
      DEBUG_MODE = not DEBUG_MODE
      log('Toggled Debug Mode to: '..tostring(DEBUG_MODE))
    elseif 'help' == cmd then
      local chat_purple = string.char(0x1F, 200)
      local chat_grey = string.char(0x1F, 160)
      local chat_red = string.char(0x1F, 167)
      local chat_white = string.char(0x1F, 001)
      local chat_green = string.char(0x1F, 214)
      local chat_yellow = string.char(0x1F, 036)
      local chat_d_blue = string.char(0x1F, 207)
      local chat_pink = string.char(0x1E, 5)
      local chat_l_blue = string.char(0x1E, 6)
      
      windower.add_to_chat(6, ' ')
      windower.add_to_chat(6, chat_d_blue.. 'HasteInfo Commands available:' )
      windower.add_to_chat(6, chat_l_blue..	'\'\/\/hi r\'' .. chat_white .. ': Reload HasteInfo addon')
      windower.add_to_chat(6, chat_l_blue..	'\'\/\/hi vis \'' .. chat_white .. ': Toggle UI visibility')
      windower.add_to_chat(6, chat_l_blue..	'\'\/\/hi show \'' .. chat_white .. ': Show UI')
      windower.add_to_chat(6, chat_l_blue..	'\'\/\/hi hide \'' .. chat_white .. ': Hide UI')
      windower.add_to_chat(6, chat_l_blue..	'\'\/\/hi resetpos \'' .. chat_white .. ': Reset position of UI to default')
      windower.add_to_chat(6, chat_l_blue..	'\'\/\/hi party \'' .. chat_white .. ': Toggle party details in UI')
      windower.add_to_chat(6, chat_l_blue..	'\'\/\/hi details \'' .. chat_white .. ': Toggle your own haste details in UI (takes optional subcommands')
			windower.add_to_chat(6, chat_l_blue..	'         fraction' .. chat_white .. 'Enables display of haste values in fractions')
			windower.add_to_chat(6, chat_l_blue..	'         percent' .. chat_white .. 'Enables display of haste values in percentages')
      windower.add_to_chat(6, chat_l_blue..	'\'\/\/hi pause \'' .. chat_white .. ': Pause haste reports (but continues processing)')
      windower.add_to_chat(6, chat_l_blue..	'\'\/\/hi play \'' .. chat_white .. ': Unpause haste reports (but continues processing)')
      windower.add_to_chat(6, chat_l_blue..	'\'\/\/hi debug \'' .. chat_white .. ': Toggle debug mode')
      windower.add_to_chat(6, chat_l_blue..	'\'\/\/hi help \'' .. chat_white .. ': Display this help menu again')
    else
      windower.send_command('hi help')
    end
  else
    windower.send_command('hi help')
  end
end)
