from typing import Literal

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=128)


class MemberCreate(BaseModel):
    username: str = Field(min_length=3, max_length=64, pattern=r"^[a-zA-Z0-9_.-]+$")
    password: str = Field(min_length=12, max_length=128)
    role: Literal["admin", "operator", "observer"]


class MemberUpdate(BaseModel):
    enabled: bool
    role: Literal["admin", "operator", "observer"]


class LinkRequest(BaseModel):
    node_id: str
    generation: int
    scan_id: str


class CommandRequest(BaseModel):
    node_id: str
    link_id: str
    action: Literal["power", "door", "brightness", "pan", "tilt", "zoom", "restart", "recover", "diagnostic", "disconnect"]
    value: bool | float | str | None = None
    expected_version: int
    key: str = Field(min_length=8, max_length=64)
    confirmation_id: str | None = None


class FaultRequest(BaseModel):
    node_id: str
    fault: Literal["OUTPUT_FAILURE", "SIGNAL_LOSS", "THERMAL_HIGH"] | None


class SimulationRequest(BaseModel):
    action: Literal["pause", "resume", "reset", "scenario"]
