#!/bin/bash

set -e
set -x

echo "Starting $DB..."

case "$DB" in
  mysql)
    sudo service mysql start
    ;;
  postgresql)
    export PGDATA=/tmp/postgres
    export PGLOGS=/tmp/log/postgres
    mkdir -p $PGDATA
    mkdir -p $PGLOGS
    # NOTE: using double quotes intentionally to pass through root-owned ENV.
    su - vcap -c "PATH=$PATH; initdb -U postgres -D $PGDATA"

    # pg_ctl start -l $PGLOGS/server.log
    sudo service postgresql start
    ;;
  *)
    echo $"Usage: $0 {mysql|postgresql}"
    exit 1
esac

set +e
$@
exitcode=$?

echo "Stopping $DB..."
case "$DB" in
  mysql)
    sudo service mysql stop
    ;;
  postgresql)
    # pg_ctl stop
    sudo service postgresql start
    ;;
esac

exit $exitcode
