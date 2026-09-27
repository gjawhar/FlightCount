-- Flight Counter 2 -- storage, model identity, totals and the counting rules.
-- Everything that touches a file lives here; draw/screen only read core.view().
--
-- Data lives in a SIBLING folder of the script (SCRIPTS:/FlightCountData/),
-- so installing or updating the script can never replace it:
--   models.csv   one line per model: key,file,rxid,name,created,v1
--   M<k>.csv     that model's append-only log: ts,date,kind,n,extra
-- Log kinds: f = flight (n=1), u = undo (n=-1, extra = date of the undone
-- flight), b = flights before Flight Counter (latest wins), e = erase (all
-- earlier rows ignored), id = provenance (name/file at the time).
-- A log is never rewritten, so a glitch can at worst lose the line being
-- written, never the history. A log that exists but cannot be read is an
-- ERROR state (shown as dashes), never "empty": v1 lost counts exactly by
-- treating a failed read as zero.

local core = {}

core.VERSION = "2.0.0"

local DEDUPE_SEC   = 5     -- two widgets firing for the same activation
local RETRY_SEC    = 1
local JUST_SEC     = 5     -- "Flight N logged" pill
local DIAG_CAP     = 300
local V1_DIRS      = { "SCRIPTS:/FlightCount/Files/", "/scripts/FlightCount/Files/" }
local DATA_DIRS    = { "SCRIPTS:/FlightCountData/", "/scripts/FlightCountData/" }
local MODEL_DIRS   = { "/models/", "RADIO:/models/", "SD:/models/", "/", "RADIO:/", "SD:/" }
local SETTLE_SEC   = 3     -- a changed model file name gets this long to settle

local S = {
  dir = nil,            -- resolved data folder
  modelsDir = false,    -- false = not resolved yet, nil = unknown (never adopt)
  index = nil,          -- array of records, nil until models.csv was read
  indexError = nil,
  key = nil,            -- bound model key
  rec = nil,            -- bound record
  path = nil, name = nil,
  loaded = false,       -- log read successfully for the bound model
  loadError = nil,
  log = nil,            -- parsed log (see parseLog)
  pending = {},         -- rows not yet written: { key=, fields= }
  lastLoggedAt = nil,   -- os.time() of the last flight logged this power-up
  countedThisPower = {},-- key -> true once a flight was logged this power-up
  just = nil,           -- { n=, at= } for the "logged" pill
  note = nil,           -- { text=, at=, sec= } one-time notices (v1 pre-fill)
  retryAt = 0,
  diagLost = 0, diagCount = nil,
  bootAt = nil, bootRowDone = false,
  pathSeenAt = nil,     -- first wakeup that saw a different model file name
  version = 0,          -- bumps whenever totals change (view cache)
  viewCache = nil, viewAt = nil, viewVersion = nil,
}
core.S = S

-- One counting state per model, shared by every widget (see core.poll).
local function newCounter()
  return { seenOff = false, startAt = nil, latched = false, state = "idle" }
end

-- ---------------------------------------------------------------- time

local function today(t) return os.date("%Y-%m-%d", t or os.time()) end
core.today = today

local function ymOf(date) return string.sub(date or "", 1, 7) end

-- ---------------------------------------------------------------- files

local function exists(p)
  if os.stat then
    local ok, st = pcall(os.stat, p)
    if ok then return st ~= nil, st end
  end
  local f = io.open(p, "r")
  if f then f:close() return true, nil end
  return false, nil
end
core.exists = exists

