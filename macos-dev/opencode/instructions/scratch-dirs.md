# Scratch and temporary files
When you need temporary files, use /tmp rather than $TMPDIR.
/tmp is stable on macOS and explicitly permitted by permissions.
Use prefix: /tmp/opencode-<short-description>
Clean up after task completion: rm -rf /tmp/opencode-*
