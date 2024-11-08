package com.douglasrlee.paychecq.configurations;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;

import static org.springframework.security.config.Customizer.withDefaults;

@Configuration
@EnableWebSecurity
public class SecurityConfiguration {
  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity httpSecurity) throws Exception {
    return httpSecurity.authorizeHttpRequests(authorize -> {
      authorize.requestMatchers("/health", "/error").permitAll();
      authorize.requestMatchers(HttpMethod.POST, "/users").permitAll();
      authorize.anyRequest().authenticated();
    }).httpBasic(withDefaults()).csrf(AbstractHttpConfigurer::disable).build();
  }
}
