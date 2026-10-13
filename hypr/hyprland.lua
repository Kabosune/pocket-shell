hl.monitor({ output = "DSI-1", mode = "1080x1920@60", position = "auto", scale = 2, transform = 1 })

hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
end)

hl.config({
    general    = { gaps_in = 0, gaps_out = 0, border_size = 0 },
    decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } },
    animations = { enabled = true },
    misc       = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0 },
    ecosystem  = { no_update_news = true, no_donation_nag = true },
    input      = { kb_layout = "us", touchdevice = { output = "DSI-1", transform = 1 } },
})

-- Hardware volume buttons: work everywhere, in games too ("locked" also
-- covers a locked screen). Pocket Shell shows the level on screen.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

hl.config({ debug = { disable_logs = false } })
