package com.douglasrlee.paychecq.configurations;

import com.douglasrlee.paychecq.exceptions.ExistingEmailException;
import org.springframework.http.HttpStatus;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class ExceptionConfiguration {
  @ResponseStatus(HttpStatus.BAD_REQUEST)
  @ExceptionHandler(MethodArgumentNotValidException.class)
  public Map<String, String> handleValidationExceptions(MethodArgumentNotValidException methodArgumentNotValidException) {
    Map<String, String> errors = new HashMap<>();

    methodArgumentNotValidException.getBindingResult().getAllErrors().forEach((error) -> {
      String fieldName = ((FieldError)error).getField();
      String errorMessage = error.getDefaultMessage();

      errors.put(fieldName, errorMessage);
    });

    return errors;
  }

  @ResponseStatus(HttpStatus.UNPROCESSABLE_ENTITY)
  @ExceptionHandler(ExistingEmailException.class)
  public Map<String, String> handleExistingEmailExceptions(ExistingEmailException existingEmailException) {
    Map<String, String> errors = new HashMap<>();

    String fieldName = "email";
    String errorMessage = existingEmailException.getMessage();

    errors.put(fieldName, errorMessage);

    return errors;
  }
}
