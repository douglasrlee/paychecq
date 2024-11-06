package com.douglasrlee.paychecq;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.mockito.MockitoAnnotations;

public class BaseTests {
  private AutoCloseable openMocksAutoCloseable;

  @BeforeEach
  public void initMocks() {
    this.openMocksAutoCloseable = MockitoAnnotations.openMocks( this);
  }

  @AfterEach
  public void closeMocks() throws Exception {
    this.openMocksAutoCloseable.close();
  }
}
