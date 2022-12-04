log_name = 'hasteinfo_err.log'

player = windower.ffxi.get_player()
current_alliance_ids = S{}

reports_paused = false

-- Offset of system clock vs server clock, to be determined by packets received from the server
clock_offset = 0

-- Stats includes total haste, and haste by category. 'Actual' is the real amount of
-- haste, and 'uncapped' is the full amount that all buffs would add up to if there was
-- no cap.
default_stats = T{
  ['haste'] = {
    ['ma'] = {
      ['actual'] = {
        ['percent'] = 0,
        ['fraction'] = 0
      },
      ['uncapped'] = {
        ['percent'] = 0,
        ['fraction'] = 0
      },
    },
    ['ja'] = {
      ['actual'] = {
        ['percent'] = 0,
        ['fraction'] = 0
      },
      ['uncapped'] = {
        ['percent'] = 0,
        ['fraction'] = 0
      },
    },
    ['eq'] = {
      ['actual'] = {
        ['percent'] = 25,
        ['fraction'] = 256
      },
      ['uncapped'] = {
        ['percent'] = 256,
        ['fraction'] = 256
      },
    },
    ['debuff'] = {
      ['actual'] = {
        ['percent'] = 0,
        ['fraction'] = 0
      },
      ['uncapped'] = {
        ['percent'] = 0,
        ['fraction'] = 0
      },
    },
    ['total'] = {
      ['actual'] = {
        ['percent'] = 25,
        ['fraction'] = 256
      },
      ['uncapped'] = {
        ['percent'] = 25,
        ['fraction'] = 256
      },
    },
  },
  ['dual_wield'] = {
    ['total_needed'] = 74,  -- Ignores all sources of dual wield already possessed
    ['traits'] = 0, -- DW possessed from traits
    ['actual_needed'] = 74, -- DW needed after traits and buffs accounted for
  }
}

stats = default_stats:copy(true)

players = T{ -- Track jobs and relevant buffs of party members
  --[[
  [id] = {id=num, name=str, main=str, main_lv=num, sub=str, sub_lv=num, samba=table, songs=table, haste_effects=table, buffs=list}
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
  buffs = L{
    {id=num}
  }

  Ex:
  [123456] = {id=123456, name='Joe', main='GEO', main_lv=99, sub='RDM', sub_lv=99, samba={expiration=12345, potency=51}, songs={}, haste_effects={}, buffs={}}
  ]]
}

-- Track Indi- actions performed on party members
-- Items are added when an Indi- spell is casted
-- Items are removed when a Colure Active buff disappears from a party member
indi_active = T{
  -- same as haste effects + some fields
  -- [target_id] = {triggering_action=str, triggering_id=num, buff_name=str, buff_id=num, haste_category=ma, potency=num, multipliers=T{}, caster_id=num, target_id=num}
}
-- Track Geo- actions performed on party members
-- Items are added when a Geo- spell is casted
-- Items are removed when caster casts a new Geo- spell
geo_active = T{
  -- same as haste effects + some fields
  -- [caster_id] = {triggering_action=str, triggering_id=num, buff_name=str, buff_id=num, haste_category=ma, potency=num, multipliers=T{}, caster_id=num}
}

summary_mode_options = T{
  [0] = 'off',
  [1] = 'minimal',
  [2] = 'verbose',
}

-- Default settings
defaults = {
  show_ui=true,
  show_fractions = false,
  show_party = false,
  show_breakdown = false,
  summary_mode = 2,
  display={
    text={
      size=10,
      font='Consolas',
      alpha=255,
      red=255,
      green=255,
      blue=255,
    },
    pos={
      x=0,
      y=0
    },
    bg={
      visible=true,
      alpha=200,
      red=0,
      green=0,
      blue=0,
    },
    flag={
      draggable=true
    },
  }
}

-- Fraction caps are all numerators. The denominator for each is 1024.
haste_caps = {
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
  ['debuff'] = {
    ['percent'] = 100,
    ['fraction'] = 1024
  },
}

