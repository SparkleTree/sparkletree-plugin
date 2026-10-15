#!/bin/sh
# Compare two versions: prints -1, 0 or 1 for "$1 <, =, > $2". Numeric per
# component, missing components count as 0. Used by the CI scripts and the
# publish job; busybox sort has no -V.
awk -v a="${1:-}" -v b="${2:-}" 'BEGIN {
  n = split(a, x, "."); m = split(b, y, ".")
  for (i = 1; i <= 3; i++) {
    if (x[i] + 0 < y[i] + 0) { print -1; exit }
    if (x[i] + 0 > y[i] + 0) { print 1; exit }
  }
  print 0
}'
