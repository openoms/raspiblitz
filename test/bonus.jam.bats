#!/usr/bin/env bats

mkdir -p /mnt/hdd/
echo "runBehindTor=on" >/mnt/hdd/raspiblitz.conf

@test "jam on" {
  run ../home.admin/config.scripts/bonus.jam.sh on
  echo "# Show the output"
  echo $output
  [ "$status" -eq 0 ]
}

@test "jam off" {
  run ../home.admin/config.scripts/bonus.jam.sh off
  echo "# Show the output"
  echo $output
  [ "$status" -eq 0 ]
}
