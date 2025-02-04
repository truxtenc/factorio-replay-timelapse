-- Output settings
local resolution = {x = 1920, y = 1080}  -- Output image resolution (1080p)
-- local resolution = {x = 3840, y = 2160}  -- Output image resolution (4k)
local framerate = 60                     -- Timelapse frames per second
local speedup = 600                      -- Game seconds per timelapse second
local watch_rocket_launch = false        -- If true, slow down to real time and zoom in on first rocket launch

local output_dir = "replay-timelapse"    -- Output directory (relative to Factorio script output directory)
local screenshot_filename_pattern = output_dir .. "/%08d-base.png"
local rocket_screenshot_filename_pattern = output_dir .. "/%08d-rocket.png"
local research_progress_filename = output_dir .. "/research-progress.csv"
local events_filename = output_dir .. "/events.csv"

-- Camera movement parameters
local min_zoom = 0.03125 * 2             -- Min zoom level (widest field of view)
local max_zoom = 0.5                     -- Max zoom level (narrowest field of view)
local rocket_min_zoom = min_zoom / 2     -- Min zoom level after zooming out from rocket launch
local margin_fraction = 0.05             -- Fraction of screen to leave as margin on each edge
local shrink_threshold = 0.75            -- Shrink base boundary when base width or height is less than this fraction of it
local shrink_delay_s = 3                 -- Seconds to wait since last boundary expansion before shrinking base boundary
local shrink_time_s = 2                  -- Seconds to complete a boundary shrink
local shrink_abort_transition_s = 0.5    -- Seconds of smooth transition after aborting a shrink
local recently_built_seconds = 2         -- When at minimum zoom, track buildings built in the last this many seconds
local base_bbox_lerp_step = 0.35         -- Exponential approach factor for base boundary tracking
local camera_lerp_step = 0.35            -- Exponential approach factor for camera movement
local camera_rocket_lerp_step = 0.05     -- Exponential approach factor for camera movement while zooming in on rocket silo
local rocket_watch_delay_s = 1           -- Seconds to keep zooming out after rocket disappears
local rocket_linger_s = 6                -- Seconds to linger after fully zooming out from rocket launch
local linger_zoom_in_s = 30              -- Seconds to zoom in after lingering after rocket launch
local linger_end_zoom = min_zoom         -- Final zoom level after zooming in after lingering
local linger_end_s = 10                  -- Seconds to wait at final zoom level after zooming back in


-- Game constants
local tick_per_s = 60
local tile_size_px = 32
local min_zoom_hard = 0.03125            -- Minimum zoom allowed by the game
local rocket_launch_ticks = 1163

-- Derived parameters
local resolution_correction = math.max(resolution.x / 1920, resolution.y / 1080)
min_zoom = math.max(min_zoom_hard, min_zoom * resolution_correction)
max_zoom = max_zoom * resolution_correction
linger_end_zoom = math.max(min_zoom_hard, linger_end_zoom * resolution_correction)
local nth_tick = tick_per_s * speedup / framerate
local recently_built_ticks = recently_built_seconds * tick_per_s * speedup
local margin_expansion_factor = 1 + (2 * margin_fraction)
local shrink_delay_ticks = shrink_delay_s * tick_per_s * speedup
local shrink_time_ticks = shrink_time_s * tick_per_s * speedup
local shrink_abort_recovery_ticks = shrink_abort_transition_s * tick_per_s * speedup
local rocket_watch_delay_ticks = tick_per_s * rocket_watch_delay_s
local rocket_linger_ticks = rocket_launch_ticks + tick_per_s * (rocket_watch_delay_s + rocket_linger_s)
local rocket_watch_ticks = rocket_launch_ticks + tick_per_s * (rocket_watch_delay_s + rocket_linger_s + linger_zoom_in_s + linger_end_s)
local rocket_zoom_delay_ticks = rocket_launch_ticks * 0.4
local rocket_zoom_out_ticks = rocket_launch_ticks - rocket_zoom_delay_ticks + rocket_watch_delay_ticks
local linger_zoom_in_ticks = linger_zoom_in_s * tick_per_s


function adjust_lerp_step_from_30fps_to_60fps(lerp_step)
  return 1 - math.sqrt(1 - lerp_step)
end

if framerate == 60 then
  base_bbox_lerp_step = adjust_lerp_step_from_30fps_to_60fps(base_bbox_lerp_step)
  camera_lerp_step = adjust_lerp_step_from_30fps_to_60fps(camera_lerp_step)
  camera_rocket_lerp_step = adjust_lerp_step_from_30fps_to_60fps(camera_rocket_lerp_step)
end


