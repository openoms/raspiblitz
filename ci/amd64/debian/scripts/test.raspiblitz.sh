#!/bin/sh -eux

echo '# Check out the branch of the PR (passed down as an env variable)'
/home/admin/config.scripts/blitz.github.sh  ${branch} ${github_user}

echo '# Test the installs'

echo 'cl.install.sh on'
/home/admin/config.scripts/cl.install.sh on
