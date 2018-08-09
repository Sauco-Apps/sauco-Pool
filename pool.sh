#!/bin/bash
SCRIPT_NAME="DPoSPool"

cd "$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
. "$(pwd)/shared.sh"
. "$(pwd)/env.sh"

if [ ! -f "$(pwd)/dpospool.js" ]; then
  echo "Error: $SCRIPT_NAME installation was not found. Exiting."
  exit 1
fi

if [ "\$USER" == "root" ]; then
  echo "Error: $SCRIPT_NAME should not be run be as root. Exiting."
  exit 1
fi

UNAME=$(uname)
POOL_CONFIG=config.json

LOGS_DIR="$(pwd)/logs"
PIDS_DIR="$(pwd)/pids"

LOG_DB_FILE="$LOGS_DIR/pgsql.log"
LOG_APP_FILE="$LOGS_DIR/app.log"
LOG_CRON_FILE="$LOGS_DIR/cron.log"

PID_APP_FILE="$PIDS_DIR/dpospool.pid"
PID_DB_FILE="$PIDS_DIR/pgsql.pid"

DB_NAME="$(grep "dbname" "$POOL_CONFIG" | cut -f 4 -d '"')"
DB_USER="$(grep "dbuser" "$POOL_CONFIG" | cut -f 4 -d '"')"
DB_PASS="$(grep "dbpass" "$POOL_CONFIG" | cut -f 4 -d '"')"
DB_PORT="$(grep "dbport" "$POOL_CONFIG" | cut -f 4 -d '"')"
DB_DATA="$(pwd)/pgsql/data"
DB_CONFIG="$(pwd)/pgsql/pgsql.conf"

CMDS=("node" "crontab" "curl")
CMDS1=("forever" "psql" "createdb" "createuser" "dropdb" "dropuser")
check_cmds CMDS[@]

################################################################################
install_node_npm() {

    echo -n "Installing nodejs and npm... "
    curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash - &>> $logfile
    sudo apt-get install -y -qq nodejs &>> $logfile || { echo "Could not install nodejs and npm. Exiting." && exit 1; }
    echo -e "done.\n" && echo -n "Installing bower... "
    sudo npm install bower -g &>> $logfile || { echo "Could not install bower. Exiting." && exit 1; }
    echo -e "done.\n" && echo -n "Installing Gulp... "
    sudo npm install gulp -g &>> $logfile || { echo "Could not install gulp. Exiting." && exit 1; }
    echo -e "done.\n"

    return 0;
}

install_prereq() {
    #Instalación de la base de datos
    echo -n "Updating apt repository sources for postgresql.. ";
    sudo bash -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main" > /etc/apt/sources.list.d/pgdg.list' &>> $logfile || \
    { echo "Could not add postgresql repo to apt." && exit 1; }
    echo -e "done.\n"

    echo -n "Adding postgresql repo key... "
    sudo wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add - &>> $logfile || \
    { echo "Could not add postgresql repo key. Exiting." && exit 1; }
    echo -e "done.\n"

    echo -n "Installing postgresql... "
    sudo apt-get update -qq &> /dev/null && sudo apt-get install -y -qq postgresql-9.6 postgresql-contrib-9.6 libpq-dev &>> $logfile || \
    { echo "Could not install postgresql. Exiting." && exit 1; }
    echo -e "done.\n"

    echo -n "Enable postgresql... "
        sudo update-rc.d postgresql enable
    echo -e "done.\n"
}

create_user() {

    if start_postgres; then
        user_exists=$(grep postgres /etc/passwd |wc -l);
        if [[ $user_exists == 1 ]]; then
            res=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" 2> /dev/null)
            if [[ $res -ne 1 ]]; then
              echo -n "Creating database user... "
              res=$(sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 2> /dev/null)
              res=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" 2> /dev/null)
              if [[ $res -eq 1 ]]; then
                echo -e "done.\n"
              fi
            fi

            echo -n "Creating database... "
            res=$(sudo -u postgres dropdb --if-exists "$DB_NAME" 2> /dev/null)
            res=$(sudo -u postgres createdb -O "$DB_USER" "$DB_NAME" 2> /dev/null)
            res=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_database where datname='$DB_NAME'" 2> /dev/null)
            if [[ $res -eq 1 ]]; then
                echo -e "done.\n"
            fi
        fi
        return 0
    fi

    return 1;
}

create_database() {
    res=$(sudo -u postgres dropdb --if-exists "$DB_NAME" 2> /dev/null)
    res=$(sudo -u postgres createdb -O "$DB_USER" "$DB_NAME" 2> /dev/null)
    res=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_database where datname='$DB_NAME'" 2> /dev/null)
    
    if [[ $res -eq 1 ]]; then
      echo "√ Postgresql database created successfully."
    else
      echo "X Failed to create Postgresql database."
      exit 1
    fi
}