-- Return the bounding box of an entity.
function entity_bbox(entity)
  return {
    l = entity.bounding_box.left_top.x,
    r = entity.bounding_box.right_bottom.x,
    t = entity.bounding_box.left_top.y,
    b = entity.bounding_box.right_bottom.y,
  }
end

-- Compute the smallest bounding box containing the union of two bounding boxes.
function expand_bbox(bbox_a, bbox_b)
  return {
    l = math.floor(math.min(bbox_a.l, bbox_b.l or bbox_a.l)),
    r = math.ceil(math.max(bbox_a.r, bbox_b.r or bbox_a.r)),
    t = math.floor(math.min(bbox_a.t, bbox_b.t or bbox_a.t)),
    b = math.ceil(math.max(bbox_a.b, bbox_b.b or bbox_a.b)),
  }
end

-- Linearly interpolate between two bounding boxes.
-- t: Interpolation parameter in the interval [0, 1]
function lerp_bbox(bbox_a, bbox_b, t)
  local s = 1 - t
  return {
    l = s * bbox_a.l + t * bbox_b.l,
    r = s * bbox_a.r + t * bbox_b.r,
    t = s * bbox_a.t + t * bbox_b.t,
    b = s * bbox_a.b + t * bbox_b.b,
  }
end

-- Linearly interpolate only the x axis between two bounding boxes.
-- t: Interpolation parameter in the interval [0, 1]
function lerp_bbox_x(bbox_a, bbox_b, t)
  local s = 1 - t
  return {
    l = s * bbox_a.l + t * bbox_b.l,
    r = s * bbox_a.r + t * bbox_b.r,
    t = bbox_a.t,
    b = bbox_a.b,
  }
end

-- Linearly interpolate only the y axis between two bounding boxes.
-- t: Interpolation parameter in the interval [0, 1]
function lerp_bbox_y(bbox_a, bbox_b, t)
  local s = 1 - t
  return {
    l = bbox_a.l,
    r = bbox_a.r,
    t = s * bbox_a.t + t * bbox_b.t,
    b = s * bbox_a.b + t * bbox_b.b,
  }
end

-- Linear interpolation between two numbers
-- t: Interpolation parameter in the interval [0, 1]
function lerp(a, b, t)
  return (1 - t) * a + t * b
end

-- Sinusoidal interpolation between 0 and 1
-- t: Interpolation parameter in the interval [0, 1]
function sirp(t)
  return (math.sin((t - 0.5) * math.pi) + 1) / 2
end


-- Ease-in interpolation between 0 and 1
-- t: Interpolation parameter in the interval [0, 1]
-- f: Interpolation point where easing ends
function ease_in(t, f)
  local alpha = 1 / (1 + math.pi/2 * (1/f - 1))

  if t <= f then
      return alpha * (1 - math.cos(t / (f / (math.pi/2))))
  else
    return (1 - alpha) / (1 - f) * (t - f) + alpha;
  end
end


-- Ease-out interpolation between 0 and 1
-- t: Interpolation parameter in the interval [0, 1]
-- f: Interpolation point from end where easing ends
function ease_out(t, f)
  return 1 - ease_in(1 - t, f)
end


-- Ease-in-out interpolation between 0 and 1
-- t: Interpolation parameter in the interval [0, 1]
-- f: Interpolation point from start and end where easing ends
function ease_in_out(t, f)
  if t < 0.5 then
    return ease_in(t * 2, f * 2) / 2
  else
    return ease_out((t - 0.5) * 2, f * 2) / 2 + 0.5
  end
end


-- Clamp number within a range
-- t: Number to clamp
-- t_min: Minimum value for t
-- t_max: Maximum value for t
function clamp(t, t_min, t_max)
  return math.max(t_min, math.min(t_max, t))
end

-- Linear interpolation between two cameras
-- t: Interpolation factor in the interval [0, 1]
-- Position and zoom are interpolated, desired zoom is taken from camera_b.
function lerp_camera(camera_a, camera_b, t)
  local s = 1 - t
  return {
    position = {
      x = s * camera_a.position.x + t * camera_b.position.x,
      y = s * camera_a.position.y + t * camera_b.position.y,
    },
    zoom = s * camera_a.zoom + t * camera_b.zoom,
    desired_zoom = camera_b.desired_zoom,
  }
end

-- Compute the smallest bounding box containing the union
-- of a list of lists of bounding boxes.
-- bboxess: list of lists of bounding boxes
function bbox_union_flattened(bboxess)
  local result = {}
  for _, bboxes in ipairs(bboxess) do
    for _, bbox in ipairs(bboxes) do
      result = expand_bbox(bbox, result)
    end
  end
  return result
