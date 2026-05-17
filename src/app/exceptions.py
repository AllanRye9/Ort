"""
Unified error handling for the Ort marketplace API.

Defines a structured exception hierarchy and error response format
to ensure consistent error handling across all API endpoints.
"""
from enum import Enum
from typing import Optional, Any, Dict


class ErrorCode(str, Enum):
    """Standard error codes for API responses."""
    
    # Authentication & Authorization
    UNAUTHORIZED = "UNAUTHORIZED"
    FORBIDDEN = "FORBIDDEN"
    INVALID_TOKEN = "INVALID_TOKEN"
    TOKEN_EXPIRED = "TOKEN_EXPIRED"
    
    # Validation
    VALIDATION_ERROR = "VALIDATION_ERROR"
    INVALID_INPUT = "INVALID_INPUT"
    MISSING_FIELD = "MISSING_FIELD"
    
    # Resource
    NOT_FOUND = "NOT_FOUND"
    ALREADY_EXISTS = "ALREADY_EXISTS"
    
    # Server
    INTERNAL_ERROR = "INTERNAL_ERROR"
    SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE"
    
    # Business Logic
    INSUFFICIENT_PERMISSIONS = "INSUFFICIENT_PERMISSIONS"
    OPERATION_NOT_ALLOWED = "OPERATION_NOT_ALLOWED"
    RESOURCE_CONFLICT = "RESOURCE_CONFLICT"
    
    # Rate Limiting
    RATE_LIMIT_EXCEEDED = "RATE_LIMIT_EXCEEDED"


class AppException(Exception):
    """
    Base exception for all application errors.
    
    All app exceptions should inherit from this class to provide
    consistent error handling, logging, and response formatting.
    """
    
    def __init__(
        self,
        message: str,
        status_code: int = 500,
        error_code: ErrorCode = ErrorCode.INTERNAL_ERROR,
        details: Optional[Dict[str, Any]] = None,
    ):
        self.message = message
        self.status_code = status_code
        self.error_code = error_code
        self.details = details or {}
        super().__init__(self.message)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert exception to API response dict."""
        return {
            "detail": self.message,
            "error_code": self.error_code.value,
            "status_code": self.status_code,
            **({"details": self.details} if self.details else {}),
        }


class BadRequestError(AppException):
    """400 Bad Request – Invalid input or malformed request."""
    
    def __init__(
        self,
        message: str,
        error_code: ErrorCode = ErrorCode.VALIDATION_ERROR,
        details: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(
            message=message,
            status_code=400,
            error_code=error_code,
            details=details,
        )


class ValidationError(BadRequestError):
    """Validation failure with field-level details."""
    
    def __init__(
        self,
        message: str,
        field: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None,
    ):
        if field:
            if details is None:
                details = {}
            details["field"] = field
        super().__init__(
            message=message,
            error_code=ErrorCode.VALIDATION_ERROR,
            details=details,
        )


class UnauthorizedError(AppException):
    """401 Unauthorized – Invalid or missing authentication."""
    
    def __init__(self, message: str = "Authentication required"):
        super().__init__(
            message=message,
            status_code=401,
            error_code=ErrorCode.UNAUTHORIZED,
        )


class InvalidTokenError(AppException):
    """Invalid or expired JWT token."""
    
    def __init__(self, message: str = "Invalid or expired token"):
        super().__init__(
            message=message,
            status_code=401,
            error_code=ErrorCode.INVALID_TOKEN,
        )


class ForbiddenError(AppException):
    """403 Forbidden – Authenticated but lacks permissions."""
    
    def __init__(self, message: str = "Insufficient permissions"):
        super().__init__(
            message=message,
            status_code=403,
            error_code=ErrorCode.FORBIDDEN,
        )


class NotFoundError(AppException):
    """404 Not Found – Resource does not exist."""
    
    def __init__(
        self,
        message: str = "Resource not found",
        resource_type: Optional[str] = None,
        resource_id: Optional[Any] = None,
    ):
        details = {}
        if resource_type:
            details["resource_type"] = resource_type
        if resource_id:
            details["resource_id"] = resource_id
        
        super().__init__(
            message=message,
            status_code=404,
            error_code=ErrorCode.NOT_FOUND,
            details=details,
        )


class ConflictError(AppException):
    """409 Conflict – Resource already exists or state conflict."""
    
    def __init__(
        self,
        message: str,
        error_code: ErrorCode = ErrorCode.ALREADY_EXISTS,
        details: Optional[Dict[str, Any]] = None,
    ):
        super().__init__(
            message=message,
            status_code=409,
            error_code=error_code,
            details=details,
        )


class OperationNotAllowedError(AppException):
    """Cannot perform requested operation due to business logic."""
    
    def __init__(self, message: str, details: Optional[Dict[str, Any]] = None):
        super().__init__(
            message=message,
            status_code=422,  # Unprocessable Entity
            error_code=ErrorCode.OPERATION_NOT_ALLOWED,
            details=details,
        )


class RateLimitError(AppException):
    """429 Too Many Requests."""
    
    def __init__(
        self,
        message: str = "Rate limit exceeded",
        retry_after: Optional[int] = None,
    ):
        details = {}
        if retry_after:
            details["retry_after"] = retry_after
        
        super().__init__(
            message=message,
            status_code=429,
            error_code=ErrorCode.RATE_LIMIT_EXCEEDED,
            details=details,
        )


class InternalServerError(AppException):
    """500 Internal Server Error."""
    
    def __init__(self, message: str = "Internal server error"):
        super().__init__(
            message=message,
            status_code=500,
            error_code=ErrorCode.INTERNAL_ERROR,
        )


class ServiceUnavailableError(AppException):
    """503 Service Unavailable."""
    
    def __init__(
        self,
        message: str = "Service temporarily unavailable",
        retry_after: Optional[int] = None,
    ):
        details = {}
        if retry_after:
            details["retry_after"] = retry_after
        
        super().__init__(
            message=message,
            status_code=503,
            error_code=ErrorCode.SERVICE_UNAVAILABLE,
            details=details,
        )
