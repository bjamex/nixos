-- Focus Rite — an eldritch Pomodoro bar widget.
--
-- Built on the [[widget]] (bar-widget) API:
--   barWidget.setText / setGlyph / setColor / setTooltip   presentation
--   barWidget.getConfig(key)                               manifest settings
--   update()        ticks on noctalia.setUpdateInterval(ms)
--   onClick()       left-click  → stay / unbind the rite (start / pause)
--   onRightClick()  right-click → sever the rite (skip to the next phase)
--
-- The countdown is deadline-based (os.clock()) like the official timer plugin,
-- so it stays accurate even if a tick is late. Colours use semantic theme roles
-- (primary/secondary/tertiary/error) so the widget follows the Eldritch palette.

local workMin = barWidget.getConfig("work") or 25
local shortMin = barWidget.getConfig("short") or 5
local longMin = barWidget.getConfig("long") or 15
local rounds = barWidget.getConfig("rounds") or 4
local autoStart = barWidget.getConfig("auto_start") == true

local DURATION = {
  work = workMin * 60,
  short = shortMin * 60,
  long = longMin * 60,
}
local MIN = { work = workMin, short = shortMin, long = longMin }

-- Per-phase flavour: sigil, name, bar glyph, semantic colour, opening whisper.
local SIGIL = { work = "⸸", short = "☽", long = "✶" }
local NAME = { work = "THE RITUAL", short = "THE VEIL THINS", long = "DESCENT INTO SLUMBER" }
local GLYPH = { work = "flame", short = "moon", long = "bed" }
local COLOR = { work = "primary", short = "secondary", long = "tertiary" }
local OPENING = {
  work = "The Old Ones demand your focus.",
  short = "The veil thins. Breathe, mortal.",
  long = "Descend into the deep. Rest now.",
}

local INCANTATIONS = {
  "ɪᴀ! ɪᴀ! the work-thing waits in the deep",
  "that is not dead which can eternal toil",
  "do not gaze away — it gazes back",
  "the unfocused mind is a door left ajar",
  "bind your attention ere it is devoured",
  "ph'nglui mglw'nafh — the task lies dreaming",
  "the abyss rewards the steadfast eye",
  "every wandering thought feeds the Old Ones",
}

local phase = "work"
local remaining = DURATION.work
local running = false
local deadline = 0 -- os.clock() value at which remaining hits zero
local completed = 0 -- focus rites brought to their end
local whisper = INCANTATIONS[1]

local function pickWhisper()
  whisper = INCANTATIONS[math.random(#INCANTATIONS)]
end

local function fmt(seconds)
  return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

-- The phase that follows the current one, without mutating anything.
local function peekNext()
  if phase == "work" then
    return ((completed + 1) % rounds == 0) and "long" or "short"
  end
  return "work"
end

local function render()
  barWidget.setGlyph(GLYPH[phase])
  barWidget.setText(fmt(remaining))

  if remaining == 0 then
    barWidget.setColor("error")
  elseif running then
    barWidget.setColor(COLOR[phase])
  else
    barWidget.setColor("on_surface_variant") -- muted while stayed/idle
  end

  local done = completed % rounds
  local eyes = string.rep("◉ ", done) .. string.rep("◯ ", rounds - done)
  local nxt = peekNext()
  local state = running and "" or "  (stayed)"
  barWidget.setTooltip(
    `{SIGIL[phase]} {NAME[phase]}{state}\n`
      .. `{fmt(remaining)} remaining\n`
      .. `{eyes} ·  rites completed: {completed}\n`
      .. `next: {NAME[nxt]} ({MIN[nxt]}m)\n`
      .. `"{whisper}"\n`
      .. `left: stay / unbind  ·  right: sever`
  )
end

-- Move to the next phase (paused unless auto_start), and whisper its dawning.
local function advance()
  if phase == "work" then
    completed += 1
    phase = (completed % rounds == 0) and "long" or "short"
  else
    phase = "work"
  end
  remaining = DURATION[phase]
  running = autoStart
  if running then
    deadline = os.clock() + remaining
  end
  pickWhisper()
  noctalia.notify(`{SIGIL[phase]} {NAME[phase]}`, OPENING[phase])
end

function update()
  noctalia.setUpdateInterval(1000)
  if running then
    remaining = math.max(0, math.ceil(deadline - os.clock()))
    if remaining == 0 then
      running = false
      advance() -- the rite ends; the next one dawns
    end
  end
  render()
end

-- Left-click: stay / unbind the rite (start / pause).
function onClick()
  if remaining == 0 then
    advance()
  end
  running = not running
  if running then
    deadline = os.clock() + remaining
  end
  render()
end

-- Right-click: sever the rite (skip straight to the next phase).
function onRightClick()
  advance()
  render()
end

-- Show the rite at rest the moment it loads.
render()
