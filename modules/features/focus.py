#!/usr/bin/env python3
"""focus — an eldritch Pomodoro rite to bind your wandering mind.

The Ritual (work), the Veil Thinning (short break) and the Descent into
Slumber (long break) cycle in turn, marked by a great flickering countdown,
watching eyes for each completed rite, a low drone at every turning, and a
whispered notification from the deep.

Palette follows the Eldritch colorscheme (violet / fungal green / abyssal
cyan), approximated to xterm-256. Noctalia is left untouched.

Keys:
  space  stay / unbind the rite (pause / resume)
  s      sever the rite (skip to next phase)
  r      begin the rite anew (restart current phase)
  q      banish (quit)
"""

import argparse
import atexit
import curses
import math
import random
import shutil
import struct
import subprocess
import tempfile
import time
import wave

# 5-row block font for the great countdown.
FONT = {
    "0": ["█████", "█   █", "█   █", "█   █", "█████"],
    "1": ["   ██", "  ███", "   ██", "   ██", "  ███"],
    "2": ["█████", "    █", "█████", "█    ", "█████"],
    "3": ["█████", "    █", " ████", "    █", "█████"],
    "4": ["█   █", "█   █", "█████", "    █", "    █"],
    "5": ["█████", "█    ", "█████", "    █", "█████"],
    "6": ["█████", "█    ", "█████", "█   █", "█████"],
    "7": ["█████", "    █", "   █ ", "  █  ", "  █  "],
    "8": ["█████", "█   █", "█████", "█   █", "█████"],
    "9": ["█████", "█   █", "█████", "    █", "█████"],
    ":": ["   ", " ◉ ", "   ", " ◉ ", "   "],
}

GLITCH_CHARS = "▓▒░▚▞▙▟╳#%@"

# Whispers that drift across the bottom of the veil.
INCANTATIONS = [
    "ɪᴀ! ɪᴀ! the work-thing waits in the deep",
    "that is not dead which can eternal toil",
    "do not gaze away — it gazes back",
    "the unfocused mind is a door left ajar",
    "bind your attention ere it is devoured",
    "ph'nglui mglw'nafh — the task lies dreaming",
    "the abyss rewards the steadfast eye",
    "every wandering thought feeds the Old Ones",
]


def notify(title, body):
    if shutil.which("notify-send"):
        try:
            subprocess.run(["notify-send", "-a", "focus", title, body], check=False)
        except OSError:
            pass


# ── The drone ─────────────────────────────────────────────────────────────


