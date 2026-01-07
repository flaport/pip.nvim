local semver = require("pip.semver")
local types = require("pip.types")
local Span = types.Span

local M = {}

---@class TomlSection
---@field text string
---@field invalid boolean?
---@field kind TomlSectionKind
---@field name string?
---@field name_col Span?
---@field lines Span
---@field header_col Span
local Section = {}
M.Section = Section

---@enum TomlSectionKind
local TomlSectionKind = {
    DEPENDENCIES = 1,
    OPTIONAL_DEPENDENCIES = 2,
    DEV_DEPENDENCIES = 3,
}
M.TomlSectionKind = TomlSectionKind

---@class TomlPackage
---@field explicit_name string
---@field explicit_name_col Span
---@field lines Span
---@field syntax TomlPackageSyntax
---@field vers TomlPackageVers?
---@field extras TomlPackageExtras?
---@field section TomlSection
local Package = {}
M.Package = Package

---@enum TomlPackageSyntax
local TomlPackageSyntax = {
    -- "requests>=2.0"
    PLAIN = 1,
    -- requests = ">=2.0"
    KEY_VALUE = 2,
    -- requests = {version = ">=2.0"}
    INLINE_TABLE = 3,
    -- [project.dependencies.requests] with version = ">=2.0"
    TABLE = 4,
}
M.TomlPackageSyntax = TomlPackageSyntax

---@class TomlPackageEntry
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field text string

---@class TomlPackageVers: TomlPackageEntry
---@field reqs Requirement[]

---@class TomlPackageExtras: TomlPackageEntry
---@field items string[]

---@param obj TomlPackage
---@return TomlPackage
function Package.new(obj)
    if obj.vers then
        obj.vers.reqs = semver.parse_requirements(obj.vers.text)
    end
    return setmetatable(obj, { __index = Package })
end

---@return Requirement[]
function Package:vers_reqs()
    return self.vers and self.vers.reqs or {}
end

---@return string
function Package:package()
    return self.explicit_name
end

---@return string
function Package:cache_key()
    return string.format(
        "%s:%s",
        self.section.kind,
        self.explicit_name:lower()
    )
end

---@param obj TomlSection
---@return TomlSection
function Section.new(obj)
    return setmetatable(obj, { __index = Section })
end

---@param override_name string?
---@return string
function Section:display(override_name)
    local text = "["

    if self.kind == TomlSectionKind.DEPENDENCIES then
        text = text .. "project.dependencies"
    elseif self.kind == TomlSectionKind.OPTIONAL_DEPENDENCIES then
        text = text .. "project.optional-dependencies"
    elseif self.kind == TomlSectionKind.DEV_DEPENDENCIES then
        text = text .. "tool.uv.dev-dependencies"
    end

    local name = override_name or self.name
    if name then
        text = text .. "." .. name
    end

    text = text .. "]"

    return text
end

---@param text string
---@param line_nr integer
---@param header_col Span
---@return TomlSection?
function M.parse_section(text, line_nr, header_col)
    ---@type TomlSection?
    local section = nil

    -- [project.dependencies]
    if text:match("^%s*project%.dependencies%s*$") then
        section = {
            text = text,
            invalid = false,
            kind = TomlSectionKind.DEPENDENCIES,
            lines = Span.new(line_nr, nil),
            header_col = header_col,
        }
    -- [project.optional-dependencies] or [project.optional-dependencies.group]
    elseif text:match("^%s*project%.optional%-dependencies") then
        local group_name, name_s, name_e = text:match("^%s*project%.optional%-dependencies%.()([%w_-]+)()%s*$")
        section = {
            text = text,
            invalid = false,
            kind = TomlSectionKind.OPTIONAL_DEPENDENCIES,
            name = group_name,
            name_col = group_name and Span.new(name_s - 1 + header_col.s + 1, name_e - 1 + header_col.s + 1) or nil,
            lines = Span.new(line_nr, nil),
            header_col = header_col,
        }
    -- [dependency-groups] (PEP 735)
    elseif text:match("^%s*dependency%-groups") then
        local group_name, name_s, name_e = text:match("^%s*dependency%-groups%.()([%w_-]+)()%s*$")
        section = {
            text = text,
            invalid = false,
            kind = TomlSectionKind.OPTIONAL_DEPENDENCIES,
            name = group_name,
            name_col = group_name and Span.new(name_s - 1 + header_col.s + 1, name_e - 1 + header_col.s + 1) or nil,
            lines = Span.new(line_nr, nil),
            header_col = header_col,
        }
    -- [tool.uv.dev-dependencies]
    elseif text:match("^%s*tool%.uv%.dev%-dependencies%s*$") then
        section = {
            text = text,
            invalid = false,
            kind = TomlSectionKind.DEV_DEPENDENCIES,
            lines = Span.new(line_nr, nil),
            header_col = header_col,
        }
    end

    if section then
        return Section.new(section)
    end
    return nil
