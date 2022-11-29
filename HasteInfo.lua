-- Version 2022.NOV.29.002
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
    [  0] = {triggering_action='Unknown', triggering_id=0, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Unknown', trigger_sub_category='Unknown', persists_thru_zoning=false, potency_base=150, potency=150},
  }
}

hasteinfo.song_assumption_priority = L{
  hasteinfo.haste_triggers['Magic'][417],
  hasteinfo.haste_triggers['Magic'][420],
  hasteinfo.haste_triggers['Magic'][419],
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

hasteinfo.SONG_HASTE_BUFF_ID = 214
hasteinfo.GEO_HASTE_BUFF_ID = 580
hasteinfo.HASTE_BUFF_IDS = S{33, 64, 214, 228, 273, 353, 580, 604}

hasteinfo.SLOW_SPELL_DEBUFF_ID = 13
hasteinfo.SLOW_SONG_DEBUFF_ID = 194
hasteinfo.SLOW_DEBUFF_IDS = S{13, 194}

hasteinfo.SOUL_VOICE_BUFF_ID = 52
hasteinfo.MARCATO_BUFF_ID = 231
hasteinfo.BOLSTER_BUFF_ID = 513
hasteinfo.ECLIPTIC_ATTRITION_BUFF_ID = 516
hasteinfo.BOG_BUFF_ID = 569
hasteinfo.COLURE_ACTIVE_ID = 612
hasteinfo.ENTRUST_BUFF_ID = 684
hasteinfo.OTHER_RELEVANT_BUFFS = S{52, 231, 513, 516, 569, 612, 684}

hasteinfo.SOUL_VOICE_ACTION_ID = 25
hasteinfo.MARCATO_ACTION_ID = 284
hasteinfo.BOLSTER_ACTION_ID = 343
hasteinfo.ECLIPTIC_ATTRITION_ACTION_ID = 347
hasteinfo.BOG_ACTION_ID = 350
hasteinfo.ENTRUST_ACTION_ID = 386
hasteinfo.OTHER_RELEVANT_ACTIONS = S{25, 284, 343, 347, 350, 386}

hasteinfo.FINAL_APOC_ID = 21808
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
    [id] = {id=num, name=str, main=str, main_lv=num, sub=str, sub_lv=num, samba=table, songs=table, haste_effects=table, buffs=table}
    songs = T{
      [triggering_id] = {triggering_action=str, triggering_id=num, buff_name=str, buff_id=num, haste_category=ma, potency=num, received_at=num, expiration=num}
    }
    samba = {
      expiration=num, -- seconds since last samba effect detected; has decimals that can track to 1/100 of a second
      potency=num,
    }
    haste_effects = T{
      [buff_id] = {triggering_action=str, triggering_id=num, buff_name=str, buff_id=num, haste_category=ma|ja, potency=num}
    }
    buffs = {
      [1]=num
      ...
      [32]=num
    }

    Ex:
    [123456] = {id=123456, name='Joe', main='GEO', main_lv=99, sub='RDM', sub_lv=99, samba={expiration=12345, potency=51}, songs={}, haste_effects={}, buffs={}}
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
  
  -- Add primary user
  local me = hasteinfo.add_member(player.id, player.name)
  -- Try to determine current haste effects based on buff icons
  local current_buffs = windower.ffxi.get_player().buffs
  current_buffs = hasteinfo.format_buffs(current_buffs)
  -- Filter for only buffs relevant to haste
  current_buffs = current_buffs:filter(function(buff)
    return hasteinfo.HASTE_BUFF_IDS:contains(buff.id)
        or hasteinfo.SLOW_DEBUFF_IDS:contains(buff.id)
        or hasteinfo.OTHER_RELEVANT_BUFFS:contains(buff.id)
  end)
  -- Add received_at param
  current_buffs = current_buffs:map(function(buff)
    buff.received_at = hasteinfo.now()
    return buff
  end)
  hasteinfo.deduce_haste_effects(me, current_buffs)
  me.buffs = current_buffs

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
  local new_member = {id=id, name=name, main='', main_lv=0, sub='', sub_lv=0, samba={}, songs=T{}, haste_effects=T{}, buffs=L{}}
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

    -- Record this action. The next player update packet will tell us what the effect really was.
    local caster = hasteinfo.get_member(act.actor_id)

    for i,target in ipairs(act.targets) do
      -- Only care about songs on main player
      if target.id == me.id then
        local target_member = hasteinfo.get_member(target.id)
  
        -- Add song gear bonuses
        local song_bonus = 0
        if caster then -- caster is in party
          -- Check for trusts
          if hasteinfo.trusts:with('name', caster.name) or caster.sub == 'BRD' then
            song_bonus = 0
          else
            song_bonus = haste_effect.song_cap
          end
        else -- caster is not defined, must make assumptions about song potency
          song_bonus = haste_effect.song_cap
        end
  
        -- Determine potency
        haste_effect.potency = haste_effect.potency_base + (haste_effect.potency_per_song_point * song_bonus)
        haste_effect.received_at = hasteinfo.now()
        target_member.songs[act.param] = haste_effect
      end
    end
  elseif type == hasteinfo.ACTION_TYPE.GEOMANCY then
    if not hasteinfo.haste_triggers['Magic'][act.param] then return end
    local haste_effect = table.copy(hasteinfo.haste_triggers['Magic'][act.param])
    
    local caster = hasteinfo.get_member(act.actor_id)

    for i,target in ipairs(act.targets) do
      local target_member = hasteinfo.get_member(target.id)

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
  elseif type == hasteinfo.ACTION_TYPE.SPELL then
    if not hasteinfo.haste_triggers['Magic'][act.param] then return end
    local haste_effect = table.copy(hasteinfo.haste_triggers['Magic'][act.param])
    
    local caster = hasteinfo.get_member(act.actor_id)

    for i,target in ipairs(act.targets) do
      local target_member = hasteinfo.get_member(target.id)
      for i,a in ipairs(target.actions) do
        local buff_id = a.param
        -- If buff doesn't match a buff that we're interested in, ignore.
        -- Also, 'no effect' spells have buff_id == 0, so this check filters those too
        if hasteinfo.HASTE_BUFF_IDS:contains(buff_id) or hasteinfo.SLOW_DEBUFF_IDS:contains(buff_id) then
          -- Determine potency
          haste_effect.potency = haste_effect.potency_base
          hasteinfo.add_haste_effect(target_member, haste_effect)
        end
      end
    end
  elseif type == hasteinfo.ACTION_TYPE.SELF_CATASTROPHE then
    -- If player has proper weapon equipped, grant 10% JA haste effect
    if hasteinfo.is_wearing_final_apoc() then
      local haste_effect = table.copy(hasteinfo.haste_triggers['Weapon Skill'][105])
      haste_effect.potency = haste_effect.potency_base
      hasteinfo.add_haste_effect(me, haste_effect)
    end
  elseif type == hasteinfo.ACTION_TYPE.PET then
    -- if targets[num].actions[num].param == buff_id, ability had no effect on that target if buff_id == 0
  end
end

function hasteinfo.parse_buffs(data)
  for k = 0, 4 do
    local actor_id = data:unpack('I', k*48+5)
    
    if actor_id ~= 0 then
      local member = hasteinfo.get_member(actor_id) or hasteinfo.add_member(actor_id)
      new_buffs = L{}
      for i = 1, 32 do
        local buff_id = data:byte(k*48+5+16+i-1) + 256*( math.floor( data:byte(k*48+5+8+ math.floor((i-1)/4)) / 4^((i-1)%4) )%4) -- Credit: Byrth, GearSwap

        new_buffs:append({id=buff_id})
      end
      
      -- Filter new buffs for only ones relevant to us
      new_buffs = new_buffs:filter(function(buff)
        return hasteinfo.HASTE_BUFF_IDS:contains(buff.id) or hasteinfo.SLOW_DEBUFF_IDS:contains(buff.id) or hasteinfo.OTHER_RELEVANT_BUFFS:contains(buff.id)
      end)
        
      hasteinfo.reconcile_buff_update(member, new_buffs)
    end
  end

  -- Thanks to this packet update, we should have all party members with IDs in the table.
  -- If there were previous entries with placeholder IDs, dump them. They will never reconcile.
  for member in hasteinfo.players:it() do
    if member.id < 0 then
      hasteinfo[member.id] = nil
    end
  end
end

function hasteinfo.is_samba_expired(member)
  local is_expired = false

  if member.samba and member.samba.expiration then
    is_expired = member.samba.expiration >= hasteinfo.now()
    if is_expired then
      member.samba = {}
    end
  end
  
  return is_expired
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
  end
end

-- Remove haste effects that don't carry through zoning, and their corresponding buffs
function hasteinfo.remove_zoned_effects(member)
  for effect in member.haste_effects:it() do
    if not effect.persists_thru_zoning then
      member.haste_effects[effect.buff_id] = nil
    end
  end
  
  -- If player had an Indi spell on them, stop tracking it
  if hasteinfo.indi_active[member.id] then
    hasteinfo.indi_active[member.id] = nil
  end
  -- If player had casted a Geo spell, stop tracking it
  if hasteinfo.geo_active[member.id] then
    hasteinfo.geo_active[member.id] = nil
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
    ['expiration'] = hasteinfo.now() + hasteinfo.SAMBA_DURATION,
    ['potency'] = potency,
  }
