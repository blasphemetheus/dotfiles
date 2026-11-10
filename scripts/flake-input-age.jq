# Resolve root inputs, including follows paths. Node names are not input names.
def resolve($ref; $depth):
  if $depth > 64 then error("cyclic or excessively deep input follows")
  elif ($ref | type) == "string" then
    if .nodes[$ref] == null then error("missing lock node: " + $ref) else $ref end
  elif ($ref | type) == "array" then
    . as $lock |
    reduce $ref[] as $part (.root;
      . as $node | $lock | resolve(.nodes[$node].inputs[$part]; $depth + 1))
  else error("invalid input reference")
  end;

. as $lock |
[.nodes[.root].inputs | to_entries[] |
  .key as $name | .value as $ref |
  $lock | resolve($ref; 0) as $node |
  .nodes[$node].locked as $locked |
  {
    input: $name,
    node: $node,
    revision: ($locked.rev // null),
    lastModified: ($locked.lastModified // null),
    ageDays: (if ($locked.lastModified | type) == "number"
      then ([0, (($now - $locked.lastModified) / 86400 | floor)] | max)
      else null end)
  }
] | sort_by(.input)
