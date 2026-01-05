"""
Payment Service.
Обработка платежей и возвратов с базовой логикой валидации.
"""
import secrets
import string
import uuid

from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.models.payment import Payment, TransactionStatus
from app.models.booking import Booking, BookingStatus, PaymentMethod


def validate_card_number(card_number: str) -> bool:
    """
    Very basic Luhn algorithm check for realistic mock validation.
    """
    # Remove spaces and dashes
    n = card_number.replace(" ", "").replace("-", "")
    if not n.isdigit() or len(n) < 13:
        return False
        
    # Luhn check (simplified for performance since it's a mock)
    r = [int(ch) for ch in n][::-1]
    return (sum(r[0::2]) + sum(sum(divmod(d*2, 10)) for d in r[1::2])) % 10 == 0

def process_payment(
    db: Session, 
    booking_id: int, 
    passenger_id: int, 
    amount: float, 
    method: PaymentMethod,
    card_info: str = None
) -> Payment:
    """
    Simulates payment processing. 
    Implements card number validation (Luhn) for CARD method.
    Uses flush() to integrate into parent transactions.
    """
    pay_status = TransactionStatus.SUCCESS
    
    if method == PaymentMethod.CARD and card_info:
        if not validate_card_number(card_info):
             pay_status = TransactionStatus.FAILED
    
    try:
        transaction_id = f"TXN-{secrets.token_hex(4).upper()}"
        payment = Payment(
            transaction_id=transaction_id,
            booking_id=booking_id,
            passenger_id=passenger_id,
            amount=amount,
            method=method,
            status=pay_status
        )
        db.add(payment)
        db.flush() 
        
        if pay_status == TransactionStatus.FAILED:
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail="Оплата отклонена банком. Пожалуйста, проверьте данные карты."
            )
            
        return payment
    except HTTPException: raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


def refund_payment(db: Session, booking_id: int) -> bool:
    """Marks a payment record as REFUNDED. Does not perform actual banking reversal."""
    payment = db.query(Payment).filter(
        Payment.booking_id == booking_id,
        Payment.status == TransactionStatus.SUCCESS
    ).first()
    
    if not payment:
        return False
        
    try:
        payment.status = TransactionStatus.REFUNDED
        db.add(payment)
        return True
    except Exception:
        return False
