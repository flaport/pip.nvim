---@class Span
---@field s integer -- start (0-indexed)
---@field e integer -- end (0-indexed, exclusive)
local Span = {}

---@param s integer
---@param e integer
---@return Span
function Span.new(s, e)
    return setmetatable({ s = s, e = e }, { __index = Span })
end

---@class PipDiagnostic
---@field lnum integer
---@field end_lnum integer
---@field col integer
---@field end_col integer
---@field severity integer
---@field kind PipDiagnosticKind
---@field data table<string,any>?
---@field message_args any[]?
local PipDiagnostic = {}

---@param obj PipDiagnostic
---@return PipDiagnostic
function PipDiagnostic.new(obj)
    return setmetatable(obj, { __index = PipDiagnostic })
end

---@param config_msg string
---@return string
function PipDiagnostic:message(config_msg)
    if self.message_args then
        return string.format(config_msg, unpack(self.message_args))
    end
    return config_msg
end

---@enum PipDiagnosticKind
local PipDiagnosticKind = {
    SECTION_INVALID = "section_invalid",
    SECTION_DUP = "section_dup",
    SECTION_DUP_ORIG = "section_dup_orig",
    PKG_DUP = "pkg_dup",
    PKG_DUP_ORIG = "pkg_dup_orig",
    PKG_NOVERS = "pkg_novers",
    PKG_ERROR_FETCHING = "pkg_error_fetching",
    PKG_NAME_CASE = "pkg_name_case",
    VERS_UPGRADE = "vers_upgrade",
    VERS_PRE = "vers_pre",
    VERS_YANKED = "vers_yanked",
    VERS_NOMATCH = "vers_nomatch",
}

---@enum MatchKind
local MatchKind = {
    VERSION = "version",
    PRERELEASE = "prerelease",
    YANKED = "yanked",
    NOMATCH = "nomatch",
}

---@class PackageInfo
---@field lines Span
---@field vers_line integer
---@field match_kind MatchKind
---@field vers_match ApiVersion?
---@field vers_upgrade ApiVersion?
---@field vers_update ApiVersion?

---@class ApiPackage
---@field name string
---@field summary string?
---@field versions ApiVersion[]
---@field homepage string?
---@field repository string?
---@field documentation string?
---@field pypi_url string?

---@class ApiVersion
---@field num string
---@field parsed SemVer?
---@field yanked boolean
---@field requires_python string?
---@field upload_time string?

return {
    Span = Span,
    PipDiagnostic = PipDiagnostic,
    PipDiagnosticKind = PipDiagnosticKind,
    MatchKind = MatchKind,
}
