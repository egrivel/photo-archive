# Module: Photo Notifications (pnot)
#
# Supporting the notification system. General principle: any event resulting in
# a notification writes a row in the notification table. The notification
# receives a unique ID (basically, row number). Clients can ask for new
# notifications since the last one they received.
#
# Notifications have:
#  notId      : unique ID (row number)
#  type       : type of notification; types must be known by both producers and
#               consumers
#  description: short text describing the notification
#  data       : additional data (type-specific) for the notification
#  timestamp  : when the notification was created

use photos_common;
use photos_sql;

return 1;
