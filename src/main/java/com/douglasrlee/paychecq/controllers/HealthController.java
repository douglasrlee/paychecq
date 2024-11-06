package com.douglasrlee.paychecq.controllers;

import com.douglasrlee.paychecq.resources.external.HealthResource;
import com.douglasrlee.paychecq.services.HealthService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {
  private final HealthService healthService;

  @Autowired
  public HealthController(HealthService healthService) {
    this.healthService = healthService;
  }

  @RequestMapping(method = RequestMethod.GET, path = "/health", produces = "application/json")
  public HealthResource index() {
    return this.healthService.getHealth();
  }
}
