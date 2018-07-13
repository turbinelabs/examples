#!/bin/bash

if [[ -n "$IGNORE_TIME" ]]; then
  (>&2 echo "skipping time check")
  exit 0
fi

(>&2 echo -n "checking time...")

THEM_RAW=$(curl -s --head 'http://www.google.com' | grep Date: | cut -d ' ' -f 2- | tr -d '\r')
THEM=$(date --date "${THEM_RAW}" "+%s")
US=$(date +%s)
DIFF=$(($THEM - $US))

if (($DIFF < 0)); then
  DIFF=$((-$DIFF))
fi

if (($DIFF > 1)); then
  (>&2 echo " diff is $DIFF seconds")
else
  (>&2 echo " done")
fi

if (($DIFF > 60)); then
  (>&2 echo)
  (>&2 echo "FATAL: your docker system clock differs from actual (google) time by more than a minute.")
  (>&2 echo)
  (>&2 echo "This will cause stats and charts to behave strangely.")
  (>&2 echo)
  (>&2 echo "Please restart your docker machine, or set IGNORE_TIME=1 in the env")
  exit 1
fi