install_dependencias(){
  cd public_src
  bower --allow-root install &>> $logfile || { echo -e "\n\nCould not install bower components for the web wallet. Exiting." && exit 1; }
  npm install --production --unsafe-perm &>> $logfile || { echo "Could not install NPM components, please check the log directory. Exiting." && exit 1; }
  gulp release
  cd ..
  npm install --production --unsafe-perm &>> $logfile || { echo "Could not install NPM components, please check the log directory. Exiting." && exit 1; }
}


#Database
#create_user() {
#  dropuser --if-exists "$DB_USER" -p "$DB_PORT" &> /dev/null
#  createuser --createdb "$DB_USER" -p "$DB_PORT" &> /dev/null
#  psql -qd postgres -c "ALTER USER "$DB_USER" WITH PASSWORD '$DB_PASS';" -p "$DB_PORT" &> /dev/null
#  if [ $? != 0 ]; then
#    echo "X Failed to create $SCRIPT_NAME database user."$DB_USER" "$DB_PASS" "$DB_PORT
#    exit 1
#  else
#    echo "√ $SCRIPT_NAME database user created successfully."
#  fi
#}
#create_database() {
#  dropdb --if-exists "$DB_NAME" -p "$DB_PORT" &> /dev/null
#  createdb "$DB_NAME" -p "$DB_PORT" &> /dev/null
#  psql -U "$DB_USER" -d "$DB_NAME" -f $(pwd)"/sql/database_scheme.sql" -p "$DB_PORT" &> /dev/null
#  if [ $? != 0 ]; then
#    echo "X Failed to create $SCRIPT_NAME database."
#    exit 1
#  else
#    echo "√ $SCRIPT_NAME database created successfully."
#  fi
#}

start_postgresql() {
  if [ -f $PID_DB_FILE ]; then
    echo "√ $SCRIPT_NAME database is running."
  else
    pg_ctl -o "-F -p $DB_PORT --config-file=$DB_CONFIG" -D "$DB_DATA" -l "$LOG_DB_FILE" start &> /dev/null
    sleep 1
    if [ $? != 0 ]; then
      echo "X Failed to start $SCRIPT_NAME database."
      exit 1
    else
      echo "√ $SCRIPT_NAME database started successfully."
    fi
  fi
}
stop_postgresql() {
  if [ -f $PID_DB_FILEL ]; then
    pg_ctl -o "-F -p $DB_PORT --config-file=$DB_CONFIG" -D "$DB_DATA" -l "$LOG_DB_FILE" stop &> /dev/null
    sleep 1
    if [ $? != 0 ]; then
      echo "X Failed to stopped $SCRIPT_NAME database."
      exit 1
      #Add kill postgres process if not stoped get pid from file
    else
      echo "√ $SCRIPT_NAME database stopped successfully."
    fi
  else
    echo "√ $SCRIPT_NAME database is not running."
  fi
}
backup_db() {
  if [ -f $PID_DB_FILEL ]; then
    pg_dump -p $DB_PORT $DB_NAME > "sql/"$DB_NAME"_dump.sql"
    sleep 1
    if [ $? != 0 ]; then
      echo "X Failed to backup $SCRIPT_NAME database."
      exit 1
    else
      echo "√ $SCRIPT_NAME database backup successfully."
    fi
  else
    echo "√ $SCRIPT_NAME database is not running."
  fi
}
restore_db() {
  if [ -f $PID_DB_FILEL ]; then
    pg_restore -p $DB_PORT $DB_NAME < "sql/"$DB_NAME"_dump.sql"
    sleep 1
    if [ $? != 0 ]; then
      echo "X Failed to restore $SCRIPT_NAME database."
      exit 1
    else
      echo "√ $SCRIPT_NAME database restore successfully."
    fi
  else
    echo "√ $SCRIPT_NAME database is not running."
  fi
}