end

---@param line string
---@return string
function M.trim_comments(line)
    -- Handle comments, but be careful with strings
    local in_string = false
    local quote_char = nil
    for i = 1, #line do
        local c = line:sub(i, i)
        if not in_string then
            if c == '"' or c == "'" then
                in_string = true
                quote_char = c
            elseif c == "#" then
                return line:sub(1, i - 1)
            end
        else
            if c == quote_char and line:sub(i - 1, i - 1) ~= "\\" then
                in_string = false
                quote_char = nil
            end
        end
    end
    return line
end

-- Parse a PEP 508 dependency specification string
-- Examples:
--   "requests>=2.0"
--   "requests[security]>=2.0,<3.0"
--   "requests>=2.0; python_version >= '3.8'"
---@param spec string
---@param col_offset integer
---@return string name
---@return Span name_col
---@return string? version_text
---@return Span? version_col
---@return string[]? extras
function M.parse_pep508_spec(spec, col_offset)
    -- Remove leading/trailing whitespace and quotes
    spec = spec:gsub("^%s*", ""):gsub("%s*$", "")

    local name_pattern = "^([a-zA-Z0-9][-a-zA-Z0-9._]*)"
    local name_s, name_e, name = spec:find(name_pattern)
    if not name then
        return spec, Span.new(col_offset, col_offset + #spec), nil, nil, nil
    end

    local rest = spec:sub(name_e + 1)
    local extras = nil
    local extras_text = rest:match("^%[([^%]]+)%]")
    if extras_text then
        extras = {}
        for extra in extras_text:gmatch("[^,%s]+") do
            table.insert(extras, extra)
        end
        rest = rest:sub(#extras_text + 3) -- skip [extras]
    end

    -- Find version specifier (starts with comparison operator or @)
    local vers_pattern = "^%s*([><=!~@][^;]*)"
    local vers_s, vers_e, vers_text = rest:find(vers_pattern)

    if vers_text then
        -- Remove environment markers (everything after ;)
        vers_text = vers_text:gsub(";.*$", ""):gsub("%s*$", "")
        local abs_vers_s = col_offset + name_e + (extras_text and #extras_text + 2 or 0) + (vers_s - 1)
        local abs_vers_e = abs_vers_s + #vers_text
        return name, Span.new(col_offset + name_s - 1, col_offset + name_e), vers_text, Span.new(abs_vers_s, abs_vers_e), extras
    end

    return name, Span.new(col_offset + name_s - 1, col_offset + name_e), nil, nil, extras
end

-- Parse inline array items like: ["requests>=2.0", "flask>=1.0"]
---@param text string
---@param line_nr integer
---@param col_offset integer
---@return TomlPackage[]
function M.parse_array_items(text, line_nr, col_offset)
    local packages = {}

    -- Find content between brackets
    local array_content = text:match("%[(.*)%]")
    if not array_content then
        return packages
    end

    local content_start = text:find("%[") + col_offset

    -- Parse each string in the array
    local pos = 1
    while pos <= #array_content do
        -- Skip whitespace and commas
        local ws_start, ws_end = array_content:find("^[%s,]+", pos)
        if ws_start then
            pos = ws_end + 1
        end

        if pos > #array_content then
            break
        end

        -- Find quoted string
        local quote_char = array_content:sub(pos, pos)
        if quote_char == '"' or quote_char == "'" then
            local str_start = pos + 1
            local str_end = array_content:find(quote_char, str_start)
            if str_end then
                local spec = array_content:sub(str_start, str_end - 1)
                local abs_col = content_start + str_start - 1

                local name, name_col, vers_text, vers_col, extras = M.parse_pep508_spec(spec, abs_col)

                if name and name ~= "" then
                    ---@type TomlPackage
                    local pkg = {
                        explicit_name = name,
                        explicit_name_col = name_col,
                        lines = Span.new(line_nr, line_nr + 1),
                        syntax = TomlPackageSyntax.PLAIN,
                    }
                    if vers_text then
                        pkg.vers = {
                            text = vers_text,
                            line = line_nr,
                            col = vers_col,
                            decl_col = Span.new(abs_col - 1, abs_col + #spec),
                        }
                    end
                    if extras then
                        pkg.extras = {
                            items = extras,
                            line = line_nr,
                            col = name_col,
                            decl_col = name_col,
                            text = table.concat(extras, ","),
                        }
                    end
                    table.insert(packages, pkg)
                end

                pos = str_end + 1
            else
                pos = pos + 1
            end
        else
            pos = pos + 1
        end
    end

    return packages
end

---@param buf integer
---@return TomlSection[]
---@return TomlPackage[]
function M.parse_packages(buf)
    ---@type string[]
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local sections = {}
    local packages = {}

    ---@type TomlSection?
    local current_section = nil
    ---@type boolean
    local in_array = false
    ---@type string[]
    local array_lines = {}
    ---@type integer
    local array_start_line = 0

    for i, line in ipairs(lines) do
        local line_nr = i - 1
        local trimmed = M.trim_comments(line)

        -- Check for section header
        local section_start, section_text, section_end = trimmed:match("^%s*()%[%[?([^%]]+)%]%]?()%s*$")
        if section_text then
            -- Close previous section
            if current_section then
                current_section.lines.e = line_nr
            end

            -- Handle multiline arrays that weren't closed
            if in_array and current_section then
                local full_text = table.concat(array_lines, "")
                local parsed = M.parse_array_items(full_text, array_start_line, 0)
                for _, pkg in ipairs(parsed) do
                    pkg.section = current_section
                    table.insert(packages, Package.new(pkg))
                end
            end
            in_array = false
            array_lines = {}

            local header_col = Span.new(section_start - 1, section_end - 1)
            current_section = M.parse_section(section_text, line_nr, header_col)

            if current_section then
                table.insert(sections, current_section)
            end
        elseif current_section then
            -- Handle multiline arrays
            if in_array then
                table.insert(array_lines, trimmed)
                if trimmed:match("%]%s*$") then
                    in_array = false
                    local full_text = table.concat(array_lines, "")
                    local parsed = M.parse_array_items(full_text, array_start_line, 0)
                    for _, pkg in ipairs(parsed) do
                        pkg.section = current_section
                        table.insert(packages, Package.new(pkg))
                    end
                    array_lines = {}
                end
            else
                -- Check for array start (dependencies = [...] or group = [...])
                local key_name, array_start = trimmed:match("^%s*([%w_-]*)%s*=%s*(%[.*)$")
                if array_start then
                    -- Check if it's a single-line array
                    if array_start:match("%]%s*$") then
                        local parsed = M.parse_array_items(array_start, line_nr, trimmed:find("%[") - 1)
                        for _, pkg in ipairs(parsed) do
                            pkg.section = current_section
                            table.insert(packages, Package.new(pkg))
                        end
                    else
                        -- Start of multiline array
                        in_array = true
                        array_start_line = line_nr
                        array_lines = { array_start }
                    end
                else
                    -- Check for simple quoted string on its own line (inside an array)
                    local quote_char, spec = trimmed:match('^%s*(["\'])(.-)%1%s*,?%s*$')
                    if spec and spec ~= "" then
                        local name, name_col, vers_text, vers_col, extras = M.parse_pep508_spec(spec, trimmed:find(quote_char) or 0)
                        if name and name ~= "" then
                            ---@type TomlPackage
                            local pkg = {
                                explicit_name = name,
                                explicit_name_col = name_col,
                                lines = Span.new(line_nr, line_nr + 1),
                                syntax = TomlPackageSyntax.PLAIN,
                                section = current_section,
                            }
                            if vers_text then
                                pkg.vers = {
                                    text = vers_text,
                                    line = line_nr,
                                    col = vers_col,
                                    decl_col = Span.new(0, #trimmed),
                                }
                            end
                            if extras then
                                pkg.extras = {
                                    items = extras,
                                    line = line_nr,
                                    col = name_col,
                                    decl_col = name_col,
                                    text = table.concat(extras, ","),
                                }
                            end
                            table.insert(packages, Package.new(pkg))
                        end
                    end
                end
            end
        end
    end

    -- Close last section
    if current_section then
        current_section.lines.e = #lines
    end

    -- Handle any remaining multiline array
    if in_array and current_section then
        local full_text = table.concat(array_lines, "")
        local parsed = M.parse_array_items(full_text, array_start_line, 0)
        for _, pkg in ipairs(parsed) do
            pkg.section = current_section
            table.insert(packages, Package.new(pkg))
        end
    end

    return sections, packages
end

return M
