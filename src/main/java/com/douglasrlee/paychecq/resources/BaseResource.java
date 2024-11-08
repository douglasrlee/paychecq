package com.douglasrlee.paychecq.resources;

import java.time.OffsetDateTime;

public class BaseResource {
  private OffsetDateTime createdAt;
  private OffsetDateTime updatedAt;

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
