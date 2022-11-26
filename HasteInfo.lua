-- Version 2022.NOV.26.001
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

local hasteinfo = {} -- Initialize library namespace

-------------------------------------------------------------------------------
-- Includes/imports
-------------------------------------------------------------------------------
local res = include('resources')
local packets = include('packets')
include('logger')


-------------------------------------------------------------------------------
-- Constants and maps
-------------------------------------------------------------------------------

-- Fraction caps are all numerators. The denominator for each is 1024.
hasteinfo.caps = {
  ['total'] = {
    ['percent'] = 80,
    ['fraction'] = 820
  },
  ['ma'] = {
    ['percent'] = 43.75,
    ['fraction'] = 448
  },
  ['ja'] = {
    ['percent'] = 25,
    ['fraction'] = 256
  },
  ['eq'] = {
    ['percent'] = 25,
    ['fraction'] = 256
  },
}
-- Haste potencies are all the numerator portion of a fraction whose denominator is 1024.
-- Ex. If Geo-Haste is 306, that means it's 306/1024, or ~29.9%.
hasteinfo.haste_triggers = T{
  ['Magic'] = {
    [  0] = {triggering_action='Unknown', triggering_id=0, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', potency_base=150},
    [ 57] = {triggering_action='Haste', triggering_id=57, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', potency_base=150},
    [511] = {triggering_action='Haste II', triggering_id=511, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', potency_base=307},
    [478] = {triggering_action='Embrava', triggering_id=478, buff_name='Embrava', buff_id=228, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', potency_base=266},
    [771] = {triggering_action='Indi-Haste', triggering_id=771, buff_name='Haste', buff_id=580, haste_category='ma', trigger_category='Magic', trigger_sub_category='Geomancy', potency_base=307, potency_per_geomancy=11},
    [801] = {triggering_action='Geo-Haste', triggering_id=801, buff_name='Haste', buff_id=580, haste_category='ma', trigger_category='Magic', trigger_sub_category='Geomancy', potency_base=307, potency_per_geomancy=11},
    [417] = {triggering_action='Honor March', triggering_id=417, buff_name='March', buff_id=214, haste_category='ma', trigger_category='Magic', trigger_sub_category='BardSong', potency_base=126, potency_per_song_point=12},
    [420] = {triggering_action='Victory March', triggering_id=420, buff_name='March', buff_id=214, haste_category='ma', trigger_category='Magic', trigger_sub_category='BardSong', potency_base=163, potency_per_song_point=16},
    [419] = {triggering_action='Advancing March', triggering_id=419, buff_name='March', buff_id=214, haste_category='ma', trigger_category='Magic', trigger_sub_category='BardSong', potency_base=108, potency_per_song_point=11},
    [530] = {triggering_action='Refueling', triggering_id=530, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', potency_base=102}, -- Exact potency unknown
    [710] = {triggering_action='Erratic Flutter', triggering_id=710, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', potency_base=307},
    [661] = {triggering_action='Animating Wail', triggering_id=661, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', potency_base=150}, -- Exact potency unknown
    [750] = {triggering_action='Mighty Guard', triggering_id=750, buff_name='Mighty Guard', buff_id=604, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', potency_base=150}, -- Exact potency unknown
  },
  ['Job Ability'] = {
    [  0] = {triggering_action='Unknown', triggering_id=0, buff_name='Haste', buff_id=33, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='Unknown', potency_base=150},
    [595] = {triggering_action='Hastega', triggering_id=595, buff_name='Haste', buff_id=33, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='BloodPactWard', potency_base=153},
    [602] = {triggering_action='Hastega II', triggering_id=602, buff_name='Haste', buff_id=33, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='BloodPactWard', potency_base=307}, -- Exact potency unknown
    [173] = {triggering_action='Hasso', triggering_id=173, buff_name='Hasso', buff_id=353, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='', potency_base=103}, -- Exact potency unknown
    [80] = {triggering_action='Spirit Link', triggering_id=80, buff_name='N/A', buff_id=0, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='', potency_base=0, potency_per_merit=21}, -- Exact potency unknown
    [51] = {triggering_action='Last Resort', triggering_id=51, buff_name='Last Resort', buff_id=64, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='', potency_base=150, potency_per_merit=21}, -- Exact potency unknown
  },
  ['Weapon Skill'] = {
    [105] = {triggering_action='Catastrophe', triggering_id=105, buff_name='Aftermath', buff_id=273, haste_category='ja', trigger_category='Weapon Skill', trigger_sub_category='Scythe', potency_base=102}, -- Exact potency unknown
  },
  ['Other'] = {
    [  0] = {triggering_action='Unknown', triggering_id=0, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Unknown', trigger_sub_category='Unknown', potency_base=150},
    [  1] = {triggering_action='Haste Samba', triggering_id=0, buff_name='Haste Samba', buff_id=0, haste_category='ja', trigger_category='MeleeAction', trigger_sub_category='SpikeEffect', potency_base=51, potency_per_merit=10, add_effect_anmiation=23}, -- Haste Samba additional effect
  }
}

-- buff ID 612 = Colure Active; shows up right before the new geo buff shows up
-- buff ID 684 = Entrust; JA action 386
hasteinfo.haste_buff_ids = S{33, 64, 214, 228, 273, 353, 580, 604, 612, 684}
hasteinfo.slow_debuff_ids = S{13, 565}


-------------------------------------------------------------------------------
-- Flags to enable/disable features and store user settings, initial values on first load
-------------------------------------------------------------------------------

hasteinfo.show_ui = false


-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function hasteinfo.init()
  -- Instatiated variables for storing values and states
  -- Stats includes total haste, and haste by category. 'Actual' is the real amount of
  -- haste, and 'uncapped' is the full amount that all buffs would add up to if there was
  -- no cap.
  hasteinfo.stats = T{
    ['haste_ma'] = {
      ['actual'] = {
        ['percent'] = 0,
        ['fraction'] = 0
      },
      ['uncapped'] = {
        ['percent'] = 0,
        ['fraction'] = 0
      },
    },
    ['haste_ja'] = {
      ['actual'] = {
        ['percent'] = 0,
        ['fraction'] = 0
      },
      ['uncapped'] = {
        ['percent'] = 0,
        ['fraction'] = 0
      },
    },
    ['haste_eq'] = {
      ['actual'] = {
        ['percent'] = 25,
        ['fraction'] = 256
      },
      ['uncapped'] = {
        ['percent'] = 256,
        ['fraction'] = 256
      },
    },
    ['haste_total'] = {
      ['actual'] = {
        ['percent'] = 25,
        ['fraction'] = 256
      },
      ['uncapped'] = {
        ['percent'] = 25,
        ['fraction'] = 256
      },
    },
    ['dual_wield'] = {
      ['total_needed'] = 74,  -- Ignores all sources of dual wield already possessed
      ['traits'] = 0, -- DW possessed from traits
      ['buffs'] = 0, -- DW increased from buffs
      ['actual_needed'] = 74, -- DW needed after traits and buffs accounted for
    }
  }

  hasteinfo.players = T{-- Track jobs and relevant buffs of party members
    -- [123456] = {id=123456, name='Joe', main='GEO', main_lv=99, sub='RDM', sub_lv=99, indi_owned=580, geo_owned=0, samba_start=6871687, haste_effects={}, buffs={}}
  }

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
      hasteinfo.get_member(actor_id, member.name)
    end
  end
end


-------------------------------------------------------------------------------
-- Feature-enabling functions
-------------------------------------------------------------------------------

function hasteinfo.show_ui()
  hasteinfo.show_ui = true
end


-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

function hasteinfo.add_member(id, name)
  if not id then
    -- IDs must still remain unique. Iterate backwards from 0 until an unused index is found
    for i=-1,-5,-1 do
      if not hasteinfo.players[i] then
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
  local init_buffs = {}
  for i=1, 32 do
    init_buffs[i] = 255
  end
  local new_member = {id=id, name=name, main='', sub='', indi_owned=0, geo_owned=0, haste_effects={}, buffs=init_buffs}
  hasteinfo.players[id] = new_member
  return hasteinfo.players[id]
end

function hasteinfo.get_member(id, name, dontCreate)
  local foundMember = hasteinfo.players[id]
  if foundMember then
    if name and foundMember.name ~= name then
      foundMember.name = name
    end
    return foundMember
  else
    local foundByName = hasteinfo.players:with('name', name)
    if foundByName then -- try to match by name if no ID match
      -- This situation may happen when resummoning trusts or if member was out of zone when first detected
      -- If name matches, keep the higher ID
      local found_id = foundByName.id
      if id > found_id then
        hasteinfo.players[id] = table.copy(foundByName)
        hasteinfo.players[id].id = id
        hasteinfo.players[found_id] = nil
        return hasteinfo.players[id]
      else
        return foundByName
      end
    elseif not dontCreate then
      return hasteinfo.add_member(id, name)
    end
  end
end

-- Packet should already be parsed
function hasteinfo.update_job_from_packet(member, packet)
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

function hasteinfo.parse_action(act, type)
  -- windower.add_to_chat(001, type..' action:')
  -- table.vprint(act)
end

function hasteinfo.parse_buffs(data)
  for k = 0, 4 do
    local actor_id = data:unpack('I', k*48+5)
    
    if actor_id ~= 0 then
      local member = hasteinfo.get_member(actor_id) or hasteinfo.add_member(actor_id)
      member.buffs = {}
      for i = 1, 32 do
        local buff = data:byte(k*48+5+16+i-1) + 256*( math.floor( data:byte(k*48+5+8+ math.floor((i-1)/4)) / 4^((i-1)%4) )%4) -- Credit: Byrth, GearSwap
        member.buffs[i] = buff
      end
    end
  end
  -- At this point we should have all party members with IDs in the table. If there were previous entries with placeholder IDs, dump them. They will never reconcile.
  for member in hasteinfo.players:it() do
    if member.id < 0 then
      hasteinfo[member.id] = nil
    end
  end
  -- windower.add_to_chat(001, 'Buffs:')
  -- table.vprint(hasteinfo.players)
end


-------------------------------------------------------------------------------
-- Event hooks
-------------------------------------------------------------------------------

-- Hook into job/subjob change event (happens BEFORE job starts changing)
windower.raw_register_event('outgoing chunk', function(id, data, modified, injected, blocked)
  if id == 0x100 then -- Sending job change command to server
    -- Re-init settings if changing jobs
    local newmain = data:byte(5)
    local newsub = data:byte(6)

    hasteinfo.init()
    -- Update DW stats
  end
end)

windower.raw_register_event('incoming chunk', function(id, data, modified, injected, blocked)
  if id == 0x076 then -- Party buffs update; does not include buffs on self
    hasteinfo.parse_buffs(data)
  elseif id == 0xDF then -- char update
    local packet = packets.parse('incoming', data)
    if packet then
      local playerId = packet['ID']
      if playerId and playerId > 0 then
        -- print('PACKET: Char update for player ID: '..playerId)
        local member = hasteinfo.get_member(playerId, nil)
        hasteinfo.update_job_from_packet(member, packet)
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
        local member = hasteinfo.get_member(playerId, name)
        hasteinfo.update_job_from_packet(member, packet)
      else
        print('Party update: name and/or ID not found.')
      end
    end
  end
end)

windower.raw_register_event('action', function(act)
  -- Melee attack; Only care about own attacks' additional effect (check for haste samba)
  if act.category == 1 and player.id == act.actor_id and act.targets[1].actions[1].add_effect_animation == 23 then
    hasteinfo.parse_action(act, 'haste samba melee')
  elseif act.category == 6 then -- JA; Only care about JA on self, except Entrust
    if act.actor_id == player.id and hasteinfo.haste_triggers['Job Ability'][act.param] then
      hasteinfo.parse_action(act, 'self ja')
    elseif act.param == 386 then -- Entrust activation
      hasteinfo.parse_action(act, 'entrust activation')
    end
  elseif act.category == 4 and hasteinfo.haste_triggers['Magic'][act.param]
      and hasteinfo.players[act.targets[1].id] then -- Spell finish casting on party member target
  -- elseif act.category == 4 then -- Spell finish casting on party member target
    hasteinfo.parse_action(act, 'spell')
  elseif act.category == 3 and hasteinfo.haste_triggers['Weapon Skill'][act.param] then -- Finish WS, only care about Catastrophe
    hasteinfo.parse_action(act, 'catastrophe')
  elseif act.category == 13 and hasteinfo.haste_triggers['Job Ability'][act.param] then -- Pet uses ability
    hasteinfo.parse_action(act, 'pet')
  end
end)

windower.raw_register_event('zone change', function(new_zone, old_zone)
  -- Update buffs after zoning
end)

hasteinfo.init()

return hasteinfo