#App
install_pool() {
  echo "#####$SCRIPT_NAME Installation#####"
  echo " * Installation may take several minutes"
  check_cmds CMDS1[@]
  echo "√ Check using commands."
  echo " * Instalando Prerequisitos"
  install_node_npm
  install_prereq
  install_dependencias
  echo "√ Pre requisitos instalados."
  stop_pool &> /dev/null
  stop_postgresql &> /dev/null    
  rm -rf $DB_DATA
  pg_ctl initdb -D $DB_DATA &> /dev/null
  sleep 2
  start_postgresql
  sleep 1
  create_user
  create_database
  autostart_pool
  start_pool
  echo " * Installation completed. $SCRIPT_NAME started."
}
autostart_pool() {
  local cmd="crontab"

  command -v "$cmd" &> /dev/null

  if [ $? != 0 ]; then
    echo "X Failed to execute crontab."
    return 1
  fi

  crontab=$($cmd -l 2> /dev/null | sed '/pool\.sh start/d' 2> /dev/null)

  crontab=$(cat <<-EOF
	$crontab
	@reboot $(command -v "bash") $(pwd)/pool.sh start > $LOG_CRON_FILE 2>&1
	EOF
  )

  printf "$crontab\n" | $cmd - &> /dev/null

  if [ $? != 0 ]; then
    echo "X Failed to update crontab."
    return 1
  else
    echo "√ Crontab updated successfully."
    return 0
  fi
}
check_status() {
  if [ -f "$PID_APP_FILE" ]; then
    PID="$(cat "$PID_APP_FILE")"
  fi
  if [ ! -z "$PID" ]; then
    ps -p "$PID" > /dev/null 2>&1
    STATUS=$?
  else
    STATUS=1
  fi

  if [ -f $PID_APP_FILE ] && [ ! -z "$PID" ] && [ $STATUS == 0 ]; then
    echo "√ $SCRIPT_NAME is running as PID: $PID"
    return 0
  else
    echo "X $SCRIPT_NAME is not running."
    return 1
  fi
}
start_pool() {
  if check_status == 1 &> /dev/null; then
    check_status
    exit 1
  else
    forever start -u $SCRIPT_NAME -a -l $LOG_APP_FILE --pidFile $PID_APP_FILE -m 1 dpospool.js &> /dev/null
    if [ $? == 0 ]; then
      echo "√ $SCRIPT_NAME started successfully."
      sleep 3
      check_status
    else
      echo "X Failed to start $SCRIPT_NAME."
    fi
  fi
}
stop_pool() {
  if check_status != 1 &> /dev/null; then
    stopPool=0
    while [[ $stopPool < 5 ]] &> /dev/null; do
      forever stop -t $PID --killSignal=SIGTERM -l $LOG_APP_FILE &> /dev/null
      if [ $? !=  0 ]; then
        echo "X Failed to stop $SCRIPT_NAME."
      else
        echo "√ $SCRIPT_NAME stopped successfully."
        break
      fi
      sleep .5
      stopPool=$[$stopPool+1]
    done
  else
    echo "√ $SCRIPT_NAME is not running."
  fi
}
tail_logs() {
  if [ -f "$LOG_APP_FILE" ]; then
    tail -f "$LOG_APP_FILE"
  fi
}

################################################################################

#Help
help() {
  echo -e "\n ##### Command Options for pool.sh #####\n"
  echo -e "install      - Install $SCRIPT_NAME script"
  echo -e "====="
  echo -e "start        - Start the $SCRIPT_NAME and $SCRIPT_NAME database processes"
  echo -e "stop         - Stop the $SCRIPT_NAME and $SCRIPT_NAME database processes"
  echo -e "reload       - Reload the $SCRIPT_NAME and $SCRIPT_NAME database processes"
  echo -e "status       - Display the status of the PID associated with $SCRIPT_NAME"
  echo -e "logs         - Display and tail $SCRIPT_NAME logs"
  echo -e "help         - Displays this message"
  echo -e "====="
  echo -e "start_node   - Start a $SCRIPT_NAME process"
  echo -e "stop_node    - Stop a $SCRIPT_NAME process"
  echo -e "====="
  echo -e "start_db     - Start the $SCRIPT_NAME database"
  echo -e "stop_db      - Stop the $SCRIPT_NAME database"
  echo -e "reset_db     - Re-create the $SCRIPT_NAME database"
  echo -e "backup_db    - Backup $SCRIPT_NAME database to 'sql' folder"
  echo -e "restore_db   - Restore $SCRIPT_NAME database from 'sql' folder(restore db file "$SCRIPT_NAME"_dump.sql) \n" 
}

#All commands
case $1 in
	"install")
	  install_pool
	  ;;
  "reset_db")
    start_postgresql
    sleep 2
    create_user
    create_database
    ;;
	"start_node")
	  start_pool
	  ;;
	"start")
    rm $LOGS_DIR/*.log
	  start_postgresql
	  sleep 2
	  start_pool
	  ;;
	"stop_node")
	  stop_pool
	  ;;
	"stop")
	  stop_pool
	  stop_postgresql
	  ;;
	"reload")
	  stop_pool
	  sleep 2
	  start_pool
	  ;;
	"start_db")
	  start_postgresql
	  ;;
	"stop_db")
	  stop_postgresql
	  ;;
  "backup_db")
    start_postgresql
    sleep 2
    backup_db
    ;;
  "restore_db")
    start_postgresql
    sleep 2
    restore_db
    ;;
	"status")
	  check_status
	  ;;
	"logs")
	  tail_logs
	  ;;
	"help")
	  help
	  ;;
	*)
  echo "Error: Unrecognized command."
  echo ""
  echo "Available commands are: install|start|stop|reload|logs|status|help|start_node|stop_node|start_db|stop_db|backup_db|restore_db"
  help
  ;;
esac