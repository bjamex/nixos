# Logitech mouse batteries in the Noctalia bar. The built-in battery widget
# reads UPower, which only sees the kernel's hidpp driver: that gives the G305 a
# coarse "Full" level and doesn't expose the MX Master on the Bolt receiver at
# all. OpenLogi talks HID++ itself and reports real percentages for both, so a
# small local plugin polls `openlogi list` and shows them.
#
# Only the CLI is used — never run openlogi-agent: its mouse-event capture
# re-emits the G305 through a uinput "virtual mouse" and mangled left click
# (presses held into key-repeat), leaving left click dead in Hyprland.
#
# Kept out of noctalia.nix so the plugin, its source and its bar slot travel
# together; the bar slot is prepended to the right-hand group via mkBefore.
{ ... }:
{
  flake.nixosModules.logiBattery =
    { pkgs, lib, ... }:
    let
      plugins = pkgs.runCommand "noctalia-styx-plugins" { } ''
        mkdir -p $out/logi_battery
        cp ${pluginToml} $out/logi_battery/plugin.toml
        cp ${widgetLuau} $out/logi_battery/widget.luau
      '';

      pluginToml = pkgs.writeText "plugin.toml" ''
        id          = "styx/logi_battery"
        name        = "Logitech battery"
        version     = "1.0.0"
        plugin_api  = 3
        author      = "styx"
        icon        = "mouse"
        description = "Battery level of connected Logitech HID++ mice, via OpenLogi."

        [[widget]]
        id    = "battery"
        entry = "widget.luau"
      '';

      # `openlogi list` probes every HID++ node, which takes ~20s (it retries
      # receiver interfaces that never answer), so it runs async with the 60s
      # max timeout and polls slowly — battery moves a percent an hour at most.
      widgetLuau = pkgs.writeText "widget.luau" ''
        local POLL_MS = 5 * 60 * 1000
        local LOW = 15
        local busy = false

        noctalia.setUpdateInterval(POLL_MS)
        barWidget.setGlyph("mouse")

        -- Lines look like:
        --   └─ slot 1 ● G305 (mouse, wpid=4074, battery=90% full (discharging))
        -- ● is a connected device, ○ a paired-but-asleep slot. A mouse paired
        -- to two receiver slots shows twice, so dedupe by name.
        local function parse(out)
          local devices, seen = {}, {}
          for line in string.gmatch(out, "[^\n]+") do
            local name, pct, state =
              string.match(line, "\u{25CF} (.-) %(.-battery=(%d+)%%[^(]*%((%a+)%)")
            if name and not seen[name] then
              seen[name] = true
              table.insert(devices, { name = name, pct = tonumber(pct), charging = state == "charging" })
            end
          end
          return devices
        end

        local function short(name)
          if string.find(name, "MX Master", 1, true) then
            return "MX"
          end
          return name
        end

        local function show(devices)
          if #devices == 0 then
            barWidget.setVisible(false)
            return
          end
          local parts, rows, low = {}, {}, false
          for _, d in ipairs(devices) do
            local mark = d.charging and "+" or ""
            table.insert(parts, short(d.name) .. " " .. d.pct .. "%" .. mark)
            table.insert(rows, { key = d.name, value = d.pct .. "%" .. (d.charging and " (charging)" or "") })
            if d.pct <= LOW and not d.charging then
              low = true
            end
          end
          barWidget.setText(table.concat(parts, "  "))
          barWidget.setTooltip(rows)
          if low then
            barWidget.setColor("error")
            barWidget.setGlyphColor("error")
          else
            barWidget.setColor("on_surface")
            barWidget.setGlyphColor("on_surface")
          end
          barWidget.setVisible(true)
        end

        local function refresh()
          if busy then
            return
          end
          busy = true
          noctalia.runAsync("${lib.getExe' pkgs.openlogi "openlogi"} list 2>/dev/null", function(result)
            busy = false
            if result.timedOut or result.exitCode ~= 0 then
              noctalia.log("openlogi list failed: exit " .. tostring(result.exitCode))
              return
            end
            show(parse(result.stdout))
          end, 60000)
        end

        function update()
          refresh()
        end

        function onClick()
          refresh()
        end

        refresh()
      '';
    in
    {
      # uaccess on Logitech hidraw nodes, so `openlogi list` can probe as the user.
      services.udev.packages = [ pkgs.openlogi ];

      hjem.users.swin.programs.noctalia.settings = {
        plugins = {
          enabled = [ "styx/logi_battery" ];
          source = [
            {
              name = "styx";
              kind = "path";
              location = "${plugins}";
              enabled = true;
            }
          ];
        };

        widget.mouse_battery.type = "styx/logi_battery:battery";
        bar.main.end = lib.mkBefore [ "mouse_battery" ];
      };
    };
}
