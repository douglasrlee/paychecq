package com.douglasrlee.paychecq.controllers;

import com.douglasrlee.paychecq.mappers.UserMapper;
import com.douglasrlee.paychecq.resources.UserResource;
import com.douglasrlee.paychecq.services.UserService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class UserController {
  private final UserService userService;
  private final UserMapper userMapper;

  @Autowired
  public UserController(UserService userService, UserMapper userMapper) {
    this.userService = userService;
    this.userMapper = userMapper;
  }

  @RequestMapping(method = RequestMethod.POST, value = "/users", consumes = "application/json", produces = "application/json")
  public UserResource create(@Valid @RequestBody UserResource userResource) {
    return this.userMapper.toResource(this.userService.createUser(userResource));
  }
}
