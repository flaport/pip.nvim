local semver = require("pip.semver")
local state = require("pip.state")

local M = {
    ---@type table<string,PackageJob>
    package_jobs = {},
    ---@type QueuedPackageJob[]
    package_queue = {},
    ---@type integer
    num_requests = 0,
    ---@type integer
    MAX_PARALLEL_REQUESTS = 10,
}

---@class Job
---@field handle uv.uv_process_t?
---@field was_cancelled boolean?

---@class PackageJob
---@field job Job
---@field callbacks fun(pkg: ApiPackage?, cancelled: boolean)[]

---@class QueuedPackageJob
---@field name string
---@field callbacks fun(pkg: ApiPackage?, cancelled: boolean)[]

local SIGTERM = 15

---@type vim.json.DecodeOpts
local JSON_DECODE_OPTS = { luanil = { object = true, array = true } }

---@param json_str string
---@return table
function M.parse_json(json_str)
    ---@type any
    local json = vim.json.decode(json_str, JSON_DECODE_OPTS)
    assert(type(json) == "table")
    return json
end

---@param name string
---@param on_exit fun(data: string?, cancelled: boolean)
---@return Job?
local function start_job(name, on_exit)
    ---@type Job
    local job = {}
    ---@type uv.uv_pipe_t
    local stdout = assert(vim.loop.new_pipe())
    ---@type uv.uv_pipe_t
    local stderr = assert(vim.loop.new_pipe())

    ---@type string?
    local stdout_str = nil

    -- Use curl to fetch from PyPI JSON API
    local url = string.format("https://pypi.org/pypi/%s/json", name)
    local opts = {
        args = { "-sL", "--retry", "1", url },
        stdio = { nil, stdout, stderr },
    }

    local handle, _pid
    ---@param code integer
    ---@param _signal integer
    handle, _pid = vim.loop.spawn("curl", opts, function(code, _signal)
        handle:close()

        local success = code == 0

        ---@type uv.uv_check_t
        local check = assert(vim.loop.new_check())
        check:start(function()
            if not stdout:is_closing() or not stderr:is_closing() then
                return
            end
            check:stop()

            vim.schedule(function()
                local data = success and stdout_str or nil
                on_exit(data, job.was_cancelled)
            end)
        end)
    end)

    if not handle then
        return nil
    end

    local accum = {}
    stdout:read_start(function(err, data)
        if err then
            stdout:read_stop()
            stdout:close()
            return
        end

        if data ~= nil then
            table.insert(accum, data)
        else
            stdout_str = table.concat(accum)
            stdout:read_stop()
            stdout:close()
        end
    end)

    -- Just close stderr, we don't need it
    stderr:read_start(function(err, data)
        if err or data == nil then
            stderr:read_stop()
            stderr:close()
        end
    end)

    job.handle = handle
    return job
end

---@param job Job
local function kill_job(job)
    if job.handle then
        job.handle:kill(SIGTERM)
    end
end

---@param name string
---@param callbacks fun(pkg: ApiPackage?, cancelled: boolean)[]
local function enqueue_package_job(name, callbacks)
    for _, j in ipairs(M.package_queue) do
        if j.name:lower() == name:lower() then
            vim.list_extend(j.callbacks, callbacks)
            return
        end
    end

    table.insert(M.package_queue, {
        name = name,
        callbacks = callbacks,
    })
end

---@param json table
---@param name string
---@return ApiPackage?
function M.parse_package(json, name)
    if not json then
        return nil
    end

    -- PyPI JSON API returns:
    -- {
    --   "info": { "name": "...", "summary": "...", ... },
    --   "releases": { "1.0.0": [...], "1.0.1": [...], ... }
    -- }

    local info = json.info
    local releases = json.releases
    if not releases then
        return nil
    end

    ---@type ApiVersion[]
    local versions = {}

    for vers_str, release_files in pairs(releases) do
        local parsed = semver.parse_version(vers_str)
        -- Check if yanked (any file in the release is yanked)
        local yanked = false
        if type(release_files) == "table" and #release_files > 0 then
            yanked = release_files[1].yanked or false
        end

        ---@type ApiVersion
        local version = {
            num = vers_str,
            parsed = parsed,
            yanked = yanked,
        }
        table.insert(versions, version)
    end

    -- Sort versions newest first
    table.sort(versions, function(a, b)
        if not a.parsed or not b.parsed then
            return a.num > b.num
        end
        return semver.compare(a.parsed, b.parsed) > 0
    end)

    ---@type ApiPackage
    local package = {
        name = info and info.name or name,
        summary = info and info.summary,
        versions = versions,
        homepage = info and info.home_page,
        documentation = info and info.docs_url,
        repository = info and info.project_urls and info.project_urls.Repository,
        pypi_url = "https://pypi.org/project/" .. name,
    }

    return package
end

---@param name string
---@param callbacks fun(pkg: ApiPackage?, cancelled: boolean)[]
local function fetch_package(name, callbacks)
    -- Normalize package name for lookup
    local normalized = name:lower():gsub("[_.-]+", "-")

    local existing = M.package_jobs[normalized]
    if existing then
        vim.list_extend(existing.callbacks, callbacks)
        return
    end

    if M.num_requests >= M.MAX_PARALLEL_REQUESTS then
        enqueue_package_job(name, callbacks)
        return
    end

    ---@param json_str string?
    ---@param cancelled boolean
    local function on_exit(json_str, cancelled)
        ---@type ApiPackage?
        local package = nil
        if not cancelled and json_str then
            local ok, json = pcall(M.parse_json, json_str)
            if ok and json then
                package = M.parse_package(json, name)
            end
        end

        for _, c in ipairs(callbacks) do
            c(package, cancelled)
        end

        M.package_jobs[normalized] = nil
        M.num_requests = M.num_requests - 1

        M.run_queued_jobs()
    end

    local job = start_job(name, on_exit)
    if job then
        M.num_requests = M.num_requests + 1
        M.package_jobs[normalized] = {
            job = job,
            callbacks = callbacks,
        }
    else
        for _, c in ipairs(callbacks) do
            c(nil, false)
        end
    end
end

---@param name string
---@return ApiPackage?, boolean
function M.fetch_package(name)
    ---@param resolve fun(pkg: ApiPackage?, cancelled: boolean)
    return coroutine.yield(function(resolve)
        fetch_package(name, { resolve })
    end)
end

---@param name string
---@return boolean
function M.is_fetching_package(name)
    local normalized = name:lower():gsub("[_.-]+", "-")
    return M.package_jobs[normalized] ~= nil
end

---@param name string
---@param callback fun(pkg: ApiPackage?, cancelled: boolean)
local function add_package_callback(name, callback)
    local normalized = name:lower():gsub("[_.-]+", "-")
    table.insert(
        M.package_jobs[normalized].callbacks,
        callback
    )
end

---@param name string
---@return ApiPackage?, boolean
function M.await_package(name)
    ---@param resolve fun(pkg: ApiPackage?, cancelled: boolean)
    return coroutine.yield(function(resolve)
        add_package_callback(name, resolve)
    end)
end

function M.run_queued_jobs()
    if #M.package_queue == 0 then
        return
    end

    local job = table.remove(M.package_queue, 1)
    fetch_package(job.name, job.callbacks)
end

function M.cancel_jobs()
    for _, r in pairs(M.package_jobs) do
        kill_job(r.job)
    end

    M.package_jobs = {}
    M.package_queue = {}
end

return M
