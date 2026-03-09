"""
User Service Microservice
Provides authentication and user management APIs
"""
import os
import sqlite3
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional, List
from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import jwt

app = FastAPI(title="User Service API", version="1.0.0")
security = HTTPBearer()

# JWT Configuration
JWT_SECRET = os.getenv("JWT_SECRET", "your-secret-key-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_HOURS = 24
JWT_ISS = os.getenv("JWT_ISS", "user-service-issuer")

# Database file path
DB_PATH = os.getenv("DB_PATH", "/app/data/users.db")


class UserCreate(BaseModel):
    username: str
    password: str
    email: Optional[str] = None


class UserResponse(BaseModel):
    id: int
    username: str
    email: Optional[str] = None
    created_at: str


class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenVerifyResponse(BaseModel):
    valid: bool
    username: Optional[str] = None
    message: str


def init_db():
    """Initialize SQLite database with users table"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT,
            password_hash TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # Create default admin user if not exists
    cursor.execute("SELECT COUNT(*) FROM users WHERE username = ?", ("admin",))
    if cursor.fetchone()[0] == 0:
        password_hash = hashlib.sha256("admin123".encode()).hexdigest()
        cursor.execute(
            "INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)",
            ("admin", "admin@example.com", password_hash)
        )
    
    conn.commit()
    conn.close()


def hash_password(password: str) -> str:
    """Hash password using SHA256"""
    return hashlib.sha256(password.encode()).hexdigest()


def verify_password(password: str, password_hash: str) -> bool:
    """Verify password against hash"""
    return hash_password(password) == password_hash


def create_jwt_token(username: str) -> str:
    """Create JWT token with iss claim for Kong JWT plugin validation"""
    payload = {
        "iss": JWT_ISS,
        "username": username,
        "exp": datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS),
        "iat": datetime.utcnow()
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def verify_jwt_token(token: str) -> Optional[dict]:
    """Verify JWT token"""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Dependency to get current authenticated user"""
    token = credentials.credentials
    payload = verify_jwt_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return payload


@app.on_event("startup")
async def startup_event():
    """Initialize database on startup"""
    # Ensure directory exists
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    init_db()


@app.get("/health")
async def health_check():
    """Health check endpoint - no authentication required"""
    return {"status": "healthy", "service": "user-service"}


@app.post("/login", response_model=LoginResponse)
async def login(login_data: LoginRequest):
    """Authenticate user and return JWT token"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("SELECT id, username, password_hash FROM users WHERE username = ?", (login_data.username,))
    user = cursor.fetchone()
    conn.close()
    
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid username or password")
    
    user_id, username, password_hash = user
    
    if not verify_password(login_data.password, password_hash):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    
    token = create_jwt_token(username)
    return LoginResponse(access_token=token, token_type="bearer")


@app.get("/verify", response_model=TokenVerifyResponse)
async def verify_token(authorization: Optional[str] = Header(None)):
    """Verify JWT token - no authentication required (bypass for Kong)"""
    if not authorization or not authorization.startswith("Bearer "):
        return TokenVerifyResponse(valid=False, message="No token provided")
    
    token = authorization.replace("Bearer ", "")
    payload = verify_jwt_token(token)
    
    if payload:
        return TokenVerifyResponse(valid=True, username=payload.get("username"), message="Token is valid")
    else:
        return TokenVerifyResponse(valid=False, message="Token is invalid or expired")


@app.get("/users", response_model=List[UserResponse])
async def get_users(current_user: dict = Depends(get_current_user)):
    """Get all users - requires JWT authentication"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("SELECT id, username, email, created_at FROM users")
    users = cursor.fetchall()
    conn.close()
    
    return [
        UserResponse(
            id=row[0],
            username=row[1],
            email=row[2],
            created_at=row[3]
        )
        for row in users
    ]


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
