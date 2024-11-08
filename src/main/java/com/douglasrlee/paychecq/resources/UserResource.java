package com.douglasrlee.paychecq.resources;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotNull;
import org.hibernate.validator.constraints.Length;

import java.util.UUID;

public class UserResource extends BaseResource {
  private UUID id;
  @NotNull(message = "must be present")
  @Length(max = 255, message = "must be less than 255 characters")
  private String name;
  @NotNull(message = "must be present")
  private String email;
  @NotNull(message = "must be present")
  @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
  private String password;

  public void setId(UUID id) {
    this.id = id;
  }

  public UUID getId() {
    return id;
  }

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

  public void setPassword(String password) {
    this.password = password;
  }

  public String getPassword() {
    return password;
  }
}
