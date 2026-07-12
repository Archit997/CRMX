from __future__ import annotations

import json
from copy import deepcopy
from datetime import date, datetime
from pathlib import Path
from threading import Lock
from typing import Any


class POCDataService:
    def __init__(self, data_dir: Path | str) -> None:
        self.data_dir = Path(data_dir)
        self._lock = Lock()

    def status_master(self) -> list[dict[str, Any]]:
        return self._read_json("status_master.json")

    def authenticate(self, identifier: str, password: str) -> dict[str, Any] | None:
        normalized_identifier = identifier.strip().lower()
        for user in self._read_json("users.json"):
            matches_identifier = normalized_identifier in {
                str(user.get("email", "")).lower(),
                str(user.get("phone", "")).lower(),
            }
            if matches_identifier and user.get("password") == password:
                session_user = {key: value for key, value in user.items() if key != "password"}
                return {
                    "token": f"poc-token-{session_user['user_id']}",
                    "user": session_user,
                }
        return None

    def clients(self) -> list[dict[str, Any]]:
        clients = self._read_json("client_info.json")
        statuses = self._status_lookup()
        return [self._with_status(client, statuses) for client in clients]

    def search_clients(self, query: str) -> list[dict[str, Any]]:
        term = query.strip().lower()
        if not term:
            return self.clients()

        fields = (
            "client_name",
            "company_name",
            "phone",
            "whatsapp_number",
            "email",
            "city",
            "assigned_to",
            "priority",
        )
        return [
            client
            for client in self.clients()
            if any(term in str(client.get(field, "")).lower() for field in fields)
        ]

    def client(self, client_id: int) -> dict[str, Any] | None:
        for client in self.clients():
            if client["client_id"] == client_id:
                client["updates"] = self.client_updates(client_id)
                return client
        return None

    def create_client(self, payload: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            clients = self._read_json("client_info.json")
            now = datetime.now().isoformat(timespec="seconds")
            client = self._client_from_payload(
                payload=payload,
                client_id=self._next_id(clients, "client_id"),
                now=now,
            )
            clients.append(client)
            self._write_json("client_info.json", clients)
            return self._with_status(client, self._status_lookup())

    def update_client(self, client_id: int, payload: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            clients = self._read_json("client_info.json")
            client = next((item for item in clients if item["client_id"] == client_id), None)
            if client is None:
                raise ValueError(f"Client {client_id} not found")

            editable_fields = {
                "client_name",
                "company_name",
                "phone",
                "whatsapp_number",
                "email",
                "city",
                "assigned_to",
                "current_status_no",
                "requirement_summary",
                "priority",
                "deal_value",
            }
            for field in editable_fields:
                if field not in payload:
                    continue
                value = payload[field]
                if field in {"current_status_no", "deal_value"}:
                    value = int(value or 0)
                client[field] = value
            client["last_updated"] = datetime.now().isoformat(timespec="seconds")
            self._write_json("client_info.json", clients)
            return self._with_status(client, self._status_lookup())

    def delete_client(self, client_id: int) -> None:
        with self._lock:
            clients = self._read_json("client_info.json")
            remaining_clients = [client for client in clients if client["client_id"] != client_id]
            if len(remaining_clients) == len(clients):
                raise ValueError(f"Client {client_id} not found")

            updates = self._read_json("client_updates.json")
            remaining_updates = [update for update in updates if update["client_id"] != client_id]
            self._write_json("client_info.json", remaining_clients)
            self._write_json("client_updates.json", remaining_updates)

    def create_status(self, payload: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            statuses = self._read_json("status_master.json")
            status = {
                "status_no": self._next_id(statuses, "status_no"),
                "status_name": payload["status_name"],
                "category": payload.get("category", "Lead"),
                "description": payload.get("description", ""),
                "is_active": bool(payload.get("is_active", True)),
            }
            statuses.append(status)
            self._write_json("status_master.json", statuses)
            return deepcopy(status)

    def client_updates(self, client_id: int) -> list[dict[str, Any]]:
        updates = [
            update
            for update in self._read_json("client_updates.json")
            if update["client_id"] == client_id
        ]
        updates.sort(key=lambda update: update["created_at"], reverse=True)
        return updates

    def create_client_update(self, client_id: int, payload: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            clients = self._read_json("client_info.json")
            updates = self._read_json("client_updates.json")

            client = next((item for item in clients if item["client_id"] == client_id), None)
            if client is None:
                raise ValueError(f"Client {client_id} not found")

            new_status_no = int(payload["new_status_no"])
            update = {
                "update_id": self._next_id(updates, "update_id"),
                "client_id": client_id,
                "update_type": payload.get("update_type", "Follow-up"),
                "old_status_no": client["current_status_no"],
                "new_status_no": new_status_no,
                "request_type": payload.get("request_type", "None"),
                "request_subtype": payload.get("request_subtype", "None"),
                "note": payload["note"],
                "followup_date": payload.get("followup_date") or None,
                "followup_time": payload.get("followup_time") or None,
                "created_by": payload.get("created_by", client["assigned_to"]),
                "created_at": datetime.now().isoformat(timespec="seconds"),
            }

            updates.append(update)
            client["current_status_no"] = new_status_no
            client["last_updated"] = update["created_at"]
            self._write_json("client_updates.json", updates)
            self._write_json("client_info.json", clients)
            return deepcopy(update)

    def followups_today(self) -> list[dict[str, Any]]:
        clients_by_id = {client["client_id"]: client for client in self.clients()}
        today = date.today().isoformat()
        rows: list[dict[str, Any]] = []

        for update in self._read_json("client_updates.json"):
            followup_date = update.get("followup_date")
            if not followup_date or followup_date > today:
                continue
            client = clients_by_id.get(update["client_id"])
            if not client:
                continue
            rows.append(
                {
                    "client_id": client["client_id"],
                    "client_name": client["client_name"],
                    "company_name": client.get("company_name"),
                    "priority": client["priority"],
                    "assigned_to": client["assigned_to"],
                    "status_name": client["status_name"],
                    "note": update["note"],
                    "followup_date": followup_date,
                    "followup_time": update.get("followup_time"),
                    "is_overdue": followup_date < today,
                }
            )

        rows.sort(key=lambda row: (not row["is_overdue"], row.get("followup_time") or "99:99"))
        return rows

    def manager_analytics(self) -> dict[str, Any]:
        clients = self.clients()
        followups = self.followups_today()
        activity = self._read_json("team_activity.json")
        overdue = [item for item in followups if item["is_overdue"]]
        quoted_value = sum(
            int(client.get("deal_value", 0))
            for client in clients
            if client["current_status_no"] in {6, 7, 8, 9, 10}
        )

        return {
            "summary": {
                "calls": sum(int(row["calls"]) for row in activity),
                "whatsapp": sum(int(row["whatsapp_chats"]) for row in activity),
                "overdue_followups": len(overdue),
                "quoted_value": quoted_value,
                "unlogged_calls": sum(int(row["unlogged_calls"]) for row in activity),
                "payment_pending_clients": sum(1 for client in clients if client["current_status_no"] == 9),
                "orders_confirmed": sum(1 for client in clients if client["current_status_no"] == 10),
            },
            "team": activity,
        }

    def finance_receivables(self) -> dict[str, Any]:
        receivables = self._read_json("finance_receivables.json")
        total_due = sum(int(item["amount_due"]) for item in receivables)
        return {
            "total_due": total_due,
            "items": receivables,
            "daily_message": self._finance_message(receivables),
        }

    def _finance_message(self, receivables: list[dict[str, Any]]) -> str:
        lines = ["Today receivable follow-up:"]
        for index, item in enumerate(receivables, start=1):
            lines.append(
                f"{index}. {item['company_name']}: {item['action']} Amount: ₹{int(item['amount_due']):,}."
            )
        return "\n".join(lines)

    def _with_status(
        self,
        client: dict[str, Any],
        statuses: dict[int, dict[str, Any]],
    ) -> dict[str, Any]:
        row = deepcopy(client)
        status = statuses.get(row["current_status_no"], {})
        row["status_name"] = status.get("status_name", "Unknown")
        row["status_category"] = status.get("category", "Unknown")
        return row

    def _client_from_payload(
        self,
        payload: dict[str, Any],
        client_id: int,
        now: str,
    ) -> dict[str, Any]:
        required_fields = ("client_name", "phone", "assigned_to", "requirement_summary")
        missing = [field for field in required_fields if not str(payload.get(field, "")).strip()]
        if missing:
            raise KeyError(", ".join(missing))

        return {
            "client_id": client_id,
            "client_name": payload["client_name"].strip(),
            "company_name": payload.get("company_name", "").strip(),
            "phone": payload["phone"].strip(),
            "whatsapp_number": payload.get("whatsapp_number") or payload["phone"].strip(),
            "email": payload.get("email", "").strip(),
            "city": payload.get("city", "").strip(),
            "assigned_to": payload["assigned_to"].strip(),
            "current_status_no": int(payload.get("current_status_no", 1)),
            "requirement_summary": payload["requirement_summary"].strip(),
            "priority": payload.get("priority", "Warm"),
            "deal_value": int(payload.get("deal_value") or 0),
            "created_date": date.today().isoformat(),
            "last_updated": now,
        }

    def _status_lookup(self) -> dict[int, dict[str, Any]]:
        return {item["status_no"]: item for item in self.status_master()}

    def _read_json(self, filename: str) -> list[dict[str, Any]]:
        path = self.data_dir / filename
        with path.open("r", encoding="utf-8") as file:
            return json.load(file)

    def _write_json(self, filename: str, rows: list[dict[str, Any]]) -> None:
        path = self.data_dir / filename
        with path.open("w", encoding="utf-8") as file:
            json.dump(rows, file, indent=2)
            file.write("\n")

    @staticmethod
    def _next_id(rows: list[dict[str, Any]], key: str) -> int:
        if not rows:
            return 1
        return max(int(row[key]) for row in rows) + 1
