data:extend({
  {
    type = "int-setting",
    name = "replay-timelapse-resolution-x",
    setting_type = "runtime-global",
    default_value = 1920,
    minimum_value = 640,
    maximum_value = 7680,
    order = "a1"
  },
  {
    type = "int-setting",
    name = "replay-timelapse-resolution-y",
    setting_type = "runtime-global",
    default_value = 1080,
    minimum_value = 480,
    maximum_value = 4320,
    order = "a2"
  },
  {
    type = "int-setting",
    name = "replay-timelapse-framerate",
    setting_type = "runtime-global",
    default_value = 60,
    minimum_value = 1,
    maximum_value = 240,
    order = "b"
  },
  {
    type = "int-setting",
    name = "replay-timelapse-speedup",
    setting_type = "runtime-global",
    default_value = 600,
    minimum_value = 1,
    maximum_value = 10000,
    order = "c"
  },
  {
    type = "bool-setting",
    name = "replay-timelapse-watch-rocket-launch",
    setting_type = "runtime-global",
    default_value = false,
    order = "d"
  },
  {
    type = "string-setting",
    name = "replay-timelapse-output-dir",
    setting_type = "runtime-global",
    default_value = "replay-timelapse",
    order = "e"
  },
  -- Camera settings
  {
    type = "double-setting",
    name = "replay-timelapse-min-zoom",
    setting_type = "runtime-global",
    default_value = 0.125,
    minimum_value = 0.03125,
    maximum_value = 1.0,
    order = "f1"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-max-zoom",
    setting_type = "runtime-global",
    default_value = 0.5,
    minimum_value = 0.03125,
    maximum_value = 1.0,
    order = "f2"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-rocket-min-zoom",
    setting_type = "runtime-global",
    default_value = 0.0625,
    minimum_value = 0.03125,
    maximum_value = 1.0,
    order = "f3"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-margin-fraction",
    setting_type = "runtime-global",
    default_value = 0.05,
    minimum_value = 0,
    maximum_value = 0.5,
    order = "g"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-shrink-threshold",
    setting_type = "runtime-global",
    default_value = 0.75,
    minimum_value = 0,
    maximum_value = 1,
    order = "h1"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-shrink-delay",
    setting_type = "runtime-global",
    default_value = 3,
    minimum_value = 0,
    maximum_value = 60,
    order = "h2"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-shrink-time",
    setting_type = "runtime-global",
    default_value = 2,
    minimum_value = 0,
    maximum_value = 60,
    order = "h3"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-shrink-abort-transition",
    setting_type = "runtime-global",
    default_value = 0.5,
    minimum_value = 0,
    maximum_value = 10,
    order = "h4"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-recently-built-seconds",
    setting_type = "runtime-global",
    default_value = 2,
    minimum_value = 0,
    maximum_value = 60,
    order = "i1"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-base-bbox-lerp-step",
    setting_type = "runtime-global",
    default_value = 0.35,
    minimum_value = 0,
    maximum_value = 1,
    order = "i2"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-camera-lerp-step",
    setting_type = "runtime-global",
    default_value = 0.35,
    minimum_value = 0,
    maximum_value = 1,
    order = "i3"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-camera-rocket-lerp-step",
    setting_type = "runtime-global",
    default_value = 0.05,
    minimum_value = 0,
    maximum_value = 1,
    order = "i4"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-rocket-watch-delay",
    setting_type = "runtime-global",
    default_value = 1,
    minimum_value = 0,
    maximum_value = 60,
    order = "j1"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-rocket-linger",
    setting_type = "runtime-global",
    default_value = 6,
    minimum_value = 0,
    maximum_value = 60,
    order = "j2"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-linger-zoom-in",
    setting_type = "runtime-global",
    default_value = 30,
    minimum_value = 0,
    maximum_value = 120,
    order = "j3"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-linger-end-zoom",
    setting_type = "runtime-global",
    default_value = 0.125,
    minimum_value = 0.03125,
    maximum_value = 1.0,
    order = "j4"
  },
  {
    type = "double-setting",
    name = "replay-timelapse-linger-end",
    setting_type = "runtime-global",
    default_value = 10,
    minimum_value = 0,
    maximum_value = 60,
    order = "j5"
  }
}) 