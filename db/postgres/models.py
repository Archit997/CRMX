from __future__ import annotations

from datetime import date, datetime, time, timezone
from typing import Any

from sqlalchemy import BIGINT, Boolean, Date, DateTime, ForeignKey, Integer, Text, Time, func, text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class StatusMaster(Base):
    __tablename__ = "status_master"
    __table_args__ = {"schema": "public"}

    status_no: Mapped[int] = mapped_column(Integer, primary_key=True)
    status_name: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(Text, nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default=text("true"))

    clients: Mapped[list["Client"]] = relationship(
        back_populates="current_status",
        foreign_keys="Client.current_status_no",
    )

    old_status_updates: Mapped[list["ClientUpdate"]] = relationship(
        back_populates="old_status",
        foreign_keys="ClientUpdate.old_status_no",
    )
    new_status_updates: Mapped[list["ClientUpdate"]] = relationship(
        back_populates="new_status",
        foreign_keys="ClientUpdate.new_status_no",
    )

    def to_dict(self) -> dict[str, Any]:
        return {
            "status_no": self.status_no,
            "status_name": self.status_name,
            "category": self.category,
            "description": self.description,
            "is_active": self.is_active,
        }


class Client(Base):
    __tablename__ = "client_info"
    __table_args__ = {"schema": "public"}

    client_id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    client_name: Mapped[str] = mapped_column(Text, nullable=False)
    company_name: Mapped[str | None] = mapped_column(Text)
    phone: Mapped[str] = mapped_column(Text, nullable=False)
    whatsapp_number: Mapped[str | None] = mapped_column(Text)
    email: Mapped[str | None] = mapped_column(Text)
    city: Mapped[str | None] = mapped_column(Text)
    assigned_to: Mapped[str] = mapped_column(Text, nullable=False)
    current_status_no: Mapped[int] = mapped_column(
        ForeignKey("public.status_master.status_no"),
        nullable=False,
    )
    requirement_summary: Mapped[str | None] = mapped_column(Text)
    priority: Mapped[str] = mapped_column(Text, nullable=False)
    created_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        default=date.today,
        server_default=func.current_date(),
    )
    last_updated: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        onupdate=func.now(),
    )

    current_status: Mapped[StatusMaster] = relationship(
        back_populates="clients",
        foreign_keys=[current_status_no],
    )
    updates: Mapped[list["ClientUpdate"]] = relationship(
        back_populates="client",
        cascade="all, delete-orphan",
    )

    def apply_updates(self, **changes: Any) -> None:
        for field_name, field_value in changes.items():
            setattr(self, field_name, field_value)
        self.touch()

    def touch(self) -> None:
        self.last_updated = datetime.now(timezone.utc)

    def to_dict(self) -> dict[str, Any]:
        return {
            "client_id": self.client_id,
            "client_name": self.client_name,
            "company_name": self.company_name,
            "phone": self.phone,
            "whatsapp_number": self.whatsapp_number,
            "email": self.email,
            "city": self.city,
            "assigned_to": self.assigned_to,
            "current_status_no": self.current_status_no,
            "requirement_summary": self.requirement_summary,
            "priority": self.priority,
            "created_date": self.created_date,
            "last_updated": self.last_updated,
        }


class ClientUpdate(Base):
    __tablename__ = "client_updates"
    __table_args__ = {"schema": "public"}

    update_id: Mapped[int] = mapped_column(BIGINT, primary_key=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("public.client_info.client_id"), nullable=False)
    update_type: Mapped[str] = mapped_column(Text, nullable=False)
    old_status_no: Mapped[int | None] = mapped_column(ForeignKey("public.status_master.status_no"))
    new_status_no: Mapped[int] = mapped_column(ForeignKey("public.status_master.status_no"), nullable=False)
    request_type: Mapped[str] = mapped_column(Text, nullable=False)
    request_subtype: Mapped[str] = mapped_column(Text, nullable=False)
    note: Mapped[str] = mapped_column(Text, nullable=False)
    followup_date: Mapped[date | None] = mapped_column(Date)
    followup_time: Mapped[time | None] = mapped_column(Time)
    created_by: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
    )

    client: Mapped[Client] = relationship(back_populates="updates")
    old_status: Mapped[StatusMaster | None] = relationship(
        back_populates="old_status_updates",
        foreign_keys=[old_status_no],
    )
    new_status: Mapped[StatusMaster] = relationship(
        back_populates="new_status_updates",
        foreign_keys=[new_status_no],
    )
