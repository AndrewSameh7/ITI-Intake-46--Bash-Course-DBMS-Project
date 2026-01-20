#!/usr/bin/bash
# ================= TABLE MENU =================

Reset="\033[0m"
Red="\033[31m"
Green="\033[32m"
Yellow="\033[33m"
Blue="\033[34m"

# ================= FUNCTIONS =================

createTable() {
    read -p "Table Name: " tname
    [[ -f $tname.table ]] && echo "Table Exists" && return

    read -p "Number of Columns: " cols
    meta=()
    names=()
    pkSet=0

    for ((i=1;i<=cols;i++)); do
        read -p "Column $i Name: " name
        read -p "Datatype (int/string): " type
        read -p "Key Type? (pk/fk/none): " key

        if [[ $key == "pk" && $pkSet -eq 0 ]]; then
            meta+=("$name:$type:PK")
            pkSet=1
        elif [[ $key == "fk" ]]; then
            read -p "Referenced Table: " refTable
            read -p "Referenced Column: " refCol
            meta+=("$name:$type:FK($refTable.$refCol)")
        else
            meta+=("$name:$type")
        fi

        names+=("$name")
    done

    (IFS="|"; echo "${meta[*]}") > "$tname.table"
    (IFS="|"; echo "${names[*]}") >> "$tname.table"
    echo -e "${Green}Table Created Successfully${Reset}"
}

listTables() {
    ls *.table 2>/dev/null || echo "No Tables Found"
}

describeTable() {
    read -p "Table Name: " t
    [[ ! -f $t.table ]] && echo "Table Not Found" && return

    echo -e "\nColumn Name | Type | Key"
    echo "--------------------------------------"
    IFS='|' read -ra meta < <(sed -n '1p' "$t.table")
    for c in "${meta[@]}"; do
        name=$(cut -d: -f1 <<< "$c")
        type=$(cut -d: -f2 <<< "$c")
        key=$(cut -d: -f3- <<< "$c")
        [[ -z $key ]] && key="-"
        printf "%-12s | %-7s | %s\n" "$name" "$type" "$key"
    done
}

dropTable() {
    select t in *.table
    do
        [[ -n $t ]] && rm "$t" && echo "Table Deleted"
        break
    done
}

insertIntoTable() {
    read -p "Table Name: " t
    file="$t.table"
    [[ ! -f $file ]] && echo "Table Not Found" && return

    meta=$(sed -n '1p' "$file")
    IFS='|' read -ra arr <<< "$meta"
    values=()

    for c in "${arr[@]}"; do
        name=$(cut -d: -f1 <<< "$c")
        type=$(cut -d: -f2 <<< "$c")
        key=$(cut -d: -f3 <<< "$c")

        read -p "$name ($type): " v
        [[ $type == "int" && ! $v =~ ^[0-9]+$ ]] && echo "Invalid Type" && return

        if [[ $key == "PK" ]]; then
            awk -F'|' -v v="$v" 'NR>2{if($1==v)exit 1}' "$file" \
            || { echo "Primary Key Exists"; return; }
        fi

        values+=("$v")
    done

    (IFS="|"; echo "${values[*]}") >> "$file"
    echo -e "${Green}Row Inserted${Reset}"
}

selectFromTable() {
    read -p "Table Name: " t
    awk -F'|' '
    NR==2{for(i=1;i<=NF;i++) printf "%-15s",$i; print "\n-----------------------------"}
    NR>2{for(i=1;i<=NF;i++) printf "%-15s",$i; print ""}
    ' "$t.table"
}

selectByPK() {
    read -p "Table Name: " t
    read -p "Primary Key Value: " pk

    awk -F'|' -v pk="$pk" '
    NR==2{for(i=1;i<=NF;i++) printf "%-15s",$i; print "\n-----------------------------"}
    NR>2 && $1==pk{for(i=1;i<=NF;i++) printf "%-15s",$i; print ""}
    ' "$t.table"
}

countRows() {
    read -p "Table Name: " t
    rows=$(($(wc -l < "$t.table") - 2))
    echo "Total Rows: $rows"
}

deleteFromTable() {
    read -p "Table Name: " t
    read -p "Primary Key Value: " pk
    sed -i "/^$pk|/d" "$t.table"
    echo "Row Deleted"
}

updateTable() {
    read -p "Table Name: " t
    read -p "Primary Key Value: " pk
    read -p "Column Number: " col
    read -p "New Value: " nv

    awk -F'|' -v pk="$pk" -v c="$col" -v nv="$nv" '
    NR<=2{print;next}
    {if($1==pk) $c=nv; print}
    ' OFS='|' "$t.table" > tmp && mv tmp "$t.table"

    echo "Row Updated"
}

# ================= SQL MODE (Capital Tables, keep semicolon) =================

sqlMode() {
    echo -e "${Yellow}Enter SQL Commands (type 'exit' to leave SQL mode)${Reset}"
    read -p "Enter Database in use: " db
    [[ ! -d ~/.DBMS/$db ]] && echo -e "${Red}Database Not Found${Reset}" && return

    while true; do
        read -p "SQL> " query
        [[ $query == "exit" ]] && break

        # Keep original query including semicolon
        q="$query"

        case "$q" in
            SELECT\ *\ FROM\ *)
                tbl=$(echo "$q" | awk '{print $4}')
                if [[ -f ~/.DBMS/$db/$tbl.table ]]; then
                    awk -F'|' '
                    NR==2{
                        for(i=1;i<=NF;i++) printf "%-15s",$i
                        print "\n--------------------------------"
                    }
                    NR>2{
                        for(i=1;i<=NF;i++) printf "%-15s",$i
                        print ""
                    }' ~/.DBMS/$db/$tbl.table
                else
                    echo -e "${Red}Table '$tbl' not found${Reset}"
                fi
            ;;
            SELECT\ *\ FROM\ *\ WHERE\ *)
                tbl=$(echo "$q" | awk '{print $4}')
                cond=$(echo "$q" | sed -n 's/.*WHERE \(.*\)/\1/p')
                if [[ -f ~/.DBMS/$db/$tbl.table ]]; then
                    awk -F'|' -v c="$cond" '
                    NR==2{
                        for(i=1;i<=NF;i++) printf "%-15s",$i
                        print "\n--------------------------------"
                    }
                    NR>2{
                        if($0 ~ c){
                            for(i=1;i<=NF;i++) printf "%-15s",$i
                            print ""
                        }
                    }' ~/.DBMS/$db/$tbl.table
                else
                    echo -e "${Red}Table '$tbl' not found${Reset}"
                fi
            ;;
            *)
                echo -e "${Red}Unsupported SQL Command${Reset}"
            ;;
        esac
    done
}

# ================= TABLE MENU =================

menu=("CreateTable" "ListTables" "DescribeTable" "DropTable" "Insert" "SelectAll" "SelectByPK" "CountRows" "Delete" "Update" "SQLMode" "Back")

select ch in "${menu[@]}"
do
    case $REPLY in
        1) createTable ;;
        2) listTables ;;
        3) describeTable ;;
        4) dropTable ;;
        5) insertIntoTable ;;
        6) selectFromTable ;;
        7) selectByPK ;;
        8) countRows ;;
        9) deleteFromTable ;;
        10) updateTable ;;
        11) sqlMode ;;
        12) break ;;
    esac
done

