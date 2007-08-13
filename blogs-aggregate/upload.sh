#!/bin/bash
. "$HOME/conf/Bash/defs/homepage.bash"
cd to-upload
rsync --rsh=ssh *.xml "${__HOMEPAGE_REMOTE_PATH}/me/blogs/agg/"
rsync --rsh=ssh *.xml "${HOMEPAGE_SSH_PATH}/me/blogs/agg/"
