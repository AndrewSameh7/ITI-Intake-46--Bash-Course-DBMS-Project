#!/usr/bin/bash
# ================= DBMS MAIN MENU =================

LC_COLLATE=C
shopt -s extglob
export PS3="DBMS>>"

# ================= Script Path =================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ================= Colors =================
Reset="\033[0m"
Red="\033[31m"
Green="\033[32m"
Yellow="\033[33m"
Blue="\033[34m"

# ================= Create DBMS Root =================
[[ ! -d ~/.DBMS ]] && mkdir ~/.DBMS

# ================= MAIN MENU =================
menu=("CreateDB" "ListAllDB" "ConnectDB" "RemoveDB" "BackupDB" "Exit")

select choice in "${menu[@]}"
do
    case $REPLY in

    1)  # Create Database
        read -p "Enter Database Name: " db
        db=$(tr ' ' '_' <<< "$db")

        if [[ $db = [0-9]* ]]; then
            echo -e "${Red}DB name can't start with number${Reset}"
        elif [[ -d ~/.DBMS/$db ]]; then
            echo -e "${Red}Database already exists${Reset}"
        elif [[ $db =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            mkdir ~/.DBMS/$db
            echo -e "${Green}Database Created Successfully${Reset}"
        else
            echo -e "${Red}Invalid DB Name${Reset}"
        fi
    ;;

    2)  # List Databases
        ls -F ~/.DBMS 2>/dev/null | grep '/' | tr -d '/'
    ;;

    3)  # Connect Database
        read -p "Enter Database Name: " db
        if [[ -d ~/.DBMS/$db ]]; then
            cd ~/.DBMS/$db || continue
            export PS3="$db>>"
            source "$SCRIPT_DIR/table.sh"  # Table menu with SQL Mode inside
            export PS3="DBMS>>"
        else
            echo -e "${Red}Database Not Found${Reset}"
        fi
    ;;

    4)  # Remove Database
        select db in $(ls ~/.DBMS)
        do
            [[ -z $db ]] && break
            rm -rf ~/.DBMS/$db
            echo -e "${Green}Database Deleted${Reset}"
            break
        done
    ;;

    5)  # Backup Database as .db file
        select db in $(ls ~/.DBMS)
        do
            [[ -z $db ]] && break
            backup_file="$SCRIPT_DIR/${db}.db"
            [[ -f $backup_file ]] && rm "$backup_file"
            tar -cf "$backup_file" -C ~/.DBMS "$db"
            rm -rf ~/.DBMS/$db
            echo -e "${Green}Database '$db' backed up successfully as $backup_file${Reset}"
            break
        done
    ;;

    6)  # Exit
        echo "Good Bye"
        break
    ;;

    *)
        echo -e "${Red}Invalid Choice${Reset}"
    ;;
    esac
done