end

-- Check if user is wearing final upgrade of Apocalypse weapon
function hasteinfo.is_wearing_final_apoc()
  local all_items = windower.ffxi.get_items()
  local weapon_bag = all_items.equipment.main_bag
  local weapon_index = all_items.equipment.main
  if not weapon_bag or not weapon_index then
    return false
  end

  local weapon = windower.ffxi.get_items(weapon_bag, weapon_index)
  return weapon.id == hasteinfo.FINAL_APOC_ID
end

function hasteinfo.deduce_haste_effects(member, new_buffs)
  -- Make sure new_buffs is in the proper format
  local buffs = hasteinfo.format_buffs(new_buffs)

  for buff in buffs:it() do
    if hasteinfo.HASTE_BUFF_IDS:contains(buff.id) then
      -- See if there is a corresponding haste effect on player already
      local haste_effect = member.haste_effects[buff.id]
      local skip
      if not haste_effect then
        -- Depending on the buff, we can possibly deduce its source
        if buff.id == 228 then -- Embrava
          haste_effect = table.copy(hasteinfo.haste_triggers['Magic'][478])
        elseif buff.id == 604 then -- Mighty Guard
          haste_effect = table.copy(hasteinfo.haste_triggers['Magic'][750])
        elseif buff.id == 353 then -- Hasso
          haste_effect = table.copy(hasteinfo.haste_triggers['Job Ability'][173])
        elseif buff.id == 64 then -- Last Resort
          haste_effect = table.copy(hasteinfo.haste_triggers['Job Ability'][51])
        elseif buff.id == 273 then -- Relic aftermath
          -- Check if current weapon is one that grants haste effect
          -- Can only check equipment for main player
          if member.id == player.id and hasteinfo.is_wearing_final_apoc() then
            haste_effect = table.copy(hasteinfo.haste_triggers['Weapon Skill'][105])
          else
            skip = true
          end
        elseif buff.id == 214 then -- March
          -- We only care about songs for main player
          if member.id ~= player.id then
            skip = true
          end
          hasteinfo.update_songs(member, new_buffs)
        elseif buff.id == 580 then -- Geomancy
          -- Get haste effect from indi- and geo- tables
          local found_indi = hasteinfo.indi_active:with('buff_id', buff.id)
          if found_indi then
            haste_effect = found_indi
          else
            local found_geo = hasteinfo.geo_active:with('buff_id', buff.id)
            if found_geo then
              haste_effect = found_geo
            end
          end
      
          if not haste_effect then
            -- Unknown source, but we know it's geomancy. Guess at potency
            haste_effect = table.copy(hasteinfo.haste_triggers[771])
            haste_effect.potency = haste_effect.potency_base + (haste_effect.potency_per_geomancy * 10)
          end
        elseif not skip then
          -- Unknown source, guess at potency
          haste_effect = table.copy(hasteinfo.haste_triggers['Other'][0])
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
        hasteinfo.add_haste_effect(member, haste_effect)
      end
    end
  end
