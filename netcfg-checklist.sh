#! /bin/bash

. /usr/lib/network/network

if ! type dialog &> /dev/null; then
   echo "Please install 'dialog' to use netcfg-menu"
   exit 1
fi



# Shut down all profiles except those given as arguments (must be sorted).
function all_down_except()
{
  EXCEPTIONS=("$@")
  while read prof; do
    # prof is the path, get the basename
    prof="${prof##*/}"
    skip=false
    for (( i=0; i < ${#EXCEPTIONS[@]}; i++ )); do
      if [[ ${EXCEPTIONS[$i]} == $prof ]]; then
        skip=true
        break
      fi
    done
    $skip || profile_down "$prof"
  done < <(find "$STATE_DIR/profiles" -type f | sort) # Only check active profiles.
}





check_make_state_dir
# JP: we'll use $STATE_DIR/menu to record what profile is being connected in this way
# rm -f "$STATE_DIR/menu"

# Set timeout
TIMEOUT=${1-0}

# Scan all profiles
i=0
# JP: change for prof to while read prof to avoid assumption that profile names are always single tokens (no spaces etc.)
while read prof; do
    profiles[i++]="$prof"
    profiles[i++]=$(. "$PROFILE_DIR/$prof"; echo "$DESCRIPTION")
    # Get the profile status for the checklist.
    if check_profile "$prof"
    then
      profiles[i++]=on
    else
      profiles[i++]=off
    fi
done < <(list_profiles | sort)  # JP: re-use list_profiles instead of duplicating it; avoid subshell we'd get by piping it to the while read...

if [[ ${#profiles} -eq 0 ]]; then
    exit_err "No profiles were found in $PROFILE_DIR"
fi

PROFILES=($(dialog --timeout "$TIMEOUT" --stdout \
                 --checklist 'Select the network profile(S) you wish to use' \
                        13 50 6 "${profiles[@]}"))

ret=$?
case $ret in
    1) ;; # Cancel - do nothing
    255|0) # Timeout /or user selection
        if [[ -z ${PROFILES[0]} ]]
        then
          all_down
        else
          for PROFILE in "${PROFILES[@]}"
          do
            check_profile "$PROFILE" || profile_up "$PROFILE"
          done
          all_down_except "${PROFILES[@]}"
        fi
        ret=$?
        ;;
    *)  # Should not happen
        exit_err "Abnormal return code from dialog: $ret"
        ;;
esac

exit $ret           # JP: exit with caught $?

# vim: ft=sh ts=4 et sw=4:
