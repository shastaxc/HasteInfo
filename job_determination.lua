-- Spells/abilities that can only be used by a single main job (not as sub job)
unique_actions = {
  ['Magic'] = {}, -- Update procedurally from res.spells
  ['Job Abilities'] = { -- SP can only be used by main job regardless of level
    [ 16] = {id=16, name='Mighty Strikes', job='WAR'},
    [ 17] = {id=17, name='Hundred Fists', job='MNK'},
    [ 18] = {id=18, name='Benediction', job='WHM'},
    [ 19] = {id=19, name='Manafont', job='BLM'},
    [ 21] = {id=21, name='Perfect Dodge', job='THF'},
    [ 22] = {id=22, name='Invincible', job='PLD'},
    [ 23] = {id=23, name='Blood Weapon', job='DRK'},
    [ 24] = {id=24, name='Familiar', job='BST'},
    [ 25] = {id=25, name='Soul Voice', job='BRD'},
    [ 26] = {id=26, name='Eagle Eye Shot', job='RNG'},
    [ 27] = {id=27, name='Meikyo Shisui', job='SAM'},
    [ 28] = {id=28, name='Mijin Gakure', job='NIN'},
    [ 29] = {id=29, name='Spirit Surge', job='DRG'},
    [ 30] = {id=30, name='Astral Flow', job='SMN'},
    [ 61] = {id=61, name='Call Wyvern', job='DRG'},
    [ 80] = {id=80, name='Spirit Link', job='DRG'},
    [ 84] = {id=84, name='Accomplice', job='THF'},
    [ 87] = {id=87, name='Dismiss', job='DRG'},
    [ 92] = {id=92, name='Rampart', job='PLD'},
    [ 93] = {id=93, name='Azure Lore', job='BLU'},
    [ 96] = {id=96, name='Wild Card', job='COR'},
    [116] = {id=116, name='Dancer\'s Roll', job='COR'},
    [117] = {id=117, name='Scholar\'s Roll', job='COR'},
    [118] = {id=118, name='Bolter\'s Roll', job='COR'},
    [119] = {id=119, name='Caster\'s Roll', job='COR'},
    [120] = {id=120, name='Courser\'s Roll', job='COR'},
    [121] = {id=121, name='Blitzer\'s Roll', job='COR'},
    [122] = {id=122, name='Tactician\'s Roll', job='COR'},
    [135] = {id=135, name='Overdrive', job='PUP'},
    [137] = {id=137, name='Repair', job='PUP'},
    [149] = {id=149, name='Warrior\'s Charge', job='WAR'},
    [150] = {id=150, name='Tomahawk', job='WAR'},
    [151] = {id=151, name='Mantra', job='MNK'},
    [152] = {id=152, name='Formless Strikes', job='MNK'},
    [153] = {id=153, name='Martyr', job='WHM'},
    [154] = {id=154, name='Devotion', job='WHM'},
    [155] = {id=155, name='Assassin\'s Charge', job='THF'},
    [156] = {id=156, name='Feint', job='THF'},
    [157] = {id=157, name='Fealty', job='PLD'},
    [158] = {id=158, name='Chivalry', job='PLD'},
    [160] = {id=160, name='Diabolic Eye', job='DRK'},
    [161] = {id=161, name='Feral Howl', job='BST'},
    [162] = {id=162, name='Killer Instinct', job='BST'},
    [163] = {id=163, name='Nightingale', job='BRD'},
    [164] = {id=164, name='Troubadour', job='BRD'},
    [165] = {id=165, name='Stealth Shot', job='RNG'},
    [166] = {id=166, name='Flashy Shot', job='RNG'},
    [167] = {id=167, name='Shikikoyo', job='SAM'},
    [168] = {id=168, name='Blade Bash', job='SAM'},
    [169] = {id=169, name='Deep Breathing', job='DRG'},
    [170] = {id=170, name='Angon', job='DRG'},
    [171] = {id=171, name='Sange', job='NIN'},
    [175] = {id=175, name='Convergence', job='BLU'},
    [176] = {id=176, name='Diffusion', job='BLU'},
    [177] = {id=177, name='Snake Eye', job='COR'},
    [178] = {id=178, name='Fold', job='COR'},
    [179] = {id=179, name='Role Reversal', job='PUP'},
    [180] = {id=180, name='Ventriloquy', job='PUP'},
    [181] = {id=181, name='Trance', job='DNC'},
    [186] = {id=186, name='Drain Samba III', job='DNC'},
    [188] = {id=188, name='Aspir Samba II', job='DNC'},
    [193] = {id=193, name='Curing Waltz IV', job='DNC'},
    [209] = {id=209, name='Wild Flourish', job='DNC'},
    [210] = {id=210, name='Tabula Rasa', job='SCH'},
    [214] = {id=214, name='Modus Veritas', job='SCH'},
    [226] = {id=226, name='Retaliation', job='WAR'},
    [227] = {id=227, name='Footwork', job='MNK'},
    [228] = {id=228, name='Despoil', job='THF'},
    [236] = {id=236, name='Collaborator', job='THF'},
    [237] = {id=237, name='Saber Dance', job='DNC'},
    [238] = {id=238, name='Fan Dance', job='DNC'},
    [239] = {id=239, name='No Foot Rise', job='DNC'},
    [241] = {id=241, name='Focalization', job='SCH'},
    [242] = {id=242, name='Tranquility', job='SCH'},
    [243] = {id=243, name='Equanimity', job='SCH'},
    [244] = {id=244, name='Enlightenment', job='SCH'},
    [248] = {id=248, name='Yonin', job='NIN'},
    [249] = {id=249, name='Innin', job='NIN'},
    [252] = {id=252, name='Restraint', job='WAR'},
    [253] = {id=253, name='Perfect Counter', job='MNK'},
    [254] = {id=254, name='Mana Wall', job='BLM'},
    [255] = {id=255, name='Divine Emblem', job='PLD'},
    [256] = {id=256, name='Nether Void', job='DRK'},
    [257] = {id=257, name='Double Shot', job='RNG'},
    [258] = {id=258, name='Sengikori', job='SAM'},
    [259] = {id=259, name='Futae', job='NIN'},
    [260] = {id=260, name='Spirit Jump', job='DRG'},
    [261] = {id=261, name='Presto', job='DNC'},
    [262] = {id=262, name='Divine Waltz II', job='DNC'},
    [264] = {id=264, name='Climactic Flourish', job='DNC'},
    [265] = {id=265, name='Libra', job='SCH'},
    [266] = {id=266, name='Tactical Switch', job='PUP'},
    [267] = {id=267, name='Blood Rage', job='WAR'},
    [269] = {id=269, name='Impetus', job='MNK'},
    [270] = {id=270, name='Divine Caress', job='WHM'},
    [271] = {id=271, name='Sacrosanctity', job='WHM'},
    [272] = {id=272, name='Enmity Douse', job='BLM'},
    [273] = {id=273, name='Manawell', job='BLM'},
    [274] = {id=274, name='Saboteur', job='RDM'},
    [275] = {id=275, name='Spontaneity', job='RDM'},
    [276] = {id=276, name='Conspirator', job='THF'},
    [277] = {id=277, name='Sepulcher', job='PLD'},
    [278] = {id=278, name='Palisade', job='PLD'},
    [279] = {id=279, name='Arcane Crest', job='DRK'},
    [280] = {id=280, name='Scarlet Delirium', job='DRK'},
    [281] = {id=281, name='Spur', job='BST'},
    [282] = {id=282, name='Run Wild', job='BST'},
    [283] = {id=283, name='Tenuto', job='BRD'},
    [284] = {id=284, name='Marcato', job='BRD'},
    [285] = {id=285, name='Bounty Shot', job='RNG'},
    [286] = {id=286, name='Decoy Shot', job='RNG'},
    [287] = {id=287, name='Hamanoha', job='SAM'},
    [288] = {id=288, name='Hagakure', job='SAM'},
    [291] = {id=291, name='Issekigan', job='NIN'},
    [292] = {id=292, name='Dragon Breaker', job='DRG'},
    [293] = {id=293, name='Soul Jump', job='DRG'},
    [295] = {id=295, name='Steady Wing', job='DRG'},
    [296] = {id=296, name='Mana Cede', job='SMN'},
    [297] = {id=297, name='Efflux', job='BLU'},
    [298] = {id=298, name='Unbridled Learning', job='BLU'},
    [301] = {id=301, name='Triple Shot', job='COR'},
    [302] = {id=302, name='Allies\' Roll', job='COR'},
    [303] = {id=303, name='Miser\'s Roll', job='COR'},
    [304] = {id=304, name='Companion\'s Roll', job='COR'},
    [305] = {id=305, name='Avenger\'s Roll', job='COR'},
    [309] = {id=309, name='Cooldown', job='PUP'},
    [311] = {id=311, name='Curing Waltz V', job='DNC'},
    [312] = {id=312, name='Feather Step', job='DNC'},
    [313] = {id=313, name='Striking Flourish', job='DNC'},
    [314] = {id=314, name='Ternary Flourish', job='DNC'},
    [316] = {id=316, name='Perpetuance', job='SCH'},
    [317] = {id=317, name='Immanence', job='SCH'},
    [318] = {id=318, name='Smiting Breath', job='DRG'},
    [319] = {id=319, name='Restoring Breath', job='DRG'},
    [320] = {id=320, name='Konzen-ittai', job='SAM'},
    [321] = {id=321, name='Bully', job='THF'},
    [322] = {id=322, name='Maintenance', job='PUP'},
    [323] = {id=323, name='Brazen Rush', job='WAR'},
    [324] = {id=324, name='Inner Strength', job='MNK'},
    [325] = {id=325, name='Asylum', job='WHM'},
    [326] = {id=326, name='Subtle Sorcery', job='BLM'},
    [327] = {id=327, name='Stymie', job='RDM'},
    [328] = {id=328, name='Larceny', job='THF'},
    [329] = {id=329, name='Intervene', job='PLD'},
    [330] = {id=330, name='Soul Enslavement', job='DRK'},
    [331] = {id=331, name='Unleash', job='BST'},
    [332] = {id=332, name='Clarion Call', job='BRD'},
    [333] = {id=333, name='Overkill', job='RNG'},
    [334] = {id=334, name='Yaegasumi', job='SAM'},
    [335] = {id=335, name='Mikage', job='NIN'},
    [336] = {id=336, name='Fly High', job='DRG'},
    [337] = {id=337, name='Astral Conduit', job='SMN'},
    [338] = {id=338, name='Unbridled Wisdom', job='BLU'},
    [339] = {id=339, name='Cutting Cards', job='COR'},
    [340] = {id=340, name='Heady Artifice', job='PUP'},
    [341] = {id=341, name='Grand Pas', job='DNC'},
    [342] = {id=342, name='Caper Emissarius', job='SCH'},
    [343] = {id=343, name='Bolster', job='GEO'},
    [345] = {id=345, name='Full Circle', job='GEO'},
    [346] = {id=346, name='Lasting Emanation', job='GEO'},
    [347] = {id=347, name='Ecliptic Attrition', job='GEO'},
    [349] = {id=349, name='Life Cycle', job='GEO'},
    [350] = {id=350, name='Blaze of Glory', job='GEO'},
    [351] = {id=351, name='Dematerialize', job='GEO'},
    [352] = {id=352, name='Theurgic Focus', job='GEO'},
    [353] = {id=353, name='Concentric Pulse', job='GEO'},
    [354] = {id=354, name='Mending Halation', job='GEO'},
    [355] = {id=355, name='Radial Arcana', job='GEO'},
    [356] = {id=356, name='Elemental Sforzo', job='RUN'},
    [370] = {id=370, name='Embolden', job='RUN'},
    [372] = {id=372, name='Gambit', job='RUN'},
    [373] = {id=373, name='Liement', job='RUN'},
    [374] = {id=374, name='One for All', job='RUN'},
    [375] = {id=375, name='Rayke', job='RUN'},
    [376] = {id=376, name='Battuta', job='RUN'},
    [377] = {id=377, name='Widened Compass', job='GEO'},
    [378] = {id=378, name='Odyllic Subterfuge', job='RUN'},
    [381] = {id=381, name='Chocobo Jig II', job='DNC'},
    [383] = {id=383, name='Vivacious Pulse', job='RUN'},
    [385] = {id=385, name='Apogee', job='SMN'},
    [386] = {id=386, name='Entrust', job='GEO'},
    [388] = {id=388, name='Cascade', job='BLM'},
    [390] = {id=390, name='Naturalist\'s Roll', job='COR'},
    [391] = {id=391, name='Runeist\'s Roll', job='COR'},
    [392] = {id=392, name='Crooked Cards', job='COR'},
    [393] = {id=393, name='Spirit Bond', job='DRG'},
    [394] = {id=394, name='Majesty', job='PLD'},
    [395] = {id=395, name='Hover Shot', job='RNG'},
  }
}

