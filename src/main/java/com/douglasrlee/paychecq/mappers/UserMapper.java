package com.douglasrlee.paychecq.mappers;

import com.douglasrlee.paychecq.entities.UserEntity;
import com.douglasrlee.paychecq.resources.UserResource;
import org.springframework.stereotype.Component;

@Component
public class UserMapper implements EntityResourceMapper<UserEntity, UserResource> {
  @Override
  public UserEntity toEntity(UserResource userResource) {
    UserEntity userEntity = new UserEntity();
    userEntity.setName(userResource.getName());
    userEntity.setEmail(userResource.getEmail());

    return userEntity;
  }

  @Override
  public UserResource toResource(UserEntity userEntity) {
    UserResource userResource = new UserResource();
    userResource.setId(userEntity.getId());
    userResource.setName(userEntity.getName());
    userResource.setEmail(userEntity.getEmail());
    userResource.setCreatedAt(userEntity.getCreatedAt());
    userResource.setUpdatedAt(userEntity.getUpdatedAt());

    return userResource;
  }
}