local function readAll(f)
  local chunks = {}
  while true do
    local chunk = f:read(2048)
    if not chunk or chunk == "" then break end
    chunks[#chunks + 1] = chunk
    if #chunk < 2048 then break end
  end
  return table.concat(chunks)
end

-- Returns content, nil on success; nil, "missing" when the file does not
-- exist; nil, <reason> when it exists but could not be read in full.
local function readFile(p)
  local present, st = exists(p)
  if not present then return nil, "missing" end
  local f = io.open(p, "r")
  if not f then return nil, "open failed" end
  local ok, content = pcall(readAll, f)
  pcall(function() f:close() end)
  if not ok then return nil, "read failed" end
  content = content or ""
  if st and type(st.size) == "number" and st.size > 0 and #content < st.size then
    return nil, "short read " .. #content .. "/" .. st.size
  end
  return content, nil
end
core.readFile = readFile

local function splitLine(line)
  local out = {}
  for field in string.gmatch(line .. ",", "([^,]*),") do out[#out + 1] = field end
  return out
end

local function lines(content)
  local rows = {}
  for line in (content or ""):gmatch("[^\r\n]+") do
    if line ~= "" and string.sub(line, 1, 1) ~= "#" then rows[#rows + 1] = splitLine(line) end
  end
  return rows
end

local function clean(s) return (tostring(s or ""):gsub("[,\r\n]", " ")) end

local function appendLine(p, fields)
  local f = io.open(p, "a")
  if not f then return false end
  local ok = pcall(function() f:write(table.concat(fields, ",") .. "\n") end)
  pcall(function() f:close() end)
  return ok
end

-- models.csv is the only file ever rewritten: written to a temp file first,
-- then renamed over the old one, so a failed write leaves the old index.
local function writeIndex()
  if not S.dir or not S.index then return false end
  local tmp, real = S.dir .. "models.tmp", S.dir .. "models.csv"
  local f = io.open(tmp, "w")
  if not f then return false end
  local ok = pcall(function()
    f:write("# Flight Counter 2 models: key,file,rxid,name,created,v1\n")
    for i = 1, #S.index do
      local r = S.index[i]
      f:write(table.concat({ r.key, clean(r.file), clean(r.rxid), clean(r.name), r.created or "", r.v1 or "" }, ",") .. "\n")
    end
  end)
  pcall(function() f:close() end)
  if not ok then return false end
  if os.rename then
    if exists(real) and os.remove then pcall(os.remove, real) end
    local rok, rres = pcall(os.rename, tmp, real)
    if rok and rres ~= nil and rres ~= false then return true end
  end
  -- No working rename: fall back to a direct write of the real file.
  f = io.open(real, "w")
  if not f then return false end
  ok = pcall(function()
    f:write("# Flight Counter 2 models: key,file,rxid,name,created,v1\n")
    for i = 1, #S.index do
      local r = S.index[i]
      f:write(table.concat({ r.key, clean(r.file), clean(r.rxid), clean(r.name), r.created or "", r.v1 or "" }, ",") .. "\n")
    end
  end)
  pcall(function() f:close() end)
  return ok
end

-- ---------------------------------------------------------------- diag

local function diag(code, detail)
  if not S.dir then return false end
  detail = clean(detail)
  if S.diagLost > 0 then detail = detail .. " lost=" .. S.diagLost end
  local ok = appendLine(S.dir .. "diag.csv", { tostring(os.time()), clean(S.name or "?"), code, detail })
  if ok then
    S.diagLost = 0
    S.diagCount = (S.diagCount or 0) + 1
    if S.diagCount > DIAG_CAP + 50 then
      local content = readFile(S.dir .. "diag.csv")
      if content then
        local rows = lines(content)
        local f = io.open(S.dir .. "diag.csv", "w")
        if f then
          for i = math.max(1, #rows - DIAG_CAP + 1), #rows do f:write(table.concat(rows[i], ",") .. "\n") end
          f:close()
          S.diagCount = math.min(#rows, DIAG_CAP)
        end
      end
    end
  else
    S.diagLost = S.diagLost + 1
  end
  return ok
end
core.diag = diag

-- ---------------------------------------------------------------- folders

local function resolveDataDir()
  -- A folder that already holds models.csv wins, so two boots can never
  -- split the data between two spellings of the same place.
  for i = 1, #DATA_DIRS do
    if exists(DATA_DIRS[i] .. "models.csv") then return DATA_DIRS[i] end
  end
  for i = 1, #DATA_DIRS do
    local d = DATA_DIRS[i]
    if os.mkdir then pcall(os.mkdir, string.sub(d, 1, -2)) end
    local p = d .. "probe.tmp"
    local f = io.open(p, "w")
    if f then
      f:write("x"); f:close()
      if os.remove then pcall(os.remove, p) end
      return d
    end
  end
  return nil
end

local function resolveModelsDir(path)
  if not path or path == "" then return nil end
  for i = 1, #MODEL_DIRS do
    if exists(MODEL_DIRS[i] .. path) then return MODEL_DIRS[i] end
  end
  return nil
end

-- ---------------------------------------------------------------- model

local function modelPath()
  local ok, p = pcall(model.path)
  if ok and type(p) == "string" and p ~= "" then return p end
  return nil
end

local function modelName()
  local ok, n = pcall(model.name)
  if ok and type(n) == "string" and n ~= "" then return n end
  return "Model"
end

local function modelRxid()
  local ok, ids = pcall(model.id)
  if not ok or type(ids) ~= "table" then return "" end
  local parts = {}
  for i = 1, #ids do parts[#parts + 1] = tostring(ids[i]) end
  return table.concat(parts, "|")
end

-- ---------------------------------------------------------------- index

local function loadIndex()
  local content, err = readFile(S.dir .. "models.csv")
  if err == "missing" then
    S.index, S.indexError = {}, nil
    return true
  end
  if not content then
    S.indexError = err
    return false
  end
  local idx = {}
  for _, r in ipairs(lines(content)) do
    if r[1] and r[1] ~= "" then
      idx[#idx + 1] = { key = r[1], file = r[2] or "", rxid = r[3] or "", name = r[4] or "",
                        created = r[5] or "", v1 = r[6] or "" }
    end
  end
  S.index, S.indexError = idx, nil
  return true
end

local function findBy(field, value)
  for i = 1, #S.index do
    if S.index[i][field] == value then return S.index[i] end
  end
  return nil
end

local function nextKey()
  local maxN = 0
  for i = 1, #S.index do
    local n = tonumber(string.match(S.index[i].key, "^M(%d+)$") or "")
    if n and n > maxN then maxN = n end
  end
  return "M" .. (maxN + 1)
end

local function logPath(key) return S.dir .. key .. ".csv" end

-- ---------------------------------------------------------------- v1 pre-fill

local function readV1Number(dir, name, suffix)
  local content = readFile(dir .. name .. "-" .. suffix .. ".txt")
  if not content then return nil end
  local v = tonumber((content:match("^%s*(.-)%s*$") or ""):match("^[%d%.%-]+") or "")
  return v
end

-- v1 kept only totals, keyed by model name. Read-only: v1's files are never
-- written. Returns the undated total (lifetime + starting count) or nil.
function core.v1Total(name)
  for i = 1, #V1_DIRS do
    local life = readV1Number(V1_DIRS[i], name, "Lifetime")
    local preset = readV1Number(V1_DIRS[i], name, "Preset")
    if life or preset then
      local total = math.floor((life or 0) + (preset or 0) + 0.5)
      if total > 0 then return total end
      return nil
    end
  end
  return nil
end

local function v1Claimed(name)
  for i = 1, #S.index do
    if S.index[i].v1 == name then return true end
  end
  return false
end

-- ---------------------------------------------------------------- log

local function emptyLog()
  return { before = 0, beforeV1 = false, flights = {}, startDate = nil, lastTs = nil }
end

-- Rows after the latest erase count. Flights are kept as a list of
-- { ts=, date= }; an undo removes the latest remaining flight.
local function parseLog(content)
  local L = emptyLog()
  for _, r in ipairs(lines(content)) do
    local ts, date, kind, n, extra = tonumber(r[1]), r[2], r[3], tonumber(r[4]) or 0, r[5] or ""
    if kind == "e" then
      L = emptyLog()
      L.startDate = date
    elseif kind == "id" then
      L.startDate = L.startDate or date
    elseif kind == "b" then
      L.before = math.max(0, math.floor(n))
      L.beforeV1 = (extra == "v1")
    elseif kind == "f" then
      L.flights[#L.flights + 1] = { ts = ts, date = date }
      L.startDate = L.startDate or date
    elseif kind == "u" then
      table.remove(L.flights)
    end
  end
  L.lastTs = nil
  for _, f in ipairs(L.flights) do
    if f.ts and (not L.lastTs or f.ts > L.lastTs) then L.lastTs = f.ts end
  end
  return L
end

local function queue(key, fields)
  S.pending[#S.pending + 1] = { key = key, fields = fields }
end

local function flushPending()
  local kept = {}
  for i = 1, #S.pending do
    local p = S.pending[i]
    if S.dir and appendLine(logPath(p.key), p.fields) then
      diag("saved_late", p.key .. " " .. p.fields[3])
    else
      kept[#kept + 1] = p
    end
  end
  S.pending = kept
end

local function writeRow(key, kind, n, extra, t)
  t = t or os.time()
  local fields = { tostring(t), today(t), kind, tostring(n), clean(extra or "") }
  if not (S.dir and appendLine(logPath(key), fields)) then
    queue(key, fields)
    diag("append_fail", key .. " " .. kind)
    return false
  end
  return true
end

local function loadLog()
  if not S.key then return false end
  local content, err = readFile(logPath(S.key))
  if err == "missing" then content, err = "", nil end
  if not content then
    S.loaded, S.loadError = false, err
    return false
  end
  S.log = parseLog(content)
  -- Rows still waiting to be written belong to this model too.
  for i = 1, #S.pending do
    local p = S.pending[i]
    if p.key == S.key then
      local f = p.fields
      if f[3] == "f" then S.log.flights[#S.log.flights + 1] = { ts = tonumber(f[1]), date = f[2] }
      elseif f[3] == "u" then table.remove(S.log.flights) end
    end
  end
  local last = S.log.flights[#S.log.flights]
  S.log.lastTs = last and last.ts or nil
  S.log.startDate = S.log.startDate or (S.rec and S.rec.created) or today()
  S.loaded, S.loadError = true, nil
  S.version = S.version + 1
  return true
end

-- ---------------------------------------------------------------- binding

local function newRecord(path, name, rxid)
  local rec = { key = nextKey(), file = path, rxid = rxid, name = name, created = today(), v1 = "" }
  local prefill = nil
  if not v1Claimed(name) then
    prefill = core.v1Total(name)
    if prefill then rec.v1 = name end
  end
  S.index[#S.index + 1] = rec
  if not writeIndex() then
    table.remove(S.index)
    return nil, "index write failed"
  end
  writeRow(rec.key, "id", 0, name .. " | " .. path)
  if prefill then
    writeRow(rec.key, "b", prefill, "v1")
    S.note = { text = "Pre-filled " .. prefill .. " from v1 - check in Settings", at = os.time(), sec = 15 }
  end
  S.name = name
  diag("new_model", rec.key .. " " .. name .. " " .. path .. (prefill and (" v1=" .. prefill) or ""))
  return rec
end

local function updateRecord(rec, path, name, rxid, why)
  local changed = rec.file ~= path or rec.name ~= name or rec.rxid ~= rxid
  if not changed then return true end
  local old = { rec.file, rec.name, rec.rxid }
  rec.file, rec.name, rec.rxid = path, name, rxid
  if not writeIndex() then
    rec.file, rec.name, rec.rxid = old[1], old[2], old[3]
    return false
  end
  writeRow(rec.key, "id", 0, name .. " | " .. path)
  diag(why, rec.key .. " " .. old[2] .. " -> " .. name .. " " .. old[1] .. " -> " .. path)
  return true
end

local function isOrphan(rec)
  if not S.modelsDir then return false end
  return not exists(S.modelsDir .. rec.file)
end

-- Picks the record for the loaded model. Known file -> that record. A new
-- file whose old record's file vanished and whose NAME matches -> the same
-- model under a new file name (restore, re-save). Otherwise a new model:
-- that covers clones, whose original file still exists. A rename done on
-- the radio is caught live by core.checkModel instead, because the widget
-- is running while the name is edited.
local function bind()
  local path, name, rxid = modelPath(), modelName(), modelRxid()
  if not path then return false, "no model path" end
  if not S.index and not loadIndex() then return false, "index: " .. tostring(S.indexError) end
  if S.modelsDir == false then S.modelsDir = resolveModelsDir(path) end

  local rec = findBy("file", path)
  if rec then
    updateRecord(rec, path, name, rxid, "updated")
  else
    local adopt = nil
    for i = 1, #S.index do
      local r = S.index[i]
      if r.name == name and isOrphan(r) then
        if adopt then adopt = nil break end   -- ambiguous: never guess
        adopt = r
      end
    end
    if adopt then
      rec = adopt
      updateRecord(rec, path, name, rxid, "refiled")
    else
      local err
      rec, err = newRecord(path, name, rxid)
      if not rec then return false, err end
    end
  end
  S.key, S.rec, S.path, S.name = rec.key, rec, path, name
  S.loaded, S.log = false, nil
  loadLog()
  return true
end

-- Called every wakeup: cheap string compares, file checks only on change.
function core.checkModel()
  if not S.key then return end
  local path = modelPath()
  if not path then return end
  local name = modelName()
  if path == S.path then
    S.pathSeenAt = nil
    if name ~= S.name then
      updateRecord(S.rec, path, name, modelRxid(), "renamed")
      S.name = name
    end
    return
  end
  -- The loaded model's file name changed. Same session, same widget: if the
  -- file we were bound to is gone, the model was renamed (Ethos renames the
  -- file with the model). If it still exists, another model was loaded.
  local oldFile = S.path
  local now = os.time()
  if S.modelsDir == nil or S.modelsDir == false then S.modelsDir = resolveModelsDir(path) end
  if S.modelsDir and not exists(S.modelsDir .. oldFile) and not findBy("file", path) then
    updateRecord(S.rec, path, name, modelRxid(), "renamed")
    S.cfgByModel[path] = S.cfgByModel[path] or S.cfgByModel[oldFile]
    S.path, S.name, S.pathSeenAt = path, name, nil
    return
  end
  -- The old file may still be on its way out: give it a moment before
  -- deciding that a different model was loaded.
  if S.modelsDir and not findBy("file", path) then
    S.pathSeenAt = S.pathSeenAt or now
    if now - S.pathSeenAt < SETTLE_SEC then return end
  end
  S.pathSeenAt = nil
  S.key, S.rec, S.path, S.name, S.loaded, S.log = nil, nil, nil, nil, false, nil
  S.retryAt, S.lastLoggedAt, S.just = 0, nil, nil
  S.counter = newCounter()
  S.version = S.version + 1
  local ok, err = bind()
  if not ok then S.loadError = err end
  diag("model", (S.name or "?") .. " " .. path)
end

-- ---------------------------------------------------------------- lifecycle

function core.init()
  if S.bootAt then return end
  S.bootAt = os.time()
  S.dir = resolveDataDir()
  if not S.dir then S.loadError = "no data folder" return end
  local ok, err = bind()
  if not ok then S.loadError = err end
end

-- Retries whatever failed (folder, index, log, unsaved rows) once a second.
function core.service()
  local now = os.time()
  if now < S.retryAt then return end
  S.retryAt = now + RETRY_SEC
  if not S.dir then
    S.dir = resolveDataDir()
    if not S.dir then return end
  end
  if #S.pending > 0 then flushPending() end
  if not S.key then
    local ok, err = bind()
    if not ok then S.loadError = err end
  elseif not S.loaded then
    if loadLog() then diag("load_retry_ok", S.key) end
  end
  if not S.bootRowDone and now - S.bootAt >= 1 then
    S.bootRowDone = diag("boot", "v" .. core.VERSION .. " " .. tostring(S.key) .. " "
      .. (S.loaded and ("life=" .. core.lifetime()) or ("err=" .. tostring(S.loadError)))
      .. " mdir=" .. tostring(S.modelsDir))
  end
end

-- ---------------------------------------------------------------- totals

function core.ready() return S.loaded and S.log ~= nil end
function core.error() return (not S.loaded) and S.loadError or nil end

function core.lifetime()
  if not core.ready() then return nil end
  return S.log.before + #S.log.flights
end

local function countWhere(pred)
  local n = 0
  for _, f in ipairs(S.log.flights) do if pred(f.date or "") then n = n + 1 end end
  return n
end

-- Everything the screens need, computed once per call.
function core.view(now)
  now = now or os.time()
  if S.viewCache and S.viewAt == now and S.viewVersion == S.version and S.viewReady == core.ready() then
    return S.viewCache
  end
  local v = core.computeView(now)
  S.viewCache, S.viewAt, S.viewVersion, S.viewReady = v, now, S.version, core.ready()
  return v
end

function core.computeView(now)
  local v = { ready = core.ready(), error = core.error(), name = S.name or modelName(),
              pending = #S.pending }
  if not v.ready then return v end
  local d = today(now)
  local ym, yr = ymOf(d), string.sub(d, 1, 4)
  local L = S.log
  v.before = L.before
  v.beforeV1 = L.beforeV1
  v.logged = #L.flights
  v.lifetime = L.before + #L.flights
  v.today = countWhere(function(x) return x == d end)
  v.month = countWhere(function(x) return ymOf(x) == ym end)
  v.year = countWhere(function(x) return string.sub(x, 1, 4) == yr end)
  v.lastTs = L.lastTs
  v.startDate = L.startDate
  -- Year tile: "Since 9/26" while the current year began before logging did.
  local sd = L.startDate or d
  if string.sub(sd, 1, 4) == yr and string.sub(sd, 6) ~= "01-01" then
    v.yearLabel = "Since " .. tonumber(string.sub(sd, 6, 7)) .. "/" .. tonumber(string.sub(sd, 9, 10))
  else
    v.yearLabel = yr
  end
  v.monthLabel = os.date("%b", now)
  -- Last 12 months, oldest first; months before logging began are nil.
  local y, m = tonumber(string.sub(d, 1, 4)), tonumber(string.sub(d, 6, 7))
  local startYm = ymOf(sd)
  local months = {}
  for back = 11, 0, -1 do
    local yy, mm = y, m - back
    while mm < 1 do mm = mm + 12; yy = yy - 1 end
    local key = string.format("%04d-%02d", yy, mm)
    months[#months + 1] = { ym = key, month = mm, year = yy,
                            n = (key >= startYm) and countWhere(function(x) return ymOf(x) == key end) or nil }
  end
  v.months = months
  local total, shown = 0, 0
  for _, mo in ipairs(months) do if mo.n then total = total + mo.n; shown = shown + 1 end end
  v.avg = shown > 0 and total / shown or 0
  v.just = (S.just and now - S.just.at < JUST_SEC) and S.just.n or nil
  v.note = (S.note and now - S.note.at < S.note.sec) and S.note.text or nil
  return v
end

-- ---------------------------------------------------------------- settings

-- The counting settings belong to the MODEL: every Flight Counter 2 widget on
-- it shows and edits the same trigger, delay, one-per-cycle and border.
-- Ethos saves settings per widget (read/write), and a switch choice only
-- survives a reboot that way, so: every widget edits one shared table, the
-- widget whose settings page closes saves it with a timestamp, and at power-
-- up the newest saved copy wins. A widget that was never configured (no
-- switch, no timestamp) is ignored. Kept in memory per model file name.
S.cfgByModel = {}

local function defaultCfg()
  return { switch = nil, delay = 0, onePerCycle = true, border = false, at = nil, adoptedAt = nil }
end

function core.cfg()
  local k = S.path or modelPath() or "?"
  local c = S.cfgByModel[k]
  if not c then c = defaultCfg(); S.cfgByModel[k] = c end
  return c
end

-- stored = one widget's saved values (read() callback: that widget belongs to
-- the model being loaded, so the live model file name is the key).
function core.adoptCfg(stored)
  if stored.switch == nil and stored.at == nil then return false end
  local k = modelPath() or "?"
  local cur = S.cfgByModel[k]
  local at = tonumber(stored.at) or 0
  if cur and cur.adoptedAt ~= nil and at <= cur.adoptedAt then return false end
  S.cfgByModel[k] = {
    switch = stored.switch,
    delay = tonumber(stored.delay) or 0,
    onePerCycle = stored.onePerCycle ~= false,
    border = stored.border == true,
    at = stored.at, adoptedAt = at,
  }
  return true
end

-- Called when a settings page closes: this copy is now the newest.
function core.stampCfg(now)
  local c = core.cfg()
  c.at = now or os.time()
  c.adoptedAt = c.at
  return c
end

-- ---------------------------------------------------------------- counting

-- Each widget's wakeup calls core.poll(); repeating it is harmless.
S.counter = newCounter()
function core.counter() return S.counter end

local function logFlight(now)
  if not S.key then return false end
  if S.lastLoggedAt and now - S.lastLoggedAt < DEDUPE_SEC then return true end
  writeRow(S.key, "f", 1, "", now)
  S.lastLoggedAt = now
  S.countedThisPower[S.key] = true
  if S.log then
    S.log.flights[#S.log.flights + 1] = { ts = now, date = today(now) }
    S.log.lastTs = now
  end
  S.just = { n = S.log and (S.log.before + #S.log.flights) or nil, at = now }
  S.version = S.version + 1
  return true
end

-- States for the screen: "noswitch", "idle", "counting" (with progress 0..1
-- and seconds left), "counted" (this power-up, with one-per-cycle on).
-- The switch must be seen OFF once after power-up before it can count, so a
-- switch left on at power-up never logs a flight.
function core.poll(now)
  now = now or os.time()
  local cfg, c = core.cfg(), S.counter
  if not cfg.switch then c.state = "noswitch" return c end
  local ok, active = pcall(function() return cfg.switch:state() end)
  active = ok and active == true
  local done = cfg.onePerCycle and S.key and S.countedThisPower[S.key]
  if not active then
    c.seenOff, c.startAt, c.latched = true, nil, false
  elseif c.seenOff and not c.latched then
    if done then
      c.startAt = nil
    else
      c.startAt = c.startAt or now
      if now - c.startAt >= (cfg.delay or 0) then
        if logFlight(now) then c.latched, c.startAt = true, nil end
      end
    end
  end
  if cfg.onePerCycle and S.key and S.countedThisPower[S.key] then
    c.state = "counted"
  elseif c.startAt and (cfg.delay or 0) > 0 then
    c.state = "counting"
    c.left = math.max(0, (cfg.delay or 0) - (now - c.startAt))
    c.progress = math.min(1, (now - c.startAt) / cfg.delay)
  else
    c.state = "idle"
  end
  return c
end

-- ---------------------------------------------------------------- settings actions

function core.setBefore(n)
  n = math.max(0, math.floor(tonumber(n) or 0))
  if not core.ready() or n == S.log.before then return false end
  writeRow(S.key, "b", n, "")
  S.log.before, S.log.beforeV1 = n, false
  S.version = S.version + 1
  diag("before", S.key .. " " .. n)
  return true
end

function core.lastFlight()
  if not core.ready() then return nil end
  return S.log.flights[#S.log.flights]
end

function core.undo()
  local last = core.lastFlight()
  if not last then return false end
  writeRow(S.key, "u", -1, last.date or "")
  table.remove(S.log.flights)
  local nl = S.log.flights[#S.log.flights]
  S.log.lastTs = nl and nl.ts or nil
  S.version = S.version + 1
  diag("undo", S.key .. " " .. tostring(last.ts))
  return true
end

function core.erase()
  if not core.ready() then return false end
  writeRow(S.key, "e", 0, "")
  S.log = emptyLog()
  S.log.startDate = today()
  S.countedThisPower[S.key] = nil
  S.lastLoggedAt = nil
  S.version = S.version + 1
  diag("erase", S.key)
  return true
end

return core
