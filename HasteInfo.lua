-- Version 2022.NOV.28.001
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
    [ 57] = {triggering_action='Haste', triggering_id=57, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', persists_thru_zoning=false, potency_base=150},
    [511] = {triggering_action='Haste II', triggering_id=511, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', persists_thru_zoning=false, potency_base=307},
    [478] = {triggering_action='Embrava', triggering_id=478, buff_name='Embrava', buff_id=228, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', persists_thru_zoning=false, potency_base=266},
    [771] = {triggering_action='Indi-Haste', triggering_id=771, buff_name='Haste', buff_id=580, haste_category='ma', trigger_category='Magic', trigger_sub_category='Geomancy', persists_thru_zoning=false, potency_base=307, potency_per_geomancy=12},
    [801] = {triggering_action='Geo-Haste', triggering_id=801, buff_name='Haste', buff_id=580, haste_category='ma', trigger_category='Magic', trigger_sub_category='Geomancy', persists_thru_zoning=false, potency_base=307, potency_per_geomancy=12},
    [417] = {triggering_action='Honor March', triggering_id=417, buff_name='March', buff_id=214, haste_category='ma', trigger_category='Magic', trigger_sub_category='BardSong', persists_thru_zoning=false, potency_base=126, potency_per_song_point=12, song_cap=4},
    [420] = {triggering_action='Victory March', triggering_id=420, buff_name='March', buff_id=214, haste_category='ma', trigger_category='Magic', trigger_sub_category='BardSong', persists_thru_zoning=false, potency_base=163, potency_per_song_point=16, song_cap=8},
    [419] = {triggering_action='Advancing March', triggering_id=419, buff_name='March', buff_id=214, haste_category='ma', trigger_category='Magic', trigger_sub_category='BardSong', persists_thru_zoning=false, potency_base=108, potency_per_song_point=11, song_cap=8},
    [530] = {triggering_action='Refueling', triggering_id=530, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', persists_thru_zoning=false, potency_base=102}, -- Exact potency unknown
    [710] = {triggering_action='Erratic Flutter', triggering_id=710, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', persists_thru_zoning=false, potency_base=307},
    [661] = {triggering_action='Animating Wail', triggering_id=661, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', persists_thru_zoning=false, potency_base=150}, -- Exact potency unknown
    [750] = {triggering_action='Mighty Guard', triggering_id=750, buff_name='Mighty Guard', buff_id=604, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', persists_thru_zoning=false, potency_base=150}, -- Exact potency unknown
  },
  ['Job Ability'] = {
    [595] = {triggering_action='Hastega', triggering_id=595, buff_name='Haste', buff_id=33, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='BloodPactWard', persists_thru_zoning=false, potency_base=153},
    [602] = {triggering_action='Hastega II', triggering_id=602, buff_name='Haste', buff_id=33, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='BloodPactWard', persists_thru_zoning=false, potency_base=307}, -- Exact potency unknown
    [173] = {triggering_action='Hasso', triggering_id=173, buff_name='Hasso', buff_id=353, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='', persists_thru_zoning=false, potency_base=103}, -- Exact potency unknown
    [80] = {triggering_action='Spirit Link', triggering_id=80, buff_name='N/A', buff_id=0, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='', persists_thru_zoning=false, potency_base=0, potency_per_merit=21, merit_name='empathy'}, -- Exact potency unknown
    [51] = {triggering_action='Last Resort', triggering_id=51, buff_name='Last Resort', buff_id=64, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='', persists_thru_zoning=false, potency_base=150, potency_per_merit=21, merit_name='desperate_blows'}, -- Exact potency unknown
  },
  ['Weapon Skill'] = {
    [105] = {triggering_action='Catastrophe', triggering_id=105, buff_name='Aftermath', buff_id=273, haste_category='ja', trigger_category='Weapon Skill', trigger_sub_category='Scythe', persists_thru_zoning=false, potency_base=102}, -- Exact potency unknown
  },
  ['Melee'] = {
    [  1] = {triggering_action='Additional Effect Melee', triggering_id=0, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Melee', trigger_sub_category='', persists_thru_zoning=false, potency_base=150},
  },
  ['Other'] = {
    [  0] = {triggering_action='Unknown', triggering_id=0, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Unknown', trigger_sub_category='Unknown', persists_thru_zoning=false, potency_base=150},
  }
}
hasteinfo.trusts = L{
	-- tanks
	{ name = 'Amchuchu', job = 'RUN', subJob = 'WAR' },
	{ name = 'ArkEV', job = 'PLD', subJob = 'WHM' },
	{ name = 'ArkHM', job = 'WAR', subJob = 'NIN' },
	{ name = 'August', job = 'PLD', subJob = 'WAR' },
	{ name = 'Curilla', job = 'PLD' },
	{ name = 'Gessho', job = 'NIN', subJob = 'WAR' },
	{ name = 'Mnejing', job = 'PLD', subJob = 'WAR' },
	{ name = 'Rahal', job = 'PLD', subJob = 'WAR' },
	{ name = 'Rughadjeen', job = 'PLD' },
	{ name = 'Trion', job = 'PLD', subJob = 'WAR' },
	{ name = 'Valaineral', job = 'PLD', subJob = 'WAR' },
	-- melee
	{ name = 'Abenzio', job = 'THF', subJob = 'WAR' },
	{ name = 'Abquhbah', job = 'WAR' },
	{ name = 'Aldo', job = 'THF', model = 3034 },
	{ name = 'Areuhat', job = 'WAR' },
	{ name = 'ArkGK', job = 'SAM', subJob = 'DRG' },
	{ name = 'ArkMR', job = 'BST', subJob = 'THF' },
	{ name = 'Ayame', job = 'SAM', model = 3004 },
	{ name = 'BabbanMheillea', job = 'MNK' },
	{ name = 'Balamor', job = 'DRK' },
	{ name = 'Chacharoon', job = 'THF' },
	{ name = 'Cid', job = 'WAR' },
	{ name = 'Darrcuiln', job = 'SPC' }, -- special / beast
	{ name = 'Excenmille', job = 'PLD', model = 3003 },
	{ name = 'Excenmille', job = 'SPC' }, -- Excenmille (S), special
	{ name = 'Fablinix', job = 'RDM', subJob = 'BLM' },
	{ name = 'Gilgamesh', job = 'SAM' },
	{ name = 'Halver', job = 'PLD', subJob = 'WAR' },
	{ name = 'Ingrid', job = 'WAR', subJob = 'WHM', model = 3102 }, -- Ingrid II
	{ name = 'Iroha', job = 'SAM', model = 3111 },
	{ name = 'Iroha', job = 'SAM', subJob = 'WHM', model = 3112 }, -- Iroha II
	{ name = 'IronEater', job = 'WAR' },
	{ name = 'Klara', job = 'WAR' },
	{ name = 'LehkoHabhoka', job = 'THF', subJob = 'BLM' },
	{ name = 'LheLhangavo', job = 'MNK' },
	{ name = 'LhuMhakaracca', job = 'BST', subJob = 'WAR' },
	{ name = 'Lilisette', job = 'DNC', model = 3049 },
	{ name = 'Lilisette', job = 'DNC', model = 3084 }, -- Lilisette II
	{ name = 'Lion', job = 'THF', model = 3011 },
	{ name = 'Lion', job = 'THF', subJob = 'NIN', model = 3081 }, -- Lion II
	{ name = 'Luzaf', job = 'COR', subJob = 'NIN' },
	{ name = 'Maat', job = 'MNK', model = 3037 },
	{ name = 'Maximilian', job = 'WAR', subJob = 'THF' },
	{ name = 'Mayakov', job = 'DNC' },
	{ name = 'Mildaurion', job = 'PLD', subJob = 'WAR' },
	{ name = 'Morimar', job = 'BST' },
	{ name = 'Mumor', job = 'DNC', subJob = 'WAR', model = 3050 },
	{ name = 'NajaSalaheem', job = 'MNK', subJob = 'WAR', model = 3016 },
	{ name = 'Naji', job = 'WAR' },
	{ name = 'NanaaMihgo', job = 'THF' },
	{ name = 'Nashmeira', job = 'PUP', subJob = 'WHM', model = 3027 },
	{ name = 'Noillurie', job = 'SAM', subJob = 'PLD' },
	{ name = 'Prishe', job = 'MNK', subJob = 'WHM', model = 3017 },
	{ name = 'Prishe', job = 'MNK', subJob = 'WHM', model = 3082 }, -- Prishe II
	{ name = 'Rainemard', job = 'RDM' },
	{ name = 'RomaaMihgo', job = 'THF' },
	{ name = 'Rongelouts', job = 'WAR' },
	{ name = 'Selh\'teus', job = 'SPC' }, -- special
	{ name = 'ShikareeZ', job = 'DRG', subJob = 'WHM' },
	{ name = 'Tenzen', job = 'SAM', model = 3012 },
	{ name = 'Teodor', job = 'SAM', subJob = 'BLM' },
	{ name = 'UkaTotlihn', job = 'DNC', subJob = 'WAR' },
	{ name = 'Volker', job = 'WAR' },
	{ name = 'Zazarg', job = 'MNK' },
	{ name = 'Zeid', job = 'DRK', model = 3010 },
	{ name = 'Zeid', job = 'DRK', model = 3086 }, -- Zeid II
	{ name = 'Matsui-P', job = 'NIN', subJob = 'BLM' },
	-- ranged
	{ name = 'Elivira', job = 'RNG', subJob = 'WAR' },
	{ name = 'Makki-Chebukki', job = 'RNG' },
	{ name = 'Margret', job = 'RNG' },
	{ name = 'Najelith', job = 'RNG' },
	{ name = 'SemihLafihna', job = 'RNG' },
	{ name = 'Tenzen', job = 'RNG', model = 3097 }, -- Tenzen II
	-- caster
	{ name = 'Adelheid', job = 'SCH' },
	{ name = 'Ajido-Marujido', job = 'BLM', subJob = 'RDM' },
	{ name = 'ArkTT', job = 'BLM', subJob = 'DRK' },
	{ name = 'D.Shantotto', job = 'BLM' },
	{ name = 'Gadalar', job = 'BLM' },
	{ name = 'Ingrid', job = 'WHM', model = 3025 },
	{ name = 'Kayeel-Payeel', job = 'BLM' },
	{ name = 'Kukki-Chebukki', job = 'BLM' },
	{ name = 'Leonoyne', job = 'BLM' },
	{ name = 'Mumor', job = 'BLM', model = 3104 }, -- Mumor II
	{ name = 'Ovjang', job = 'RDM', subJob = 'WHM' },
	{ name = 'Robel-Akbel', job = 'BLM' },
	{ name = 'Rosulatia', job = 'BLM' },
	{ name = 'Shantotto', job = 'BLM', model = 3000 },
	{ name = 'Shantotto', job = 'BLM', model = 3110 }, -- Shantotto II
	{ name = 'Ullegore', job = 'BLM' },
	-- healer
	{ name = 'Cherukiki', job = 'WHM' },
	{ name = 'FerreousCoffin', job = 'WHM', subJob = 'WAR' },
	{ name = 'Karaha-Baruha', job = 'WHM', subJob = 'SMN' },
	{ name = 'Kupipi', job = 'WHM' },
	{ name = 'MihliAliapoh', job = 'WHM' },
	{ name = 'Monberaux', job = 'SPC' }, -- special / chemist
	{ name = 'Nashmeira', job = 'WHM', model = 3083 }, -- Nashmeira II
	{ name = 'Ygnas', job = 'WHM' },
	-- support
	{ name = 'Arciela', job = 'RDM', model = 3074 },
	{ name = 'Arciela', job = 'RDM', model = 3085 }, -- Arciela II
	{ name = 'Joachim', job = 'BRD', subJob = 'WHM' },
	{ name = 'KingOfHearts', job = 'RDM', subJob = 'WHM' },
	{ name = 'Koru-Moru', job = 'RDM' },
	{ name = 'Qultada', job = 'COR' },
	{ name = 'Ulmia', job = 'BRD' },
	-- special
	{ name = 'Brygid', job = 'GEO' },
	{ name = 'Cornelia', job = 'GEO' },
	{ name = 'Kupofried', job = 'GEO' },
	{ name = 'KuyinHathdenna', job = 'GEO' },
	{ name = 'Moogle', job = 'GEO' },
	{ name = 'Sakura', job = 'GEO' },
	{ name = 'StarSibyl', job = 'GEO' },
	-- unity
	{ name = 'Aldo', job = 'THF' },
	{ name = 'Apururu', job = 'WHM', subJob = 'RDM', model = 3061 },
	{ name = 'Ayame', job = 'SAM', },
	{ name = 'Flaviria', job = 'DRG', subJob = 'WAR' },
	{ name = 'InvincibleShield', job = 'WAR', subJob = 'MNK' }, 
	{ name = 'JakohWahcondalo', job = 'THF', subJob = 'WAR' },
	{ name = 'Maat', job = 'MNK', subJob = 'WAR' },
	{ name = 'NajaSalaheem', job = 'THF', subJob = 'WAR' },
	{ name = 'Pieuje', job = 'WHM' },
	{ name = 'Sylvie', job = 'GEO', subJob = 'WHM' },
	{ name = 'Yoran-Oran', job = 'WHM' },
}

-- Haste Samba does not have an actual buff or triggering action but here's the relevant info:
-- Upon melee action, action packet is sent and if the add_effect_animation == 23, you have haste samba benefit
-- Counts as Job Ability haste. Base potency=51, potency increases by 10/1024
-- Merit ID is 1538
hasteinfo.samba_stats = {potency_base=51, potency_per_merit=10, merit_id=1538, merit_name='haste_samba_effect', animation_id=23}

-- buff ID 612 = Colure Active; shows up right before the new geo buff shows up
-- buff ID 684 = Entrust; JA action 386
hasteinfo.haste_buff_ids = S{33, 64, 214, 228, 273, 353, 580, 604}
hasteinfo.slow_debuff_ids = S{13, 194, 565}
hasteinfo.SAMBA_DURATION = 9 -- Assume samba lasts 9 seconds on players after hitting a mob inflicted with Samba Daze
hasteinfo.ACTION_TYPE = T{
  ['SELF_MELEE'] = 'Self Melee',
  ['SELF_HASTE_JA'] = 'Self Haste JA',
  ['ENTRUST_ACTIVATION'] = 'Entrust Activation',
  ['SPELL'] = 'Spell',
  ['BARD_SONG'] = 'Bard Song',
  ['GEOMANCY'] = 'Geomancy',
  ['SELF_CATASTROPHE'] = 'Self Catastrophe',
  ['PET'] = 'Pet',
}


-------------------------------------------------------------------------------
-- Flags to enable/disable features and store user settings, initial values on first load
-------------------------------------------------------------------------------

hasteinfo.show_ui = false


-------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------

function hasteinfo.init()
  -- Instantiated variables for storing values and states
  -- Offset of system clock vs server clock, to be determined by packets received from the server
  hasteinfo.clock_offset = 0

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

  hasteinfo.players = T{ -- Track jobs and relevant buffs of party members
    --[[
    [id] = {id=num, name=str, main=str, main_lv=num, sub=str, sub_lv=num, songs=list, samba=table, haste_effects=table, buffs=set}
    songs = L{
      {triggering_action=str, triggering_id=num, buff_name=str, buff_id=num, haste_category=ma, potency=num, expiration=num}
    }
    samba = {
      expiration=num, -- seconds since last samba effect detected; has decimals that can track to 1/100 of a second
      potency=num,
    }
    haste_effects = {
      [buff_id] = {triggering_action=str, triggering_id=num, buff_name=str, buff_id=num, haste_category=ma|ja, potency=num}
    }
    buffs = {num, num, num, num}

    Ex:
    [123456] = {id=123456, name='Joe', main='GEO', main_lv=99, sub='RDM', sub_lv=99, samba={expiration=12345, potency=51}, haste_effects=T{}, buffs=S{}}
    ]]
  }
  
  -- Track Indi- actions performed on party members
  -- Items are added when an Indi- spell is casted
  -- Items are removed when a Colure Active buff disappears from a party member
  hasteinfo.indi_active = T{
    -- same as haste effects + some fields
    -- [target_id] = {triggering_action=str, triggering_id=num, buff_name=str, buff_id=num, haste_category=ma, potency=num, caster_id=num, target_id=num}
  }
  -- Track Geo- actions performed on party members
  -- Items are added when a Geo- spell is casted
  -- Items are removed when caster casts a new Geo- spell
  hasteinfo.geo_active = T{
    -- same as haste effects + some fields
    -- [caster_id] = {triggering_action=str, triggering_id=num, buff_name=str, buff_id=num, haste_category=ma, potency=num, caster_id=num}
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
  local new_member = {id=id, name=name, main='', main_lv=0, sub='', sub_lv=0, samba={}, haste_effects=T{}, buffs=S{}}
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
  local me = hasteinfo.get_member(player.id, player.name)

  if type == hasteinfo.ACTION_TYPE.SELF_MELEE then
    -- Check for haste samba animation
    local is_samba_active = act.targets[1].actions[1].add_effect_animation == 23
    hasteinfo.update_samba(me, is_samba_active)
  elseif type == hasteinfo.ACTION_TYPE.SELF_HASTE_JA then
    if not hasteinfo.haste_triggers['Job Ability'][act.param] then return end
    local haste_effect = table.copy(hasteinfo.haste_triggers['Job Ability'][act.param])

    local me_target = table.with(act.targets, 'id', me.id)
    if not me_target then return end
    -- Check if it has any effect
    if table.find(me_target.actions, function(a) return a.param ~= 0 end) then
      -- Set potency
      haste_effect.potency = haste_effect.potency_base
      if haste_effect.potency_per_merit then
        haste_effect.potency = haste_effect.potency + (haste_effect.potency_per_merit * player.merits[haste_effect.merit_name])
      end
      hasteinfo.add_haste_effect(me, haste_effect)
    end
  elseif type == hasteinfo.ACTION_TYPE.ENTRUST_ACTIVATION then
  elseif type == hasteinfo.ACTION_TYPE.BARD_SONG then
    if not hasteinfo.haste_triggers['Magic'][act.param] then return end
    local haste_effect = table.copy(hasteinfo.haste_triggers['Magic'][act.param])
    
    local caster = hasteinfo.get_member(act.actor_id)

    for i,target in ipairs(act.targets) do
      local target_member = hasteinfo.get_member(target.id)
      for i,a in ipairs(target.actions) do
        local buff_id = a.param
        -- If buff doesn't match a buff that we're interested in, ignore
        if hasteinfo.haste_buff_ids:contains(buff_id) or hasteinfo.slow_debuff_ids:contains(buff_id) then
          -- Determine potency
          haste_effect.potency = haste_effect.potency_base

          -- Add song gear bonuses
          local song_bonus = 0
          if caster then -- caster is in party
            -- Check for trusts
            if hasteinfo.trusts:with('name', caster.name) then
              song_bonus = 0
            else -- not a trust
              if caster.main == 'BRD' then
                song_bonus = haste_effect.song_cap
              else -- subjob brd
                song_bonus = 0
              end
            end
          else -- caster is not in your party, must make assumptions about song potency
            song_bonus = haste_effect.song_cap
          end
          haste_effect.potency = haste_effect.potency + (haste_effect.potency_per_song_point * song_bonus)
            
          hasteinfo.add_haste_effect(target_member, haste_effect)
        end
      end
    end
  elseif type == hasteinfo.ACTION_TYPE.GEOMANCY then
    if not hasteinfo.haste_triggers['Magic'][act.param] then return end
    local haste_effect = table.copy(hasteinfo.haste_triggers['Magic'][act.param])
    
    local caster = hasteinfo.get_member(act.actor_id)

    for i,target in ipairs(act.targets) do
      local target_member = hasteinfo.get_member(target.id)
      for i,a in ipairs(target.actions) do
        local buff_id = a.param
        -- If buff doesn't match a buff that we're interested in, ignore
        -- Have to allow 0 value because for some reason geomancy spells come in as buff_id 0 on the action packet
        if buff_id == 0 or hasteinfo.haste_buff_ids:contains(buff_id) or hasteinfo.slow_debuff_ids:contains(buff_id) then
          -- Determine potency
          haste_effect.potency = haste_effect.potency_base

          -- Add geomancy gear bonus
          local geomancy = 0
          -- Check for trusts
          if hasteinfo.trusts:with('name', caster.name) then
            geomancy = 0
          else -- not a trust
            geomancy = 10 -- assume idris; TODO: Enhance this with a whitelist/blacklist
          end
          haste_effect.potency = haste_effect.potency + (haste_effect.potency_per_geomancy * geomancy)
          -- Also, add to the indi- or geo- table
          if haste_effect.triggering_action:startswith('Indi-') then
            haste_effect.caster_id = caster.id
            haste_effect.target_id = target_member.id
            hasteinfo.indi_active[target_member.id] = haste_effect
          elseif haste_effect.triggering_action:startswith('Geo-') then
            haste_effect.caster_id = caster.id
            hasteinfo.geo_active[caster.id] = haste_effect
          end

          hasteinfo.add_haste_effect(target_member, haste_effect)
        end
      end
    end
  elseif type == hasteinfo.ACTION_TYPE.SPELL then
    if not hasteinfo.haste_triggers['Magic'][act.param] then return end
    local haste_effect = table.copy(hasteinfo.haste_triggers['Magic'][act.param])
    
    local caster = hasteinfo.get_member(act.actor_id)

    for i,target in ipairs(act.targets) do
      local target_member = hasteinfo.get_member(target.id)
      for i,a in ipairs(target.actions) do
        local buff_id = a.param
        -- If buff doesn't match a buff that we're interested in, ignore
        -- Have to allow 0 value because for some reason geomancy spells come in as buff_id 0 on the action packet
        if hasteinfo.haste_buff_ids:contains(buff_id) or hasteinfo.slow_debuff_ids:contains(buff_id) then
          -- Determine potency
          haste_effect.potency = haste_effect.potency_base
          hasteinfo.add_haste_effect(target_member, haste_effect)
        end
      end
    end
  elseif type == hasteinfo.ACTION_TYPE.SELF_CATASTROPHE then
    -- If player has proper weapon equipped, grant 10% JA haste effect

  elseif type == hasteinfo.ACTION_TYPE.PET then
    -- if targets[num].actions[num].param == buff_id, ability had no effect on that target if buff_id == 0
  end
end

function hasteinfo.parse_buffs(data)
  for k = 0, 4 do
    local actor_id = data:unpack('I', k*48+5)
    
    if actor_id ~= 0 then
      local member = hasteinfo.get_member(actor_id) or hasteinfo.add_member(actor_id)
      local old_buffs = member.buffs:copy()
      member.buffs = S{}
      for i = 1, 32 do
        local buff_id = data:byte(k*48+5+16+i-1) + 256*( math.floor( data:byte(k*48+5+8+ math.floor((i-1)/4)) / 4^((i-1)%4) )%4) -- Credit: Byrth, GearSwap
        if buff_id ~= 255 then
          hasteinfo.add_buff(member, buff_id)
        end
      end
      -- Find lost buffs and remove corresponding haste effect
      hasteinfo.resolve_lost_buffs(member, old_buffs)
    end
  end
  -- At this point we should have all party members with IDs in the table. If there were previous entries with placeholder IDs, dump them. They will never reconcile.
  for member in hasteinfo.players:it() do
    if member.id < 0 then
      hasteinfo[member.id] = nil
    end
  end
end

function hasteinfo.is_samba_expired(member)
  local is_expired = false

  if member.samba and member.samba.expiration then
    is_expired = member.samba.expiration >= os.clock()
    if is_expired then
      member.samba = {}
    end
  end
  
  return is_expired
end

function hasteinfo.add_buff(member, buff_id)
  if not member or not buff_id or buff_id == 255 then return end

  -- Check if buff is currently being tracked. If not, add it and check for corresponding action to link it to
  if member.buffs and not member.buffs:contains(buff_id) then
    member.buffs:add(buff_id)
    -- Check if it's a haste-related buff
    local is_haste_buff = hasteinfo.haste_buff_ids:contains(buff_id) or hasteinfo.slow_debuff_ids:contains(buff_id)
    -- Add corresponding haste effect if possible
    if is_haste_buff and not member.haste_effects[buff_id] then
      local new_haste_effect
      -- TODO: Remove after finished debugging. Just curious how often this happens.
      print('Received haste buff '..buff_id..' while missing corresponding "haste_effect".')
      -- If we can't find a corresponding haste effect, check geo lists; that's the only haste effect that can
      -- applied without any action having been taken on you.
      local found_indi = hasteinfo.indi_active:with('buff_id', buff_id)
      if found_indi then
        new_haste_effect = found_indi
      else
        local found_geo = hasteinfo.geo_active:with('buff_id', buff_id)
        if found_geo then
          new_haste_effect = found_geo
        end
      end

      if not new_haste_effect then
        -- If still no match, this is an unknown haste. You must have had an action taken on you but lost the packet.
        new_haste_effect = hasteinfo.haste_triggers['Other'][0]
      end

      if new_haste_effect then
        member.haste_effects[buff_id] = new_haste_effect
      else
        -- This should never happen
        print('Something went wrong in detecting "haste_effect" for buff '..buff_id..'.')
      end
    end
  end
end

function hasteinfo.remove_buff(member, buff_id, remove_all)
  if not member or buff_id == 255 then return end

  -- If this is an indi- spell, check if this member was the owner in the indi_active table
  if hasteinfo.indi_active[member.id] and hasteinfo.indi_active[member.id].buff_id == buff_id then
    -- Might need to also make sure this member does not have the Colure Active buff, but at this point
    -- I'm gonna assume that's an unnecessary redundancy
    hasteinfo.indi_active[member.id] = nil
  end

  if member.buffs then
    if remove_all then
      member.buffs = S{}
      member.haste_effects = T{}
    else
      member.buffs:remove(buff_id)

      -- Remove corresponding haste effect
      member.haste_effects[buff_id] = nil
    end
  end
end

-- Find lost buffs and remove corresponding haste effect
function hasteinfo.resolve_lost_buffs(member, old_buffs)
  local lost_buffs = S{}
  for buff_id in old_buffs:it() do
    if not member.buffs:contains(buff_id) then
      lost_buffs:add(buff_id)
    end
  end

  -- Remove haste effects that correspond to the lost buffs
  for buff_id in lost_buffs:it() do
    member.haste_effects[buff_id] = nil
  end
end

function hasteinfo.add_haste_effect(member, haste_effect)
  if not member or not haste_effect then return end
  if not haste_effect.potency then
    print('Missing potency on haste_effect: '..haste_effect.triggering_action)
    return
  end

  if member.haste_effects then
    -- Even if buff_id is already present, this could be a different action that provides the same buff_id but
    -- potentially different potency, so track this newer haste_effect instead.
    member.haste_effects[haste_effect.buff_id] = haste_effect
    hasteinfo.add_buff(member, haste_effect.buff_id)
  end
end

-- Remove haste effects that don't carry through zoning, and their corresponding buffs
function hasteinfo.remove_zoned_effects(member)
  for effect in member.haste_effects:it() do
    if not effect.persists_thru_zoning then
      member.haste_effects[effect.buff_id] = nil
    end
  end
end

function hasteinfo.update_samba(member, is_samba_active)
  if not member then return end
  if not is_samba_active then
    member.samba = {}
  end
  local potency = hasteinfo.samba_stats.potency_base
  -- Check if primary player is DNC
  if player.main_job == 'DNC' then
    potency = potency + (hasteinfo.samba_stats.potency_per_merit * player.merits[hasteinfo.samba_stats.merit_name])
  else
    -- Determine potency based on party jobs
    local has_main_dnc
    for member in hasteinfo.players:it() do
      if member.main == 'DNC' then
        has_main_dnc = true
        break
      end
    end

    if has_main_dnc then
      potency = potency + (hasteinfo.samba_stats.potency_per_merit * 5)
    end
  end

  member.samba = {
    ['expiration'] = os.clock() + hasteinfo.SAMBA_DURATION,
    ['potency'] = potency,
  }
end

function hasteinfo.reset_member(member)
  if member then
    member.haste_effects = T{}
    member.buffs = S{}
  end
end

function hasteinfo.from_server_time(t)
  return t / 60 + hasteinfo.clock_offset
end
  


-------------------------------------------------------------------------------
-- Event hooks
-------------------------------------------------------------------------------

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
  elseif id == 0x01B then -- job info, comes in after changing jobs
    local packet = packets.parse('incoming', data)
    local member = hasteinfo.get_member(player.id, player.name)
    hasteinfo.update_job_from_packet(member, packet)
  elseif id == 0x063 then -- Set Update packet
    -- update buff durations
    -- credit: Akaden, Buffed addon
    local order = data:unpack('H',0x05)
    if order == 9 then
      local read_statuses = {}

      -- read ids
      for i = 1, 32 do
        local index = 0x09 + ((i-1) * 0x02)
        local status_i = data:unpack('H', index)

        if status_i ~= 255 then
          read_statuses[i] = { id = status_i }
        end
      end
      -- read times
      for i = 1, 32 do
        if read_statuses[i] then
          local index = 0x49 + ((i-1) * 0x04)
          local endtime = data:unpack('I', index)

          read_statuses[i].endtime = from_server_time(endtime)
        end
      end
    end
  elseif id == 0x037 then -- Update Char packet
    -- update clock offset
    -- credit: Akaden, Buffed addon
    local p = packets.parse('incoming', data)
    if p['Timestamp'] and p['Time offset?'] then
      local vana_time = p['Timestamp'] * 60 - math.floor(p['Time offset?'])
      hasteinfo.clock_offset = math.floor(os.time() - vana_time % 0x100000000 / 60)
    end
  end
end)

windower.raw_register_event('gain buff', function(buff_id)
  windower.add_to_chat(001, 'gained buff '..buff_id)
  if hasteinfo.haste_buff_ids:contains(buff_id) or hasteinfo.slow_debuff_ids:contains(buff_id) then
    local member = hasteinfo.get_member(player.id, player.name)
    hasteinfo.add_buff(member, buff_id)
  end
end)

windower.raw_register_event('lose buff', function(buff_id)
  windower.add_to_chat(001, 'last buff '..buff_id)
  local member = hasteinfo.get_member(player.id, player.name)
  hasteinfo.remove_buff(member, buff_id)
end)

windower.raw_register_event('action', function(act)
  if act.category == 1 and player.id == act.actor_id then -- Melee attack
    hasteinfo.parse_action(act, hasteinfo.ACTION_TYPE.SELF_MELEE)
  elseif act.category == 6 then -- JA; Only care about JA on self, except Entrust
    if act.actor_id == player.id and hasteinfo.haste_triggers['Job Ability'][act.param] then
      hasteinfo.parse_action(act, hasteinfo.ACTION_TYPE.SELF_HASTE_JA)
    elseif act.param == 386 then -- Entrust activation
      hasteinfo.parse_action(act, hasteinfo.ACTION_TYPE.ENTRUST_ACTIVATION)
    end
  elseif act.category == 4 and hasteinfo.haste_triggers['Magic'][act.param]
      and hasteinfo.players[act.targets[1].id] then -- Spell finish casting on party member target
    -- Determine if bard song, geomancy, or other
    local spell = res.spells[act.param]
    if spell then
      if spell.type == 'BardSong' then
        hasteinfo.parse_action(act, hasteinfo.ACTION_TYPE.BARD_SONG)
      elseif spell.type == 'Geomancy' then
        hasteinfo.parse_action(act, hasteinfo.ACTION_TYPE.GEOMANCY)
      else
        hasteinfo.parse_action(act, hasteinfo.ACTION_TYPE.SPELL)
      end
    end
  elseif act.category == 3 and player.id == act.actor_id and hasteinfo.haste_triggers['Weapon Skill'][act.param] then -- Finish WS, only care about Catastrophe
    hasteinfo.parse_action(act, hasteinfo.ACTION_TYPE.SELF_CATASTROPHE)
  elseif act.category == 13 and hasteinfo.haste_triggers['Job Ability'][act.param] then -- Pet uses ability
    hasteinfo.parse_action(act, hasteinfo.ACTION_TYPE.PET)
  end
end)

-- Triggers on player status change. This only triggers for the following statuses:
-- Idle, Engaged, Resting, Dead, Zoning
windower.raw_register_event('status change', function(new_status_id, old_status_id)
  -- In any of these status change scenarios, haste samba status should be reset
  local member = hasteinfo.get_member(player.id, player.name)
  if member and member.samba then
    hasteinfo.update_samba(member, false)
  end
end)

-- Hook into job/subjob change event (happens BEFORE job starts changing)
windower.raw_register_event('outgoing chunk', function(id, data, modified, injected, blocked)
  if id == 0x100 then -- Sending job change command to server
    local member = hasteinfo.get_member(player.id, player.name)
    hasteinfo.reset_member(member)
    -- TODO: Write player data to file, to retrieve after library reloads. Cannot prevent
    -- gearswap from reloading the whole addon when changing jobs. That's a built-in function.
  end
end)

windower.raw_register_event('zone change', function(new_zone, old_zone)
  -- Update buffs after zoning
  local member = hasteinfo.get_member(player.id, player.name)
  hasteinfo.remove_zoned_effects(member)
end)

hasteinfo.init()

return hasteinfo