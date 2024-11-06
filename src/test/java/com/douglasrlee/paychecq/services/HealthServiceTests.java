package com.douglasrlee.paychecq.services;

import com.douglasrlee.paychecq.BaseTests;
import com.douglasrlee.paychecq.enums.HealthStatus;
import com.douglasrlee.paychecq.resources.external.HealthResource;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

public class HealthServiceTests extends BaseTests {
  @InjectMocks
  private HealthService healthService;

  // region getHealth
  @Test
  public void getHeath_Returns_HealthResource() {
    HealthResource healthResource = healthService.getHealth();

    assertNotNull(healthResource);
    assertEquals(healthResource.overallStatus, HealthStatus.UP);
  }
  // endregion
}