end

function hasteinfo.reset_member(member)
  if member then
    member.haste_effects = T{}
    member.buffs = L{}
  end
end

function hasteinfo.from_server_time(t)
  return t / 60 + hasteinfo.clock_offset
end

function hasteinfo.now()
  return os.clock()
end

function hasteinfo.format_buffs(buff_list)
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
function hasteinfo.sort_song_dur(is_missing_expirations)
  return function(e1, e2)
    windower.add_to_chat(001, 'comparing:')
    table.vprint(e1)
    table.vprint(e2)
    if is_missing_expirations then
      return e1.received_at < e2.received_at
    else
      return e1.expiration < e2.expiration
    end
  end
end

-- Update tracked songs
-- Note: song expirations can vary by +/-1 second between packets
function hasteinfo.update_songs(member, buffs)
  -- Format and filter to only Marches
  local new_buffs = hasteinfo.format_buffs(buffs):filter(function(buff)
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
  new_buffs:sort(hasteinfo.sort_song_dur(is_missing_expirations))

  -- Copy song table to list
  local my_song_copy = L{}
  for buff in member.songs:it() do
    my_song_copy:append(buff)
  end

  local old_count = my_song_copy.n

  is_missing_expirations = my_song_copy:with('expiration', nil) ~= nil
  my_song_copy:sort(hasteinfo.sort_song_dur(is_missing_expirations))

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
            old_song.received_at = hasteinfo.now()
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
    local song_assumption_priority = hasteinfo.song_assumption_priority:copy()

    -- Gained songs should already be sorted by shortest duration first
    for song in gained_songs:it() do
      for assumed_song in song_assumption_priority:it() do
        -- If assumed song not already tracked, add it and include instance specific attributes
        if not member.songs[assumed_song.triggering_id] then
          assumed_song.received_at = hasteinfo.now()
          assumed_song.expiration = song.expiration
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
function hasteinfo.reconcile_buff_update(member, new_buffs)
  if not member or not new_buffs then return end
  
  -- Ensure formatting
  new_buffs = hasteinfo.format_buffs(new_buffs)

  -- Filter new buffs for only ones relevant to us
  new_buffs = new_buffs:filter(function(buff)
    return hasteinfo.HASTE_BUFF_IDS:contains(buff.id) or hasteinfo.SLOW_DEBUFF_IDS:contains(buff.id) or hasteinfo.OTHER_RELEVANT_BUFFS:contains(buff.id)
  end)

  -- Assume correct format since this is the only place member.buffs is ever modified
  local old_buffs = table.copy(member.buffs, true)

  -- To figure out the impact on haste effects, we need to know which buffs were gained and lost
  local gained_buffs = L{}
  local lost_buffs = L{}

  for new_buff in new_buffs:it() do
    for old_buff in old_buffs:it() do
      if new_buff.id == old_buff.id and not old_buff.paired then
        new_buff.paired = true
        old_buff.paired = true
        -- Old buffs that were paired may have had duration refreshed. Need to do anything here?
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
    if buff.id == hasteinfo.BOLSTER_BUFF_ID then -- Resolve Bolster effect on current Indi spell potency
      -- TODO: update indi- table, and haste effects for all party members who have the corresponding buff
    elseif buff.id == hasteinfo.ECLIPTIC_ATTRITION_BUFF_ID then -- Resolve EA effect on current Geo spell potency
      -- TODO: update geo- table, and haste effects for all party members who have the corresponding buff
    elseif hasteinfo.HASTE_BUFF_IDS:contains(buff.id) then
      hasteinfo.deduce_haste_effects(member, new_buffs)
    end
  end
  
  -- Resolve lost buffs' haste effects and other special handling
  for buff in lost_buffs:it() do
    -- See if there is a corresponding haste effect on player
    local haste_effect = member.haste_effects[buff.id]
    if haste_effect then -- Remove haste effect
      member.haste_effects[buff.id] = nil
    end

    -- If lost buff is Colure Active, and this player was tracked as an indi target, remove from indi table
    if buff.id == hasteinfo.COLURE_ACTIVE_ID then
      if hasteinfo.indi_active[member.id] then
        hasteinfo.indi_active[member.id] = nil
      end
    end
  end

  -- Update buff list to new list
  member.buffs = new_buffs
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

          buffs[i].expiration = hasteinfo.from_server_time(expiration)
        end
      end

      local me = hasteinfo.get_member(player.id, player.name)

      -- Reconcile these buffs with tracked haste effects and actions; resolve discrepancies using assumed values
      hasteinfo.reconcile_buff_update(me, buffs)
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