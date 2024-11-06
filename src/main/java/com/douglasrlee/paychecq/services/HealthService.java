package com.douglasrlee.paychecq.services;

import com.douglasrlee.paychecq.enums.HealthStatus;
import com.douglasrlee.paychecq.resources.external.HealthResource;
import org.springframework.stereotype.Service;

@Service
public class HealthService {
  public HealthResource getHealth() {
    HealthResource healthResource = new HealthResource();
    healthResource.overallStatus = HealthStatus.UP;

    return healthResource;
  }
}
