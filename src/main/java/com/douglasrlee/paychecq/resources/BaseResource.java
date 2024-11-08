package com.douglasrlee.paychecq.resources;

import java.time.OffsetDateTime;
import java.util.UUID;

public class BaseResource {
  private UUID id;
  private OffsetDateTime createdAt;
  private OffsetDateTime updatedAt;

  public void setId(UUID id) {
    this.id = id;
  }

  public UUID getId() {
    return id;
  }

  public void setCreatedAt(OffsetDateTime createdAt) {
    this.createdAt = createdAt;
  }

  public OffsetDateTime getCreatedAt() {
    return createdAt;
  }

  public void setUpdatedAt(OffsetDateTime updatedAt) {
    this.updatedAt = updatedAt;
  }

  public OffsetDateTime getUpdatedAt() {
    return updatedAt;
  }
}
