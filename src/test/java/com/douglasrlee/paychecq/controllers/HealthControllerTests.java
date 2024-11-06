package com.douglasrlee.paychecq.controllers;

import com.douglasrlee.paychecq.enums.HealthStatus;
import com.douglasrlee.paychecq.resources.external.HealthResource;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.reactive.AutoConfigureWebTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureWebTestClient
public class HealthControllerTests {
  @Autowired
  private TestRestTemplate restTemplate;

  @Test
  public void index_Returns_HealthResource() {
    HealthResource healthResource = this.restTemplate.getForObject("/health", HealthResource.class);

    assertNotNull(healthResource);
    assertEquals(healthResource.overallStatus, HealthStatus.UP);
  }
}
