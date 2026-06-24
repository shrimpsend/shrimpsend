package dev.ultrasend.backend.repository;

import dev.ultrasend.backend.entity.WebDavConnection;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface WebDavConnectionRepository extends JpaRepository<WebDavConnection, Long> {

    List<WebDavConnection> findByUserIdOrderBySortOrderAscIdAsc(Long userId);

    Optional<WebDavConnection> findByIdAndUserId(Long id, Long userId);
}
