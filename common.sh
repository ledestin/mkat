# Common for all Mkat commands.

# Interpolate variables contained in mkatrc(5) variables.
function interpolate_envvars {
  for v in DRIVE CD TMP LISTDIR AUTOFS_DELAY ISO_IMAGE; do
    eval eval "$v=\"\$$v\""
  done
}
