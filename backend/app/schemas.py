from pydantic import BaseModel, Field
from uuid import UUID
from datetime import datetime


class CollectionCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    collection_type: str = "custom"
    icon_url: str | None = None

class CollectionOut(BaseModel):
    id: UUID
    owner_id: UUID
    name: str
    description: str | None
    created_at: datetime
    updated_at: datetime
    collection_type: str
    icon_url: str | None
    class Config:
        from_attributes = True



class CollectionFieldCreate(BaseModel):
    field_key: str = Field(min_length=1, max_length=64, pattern=r"^[a-zA-Z][a-zA-Z0-9_]*$")
    label: str = Field(min_length=1, max_length=120)
    data_type: str = Field(min_length=1, max_length=32)  # we'll validate allowed values later
    required: bool = False
    sort_order: int = 0
    options_json: dict | None = None


class CollectionFieldOut(BaseModel):
    id: UUID
    collection_id: UUID
    field_key: str
    label: str
    data_type: str
    required: bool
    sort_order: int
    options_json: dict | None
    created_at: datetime

    class Config:
        from_attributes = True
        
        

class ItemCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    notes: str | None = Field(default=None, max_length=2000)
    cover_image_url: str | None = Field(default=None, max_length=1000)


class ItemOut(BaseModel):
    id: UUID
    collection_id: UUID
    title: str
    notes: str | None
    cover_image_url: str | None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True



class ItemFieldValueUpsert(BaseModel):
    field_key: str = Field(min_length=1, max_length=64)
    value: object  # can be str/bool/number/list/etc


class ItemFieldValueOut(BaseModel):
    id: UUID
    item_id: UUID
    field_id: UUID
    field_key: str            # ✅ ADD
    label: str                # ✅ ADD (optional but recommended)
    data_type: str            # ✅ ADD (optional but recommended)

    value: object | None = None
    value_json: dict

    class Config:
        from_attributes = True



class RegisterRequest(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=6, max_length=128)


class LoginRequest(BaseModel):
    email: str
    password: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str
