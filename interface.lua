-------------------------------------------------------------------------------
-- UI Functions
-------------------------------------------------------------------------------

function load_ui(ui_s)
  local temp_ui = texts.new('${value}', ui_s.display)
  
  temp_ui.value = 'HasteInfo Loading/Broken...'

  return temp_ui
end

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

  local default_color = reports_paused and inline_red or inline_white

  -- Get stats to display and report
  local dw_needed = stats.dual_wield.actual_needed > -1 and tostring(stats.dual_wield.actual_needed) or 'N/A'
  if stats.dual_wield.actual_needed == 0 then
    -- Change to green if capped
    dw_needed = inline_green..dw_needed..default_color
  end
  local total_haste = settings.show_fractions and tostring(stats.haste.total.actual.fraction) or string.format('%.1f', stats.haste.total.actual.percent)
  if stats.haste.total.actual.fraction == haste_caps.total.fraction then
    -- Change to green if capped
    total_haste = inline_green..total_haste..default_color
  end
  local perc = settings.show_fractions and '' or '%'
  local dw_traits = ''
  local ma_haste = ''
  local ja_haste = ''
  local eq_haste = ''
  local debuff = ''

  if settings.summary_mode == 2 then
    dw_traits = stats.dual_wield.traits
    ma_haste = settings.show_fractions and stats.haste.ma.actual.fraction or string.format('%.1f', stats.haste.ma.actual.percent)
    if stats.haste.ma.actual.fraction == haste_caps.ma.fraction then
      ma_haste = inline_green..ma_haste..default_color
    end
    ja_haste = settings.show_fractions and stats.haste.ja.actual.fraction or string.format('%.1f', stats.haste.ja.actual.percent)
    if stats.haste.ja.actual.fraction == haste_caps.ja.fraction then
      ja_haste = inline_green..ja_haste..default_color
    end
    eq_haste = settings.show_fractions and stats.haste.eq.actual.fraction or string.format('%.1f', stats.haste.eq.actual.percent)
    if stats.haste.eq.actual.fraction == haste_caps.eq.fraction then
      eq_haste = inline_green..eq_haste..default_color
    end
    debuff = settings.show_fractions and stats.haste.debuff.actual.fraction or string.format('%.1f', stats.haste.debuff.actual.percent)
    if stats.haste.debuff.actual.fraction > 0 then
      debuff = inline_red..'-'..debuff..default_color
    end
  end

  -- Create text line-by-line
  local lines = T{}

  if settings.summary_mode > 0 then
    local str = ' '..default_color
    if dw_needed == -1 then
      str = str..'DW: N/A'
    else
      str = str..'DW Needed: '..dw_needed
      if settings.summary_mode == 2 then
        str = str..' ('..dw_traits..' from traits)'
      end
    end
    str = str..' | Haste: '..total_haste..perc
    str = str..(settings.show_fractions and '/1024' or '')
    if settings.summary_mode == 2 then
      str = str..' ('..ma_haste..perc..' MA, '..ja_haste..perc..' JA, '..eq_haste..perc..' EQ, '..debuff..perc..' Debuff)'
    end
    lines:append(str)
  end
  
  if settings.show_party then
    local me = get_member(player.id, player.name, true)
    for p in players:it() do
      local main_str = (not p.main and '???') or (p.main=='' and '???') or p.main
      local sub_str = (not p.sub and '???') or (p.sub=='' and '???') or p.sub
      local name_str = (not p.name and p.id) or (p.name=='' and p.id) or p.name
      local str = main_str..'/'..sub_str..' '..name_str
      -- Grey out the line if player is out of zone
      if not is_in_zone(p) then
        str = inline_gray..str..default_color
      end
      lines:append(str)
    end
  end

  if settings.show_breakdown then
    -- Make sure player is being tracked and has buffs
    local me = get_member(player.id, player.name, true)
    if me and me.haste_effects then
      local line_count = settings.summary_mode == 0 and 1 or 2
      -- Initialize current line as empty string if doesn't exist
      local current_line = lines[line_count] or ''

      -- Add samba effect to display
      if not is_samba_expired(me) then
        -- Add divider to current line
        current_line = current_line..divider_str(current_line)
        local effect = samba_stats
        local samba_str = ''
        local potency_str = potency_str(me.samba.potency)
        samba_str = samba_str..potency_str..' '..effect.triggering_action
        lines[line_count] = current_line..samba_str

        line_count = line_count + 1 -- Increment line for next effect
      end

      -- Add song effects to display
      for effect in me.songs:it() do
        -- Update to current line
        current_line = lines[line_count] or ''

        -- Add divider to current line
        current_line = current_line..divider_str(current_line)

        local effect_str = '' -- Format as: buff icon <space> potency <space> triggering action name
        local potency = math.floor(effect.potency * total_multiplier(effect.multipliers, SONG_JA_MULTIPLIER_MAX))
        local potency_str = potency_str(potency)
        effect_str = effect_str..potency_str..' '.. effect.triggering_action
        lines[line_count] = current_line..effect_str

        line_count = line_count + 1 -- Increment line for next effect
      end
  
      -- Add haste effects to display
      for effect in me.haste_effects:it() do
        -- Update to current line
        current_line = lines[line_count] or ''

        -- Add divider to current line
        current_line = current_line..divider_str(current_line)

        local effect_str = '' -- Format as: <space(s)> potency <space> triggering action name
        local potency = effect.potency
        if effect.trigger_sub_category=='Geomancy' then
          potency = math.floor(effect.potency * total_multiplier(effect.multipliers, GEOMANCY_JA_MULTIPLIER_MAX))
        end
        local potency_str = potency_str(potency, effect.haste_category == 'debuff')
        effect_str = effect_str..potency_str..' '.. effect.triggering_action
        lines[line_count] = current_line..effect_str

        line_count = line_count + 1 -- Increment line for next effect
      end
      
      -- Add geo effects to display
      local effect = get_geomancy_effect(me)
      if effect then
        -- Update to current line
        current_line = lines[line_count] or ''

        -- Add divider to current line
        current_line = current_line..divider_str(current_line)

        local effect_str = '' -- Format as: <space(s)> potency <space> triggering action name
        local potency_str = potency_str(effect.potency, effect.haste_category == 'debuff')
        effect_str = effect_str..potency_str..' '.. effect.triggering_action
        lines[line_count] = current_line..effect_str

        line_count = line_count + 1 -- Increment line for next effect
      end
    end
  end

  -- Compose new text by combining all lines into a single string separated by line breaks
  local str = lines:concat('\n ')

  ui:text(str)