-- 'levels' param indicates which jobs gain access to spells at which levels. JP are also indicated in the same way.
for _,spell in pairs(res.spells) do
  local levels = spell.levels
  if levels then
    local count = 0
    local job_id
    local lv
    for job,level in pairs(levels) do
      count = count + 1
      job_id = job
      lv = level
    end
    if count == 1 and lv > 59 then -- Unique
      local job_short = res.jobs[job_id] and res.jobs[job_id].ens
      if job_short then
        unique_actions['Magic'][spell.id] = {id=spell.id, name=spell.name, job=job_short}
      else
        print('Problem injesting spell '..spell.id)
      end
    end
  end
end

function deduce_job_from_action(act)
  if not act or act.actor_id == player.id then return end -- We always know our own job

  -- If caster is an anon party member, try to deduce their job
  local caster = get_member(act.actor_id, nil, true)
  if not caster or not caster.is_anon then return end

  local category
  local action_id
  if act.category == 8 then
    category = 'Magic'
    action_id = act.targets[1] and act.targets[1].actions[1] and act.targets[1].actions[1].param
  elseif act.category == 6 or act.category == 14 or act.category == 15 then
    category = 'Job Abilities'
    action_id = act.param
  end
  
  if not category or not action_id then return end -- Not an action we can use for this

  -- Check if action is unique to one job
  local unique_action = unique_actions[category][action_id]
  
  -- If job is different than current job, update job and also set sub to unknown
  if unique_action and caster.main ~= unique_action.job then
    caster.main = unique_action.job
    caster.main_lv = 99
    caster.sub = ''
    caster.sub_lv = 0
    update_ui_text()
  end
end

-- Using data from incoming packet 0x0C9 Type 3, triggered when examining a player
function deduce_job_from_examination(packet)
  -- Get player and determine if it's an anonymous party member
  local member = get_member(packet['Target ID'], nil, true)

  -- Only need to deduce job for players who are in party and anon
  if member and member.is_anon then
    local jobs

    -- Iterate through all possible items in packet and find the intersection of all items
    for i=1,8 do
      local item_id = packet['Item '..i]
      if not item_id then break end
      
      local item_jobs = res.items[item_id].jobs
      if item_jobs then
          if jobs then
              jobs = jobs:intersection(item_jobs)
          else
              jobs = item_jobs
          end
          if jobs and jobs:length() <= 1 then
              break
          end
      end
    end

    -- If the intersection of all items leaves us with only 1 job, we know what job the player is
    if jobs:length() == 1 then
      local job_id = next(jobs)
      local job = res.jobs[job_id].ens
      if member.main ~= job then -- Update player's job
        member.main = job
        member.main_lv = 99
        member.sub = ''
        member.sub_lv = 0
        update_ui_text()
      end
    end
  end
end