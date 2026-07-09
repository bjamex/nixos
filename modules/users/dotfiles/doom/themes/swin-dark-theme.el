;;; swin-dark-theme.el --- a personal eldritch-based dark theme -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;;; Commentary:
;; A custom Doom theme using the authentic Eldritch palette (pulled from
;; Saboti/eldritch.emacs), remapped onto Doom's theme slots so you can tweak it
;; freely. Edit a `#rrggbb' (the "default" column) and run `M-x doom/reload-theme'
;; (or `SPC h r t') to see changes live — no `doom sync'.
;;
;; Eldritch palette reference:
;;   bg #212337  fg #ebfafa  red #f16c75  orange #f7c67f  yellow #f1fc79
;;   green #37f499  cyan/blue #04d1f9  magenta/pink #f265b5  purple #a48cf2
;;   comment #7081d0
;;
;;; Code:

(require 'doom-themes)

(defgroup swin-dark-theme nil
  "Options for the `swin-dark' theme."
  :group 'doom-themes)

(defcustom swin-dark-padded-modeline doom-themes-padded-modeline
  "If non-nil, adds a 4px padding to the mode-line. Can be an integer."
  :group 'swin-dark-theme
  :type '(choice integer boolean))

(def-doom-theme swin-dark
  "A personal dark theme using the Eldritch palette."
  :family 'swin-dark
  :background-mode 'dark

  ;; name        default     256          16
  ((bg         '("#212337" "black"       "black"        )) ; Sunken Depths Grey
   (fg         '("#ebfafa" "#bfbfbf"     "brightwhite"  )) ; Lighthouse White

   (bg-alt     '("#171928" "black"       "black"        )) ; darker bg variant
   (fg-alt     '("#abb4da" "#bfbfbf"     "white"        )) ; darker fg variant

   ;; bg -> fg ramp, using eldritch's blue-grey scale
   (base0      '("#171928" "black"       "black"        ))
   (base1      '("#212337" "#1e1e1e"     "brightblack"  ))
   (base2      '("#292e42" "#2e2e2e"     "brightblack"  )) ; highlight bg
   (base3      '("#323449" "#262626"     "brightblack"  )) ; current line
   (base4      '("#3d3f54" "#3f3f3f"     "brightblack"  ))
   (base5      '("#494c63" "#525252"     "brightblack"  ))
   (base6      '("#5866a2" "#6b6b6b"     "brightblack"  ))
   (base7      '("#7081d0" "#979797"     "brightblack"  )) ; The Old One Purple
   (base8      '("#abb4da" "#dfdfdf"     "white"        ))

   (grey       base4)
   (red        '("#f16c75" "#ff6655" "red"          )) ; R'lyeh Red
   (orange     '("#f7c67f" "#dd8844" "brightred"    )) ; Dreaming Orange
   (green      '("#37f499" "#99bb66" "green"        )) ; Great Old One Green
   (teal       '("#33c57f" "#44b9b1" "brightgreen"  )) ; darker green
   (yellow     '("#f1fc79" "#ECBE7B" "yellow"       )) ; Gold of Yuggoth
   (blue       '("#04d1f9" "#51afef" "brightblue"   )) ; Watery Tomb Blue
   (dark-blue  '("#10a1bd" "#2257A0" "blue"         )) ; darker cyan
   (magenta    '("#f265b5" "#c678dd" "brightmagenta")) ; Pustule Pink
   (violet     '("#a48cf2" "#a9a1e1" "magenta"      )) ; Lovecraft Purple
   (cyan       '("#04d1f9" "#46D9FF" "brightcyan"   )) ; Watery Tomb Blue
   (dark-cyan  '("#10a1bd" "#5699AF" "cyan"         ))

   ;; Mandatory "universal syntax classes" — every doom theme must set these.
   (highlight      violet)
   (vertical-bar   (doom-darken base1 0.1))
   (selection      base3)
   (builtin        magenta)
   (comments       base7)                     ; eldritch's purple comments
   (doc-comments   (doom-lighten base7 0.15))
   (constants      violet)
   (functions      green)
   (keywords       cyan)
   (methods        cyan)
   (operators      blue)
   (type           yellow)
   (strings        yellow)
   (variables      fg)
   (numbers        orange)
   (region         base2)
   (error          red)
   (warning        yellow)
   (success        green)
   (vc-modified    cyan)
   (vc-added       green)
   (vc-deleted     red)

   ;; Theme-local extras (modeline).
   (modeline-fg              fg)
   (modeline-fg-alt          base6)
   (modeline-bg              bg-alt)
   (modeline-bg-alt          base1)
   (modeline-bg-inactive     `(,(car bg-alt) ,@(cdr base1)))
   (modeline-bg-inactive-alt (doom-darken bg-alt 0.05))

   (-modeline-pad
    (when swin-dark-padded-modeline
      (if (integerp swin-dark-padded-modeline) swin-dark-padded-modeline 4))))


  ;;;; Base theme face overrides
  (((line-number &override) :foreground base4)
   ((line-number-current-line &override) :foreground fg)
   (mode-line
    :background modeline-bg :foreground modeline-fg
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg)))
   (mode-line-inactive
    :background modeline-bg-inactive :foreground modeline-fg-alt
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg-inactive)))
   (mode-line-emphasis :foreground highlight))

  ;;;; Base theme variable overrides
  ())

;;; swin-dark-theme.el ends here
