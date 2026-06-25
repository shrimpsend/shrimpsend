-- Optional manual migration for webdav_connections.client_app
-- Hibernate ddl-auto=update also adds this column automatically.

ALTER TABLE webdav_connections
  ADD COLUMN client_app VARCHAR(64) NULL AFTER root_path;
