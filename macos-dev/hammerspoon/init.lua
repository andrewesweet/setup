-- hammerspoon/init.lua — Desktop Layer 2 keyboard foundation.
--
-- Sole responsibility: Caps Lock tap → Escape; Caps Lock hold → Hyper
-- (Cmd+Alt+Ctrl+Shift applied to the next keypress). Nothing else.
--
-- Spec: docs/plans/2026-04-14-macos-desktop-env-design.md §3.4.
-- Requires: Accessibility permission for Hammerspoon.app.
-- Requires: "Launch Hammerspoon at login" toggled in Hammerspoon prefs.

local THRESHOLD_MS = 200  -- tap-vs-hold distinction (~humanly imperceptible on hold)
local CAPS_LOCK_KEYCODE = 57

-- State tracked across the keyDown/keyUp callback invocations.
local state = {
  caps_down_at = nil,     -- hs.timer.secondsSinceEpoch() when Caps pressed
  next_is_hyper = false,  -- set on Caps release when hold threshold exceeded
  sent_hyper_for_current_hold = false,
}

-- Modifier table applied to the next keypress when we synthesise a Hyper
-- chord. ALL FOUR modifiers are required so skhd sees an unambiguous
-- "Hyper" without competing with Cmd-only or Alt-only bindings.
local HYPER_MODS = { cmd = true, alt = true, ctrl = true, shift = true }

local function millis_since(t)
  return (hs.timer.secondsSinceEpoch() - t) * 1000
end

local function on_caps_event(event)
  local t = event:getType()
  local keycode = event:getKeyCode()

  if keycode ~= CAPS_LOCK_KEYCODE then
    -- Foreign key press WHILE Caps is held: inject Hyper modifiers.
    if state.caps_down_at and t == hs.eventtap.event.types.keyDown then
      if millis_since(state.caps_down_at) >= THRESHOLD_MS then
        state.sent_hyper_for_current_hold = true
        event:setFlags(HYPER_MODS)
      end
    end
    return false  -- let the (possibly-modified) event through
  end

  if t == hs.eventtap.event.types.keyDown then
    if not state.caps_down_at then
      state.caps_down_at = hs.timer.secondsSinceEpoch()
      state.sent_hyper_for_current_hold = false
    end
    return true   -- swallow the raw Caps Lock down event
  end

  if t == hs.eventtap.event.types.keyUp then
    local held_ms = state.caps_down_at and millis_since(state.caps_down_at) or 0
    if held_ms < THRESHOLD_MS and not state.sent_hyper_for_current_hold then
      -- Tap → Escape.
      hs.eventtap.keyStroke({}, "escape", 0)
    end
    state.caps_down_at = nil
    state.sent_hyper_for_current_hold = false
    return true   -- swallow the raw Caps Lock up event
  end

  return false
end

-- Wrap registration in pcall so a runtime error surfaces in the console
-- rather than crashing the Hammerspoon daemon. Menu-bar icon stays
-- responsive for "Reload Config" regardless.
local ok, err = pcall(function()
  caps_tap = hs.eventtap.new(
    { hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp },
    on_caps_event
  )
  caps_tap:start()
end)

if not ok then
  hs.alert.show("Hammerspoon init error: " .. tostring(err))
  print("init.lua pcall failed: " .. tostring(err))
end
