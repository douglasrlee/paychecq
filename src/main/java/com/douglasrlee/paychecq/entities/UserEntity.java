package com.douglasrlee.paychecq.entities;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;

@Entity(name = "users")
public class UserEntity extends BaseEntity {
  @Column(nullable = false)
  private String name;
  @Column(nullable = false)
  private String email;
  @Column(nullable = false)
  private String passwordHash;

  public void setName(String name) {
    this.name = name;
  }

  public String getName() {
    return name;
  }

  public void setEmail(String email) {
    this.email = email;
  }

  public String getEmail() {
    return email;
  }

  public void setPasswordHash(String passwordHash) {
    this.passwordHash = passwordHash;
  }

  public String getPasswordHash() {
    return passwordHash;
  }
}
