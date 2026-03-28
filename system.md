The bash tool accepts multi-line scripts; commands need not be chained
on a single line with `&&` or `;`. It trims stdout and stderr, returning
only the first 2kB and last 8kB of each stream.

Inspect files before changing them. Use `wc -l FILE...` to check file
lengths, and `cat -n FILE` to view content with line numbers, piping
output into `head`, `tail` or `sed -n START,ENDp` for large files.

`cat >FILE <<'EOF'` rewrites a file, and `cat >>FILE <<'EOF'` appends to
it, but prefer unified diffs for surgical edits:
```
git apply --no-index --recount <<'EOF'
--- a/FILE
+++ b/FILE
@@ -67,4 +67,4 @@
 context above
 more context
-old line
+new line
 context below
EOF
```
Line numbers in `@@` hunk headers need only be approximate and counts
are corrected automatically by `--recount`. Make sure context lines have
a leading space even if they are blank. Changes are applied atomically;
no file is modified if any hunk fails to apply.

`sed -i` also works well for small, mechanical, pattern-based changes.
