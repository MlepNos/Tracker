from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import (
    User,
    Collection,
    CollectionField,
    Item,
    ItemFieldValue,
)
from app.schemas import (
    CollectionCreate,
    CollectionOut,
    CollectionFieldCreate,
    CollectionFieldOut,
    ItemCreate,
    ItemOut,
    ItemFieldValueUpsert,
    ItemFieldValueOut,
    RegisterRequest,
    LoginRequest,
    TokenPair,
    RefreshRequest,
)
from app.auth import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
)

router = APIRouter()


def get_owned_collection(db: Session, collection_id: UUID, owner_id: UUID) -> Collection:
    col = db.get(Collection, collection_id)
    if not col or col.owner_id != owner_id:
        raise HTTPException(status_code=404, detail="Collection not found")
    return col


# -------------------------
# Collections
# -------------------------

@router.post("/collections", response_model=CollectionOut)
def create_collection(
    payload: CollectionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    c = Collection(owner_id=current_user.id, name=payload.name, description=payload.description)
    db.add(c)
    db.commit()
    db.refresh(c)
    return c


@router.get("/collections", response_model=list[CollectionOut])
def list_collections(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(Collection)
        .filter(Collection.owner_id == current_user.id)
        .order_by(Collection.created_at.desc())
        .all()
    )


# -------------------------
# Fields
# -------------------------

@router.post("/collections/{collection_id}/fields", response_model=CollectionFieldOut)
def create_field(
    collection_id: UUID,
    payload: CollectionFieldCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    col = get_owned_collection(db, collection_id, current_user.id)

    existing = (
        db.query(CollectionField)
        .filter(
            CollectionField.collection_id == col.id,
            CollectionField.field_key == payload.field_key,
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="field_key already exists in this collection")

    f = CollectionField(
        collection_id=col.id,
        field_key=payload.field_key,
        label=payload.label,
        data_type=payload.data_type,
        required=payload.required,
        sort_order=payload.sort_order,
        options_json=payload.options_json,
    )
    db.add(f)
    db.commit()
    db.refresh(f)
    return f


@router.get("/collections/{collection_id}/fields", response_model=list[CollectionFieldOut])
def list_fields(
    collection_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    col = get_owned_collection(db, collection_id, current_user.id)

    return (
        db.query(CollectionField)
        .filter(CollectionField.collection_id == col.id)
        .order_by(CollectionField.sort_order.asc(), CollectionField.created_at.asc())
        .all()
    )


# -------------------------
# Items
# -------------------------

@router.post("/collections/{collection_id}/items", response_model=ItemOut)
def create_item(
    collection_id: UUID,
    payload: ItemCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    col = get_owned_collection(db, collection_id, current_user.id)

    item = Item(
        collection_id=col.id,
        title=payload.title,
        notes=payload.notes,
        cover_image_url=payload.cover_image_url,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


@router.get("/collections/{collection_id}/items", response_model=list[ItemOut])
def list_items(
    collection_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    col = get_owned_collection(db, collection_id, current_user.id)

    return (
        db.query(Item)
        .filter(Item.collection_id == col.id)
        .order_by(Item.created_at.desc())
        .all()
    )


# -------------------------
# Item field values
# -------------------------

@router.post("/items/{item_id}/values", response_model=list[ItemFieldValueOut])
def upsert_item_values(
    item_id: UUID,
    payload: list[ItemFieldValueUpsert],
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    item = db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    # verify ownership via collection
    col = get_owned_collection(db, item.collection_id, current_user.id)

    fields = (
        db.query(CollectionField)
        .filter(CollectionField.collection_id == col.id)
        .all()
    )
    field_by_key = {f.field_key: f for f in fields}

    results: list[ItemFieldValue] = []

    for entry in payload:
        f = field_by_key.get(entry.field_key)
        if not f:
            raise HTTPException(status_code=400, detail=f"Unknown field_key: {entry.field_key}")

        new_value = {"value": entry.value}

        existing = (
            db.query(ItemFieldValue)
            .filter(ItemFieldValue.item_id == item_id, ItemFieldValue.field_id == f.id)
            .first()
        )
        if existing:
            existing.value_json = new_value
            results.append(existing)
        else:
            v = ItemFieldValue(item_id=item_id, field_id=f.id, value_json=new_value)
            db.add(v)
            results.append(v)

    db.commit()
    for r in results:
        db.refresh(r)

    return results


@router.get("/items/{item_id}/values", response_model=list[ItemFieldValueOut])
def list_item_values(
    item_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    item = db.get(Item, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    # verify ownership via collection
    _ = get_owned_collection(db, item.collection_id, current_user.id)

    return db.query(ItemFieldValue).filter(ItemFieldValue.item_id == item_id).all()


# -------------------------
# Auth
# -------------------------

@router.post("/auth/register", response_model=TokenPair)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")

    user = User(email=payload.email, password_hash=hash_password(payload.password))
    db.add(user)
    db.commit()
    db.refresh(user)

    return TokenPair(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/auth/login", response_model=TokenPair)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email).first()
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    return TokenPair(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/auth/refresh", response_model=TokenPair)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)):
    token_payload = decode_token(payload.refresh_token)
    if token_payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Wrong token type")

    sub = token_payload.get("sub")
    if not sub:
        raise HTTPException(status_code=401, detail="Invalid token")

    try:
        user_id = UUID(sub)
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return TokenPair(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )
