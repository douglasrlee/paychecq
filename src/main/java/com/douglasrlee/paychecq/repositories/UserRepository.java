package com.douglasrlee.paychecq.repositories;

import com.douglasrlee.paychecq.entities.UserEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<UserEntity, UUID> {
  UserEntity findByEmail(String email);
}