end

-- Compute the smallest bounding box covering all of the player's buildings.
function base_bbox()
  local entities = game.surfaces[1].find_entities_filtered{force = "player"}
  local result = {}
  for _, entity in ipairs(entities) do
    if entity.type ~= "character" and entity.type ~= "car" and entity.name ~= "crash-site-spaceship" then
      result = expand_bbox(entity_bbox(entity), result)
    end
  end
  return result
end

-- Compute a camera view centered on and zoomed out (as far as allowed) to cover a bounding box.
function compute_camera(bbox)
  local center = { x = (bbox.l + bbox.r) / 2, y = (bbox.t + bbox.b) / 2 }

  local w_tile = bbox.r - bbox.l
  local h_tile = bbox.b - bbox.t

  local w_px = w_tile * tile_size_px * margin_expansion_factor
  local h_px = h_tile * tile_size_px * margin_expansion_factor

  local desired_zoom = math.min(1, resolution.x / w_px, resolution.y / h_px)
  local zoom = math.min(max_zoom, math.max(min_zoom, desired_zoom))

  return {
    position = center,
    zoom = zoom,
    desired_zoom = desired_zoom,
  }
end

-- Compute a camera view optimized for watching a rocket launch.
function compute_rocket_camera(event, rocket_silo, rocket_launch_start_tick)
  local bbox = entity_bbox(rocket_silo)
  local h_tile = resolution.y / tile_size_px
  local center = {
    x = (bbox.l + bbox.r) / 2,
    y = (bbox.t + bbox.b) / 2 - h_tile / 4,
  }

  local zoom = 1
  if event.tick < rocket_launch_start_tick + rocket_linger_ticks then
    zoom = lerp(
      1,
      rocket_min_zoom,
      ease_in_out(
        clamp(
          (event.tick - (rocket_launch_start_tick + rocket_zoom_delay_ticks)) / rocket_zoom_out_ticks,
          0,
          1
        ),
        3 * tick_per_s / rocket_zoom_out_ticks
      )
    )
  else
    zoom = lerp(
      rocket_min_zoom,
      linger_end_zoom,
      ease_in_out(
        clamp(
          (event.tick - (rocket_launch_start_tick + rocket_linger_ticks)) / linger_zoom_in_ticks,
          0,
          1
        ),
        2 / linger_zoom_in_s
      )
    )
  end

  return {
    position = center,
    zoom = zoom,
    desired_zoom = zoom,
  }
end

-- Compute a new camera with the same settings but a displaced position.
function translate_camera(camera, dxy)
  return {
    position = {
      x = camera.position.x + dxy.x,
      y = camera.position.y + dxy.y,
    },
    zoom = camera.zoom,
    desired_zoom = camera.desired_zoom,
  }
end

-- Compute the bounding box for a camera's view, excluding the margins.
function camera_bbox(camera)
  local f = 2 * camera.zoom * tile_size_px * margin_expansion_factor
  return {
    l = camera.position.x - resolution.x / f,
    r = camera.position.x + resolution.x / f,
    t = camera.position.y - resolution.y / f,
    b = camera.position.y + resolution.y / f,
  }
end

-- If the camera is larger than the bounding box, move the camera as little as
-- possible to cover the bounding box.
-- If the camera is smaller than the bounding box, move the camera as little as
-- possible to be within the bounding box.
-- This applies to each dimension independently.
function pan_camera_to_cover_bbox(camera, bbox)
  if bbox.l ~= nil then
    local cbb = camera_bbox(camera)
    local bbox_w = bbox.r - bbox.l
    local bbox_h = bbox.b - bbox.t
    local camera_w = cbb.r - cbb.l
    local camera_h = cbb.b - cbb.t

    if camera_w < bbox_w then
      if cbb.l < bbox.l then
        camera = translate_camera(camera, { x = bbox.l - cbb.l, y = 0 })
      elseif cbb.r > bbox.r then
        camera = translate_camera(camera, { x = bbox.r - cbb.r, y = 0 })
      end
    else
      if bbox.l < cbb.l then
        camera = translate_camera(camera, { x = bbox.l - cbb.l, y = 0 })
      elseif bbox.r > cbb.r then
        camera = translate_camera(camera, { x = bbox.r - cbb.r, y = 0 })
      end
    end

    if camera_h < bbox_h then
      if cbb.t < bbox.t then
        camera = translate_camera(camera, { x = 0, y = bbox.t - cbb.t })
      elseif cbb.b > bbox.b then
        camera = translate_camera(camera, { x = 0, y = bbox.b - cbb.b })
      end
    else
      if bbox.t < cbb.t then
        camera = translate_camera(camera, { x = 0, y = bbox.t - cbb.t })
      elseif bbox.b > cbb.b then
        camera = translate_camera(camera, { x = 0, y = bbox.b - cbb.b })
      end
    end
  end

  return camera
