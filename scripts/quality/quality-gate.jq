# Validate and normalise the quality gate configuration for quality-gate.sh.
#
# Input: an array of configuration documents, the template file first and the
# drop-in files after it in sorted order. A gate in a later document with the
# same name overrides the fields it sets. Output: {max_blocks, gates} holding
# only the enabled gates with every field resolved. A violation raises an
# error that names the gate and the field.
#
# Usage:
#   yq -o=json scripts/config/quality-gates.yaml | jq -c -s -f scripts/quality/quality-gate.jq

# Helpers used by the rules below.

# True when the input is a string that matches the pattern.
def token($pattern): type == "string" and test($pattern);

# Pass the input through when the condition holds, otherwise stop with the message.
def require($ok; $message): if $ok then . else error($message) end;

# True when the input is a whole number from $min to $max inclusive.
def whole($min; $max): type == "number" and . == floor and . >= $min and . <= $max;

# Reject any key of the input mapping that is not in the allowed list.
def only($allowed; $where):
  ((keys - $allowed) | join(", ")) as $extra
  | require($extra == ""; "\($where): unknown key(s): \($extra)");

# Apply the built-in defaults to one merged gate and validate each field. A disabled gate yields nothing.
def resolve($name; $gate):
  ({mode: "block", timeout: 120, enabled: true} + $gate) as $g
  | ($g | only(["name", "target", "mode", "timeout", "paths", "enabled", "description"]; "gate \($name)")) as $_
  | require($g.enabled | type == "boolean"; "gate \($name): enabled must be true or false")
  | if $g.enabled then
      require($g.target | token("^[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$"); "gate \($name): target must be a Make target name, for example lint")
      | require($g.mode | IN("block", "warn"); "gate \($name): mode must be block or warn")
      | require($g.timeout | whole(1; 1800); "gate \($name): timeout must be a whole number of seconds from 1 to 1800")
      | require(($g.paths // []) | type == "array" and all(.[]; type == "string" and length > 0 and (test("[\u0000-\u001f]") | not)); "gate \($name): paths must be a list of non-empty globs")
      | require(($g.description // "") | type == "string"; "gate \($name): description must be text")
      | $g | {name, target, mode, timeout, paths: ($g.paths // []), description: ($g.description // "")}
    else
      empty
    end;

# Main pipeline.

# Merge the documents in order. Keys are checked per document, the defaults and
# max_blocks of later files win, and same-name gates merge field by field while
# keeping the order in which a name first appeared.
require(type == "array" and length > 0 and all(.[]; type == "object"); "each configuration file must be a mapping")
| reduce .[] as $doc (
    {defaults: {}, max_blocks: null, order: [], by: {}};
    ($doc | only(["version", "defaults", "max_blocks", "gates"]; "configuration")) as $_
    | require($doc.version == 1; "version must be 1")
    | require(($doc.defaults // {}) | type == "object"; "defaults must be a mapping")
    | require(($doc.gates // []) | type == "array"; "gates must be a list")
    | .defaults += ($doc.defaults // {})
    | if $doc | has("max_blocks") then .max_blocks = $doc.max_blocks else . end
    | reduce ($doc.gates // [])[] as $gate (
        .;
        require($gate | type == "object"; "each gate must be a mapping")
        | require($gate.name | token("^[a-z0-9][a-z0-9-]{0,39}$"); "gate name must match ^[a-z0-9][a-z0-9-]{0,39}$")
        | if .by[$gate.name] then . else .order += [$gate.name] end
        | .by[$gate.name] += $gate
      )
  )
# Only mode and timeout may be defaulted.
| (.defaults | only(["mode", "timeout"]; "defaults")) as $_
| . as $merged
# Resolve every gate against the defaults. max_blocks falls back to 1.
| {
    max_blocks: ($merged.max_blocks // 1 | require(whole(1; 5); "max_blocks must be a whole number from 1 to 5")),
    gates: [$merged.order[] as $name | resolve($name; $merged.defaults + $merged.by[$name])]
  }
# Names are already unique by construction, so this guards against a future change.
| require(([.gates[].name] | length) == ([.gates[].name] | unique | length); "gate names must be unique")
