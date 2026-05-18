import base64
import json
import hmac
import hashlib
from datetime import datetime, timedelta

SECRET_KEY = "optiflow-super-secret-key-for-karachi-logistics-command-center-2026"

def base64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('utf-8')

def base64url_decode(data: str) -> bytes:
    padding = '=' * (4 - len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)

def encode_jwt(payload: dict, expires_in_hours: int = 24) -> str:
    # Setup standard JWT fields
    header = {"alg": "HS256", "typ": "JWT"}
    header_json = json.dumps(header, separators=(',', ':')).encode('utf-8')
    
    # Expiry
    claims = payload.copy()
    if "exp" not in claims:
        claims["exp"] = int((datetime.utcnow() + timedelta(hours=expires_in_hours)).timestamp())
    
    payload_json = json.dumps(claims, separators=(',', ':')).encode('utf-8')
    
    header_b64 = base64url_encode(header_json)
    payload_b64 = base64url_encode(payload_json)
    
    signing_input = f"{header_b64}.{payload_b64}".encode('utf-8')
    signature = hmac.new(SECRET_KEY.encode('utf-8'), signing_input, hashlib.sha256).digest()
    signature_b64 = base64url_encode(signature)
    
    return f"{header_b64}.{payload_b64}.{signature_b64}"

def decode_jwt(token: str) -> dict:
    try:
        parts = token.split('.')
        if len(parts) != 3:
            raise ValueError("Malformed token")
        
        header_b64, payload_b64, signature_b64 = parts
        signing_input = f"{header_b64}.{payload_b64}".encode('utf-8')
        
        # Verify signature
        expected_signature = hmac.new(SECRET_KEY.encode('utf-8'), signing_input, hashlib.sha256).digest()
        expected_signature_b64 = base64url_encode(expected_signature)
        
        if not hmac.compare_digest(signature_b64, expected_signature_b64):
            raise ValueError("Token signature validation failed")
            
        payload_json = base64url_decode(payload_b64)
        claims = json.loads(payload_json.decode('utf-8'))
        
        # Check expiry
        if "exp" in claims and claims["exp"] < int(datetime.utcnow().timestamp()):
            raise ValueError("Token has expired")
            
        return claims
    except Exception as e:
        raise ValueError(f"Invalid token: {str(e)}")
