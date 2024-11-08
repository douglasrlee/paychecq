package com.douglasrlee.paychecq.mappers;

public interface EntityResourceMapper<E, R> {
  E toEntity(R resource);
  R toResource(E entity);
}
