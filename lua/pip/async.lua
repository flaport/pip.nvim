local M = {}

---@generic T
---@param func fun(...: any): T
---@return fun(...: any): T
function M.wrap(func)
    return function(...)
        local args = { ... }
        local co = coroutine.create(function()
            func(unpack(args))
        end)

        local function step(...)
            local ok, result = coroutine.resume(co, ...)
            if not ok then
                error(debug.traceback(co, result))
            end

            if coroutine.status(co) ~= "dead" then
                result(step)
            end
        end

        step()
    end
end

---@param func fun(...: any)
---@param timeout integer
---@return fun(...: any)
function M.throttle(func, timeout)
    local timer = nil
    local last_args = nil

    return function(...)
        last_args = { ... }

        if timer then
            return
        end

        timer = vim.loop.new_timer()
        timer:start(timeout, 0, vim.schedule_wrap(function()
            timer:stop()
            timer:close()
            timer = nil

            if last_args then
                func(unpack(last_args))
                last_args = nil
            end
        end))
    end
end

return M