def _synth(base, kind):
    """Render a short, ominous drone to a temp WAV and return its path."""
    sr = 44100
    dur = 3.2 if kind == "work" else 2.4
    n = int(sr * dur)
    if kind == "work":
        # Fundamental + fifth + octave + a quiet tritone for unease, sinking.
        partials = [(1.0, 0.9), (1.5, 0.45), (2.0, 0.3), (2 ** 0.5, 0.12)]
        glide, trem_hz, trem_depth, fade_out = -0.02, 4.0, 0.18, 1.0
    else:
        # Brighter, shimmering — the veil lifting.
        partials = [(1.0, 0.8), (1.5, 0.4), (2.0, 0.35), (3.0, 0.12)]
        glide, trem_hz, trem_depth, fade_out = 0.015, 6.0, 0.10, 0.8
    fade_in_n = int(sr * 0.4)
    fade_out_n = int(sr * fade_out)
    weight = sum(a for _, a in partials)

    frames = bytearray()
    for i in range(n):
        t = i / sr
        pitch = base * (1 + glide * (t / dur))
        s = sum(a * math.sin(2 * math.pi * pitch * m * t) for m, a in partials)
        s /= weight
        trem = 1 - trem_depth + trem_depth * 0.5 * (1 + math.sin(2 * math.pi * trem_hz * t))
        if i < fade_in_n:
            env = i / fade_in_n
        elif i > n - fade_out_n:
            env = (n - i) / fade_out_n
        else:
            env = 1.0
        val = int(max(-1.0, min(1.0, s * trem * env * 0.28)) * 32767)
        frames += struct.pack("<h", val)

    f = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    with wave.open(f, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(bytes(frames))
    return f.name


class Drone:
    def __init__(self):
        self.enabled = bool(shutil.which("paplay"))
        self.paths = {}
        if not self.enabled:
            return
        try:
            self.paths["work"] = _synth(58.27, "work")  # ~Bb1, the descent
            self.paths["break"] = _synth(98.0, "break")  # ~G2, the lifting
            for p in self.paths.values():
                atexit.register(lambda path=p: shutil.os.unlink(path))
        except Exception:
            self.enabled = False

    def play(self, phase):
        if not self.enabled:
            return
        path = self.paths["work"] if phase == "work" else self.paths["break"]
        try:
            subprocess.Popen(
                ["paplay", path],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except OSError:
            pass


# ── The rite ────────────────────────────────────────────────────────────────


def big(text):
    """Render text into 5 rows of block characters."""
    rows = ["", "", "", "", ""]
    for ch in text:
        glyph = FONT.get(ch, ["     "] * 5)
        for i in range(5):
            rows[i] += glyph[i] + " "
    return rows


def corrupt(s, p):
    """Randomly replace non-space glyph cells with static — the glitch."""
    if p <= 0:
        return s
    return "".join(
        random.choice(GLITCH_CHARS) if (c != " " and random.random() < p) else c
        for c in s
    )


class Pomodoro:
    # phase -> (sigil, name, whisper at its dawning)
    PHASES = {
        "work": ("⸸", "THE RITUAL", "The Old Ones demand your focus."),
        "short": ("☽", "THE VEIL THINS", "The veil thins. Breathe, mortal."),
        "long": ("✶", "DESCENT INTO SLUMBER", "Descend into the deep. Rest now."),
    }

    def __init__(self, work, short, long, rounds, drone=None):
        self.durations = {"work": work, "short": short, "long": long}
        self.rounds = rounds
        self.drone = drone
        self.completed = 0  # rites of focus brought to their end
        self.phase = "work"
        self.remaining = self.durations["work"]
        self.paused = False

    def sigil(self):
        return self.PHASES[self.phase][0]

    def name(self):
        return self.PHASES[self.phase][1]

    def next_phase(self, announce=True):
        if self.phase == "work":
            self.completed += 1
            nxt = "long" if self.completed % self.rounds == 0 else "short"
        else:
            nxt = "work"
        self.phase = nxt
        self.remaining = self.durations[nxt]
        self.paused = False
        if announce:
            notify(f"{self.sigil()} {self.name()}", self.PHASES[nxt][2])
            if self.drone:
                self.drone.play(nxt)

    def restart(self):
        self.remaining = self.durations[self.phase]
        self.paused = False

    def tick(self):
        if self.paused:
            return
        if self.remaining > 0:
            self.remaining -= 1
            if self.remaining == 0:
                self.next_phase()


def phase_pair(phase):
    return {"work": 1, "short": 2, "long": 3}[phase]


def draw(stdscr, p, whisper):
    stdscr.erase()
    h, w = stdscr.getmaxyx()

    # A flicker spasm now and then — corrupt the banner heavily, digits faintly.
    glitch = random.random() < 0.07
    label_p = random.uniform(0.06, 0.18) if glitch else 0.0
    clock_p = random.uniform(0.02, 0.05) if glitch else 0.0

    mins, secs = divmod(max(p.remaining, 0), 60)
    clock = big(f"{mins:02d}:{secs:02d}")
    block_w = len(clock[0])
    color = curses.color_pair(phase_pair(p.phase))

    # The rite's name, crowned with sigils — flickers like dying neon.
    sig = p.sigil()
    label = f"{sig}  {'⟂ STAYED ⟂  ' if p.paused else ''}{p.name()}  {sig}"
    label = corrupt(label, label_p)
    title_attr = color | (curses.A_DIM if (glitch and random.random() < 0.5) else curses.A_BOLD)
    top = max(0, h // 2 - 4)
    stdscr.addnstr(
        max(0, top - 2),
        max(0, (w - len(label)) // 2),
        label,
        max(0, w - 1),
        title_attr,
    )

    # The great countdown.
    for i, line in enumerate(clock):
        line = corrupt(line, clock_p)
        x = max(0, (w - block_w) // 2)
        if top + i < h:
            stdscr.addnstr(top + i, x, line, max(0, w - x - 1), color | curses.A_BOLD)

    # Watching eyes — one opens for each rite of focus completed this cycle.
    done = p.completed % p.rounds
    eyes = "◉ " * done + "◯ " * (p.rounds - done)
    stdscr.addnstr(
        min(h - 4, top + 6),
        max(0, (w - len(eyes)) // 2),
        eyes.rstrip(),
        max(0, w - 1),
        color,
    )

    tally = f"rites completed: {p.completed}"
    stdscr.addnstr(
        min(h - 3, top + 7),
        max(0, (w - len(tally)) // 2),
        tally,
        max(0, w - 1),
        curses.A_DIM,
    )

    # A whisper from the deep.
    stdscr.addnstr(
        min(h - 2, top + 9),
        max(0, (w - len(whisper)) // 2),
        whisper,
        max(0, w - 1),
        curses.A_DIM | curses.A_ITALIC,
    )

    rites = "space stay · s sever · r anew · q banish"
    stdscr.addnstr(
        h - 1, max(0, (w - len(rites)) // 2), rites, max(0, w - 1), curses.A_DIM
    )
    stdscr.noutrefresh()
    curses.doupdate()


def init_colors():
    """Eldritch palette — violet / fungal green / abyssal cyan."""
    curses.use_default_colors()
    if curses.COLORS >= 256:
        violet, rot, abyss = 141, 49, 45  # ~#a48cf2 / #37f499 / #04d1f9
    else:
        violet, rot, abyss = curses.COLOR_MAGENTA, curses.COLOR_GREEN, curses.COLOR_CYAN
    curses.init_pair(1, violet, -1)  # the ritual
    curses.init_pair(2, rot, -1)  # the veil thins
    curses.init_pair(3, abyss, -1)  # the descent


def run(stdscr, p):
    curses.curs_set(0)
    init_colors()
    stdscr.nodelay(True)

    whisper = random.choice(INCANTATIONS)
    notify(f"{p.sigil()} {p.name()}", "The rite begins. Do not look away.")
    if p.drone:
        p.drone.play("work")
    last = time.monotonic()
    last_whisper = last
    while True:
        draw(stdscr, p, whisper)

        ch = stdscr.getch()
        if ch != -1:
            key = chr(ch) if 0 <= ch < 256 else ""
            if key in ("q", "Q"):
                return
            elif key == " ":
                p.paused = not p.paused
            elif key in ("s", "S"):
                p.next_phase(announce=False)
            elif key in ("r", "R"):
                p.restart()

        now = time.monotonic()
        if now - last >= 1.0:
            last = now
            p.tick()
        if now - last_whisper >= 12.0:
            last_whisper = now
            whisper = random.choice(INCANTATIONS)
        time.sleep(0.05)


def main():
    ap = argparse.ArgumentParser(description="An eldritch Pomodoro focus rite.")
    ap.add_argument("-w", "--work", type=int, default=25, help="ritual minutes (25)")
    ap.add_argument("-s", "--short", type=int, default=5, help="veil-thinning minutes (5)")
    ap.add_argument("-l", "--long", type=int, default=15, help="slumber minutes (15)")
    ap.add_argument("-r", "--rounds", type=int, default=4, help="rituals before the long slumber (4)")
    ap.add_argument("--silent", action="store_true", help="forsake the drone")
    args = ap.parse_args()

    drone = None if args.silent else Drone()
    p = Pomodoro(args.work * 60, args.short * 60, args.long * 60, args.rounds, drone)
    try:
        curses.wrapper(run, p)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
