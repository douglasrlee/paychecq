package com.douglasrlee.paychecq.exceptions;

public class ExistingEmailException extends RuntimeException {
  public ExistingEmailException(String message) {
    super(message);
  }
}