end

-- Compute an ffmpeg time duration expressing the given frame count.
function frame_to_timestamp(frame)
  local s = math.floor(frame / framerate)
  local m = math.floor(s / 60)
  local h = math.floor(m / 60)
  local f = frame % framerate
  return string.format("%02d:%02d:%02d:%02d", h, m % 60, s % 60, f)
end

-- Write CSV headers to the research progress files.
function init_research_csv()
  helpers.write_file(
    events_filename,
    string.format("%s,%s,%s,%s\n", "tick", "frame", "timestamp", "event"),
    false
  )
  helpers.write_file(
    research_progress_filename,
    string.format("%s,%s,%s,%s,%s,%s\n", "state", "tick", "frame", "timestamp", "research_name", "research_progress"),
    false
  )
end

function run()
  local bbox = { l = -30, r = 30, t = -30, b = 30 }
  local current_camera = compute_camera(bbox)
  local last_expansion = 0
  local last_expansion_bbox = bbox
  local recently_built_bboxes = {{}, {}, {}}
  local shrink_start_tick = nil
  local shrink_start_camera = nil
  local shrink_abort_tick = nil
  local shrink_abort_camera = nil
  local frame_num = 0
  local watching_rocket_silo = nil
  local rocket_start_tick = nil
  local rocket_smoothing_camera = nil

  function watch(tick)
    local filename_pattern = screenshot_filename_pattern
    if watching_rocket_silo then
      filename_pattern = rocket_screenshot_filename_pattern
    end

    -- Iterate through all surfaces and take a screenshot of each
    for _, surface in pairs(game.surfaces) do
      -- Add surface name to filename to distinguish between different surfaces
      local base_filename = string.format(filename_pattern, frame_num)
      local surface_filename = base_filename:gsub(".png$", "_" .. surface.name .. ".png")
      
      game.take_screenshot{
        surface = surface,
        position = current_camera.position,
        resolution = {resolution.x, resolution.y},
        zoom = current_camera.zoom,
        path = surface_filename,
        show_entity_info = true,
        daytime = 0,
        allow_in_replay = true,
        anti_alias = true,
        force_render = true,
      }
    end

    local force = game.players[1].force
    if force.current_research then
      local research = force.current_research
      helpers.write_file(
        research_progress_filename,
        string.format(
          "current,%s,%s,%s,%s,%s\n",
          tick,
          frame_num,
          frame_to_timestamp(frame_num),
          research.name,
          force.research_progress
        ),
        true
      )
    else
      helpers.write_file(
        research_progress_filename,
        string.format(
          "none,%s,%s,%s,,\n",
          tick,
          frame_num,
          frame_to_timestamp(frame_num)
        ),
        true
      )
    end

    frame_num = frame_num + 1
  end

  function watch_base(event)
    if event.tick == 0 then
      init_research_csv()
    end

    local base_bb = base_bbox()
    local expanded_bbox = expand_bbox(bbox, base_bb)
    if (expanded_bbox.l < last_expansion_bbox.l)
      or (expanded_bbox.r > last_expansion_bbox.r)
      or (expanded_bbox.t < last_expansion_bbox.t)
      or (expanded_bbox.b > last_expansion_bbox.b)
    then
      last_expansion = event.tick
      last_expansion_bbox = expanded_bbox
    end

    if shrink_start_tick ~= nil and shrink_abort_tick == nil then
      local current_camera_bbox = camera_bbox(current_camera)
      if (base_bb.l < current_camera_bbox.l)
        or (base_bb.r > current_camera_bbox.r)
        or (base_bb.t < current_camera_bbox.t)
        or (base_bb.b > current_camera_bbox.b)
      then
        shrink_abort_tick = event.tick
        shrink_abort_camera = current_camera
      end
    end

    if base_bb.l ~= nil and shrink_start_tick == nil and (event.tick - last_expansion) >= shrink_delay_ticks then
      local target_bbox = bbox
      local shrinking = false
      if (base_bb.r - base_bb.l) / (bbox.r - bbox.l) < shrink_threshold then
        target_bbox = lerp_bbox_x(target_bbox, base_bb, 1)
        shrinking = true
      end
      if (base_bb.b - base_bb.t) / (bbox.b - bbox.t) < shrink_threshold then
        target_bbox = lerp_bbox_y(target_bbox, base_bb, 1)
        shrinking = true
      end

      if shrinking then
        shrink_start_tick = event.tick
        shrink_start_camera = current_camera
        shrink_abort_tick = nil
        shrink_abort_camera = nil
        bbox = base_bb
        last_expansion = event.tick
        last_expansion_bbox = bbox
      end
    else
      bbox = lerp_bbox(bbox, expanded_bbox, base_bbox_lerp_step)
    end

    local bbox_target_camera = compute_camera(bbox)
    if bbox_target_camera.desired_zoom < min_zoom then
      local recent_bbox = bbox_union_flattened(recently_built_bboxes)
      bbox_target_camera = pan_camera_to_cover_bbox(
        {
          position = current_camera.position,
          zoom = bbox_target_camera.zoom,
          desired_zoom = current_camera.zoom,
        },
        recent_bbox
      )
    end

    local shrink_target_camera = nil
    if shrink_start_tick ~= nil then
      local shrink_tick = event.tick - shrink_start_tick
      if (shrink_abort_tick == nil and shrink_tick > shrink_time_ticks)
        or (shrink_abort_tick ~= nil and event.tick - shrink_abort_tick >= shrink_abort_recovery_ticks)
      then
        shrink_start_tick = nil
        shrink_start_camera = nil
        shrink_abort_tick = nil
        shrink_abort_camera = nil
        shrinking_w = false
        shrinking_h = false
      else
        shrink_target_camera = lerp_camera(
          shrink_start_camera,
          bbox_target_camera,
          sirp(shrink_tick / shrink_time_ticks)
        )
      end
    end

    local target_camera = bbox_target_camera
    if shrink_abort_tick ~= nil and shrink_abort_camera ~= nil then
      target_camera = lerp_camera(
        shrink_abort_camera,
        bbox_target_camera,
        (event.tick - shrink_abort_tick) / shrink_abort_recovery_ticks
      )
    elseif shrink_target_camera ~= nil then
      target_camera = shrink_target_camera
    end
    current_camera = lerp_camera(current_camera, target_camera, camera_lerp_step)

    watch(event.tick)
  end

  function watch_rocket(event)
    local target_camera = compute_rocket_camera(event, watching_rocket_silo, rocket_start_tick)
    if event.tick < rocket_start_tick + rocket_zoom_delay_ticks then
      rocket_smoothing_camera = lerp_camera(rocket_smoothing_camera or current_camera, target_camera, camera_rocket_lerp_step)
      current_camera = lerp_camera(current_camera, rocket_smoothing_camera, camera_rocket_lerp_step)
    else
      current_camera = target_camera
    end
    watch(event.tick)
  end

  script.on_nth_tick(nth_tick, watch_base)

  script.on_event(
    defines.events.on_research_finished,
    function (event)
      helpers.write_file(
        events_filename,
        string.format(
          "%s,%s,%s,%s,%s,",
          event.tick,
          frame_num,
          frame_to_timestamp(frame_num),
          "research-finished",
          event.research.name
        ),
        true
      )
      helpers.write_file(events_filename, event.research.localised_name, true)
      helpers.write_file(events_filename, "\n", true)
    end
  )

  script.on_event(
    defines.events.on_built_entity,
    function (event)
      local idx = (event.tick % recently_built_ticks) + 1
      recently_built_bboxes[idx] = recently_built_bboxes[idx] or {}
      table.insert(recently_built_bboxes[idx], entity_bbox(event.entity))
    end
  )

  script.on_event(
    defines.events.on_tick,
    function (event)
      local idx = ((event.tick + 1) % recently_built_ticks) + 1
      recently_built_bboxes[idx] = {}

      if watching_rocket_silo then
        watch_rocket(event)
        if event.tick - rocket_start_tick >= rocket_watch_ticks then
          watching_rocket_silo = nil
        end
      end
    end
  )

  script.on_event(
    defines.events.on_rocket_launched,
    function (event)
      helpers.write_file(
        events_filename,
        string.format(
          "%s,%s,%s,%s\n",
          event.tick,
          frame_num,
          frame_to_timestamp(frame_num),
          "rocket-launched"
        ),
        true
      )
    end
  )

  script.on_event(
    defines.events.on_rocket_launch_ordered,
    function (event)
      helpers.write_file(
        events_filename,
        string.format(
          "%s,%s,%s,%s\n",
          event.tick,
          frame_num,
          frame_to_timestamp(frame_num),
          "rocket-launch-ordered"
        ),
        true
      )
      if watch_rocket_launch and (watching_rocket_silo == nil) then
        script.on_nth_tick(nil)
        rocket_start_tick = event.tick
        watching_rocket_silo = event.rocket_silo
      end
    end
  )
end

return {
  run = run,
}