-- Haste potencies are all the numerator portion of a fraction whose denominator is 1024.
-- Ex. If Geo-Haste is 306, that means it's 306/1024, or ~29.9%.
haste_triggers = T{
  ['Magic'] = {
    [ 57] = {triggering_action='Haste', triggering_id=57, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', persists_thru_zoning=true, potency_base=150},
    [511] = {triggering_action='Haste II', triggering_id=511, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', persists_thru_zoning=true, potency_base=307},
    [478] = {triggering_action='Embrava', triggering_id=478, buff_name='Embrava', buff_id=228, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', persists_thru_zoning=false, potency_base=266},
    [771] = {triggering_action='Indi-Haste', triggering_id=771, buff_name='Haste', buff_id=580, haste_category='ma', trigger_category='Magic', trigger_sub_category='Geomancy', persists_thru_zoning=false, potency_base=307, potency_per_geomancy=12, multipliers=T{}},
    [801] = {triggering_action='Geo-Haste', triggering_id=801, buff_name='Haste', buff_id=580, haste_category='ma', trigger_category='Magic', trigger_sub_category='Geomancy', persists_thru_zoning=false, potency_base=307, potency_per_geomancy=12, multipliers=T{}},
    [417] = {triggering_action='Honor March', triggering_id=417, buff_name='March', buff_id=214, haste_category='ma', trigger_category='Magic', trigger_sub_category='BardSong', persists_thru_zoning=false, potency_base=126, song_cap=4, multipliers=T{}},
    [420] = {triggering_action='Victory March', triggering_id=420, buff_name='March', buff_id=214, haste_category='ma', trigger_category='Magic', trigger_sub_category='BardSong', persists_thru_zoning=false, potency_base=163, song_cap=8, multipliers=T{}},
    [419] = {triggering_action='Advancing March', triggering_id=419, buff_name='March', buff_id=214, haste_category='ma', trigger_category='Magic', trigger_sub_category='BardSong', persists_thru_zoning=false, potency_base=108, song_cap=8, multipliers=T{}},
    [530] = {triggering_action='Refueling', triggering_id=530, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', persists_thru_zoning=true, potency_base=102}, -- Exact potency unknown
    [710] = {triggering_action='Erratic Flutter', triggering_id=710, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', persists_thru_zoning=true, potency_base=307},
    [661] = {triggering_action='Animating Wail', triggering_id=661, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', persists_thru_zoning=true, potency_base=150}, -- Exact potency unknown
    [750] = {triggering_action='Mighty Guard', triggering_id=750, buff_name='Mighty Guard', buff_id=604, haste_category='ma', trigger_category='Magic', trigger_sub_category='BlueMagic', persists_thru_zoning=false, potency_base=150}, -- Exact potency unknown
    [421] = {triggering_action='Battlefield Elegy', triggering_id=421, buff_name='Elegy', buff_id=194, haste_category='ma', trigger_category='Magic', trigger_sub_category='BardSong', persists_thru_zoning=false, potency_base=256}, -- Assume enemies have base potency
    [422] = {triggering_action='Carnage Elegy', triggering_id=422, buff_name='Elegy', buff_id=194, haste_category='ma', trigger_category='Magic', trigger_sub_category='BardSong', persists_thru_zoning=false, potency_base=512}, -- Assume enemies have base potency
    [ 56] = {triggering_action='Slow', triggering_id=56, buff_name='Slow', buff_id=13, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', persists_thru_zoning=false, potency_base=300}, -- Assume enemies have base potency
    [ 79] = {triggering_action='Slow II', triggering_id=56, buff_name='Slow', buff_id=13, haste_category='ma', trigger_category='Magic', trigger_sub_category='WhiteMagic', persists_thru_zoning=false, potency_base=359}, -- Assume enemies have base potency
    [795] = {triggering_action='Indi-Slow', triggering_id=795, buff_name='Slow', buff_id=565, haste_category='ma', trigger_category='Magic', trigger_sub_category='Geomancy', persists_thru_zoning=false, potency_base=152}, -- Assume enemies have base potency
    [825] = {triggering_action='Geo-Slow', triggering_id=825, buff_name='Slow', buff_id=565, haste_category='ma', trigger_category='Magic', trigger_sub_category='Geomancy', persists_thru_zoning=false, potency_base=152}, -- Assume enemies have base potency
  },
  ['Job Ability'] = {
    [595] = {triggering_action='Hastega', triggering_id=595, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Job Ability', trigger_sub_category='BloodPactWard', persists_thru_zoning=true, potency_base=153},
    [602] = {triggering_action='Hastega II', triggering_id=602, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Job Ability', trigger_sub_category='BloodPactWard', persists_thru_zoning=true, potency_base=307}, -- Exact potency unknown
    [173] = {triggering_action='Hasso', triggering_id=173, buff_name='Hasso', buff_id=353, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='', persists_thru_zoning=false, potency_base=103}, -- Exact potency unknown
    [80] = {triggering_action='Spirit Link', triggering_id=80, buff_name='N/A', buff_id=0, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='', persists_thru_zoning=false, potency_base=0, potency_per_merit=21, merit_job='DRG', merit_name='empathy'}, -- Exact potency unknown
    [51] = {triggering_action='Last Resort', triggering_id=51, buff_name='Last Resort', buff_id=64, haste_category='ja', trigger_category='Job Ability', trigger_sub_category='', persists_thru_zoning=false, potency_base=150, potency_per_merit=21, merit_job='DRK', merit_name='desperate_blows'}, -- Exact potency unknown
  },
  ['Weapon Skill'] = {
    [105] = {triggering_action='Catastrophe', triggering_id=105, buff_name='Aftermath', buff_id=273, haste_category='ja', trigger_category='Weapon Skill', trigger_sub_category='Scythe', persists_thru_zoning=false, potency_base=102}, -- Exact potency unknown
  },
  ['Other'] = {
    [  0] = {triggering_action='Weakness', triggering_id=0, buff_name='Slow', buff_id=1, haste_category='debuff', trigger_category='', trigger_sub_category='', persists_thru_zoning=false, potency_base=1024, potency=1024},
    [  1] = {triggering_action='Unknown Haste', triggering_id=0, buff_name='Haste', buff_id=33, haste_category='ma', trigger_category='Unknown', trigger_sub_category='Unknown', persists_thru_zoning=false, potency_base=150, potency=150},
    [  2] = {triggering_action='Unknown GEO Haste', triggering_id=0, buff_name='Haste', buff_id=580, haste_category='ma', trigger_category='Magic', trigger_sub_category='Geomancy', persists_thru_zoning=false, potency_base=307, potency=427},
    [  3] = {triggering_action='Unknown Slow', triggering_id=0, buff_name='Slow', buff_id=13, haste_category='debuff', trigger_category='Magic', trigger_sub_category='Unknown', persists_thru_zoning=false, potency_base=300, potency=300}, -- Assume enemies have base potency
    [  4] = {triggering_action='Unknown Elegy', triggering_id=0, buff_name='Elegy', buff_id=194, haste_category='debuff', trigger_category='Magic', trigger_sub_category='BardSong', persists_thru_zoning=false, potency_base=512, potency=512}, -- Assume enemies have base potency
    [  5] = {triggering_action='Unknown GEO Slow', triggering_id=0, buff_name='Slow', buff_id=565, haste_category='debuff', trigger_category='Magic', trigger_sub_category='Geomancy', persists_thru_zoning=false, potency_base=152, potency=152}, -- Assume enemies have base potency
  }
}

song_assumption_priority = L{
  haste_triggers['Magic'][417],
  haste_triggers['Magic'][420],
  haste_triggers['Magic'][419],
}

trusts = L{
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

STR = {
  SOUL_VOICE = 'Soul Voice',
  MARCATO = 'Marcato',
  BOLSTER = 'Bolster',
  EA = 'Ecliptic Attrition',
  BOG = 'Blaze of Glory',
}

-- Haste Samba does not have an actual buff or triggering action but here's the relevant info:
-- Upon melee action, action packet is sent and if the add_effect_animation == 23, you have haste samba benefit
-- Counts as Job Ability haste. Base potency=51, potency increases by 10/1024
-- Merit ID is 1538
samba_stats = {potency_base=51, potency_per_merit=10, merit_id=1538, merit_name='haste_samba_effect', animation_id=23}

SONG_HASTE_BUFF_ID = 214
GEO_HASTE_BUFF_ID = 580
HASTE_BUFF_IDS = S{33, 64, 214, 228, 273, 353, 580, 604}

WEAKNESS_DEBUFF_ID = 1
SLOW_SPELL_DEBUFF_ID = 13
SLOW_SONG_DEBUFF_ID = 194
SLOW_GEO_DEBUFF_ID = 565
SLOW_DEBUFF_IDS = S{1, 13, 194, 565}

SOUL_VOICE_BUFF_ID = 52
SOUL_VOICE_MULTIPLIER = 2
MARCATO_BUFF_ID = 231
MARCATO_MULTIPLIER = 1.5
BOLSTER_BUFF_ID = 513
BOLSTER_MULTIPLIER = 2
ECLIPTIC_ATTRITION_BUFF_ID = 516
ECLIPTIC_ATTRITION_MULTIPLIER = 1.25
BOG_BUFF_ID = 569
BOG_MULTIPLIER = 1.5
COLURE_ACTIVE_ID = 612
ENTRUST_BUFF_ID = 684
OTHER_RELEVANT_BUFFS = S{52, 231, 513, 516, 569, 612, 684}

SOUL_VOICE_ACTION_ID = 25
MARCATO_ACTION_ID = 284
BOLSTER_ACTION_ID = 343
ECLIPTIC_ATTRITION_ACTION_ID = 347
BOG_ACTION_ID = 350
ENTRUST_ACTION_ID = 386
OTHER_RELEVANT_ACTIONS = S{25, 284, 343, 347, 350, 386}

GEOMANCY_JA_MULTIPLIER_MAX = 2 -- Max potency multiplier of all geomancy buffs (max boost if Bolster + BoG + EA are all active)
SONG_JA_MULTIPLIER_MAX = 2 -- Max potency multiplier of all song buffs (max boost if SV + Marcato are all active)

FINAL_APOC_ID = 21808
SAMBA_DURATION = 9 -- Assume samba lasts 9 seconds on players after hitting a mob inflicted with Samba Daze
ACTION_TYPE = T{
  ['SELF_MELEE'] = 'Self Melee',
  ['SELF_HASTE_JA'] = 'Self Haste JA',
  ['ENTRUST_ACTIVATION'] = 'Entrust Activation',
  ['SPELL'] = 'Spell',
  ['BARD_SONG'] = 'Bard Song',
  ['GEOMANCY'] = 'Geomancy',
  ['SELF_CATASTROPHE'] = 'Self Catastrophe',
  ['PET'] = 'Pet',
}

dw_tiers = {
  [0] = 0,
  [1] = 10,
  [2] = 15,
  [3] = 25,
  [4] = 30,
  [5] = 35,
  [6] = 40,
}

dw_jobs = {
  ['NIN'] = {
    {tier=1, lv=10, jp_spent=0},
    {tier=2, lv=25, jp_spent=0},
    {tier=3, lv=45, jp_spent=0},
    {tier=4, lv=65, jp_spent=0},
    {tier=5, lv=85, jp_spent=0},
  },
  ['DNC'] = {
    {tier=1, lv=20, jp_spent=0},
    {tier=2, lv=40, jp_spent=0},
    {tier=3, lv=60, jp_spent=0},
    {tier=4, lv=80, jp_spent=0},
    {tier=5, lv=99, jp_spent=550},
  },
  ['THF'] = {
    {tier=1, lv=83, jp_spent=0},
    {tier=2, lv=90, jp_spent=0},
    {tier=3, lv=98, jp_spent=0},
    {tier=4, lv=99, jp_spent=550}
  },
}

dw_blu_spells = {
  [657] = {id=657,en="Blazing Bound",ja="ブレーズバウンド",trait_points=4},
  [661] = {id=661,en="Animating Wail",ja="鯨波",trait_points=4},
  [673] = {id=673,en="Quad. Continuum",ja="四連突",trait_points=4},
  [682] = {id=682,en="Delta Thrust",ja="デルタスラスト",trait_points=4},
  [686] = {id=686,en="Mortal Ray",ja="モータルレイ",trait_points=4},
  [699] = {id=699,en="Barbed Crescent",ja="偃月刃",trait_points=4},
  [715] = {id=715,en="Molting Plumage",ja="モルトプルメイジ",trait_points=8},
}

-- Incoming packet 0x044 actually sends 2 different packets on job change and zone change
-- One packet includes subjob info, the other includes main job info
-- This table tracks the status so we know when both updates have completed
job_update_status = {
  main_update_received=false,
  sub_update_received=false,
  is_changed=false,
  started_update_at=0,
}

chat_purple = string.char(0x1F, 200)
chat_grey = string.char(0x1F, 160)
chat_red = string.char(0x1F, 167)
chat_white = string.char(0x1F, 001)
chat_green = string.char(0x1F, 214)
chat_yellow = string.char(0x1F, 036)
chat_d_blue = string.char(0x1F, 207)
chat_pink = string.char(0x1E, 5)
chat_l_blue = string.char(0x1E, 6)

inline_white = '\\cs(255,255,255)'
inline_red = '\\cs(255,0,0)'
inline_green = '\\cs(0,255,0)'
inline_blue = '\\cs(0,0,255)'