local semver = require("pip.semver")
local state = require("pip.state")
local types = require("pip.types")
local PipDiagnostic = types.PipDiagnostic
local PipDiagnosticKind = types.PipDiagnosticKind
local MatchKind = types.MatchKind
local util = require("pip.util")

local M = {}

---@enum SectionScope
local SectionScope = {
    HEADER = 1,
}

---@enum PackageScope
local PackageScope = {
    VERS = 1,
    PACKAGE = 2,
}

---@param section TomlSection
---@param kind PipDiagnosticKind
---@param severity integer
---@param scope SectionScope?
---@param data table<string,any>?
---@param message_args any[]?
---@return PipDiagnostic
local function section_diagnostic(section, kind, severity, scope, data, message_args)
    local d = PipDiagnostic.new({
        lnum = section.lines.s,
        end_lnum = section.lines.e - 1,
        col = 0,
        end_col = 999,
        severity = severity,
        kind = kind,
        data = data,
        message_args = message_args,
    })

    if scope == SectionScope.HEADER then
        d.end_lnum = d.lnum + 1
    end

    return d
end

---@param pkg TomlPackage
---@param kind PipDiagnosticKind
---@param severity integer
---@param scope PackageScope?
---@param data table<string,any>?
---@param message_args any[]?
---@return PipDiagnostic
local function package_diagnostic(pkg, kind, severity, scope, data, message_args)
    local d = PipDiagnostic.new({
        lnum = pkg.lines.s,
        end_lnum = pkg.lines.e - 1,
        col = 0,
        end_col = 999,
        severity = severity,
        kind = kind,
        data = data,
        message_args = message_args,
    })

    if not scope then
        return d
    end

    if scope == PackageScope.VERS then
        if pkg.vers then
            d.lnum = pkg.vers.line
            d.end_lnum = pkg.vers.line
            d.col = pkg.vers.col.s
            d.end_col = pkg.vers.col.e
        end
    elseif scope == PackageScope.PACKAGE then
        d.lnum = pkg.lines.s
        d.end_lnum = pkg.lines.s
        d.col = pkg.explicit_name_col.s
        d.end_col = pkg.explicit_name_col.e
    end

    return d
end

---@param sections TomlSection[]
---@param packages TomlPackage[]
---@return table<string,TomlPackage>
---@return PipDiagnostic[]
function M.process_packages(sections, packages)
    ---@type PipDiagnostic[]
    local diagnostics = {}
    ---@type table<string,TomlSection>
    local s_cache = {}
    ---@type table<string,TomlPackage>
    local cache = {}

    for _, s in ipairs(sections) do
        local key = s.text:gsub("%s+", "")

        if s.invalid then
            table.insert(diagnostics, section_diagnostic(
                s,
                PipDiagnosticKind.SECTION_INVALID,
                vim.diagnostic.severity.WARN
            ))
        elseif s_cache[key] then
            table.insert(diagnostics, section_diagnostic(
                s_cache[key],
                PipDiagnosticKind.SECTION_DUP_ORIG,
                vim.diagnostic.severity.HINT,
                SectionScope.HEADER,
                { lines = s_cache[key].lines }
            ))
            table.insert(diagnostics, section_diagnostic(
                s,
                PipDiagnosticKind.SECTION_DUP,
                vim.diagnostic.severity.ERROR
            ))
        else
            s_cache[key] = s
        end
    end

    for _, p in ipairs(packages) do
        local key = p:cache_key()
        if p.section and p.section.invalid then
            goto continue
        end

        if cache[key] then
            table.insert(diagnostics, package_diagnostic(
                cache[key],
                PipDiagnosticKind.PKG_DUP_ORIG,
                vim.diagnostic.severity.HINT
            ))
            table.insert(diagnostics, package_diagnostic(
                p,
                PipDiagnosticKind.PKG_DUP,
                vim.diagnostic.severity.ERROR
            ))
        else
            cache[key] = p
        end

        ::continue::
    end

    return cache, diagnostics
end

---@param pkg TomlPackage
---@param api_pkg ApiPackage?
---@param diagnostics PipDiagnostic[] -- out parameter, diagnostics are appended
---@return PackageInfo
function M.process_api_package(pkg, api_pkg, diagnostics)
    local versions = api_pkg and api_pkg.versions
    local allow_pre = semver.allows_pre(pkg:vers_reqs())
    local newest, newest_pre, newest_yanked = util.get_newest(versions, nil, allow_pre)
    newest = newest or newest_pre or newest_yanked

    ---@type PackageInfo
    local info = {
        lines = pkg.lines,
        vers_line = pkg.vers and pkg.vers.line or pkg.lines.s,
        match_kind = MatchKind.NOMATCH,
    }

    if api_pkg then
        -- Check for case mismatch
        local normalized_pkg = util.normalize_package_name(pkg:package())
        local normalized_api = util.normalize_package_name(api_pkg.name)
        if normalized_pkg ~= normalized_api then
            table.insert(diagnostics, package_diagnostic(
                pkg,
                PipDiagnosticKind.PKG_NAME_CASE,
                vim.diagnostic.severity.WARN,
                PackageScope.PACKAGE,
                { package = pkg, package_name = api_pkg.name },
                { api_pkg.name }
            ))
        end
    end

    if newest then
        if semver.matches_requirements(newest.parsed, pkg:vers_reqs()) then
            -- version matches, no upgrade available
            info.vers_match = newest
            info.match_kind = MatchKind.VERSION
        else
            -- version does not match, upgrade available
            local match, match_pre, match_yanked = util.get_newest(versions, pkg:vers_reqs())
            info.vers_match = match or match_pre or match_yanked
            info.vers_upgrade = newest

            if state.cfg.enable_update_available_warning then
                table.insert(diagnostics, package_diagnostic(
                    pkg,
                    PipDiagnosticKind.VERS_UPGRADE,
                    vim.diagnostic.severity.WARN,
                    PackageScope.VERS
                ))
            end

            if match then
                -- found a match
                info.match_kind = MatchKind.VERSION
            elseif match_pre then
                -- found a pre-release match
                info.match_kind = MatchKind.PRERELEASE
                table.insert(diagnostics, package_diagnostic(
                    pkg,
                    PipDiagnosticKind.VERS_PRE,
                    vim.diagnostic.severity.ERROR,
                    PackageScope.VERS
                ))
            elseif match_yanked then
                -- found a yanked match
                info.match_kind = MatchKind.YANKED
                table.insert(diagnostics, package_diagnostic(
                    pkg,
                    PipDiagnosticKind.VERS_YANKED,
                    vim.diagnostic.severity.ERROR,
                    PackageScope.VERS
                ))
            else
                -- no match found
                local kind = PipDiagnosticKind.VERS_NOMATCH
                if not pkg.vers then
                    kind = PipDiagnosticKind.PKG_NOVERS
                end
                table.insert(diagnostics, package_diagnostic(
                    pkg,
                    kind,
                    vim.diagnostic.severity.ERROR,
                    PackageScope.VERS
                ))
            end
        end
    else
        table.insert(diagnostics, package_diagnostic(
            pkg,
            PipDiagnosticKind.PKG_ERROR_FETCHING,
            vim.diagnostic.severity.ERROR,
            PackageScope.VERS
        ))
    end

    return info
end

return M