end

-- Adds spaces as needed to format potency column
function potency_str(potency, is_debuff)
  potency = settings.show_fractions and potency or string.format('%.1f', percent(potency))
  local potency_str = ''
  local potency_space_count = (4 + (is_debuff and 0 or 1)) - tostring(potency):length()

  -- Add spaces before potency
  for i=1,potency_space_count do
    potency_str = potency_str..' '
  end
  potency_str = potency_str..(is_debuff and '-' or '')..tostring(potency)..(settings.show_fractions and '' or '%')
  return potency_str
end

-- Adds spaces as needed to format divider string between party info and haste effects
function divider_str(current_line)
  -- Add divider to current line (if needed)
  local divider_str = ''

  if settings.show_party then
    -- If inline coloring is included, don't include that in the character count
    local current_line_len
    if current_line and current_line:startswith('\\') and current_line:length() >= 32 then
      current_line_len = current_line:sub(17,current_line:length()-16):length()
    else
      current_line_len = current_line and current_line:length() or 0
    end
    
    -- Include 8 characters for main/sub column
    local forespace_count = 8 + NAME_MAX_CHAR_COUNT - current_line_len
    for i=0,forespace_count do
      divider_str = divider_str..' '
    end
    divider_str = divider_str..' |'
  end

  return divider_str
end
