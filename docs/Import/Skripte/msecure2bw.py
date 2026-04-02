""" Convert mSecure6 CSV export file to a Bitwarden JSON file """

import sys
import argparse
import uuid
import hashlib
import datetime
import json

groupName = []
groupData = []

def get_id(name: str) -> str:
    """Calculate deterministic UUID from string"""
    md5 = hashlib.md5(name.encode())
    return str(uuid.UUID(bytes=md5.digest()))


def get_date() -> str:
    """Return the current date string in Bitwarden format"""
    return datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S.000Z")


def add_record(line: str):
    """Parse one mSecure6 CSV line and add Bitwarden record"""

    tokens = line.strip().split(";")

    # Token[0] ist "Name|ID"
    if "|" in tokens[0]:
        name, ms_id = tokens[0].split("|", 1)
    else:
        name, ms_id = tokens[0], None

    category = tokens[1] if len(tokens) > 1 else ""
    notes = tokens[3] if len(tokens) > 3 else ""

    # Gruppe anlegen (entspricht Kategorie)
    if category not in groupName:
        groupName.append(category)
        group = {"encrypted": False, "folders": [], "items": []}
        groupData.append(group)

    group_id = groupName.index(category)
    collections = groupData[group_id].get("folders")
    collection_id = get_id(category)
    items = groupData[group_id].get("items")

    for col in collections:
        if col.get("name") == category:
            break
    else:
        collection = {"id": collection_id, "name": category}
        collections.append(collection)

    # Grundstruktur Item
    item = {
        "passwordHistory": None,
        "revisionDate": get_date(),
        "creationDate": get_date(),
        "deletedDate": None,
        "id": get_id(name),
        "organizationId": None,
        "folderId": get_id(category),
        "reprompt": 0,
        "name": name,
        "notes": notes,
        "favorite": False,
    }

    # mSecure-Felder parsen
    fields = []
    username = password = uri = None

    for field in tokens[4:]:
        if "|" not in field:
            continue
        parts = field.split("|")
        if len(parts) < 2:
            continue
        label = parts[0].strip()
        value = parts[-1].strip()

        if label.lower().startswith("benutzername"):
            username = value
        elif label.lower().startswith("kennwort") or label.lower().startswith("passwort"):
            password = value
        elif label.lower() in ["server", "website", "url"]:
            uri = value
        elif value:
            fields.append({"name": label, "value": value, "type": 0, "linkedId": None})

    # Login
    item["type"] = 1
    item["login"] = {
        "fido2Credentials": [],
        "uris": [{"match": None, "uri": uri}] if uri else [],
        "username": username,
        "password": password,
        "totp": None,
    }

    if fields:
        item["fields"] = fields

    item["collectionIds"] = [None]
    items.append(item)


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert mSecure csv file to bitWarden json file.")
    parser.add_argument("file", help="csv file exported from mSecure.")
    args = parser.parse_args()

    with open(args.file, "r", encoding="utf_8") as f:
        for line in f:
            if not line.strip():
                continue
            if line == "mSecure6 CSV export file":
                # Erste Zeile verwerfen
                continue
            add_record(line.strip())

    output_file = args.file.replace(".csv", ".json")
    # Alles in eine Datei schreiben
    merged = {"encrypted": False, "items": [], "folders": []}

    for g in groupData:
        merged["folders"].extend(g["folders"])
        merged["items"].extend(g["items"])

    out_str = json.dumps(merged, ensure_ascii=False, indent=4).replace("\\\\n", "\\n")
    with open(output_file, "w", encoding="utf_8") as f:
        f.write(out_str)
    print(output_file + " generated")

    return 0


if __name__ == "__main__":
    sys.exit(main())
