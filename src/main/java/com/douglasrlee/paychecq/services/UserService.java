package com.douglasrlee.paychecq.services;

import com.douglasrlee.paychecq.entities.UserEntity;
import com.douglasrlee.paychecq.exceptions.ExistingEmailException;
import com.douglasrlee.paychecq.mappers.UserMapper;
import com.douglasrlee.paychecq.repositories.UserRepository;
import com.douglasrlee.paychecq.resources.UserResource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class UserService implements UserDetailsService {
  private final UserRepository userRepository;
  private final UserMapper userMapper;
  private final PasswordEncoder passwordEncoder;

  @Autowired
  public UserService(UserRepository userRepository, UserMapper userMapper, PasswordEncoder passwordEncoder) {
    this.userRepository = userRepository;
    this.userMapper = userMapper;
    this.passwordEncoder = passwordEncoder;
  }

  public UserEntity createUser(UserResource userResource) {
    UserEntity existingUserEntity = this.userRepository.findByEmail(userResource.getEmail());

    if (existingUserEntity != null) {
      throw new ExistingEmailException(userResource.getEmail() + " already exists");
    }

    UserEntity userEntity = this.userMapper.toEntity(userResource);
    userEntity.setPasswordHash(this.passwordEncoder.encode(userResource.getPassword()));

    return this.userRepository.save(userEntity);
  }

  @Override
  public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
    UserEntity userEntity = this.userRepository.findByEmail(username);

    if (userEntity == null) {
      throw new UsernameNotFoundException("User with username " + username + " was not found");
    }

    return User
        .builder()
        .username(userEntity.getEmail())
        .password(userEntity.getPasswordHash())
        .roles("User")
        .build();
  }
}
